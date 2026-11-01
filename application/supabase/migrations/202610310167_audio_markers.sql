begin;
alter table uniion_private.meeting_audio add column duration_ms integer check(duration_ms between 0 and 3600000);
alter table uniion_private.meeting_audio add unique(organization_id,meeting_id,id);
create table uniion_private.meeting_audio_markers(
 organization_id uuid not null,meeting_id uuid not null,audio_id uuid not null,
 version integer not null check(version>0),markers jsonb not null check(jsonb_typeof(markers)='array'),
 actor uuid not null references auth.users,created_at timestamptz not null default now(),
 primary key(organization_id,meeting_id,audio_id,version),
 foreign key(organization_id,meeting_id,audio_id) references uniion_private.meeting_audio(organization_id,meeting_id,id)
);
alter table uniion_private.meeting_audio_markers enable row level security;
revoke all on uniion_private.meeting_audio_markers from public,anon,authenticated;
-- Only the existing restricted byte-processing identity can attest duration.
create function public.uniion_meeting_audio_duration(p_id uuid,p_sha text,p_duration_ms integer)
returns void language plpgsql security definer set search_path='' as $$
declare f uniion_private.meeting_audio;
begin
 if not uniion_private.is_scanner() or p_duration_ms is null or p_duration_ms not between 0 and 3600000 then raise insufficient_privilege;end if;
 select * into f from uniion_private.meeting_audio where id=p_id for update;
 if not found or f.status<>'clean' or f.sha256 is distinct from p_sha or (f.duration_ms is not null and f.duration_ms<>p_duration_ms) then raise insufficient_privilege;end if;
 if f.duration_ms is not null then return;end if;
 update uniion_private.meeting_audio set duration_ms=p_duration_ms where id=p_id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(f.organization_id,auth.uid(),'meeting.audio.duration',jsonb_build_object('audio',f.id,'durationMs',p_duration_ms));
end$$;
create function public.uniion_meeting_audio_markers(p_org uuid,p_meeting uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare meta jsonb;aid uuid;d integer;v integer;items jsonb;item jsonb;ids uuid[]='{}';marker_id uuid;
begin
 if p_action is null or p_action not in ('get','save') or jsonb_typeof(p_payload) is distinct from 'object' or jsonb_typeof(p_payload->'audio') is distinct from 'string' then raise insufficient_privilege;end if;
 aid=(p_payload->>'audio')::uuid;
 -- Parent RPC locks the meeting and enforces source ACL, consent and clean status.
 if p_action='save' then
  perform public.uniion_meeting_audio(p_org,p_meeting,'uploaded',jsonb_build_object('audio',aid));
 else
  perform public.uniion_meeting_audio(p_org,p_meeting,'listen',jsonb_build_object('audio',aid,'audit',false));
 end if;
 select duration_ms into d from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting and id=aid;
 if d is null then raise insufficient_privilege;end if;
 select version,markers into v,items from uniion_private.meeting_audio_markers where organization_id=p_org and meeting_id=p_meeting and audio_id=aid order by version desc limit 1;
 v=coalesce(v,0);items=coalesce(items,'[]');
 if p_action='save' then
  if not(p_payload ?& array['audio','version','markers']) or p_payload-array['audio','version','markers']<>'{}'
   or jsonb_typeof(p_payload->'version') is distinct from 'number' or (p_payload->>'version') !~ '^(0|[1-9][0-9]{0,8})$'
   or v<>(p_payload->>'version')::int or jsonb_typeof(p_payload->'markers') is distinct from 'array' then raise insufficient_privilege;end if;
  items=p_payload->'markers';
  if jsonb_array_length(items)>100 or octet_length(items::text)>150000 then raise insufficient_privilege;end if;
  for item in select value from jsonb_array_elements(items) loop
   if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['id','timeMs','kind','note']) or item-array['id','timeMs','kind','note']<>'{}'
    or jsonb_typeof(item->'id') is distinct from 'string' or jsonb_typeof(item->'timeMs') is distinct from 'number' or (item->>'timeMs') !~ '^(0|[1-9][0-9]{0,8})$'
    or (item->>'timeMs')::int>d or jsonb_typeof(item->'kind') is distinct from 'string' or item->>'kind' not in ('vote','decision','engagement','desaccord','verifier','diverse','point')
    or jsonb_typeof(item->'note') is distinct from 'string' or length(item->>'note')>1000 then raise insufficient_privilege;end if;
   marker_id=(item->>'id')::uuid;
   if marker_id=any(ids) then raise insufficient_privilege;end if;ids=array_append(ids,marker_id);
  end loop;
  v=v+1;
  insert into uniion_private.meeting_audio_markers values(p_org,p_meeting,aid,v,items,auth.uid(),now());
 else
  if p_payload-array['audio']<>'{}' then raise insufficient_privilege;end if;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.markers.'||p_action,jsonb_build_object('audio',aid,'version',v));
 return jsonb_build_object('audio',aid,'version',v,'durationMs',d,'markers',items);
exception when invalid_text_representation or numeric_value_out_of_range then raise insufficient_privilege;
end$$;
revoke all on function public.uniion_meeting_audio_duration(uuid,text,integer),public.uniion_meeting_audio_markers(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_meeting_audio_duration(uuid,text,integer),public.uniion_meeting_audio_markers(uuid,uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

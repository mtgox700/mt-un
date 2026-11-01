begin;
create table uniion_private.meeting_audio_chunks(
 audio_id uuid not null references uniion_private.meeting_audio(id),part integer not null check(part between 0 and 19),
 bytes bytea not null check(octet_length(bytes) between 1 and 262144),primary key(audio_id,part)
);
alter table uniion_private.meeting_audio_chunks enable row level security;
revoke all on uniion_private.meeting_audio_chunks from public,anon,authenticated;
create function public.uniion_meeting_audio_setup(p_org uuid,p_meeting uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources;g uniion_private.meeting_audio_grants;c uniion_private.meeting_consents;u uuid;v integer;mode text;
begin
 perform public.uniion_module_use(p_org,'reunions');
 select * into r from public.uniion_resources where organization_id=p_org and id=p_meeting and module='reunions' for update;
 if not found or not uniion_private.actor_resource(p_org,p_meeting,auth.uid(),false) or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='manage' then
  if not uniion_private.authority(p_org,auth.uid(),'rights') or not uniion_private.actor_resource(p_org,p_meeting,auth.uid(),true)
   or p_payload-array['email','mode']<>'{}' or jsonb_typeof(p_payload->'email') is distinct from 'string' or jsonb_typeof(p_payload->'mode') is distinct from 'string' then raise insufficient_privilege;end if;
  mode=p_payload->>'mode';if mode not in ('read','write','download','revoke') then raise insufficient_privilege;end if;
  select id into u from auth.users where lower(email)=lower(btrim(p_payload->>'email'));
  if u is null then raise insufficient_privilege;end if;
  select version into v from uniion_private.meeting_audio_grants where organization_id=p_org and meeting_id=p_meeting and user_id=u;
  return public.uniion_meeting_audio(p_org,p_meeting,'grant',jsonb_build_object('user',u,'version',coalesce(v,0),'read',mode<>'revoke','write',mode in ('write','download'),'download',mode='download'));
 end if;
 if p_action is distinct from 'status' or p_payload<>'{}' then raise insufficient_privilege;end if;
 select * into g from uniion_private.meeting_audio_grants where organization_id=p_org and meeting_id=p_meeting and user_id=auth.uid();
 select * into c from uniion_private.meeting_consents where organization_id=p_org and meeting_id=p_meeting;
 return jsonb_build_object('meetingVersion',r.version,'consentVersion',coalesce(c.version,0),'consentCurrent',coalesce(c.accepted and c.meeting_version=r.version,false),
 'read',coalesce(g.can_read,false),'write',coalesce(g.can_read and g.can_write,false) and uniion_private.actor_resource(p_org,p_meeting,auth.uid(),true),
 'download',coalesce(g.can_read and g.can_download,false),'manage',uniion_private.authority(p_org,auth.uid(),'rights') and uniion_private.actor_resource(p_org,p_meeting,auth.uid(),true));
end$$;
create function public.uniion_meeting_audio_transfer(p_org uuid,p_meeting uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f uniion_private.meeting_audio;partno integer;b bytea;old bytea;result bytea;
begin
 perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');
 if jsonb_typeof(p_payload) is distinct from 'object' or jsonb_typeof(p_payload->'audio') is distinct from 'string' then raise insufficient_privilege;end if;
 select * into f from uniion_private.meeting_audio where id=(p_payload->>'audio')::uuid and organization_id=p_org and meeting_id=p_meeting and actor=auth.uid() for update;
 if not found or f.status='blocked' or not exists(select 1 from uniion_private.meeting_consents where organization_id=p_org and meeting_id=p_meeting and version=f.consent_version and accepted) then raise insufficient_privilege;end if;
 if p_action='put' then
  if p_payload-array['audio','part','content']<>'{}' or jsonb_typeof(p_payload->'part') is distinct from 'number' or (p_payload->>'part') !~ '^(0|[1-9][0-9]?)$' or jsonb_typeof(p_payload->'content') is distinct from 'string' or length(p_payload->>'content')>349528 then raise insufficient_privilege;end if;
  partno=(p_payload->>'part')::int;b=decode(p_payload->>'content','base64');
  if partno not between 0 and (f.size-1)/262144 or octet_length(b)<>least(262144,f.size-partno*262144) then raise insufficient_privilege;end if;
  select bytes into old from uniion_private.meeting_audio_chunks where audio_id=f.id and part=partno;
  if found then
   if old<>b then raise insufficient_privilege;end if;
  else
   if f.status<>'pending' then raise insufficient_privilege;end if;
   insert into uniion_private.meeting_audio_chunks values(f.id,partno,b);
  end if;
 elsif p_action='assemble' then
  if p_payload-array['audio']<>'{}' then raise insufficient_privilege;end if;
  select string_agg(bytes,''::bytea order by part) into result from uniion_private.meeting_audio_chunks where audio_id=f.id;
  if result is null or octet_length(result)<>f.size then raise insufficient_privilege;end if;
  return jsonb_build_object('filename',f.filename,'request_id',f.request_id,'consentVersion',f.consent_version,'content',encode(result,'base64'),'sha256',f.sha256);
 elsif p_action is distinct from 'status' or p_payload-array['audio']<>'{}' then raise insufficient_privilege;end if;
 return jsonb_build_object('audio',f.id,'parts',coalesce((select jsonb_agg(part order by part) from uniion_private.meeting_audio_chunks where audio_id=f.id),'[]'),'status',f.status);
exception when invalid_text_representation or numeric_value_out_of_range or check_violation then raise insufficient_privilege;
end$$;
revoke all on function public.uniion_meeting_audio_setup(uuid,uuid,text,jsonb),public.uniion_meeting_audio_transfer(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_meeting_audio_setup(uuid,uuid,text,jsonb),public.uniion_meeting_audio_transfer(uuid,uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

begin;
create table uniion_private.meeting_audio_grants(
 organization_id uuid not null,meeting_id uuid not null,user_id uuid not null references auth.users,
 can_read boolean not null,can_write boolean not null,can_download boolean not null,
 version integer not null check(version>0),primary key(organization_id,meeting_id,user_id),
 foreign key(organization_id,meeting_id) references public.uniion_resources(organization_id,id)
);
create table uniion_private.meeting_audio(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,meeting_id uuid not null,
 request_id uuid not null,actor uuid not null references auth.users,
 consent_version integer not null,meeting_version integer not null,consent_actor uuid not null references auth.users,
 consent_at timestamptz not null,participants jsonb not null,
 filename text not null check(length(filename) between 5 and 180 and filename !~ '[[:cntrl:]/\\]' and filename ~* '\.wav$'),
 size integer not null check(size between 44 and 5242880),sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),
 path text not null unique,status text not null default 'pending' check(status in ('pending','clean','blocked')),
 created_at timestamptz not null default now(),unique(organization_id,actor,request_id),
 foreign key(organization_id,meeting_id) references public.uniion_resources(organization_id,id)
);
alter table uniion_private.meeting_audio_grants enable row level security;
alter table uniion_private.meeting_audio enable row level security;
revoke all on uniion_private.meeting_audio_grants,uniion_private.meeting_audio from public,anon,authenticated;
create function public.uniion_meeting_audio(p_org uuid,p_meeting uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources;c uniion_private.meeting_consents;g uniion_private.meeting_audio_grants;f uniion_private.meeting_audio;aid uuid;v integer;
begin
 if p_action is null or p_action not in ('grant','list','write','prepare','uploaded','listen','download') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 perform public.uniion_module_use(p_org,'reunions');
 select * into r from public.uniion_resources where organization_id=p_org and id=p_meeting and module='reunions' for update;
 if not found or not exists(select 1 from uniion_private.business_records where organization_id=p_org and id=p_meeting)
 or not uniion_private.actor_resource(p_org,p_meeting,auth.uid(),p_action in ('grant','write','prepare','uploaded')) then raise insufficient_privilege;end if;
 if p_action='grant' then
  if not uniion_private.authority(p_org,auth.uid(),'rights') or not(p_payload ?& array['user','version','read','write','download']) or p_payload-array['user','version','read','write','download']<>'{}'
   or jsonb_typeof(p_payload->'user') is distinct from 'string' or (p_payload->>'user')::uuid=auth.uid()
   or not uniion_private.actor_member(p_org,(p_payload->>'user')::uuid)
   or jsonb_typeof(p_payload->'version') is distinct from 'number' or (p_payload->>'version') !~ '^(0|[1-9][0-9]{0,8})$'
   or jsonb_typeof(p_payload->'read') is distinct from 'boolean' or jsonb_typeof(p_payload->'write') is distinct from 'boolean' or jsonb_typeof(p_payload->'download') is distinct from 'boolean' then raise insufficient_privilege;end if;
  select version into v from uniion_private.meeting_audio_grants where organization_id=p_org and meeting_id=p_meeting and user_id=(p_payload->>'user')::uuid;
  if coalesce(v,0)<>(p_payload->>'version')::int then raise insufficient_privilege;end if;
  insert into uniion_private.meeting_audio_grants values(p_org,p_meeting,(p_payload->>'user')::uuid,(p_payload->>'read')::boolean,(p_payload->>'write')::boolean,(p_payload->>'download')::boolean,coalesce(v,0)+1)
   on conflict(organization_id,meeting_id,user_id) do update set can_read=excluded.can_read,can_write=excluded.can_write,can_download=excluded.can_download,version=excluded.version;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.grant',jsonb_build_object('meeting',p_meeting,'user',p_payload->>'user','version',coalesce(v,0)+1,'read',p_payload->'read','write',p_payload->'write','download',p_payload->'download'));
  return jsonb_build_object('version',coalesce(v,0)+1);
 end if;
 select * into g from uniion_private.meeting_audio_grants where organization_id=p_org and meeting_id=p_meeting and user_id=auth.uid();
 if not found or not g.can_read or (p_action in ('write','prepare','uploaded') and not g.can_write) or (p_action='download' and not g.can_download) then raise insufficient_privilege;end if;
 select * into c from uniion_private.meeting_consents where organization_id=p_org and meeting_id=p_meeting;
 if not found or not c.accepted or c.meeting_version<>r.version then raise insufficient_privilege;end if;
 if p_action='write' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;return jsonb_build_object('ok',true);
 elsif p_action='list' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;
  return jsonb_build_object('files',coalesce((select jsonb_agg(jsonb_build_object('id',id,'filename',filename,'size',size,'status',status,'consentVersion',consent_version,'current',consent_version=c.version and meeting_version=r.version) order by created_at,id) from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting),'[]'));
 elsif p_action='prepare' then
  if not(p_payload ?& array['request_id','consentVersion','filename','size','sha256']) or p_payload-array['request_id','consentVersion','filename','size','sha256']<>'{}'
   or jsonb_typeof(p_payload->'request_id') is distinct from 'string' or jsonb_typeof(p_payload->'filename') is distinct from 'string'
   or jsonb_typeof(p_payload->'sha256') is distinct from 'string' or jsonb_typeof(p_payload->'size') is distinct from 'number' or (p_payload->>'size') !~ '^[1-9][0-9]{0,7}$'
   or jsonb_typeof(p_payload->'consentVersion') is distinct from 'number' or (p_payload->>'consentVersion') !~ '^[1-9][0-9]{0,8}$'
   or c.version<>(p_payload->>'consentVersion')::int then raise insufficient_privilege;end if;
  select * into f from uniion_private.meeting_audio where organization_id=p_org and actor=auth.uid() and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if f.meeting_id<>p_meeting or f.consent_version<>c.version or f.meeting_version<>r.version or f.filename is distinct from p_payload->>'filename' or f.size is distinct from (p_payload->>'size')::int or f.sha256 is distinct from p_payload->>'sha256' then raise insufficient_privilege;end if;
  else
   if (select count(*) from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting)>=20 then raise insufficient_privilege;end if;
   aid=gen_random_uuid();
   insert into uniion_private.meeting_audio(id,organization_id,meeting_id,request_id,actor,consent_version,meeting_version,consent_actor,consent_at,participants,filename,size,sha256,path)
    values(aid,p_org,p_meeting,(p_payload->>'request_id')::uuid,auth.uid(),c.version,r.version,c.actor,c.updated_at,coalesce(r.body->'participants','[]'),p_payload->>'filename',(p_payload->>'size')::int,p_payload->>'sha256',p_org::text||'/'||p_meeting::text||'/'||aid::text) returning * into f;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.prepared',jsonb_build_object('meeting',p_meeting,'audio',f.id,'consentVersion',c.version));
  end if;
  return to_jsonb(f)-'participants';
 end if;
 if not(p_payload ? 'audio') or jsonb_typeof(p_payload->'audio') is distinct from 'string' or p_payload-(case when p_action='uploaded' then array['audio'] else array['audio','audit'] end)<>'{}' then raise insufficient_privilege;end if;
 if p_action<>'uploaded' and jsonb_typeof(p_payload->'audit') is distinct from 'boolean' then raise insufficient_privilege;end if;
 select * into f from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting and id=(p_payload->>'audio')::uuid and status='clean' and consent_version=c.version and meeting_version=r.version;
 if not found then raise insufficient_privilege;end if;
 if p_action='uploaded' then return jsonb_build_object('id',f.id,'status',f.status,'sha256',f.sha256,'size',f.size);end if;
 if p_payload->>'audit'='true' then
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.'||p_action,jsonb_build_object('meeting',p_meeting,'audio',f.id));
 end if;
 return to_jsonb(f)-'participants';
exception when invalid_text_representation or check_violation or numeric_value_out_of_range or not_null_violation then raise insufficient_privilege;
end$$;
create function public.uniion_meeting_audio_finish(p_id uuid,p_sha text,p_status text) returns void language plpgsql security definer set search_path='' as $$
declare f uniion_private.meeting_audio;
begin
 if not uniion_private.is_scanner() or p_status is null or p_status not in ('clean','blocked') then raise insufficient_privilege;end if;
 select * into f from uniion_private.meeting_audio where id=p_id for update;
 if not found or f.sha256 is distinct from p_sha or f.status='blocked' or (p_status='clean' and not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=f.path and (metadata->>'size')::bigint=f.size)) then raise insufficient_privilege;end if;
 if f.status=p_status then return;end if;
 update uniion_private.meeting_audio set status=p_status where id=f.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(f.organization_id,auth.uid(),'meeting.audio.scanned',jsonb_build_object('audio',f.id,'status',p_status));
end$$;
create function uniion_private.meeting_audio_insert(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.is_scanner() and exists(select 1 from uniion_private.meeting_audio where path=p_path and status='pending')
$$;
revoke all on function public.uniion_meeting_audio(uuid,uuid,text,jsonb),public.uniion_meeting_audio_finish(uuid,text,text),uniion_private.meeting_audio_insert(text) from public,anon;
grant execute on function public.uniion_meeting_audio(uuid,uuid,text,jsonb),public.uniion_meeting_audio_finish(uuid,text,text),uniion_private.meeting_audio_insert(text) to authenticated;
create policy uniion_meeting_audio_insert on storage.objects for insert to authenticated with check(bucket_id='uniion-private' and uniion_private.meeting_audio_insert(name));
notify pgrst,'reload schema';
commit;

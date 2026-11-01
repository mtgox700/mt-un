begin;
create table uniion_private.meeting_audio_originals(
 audio_id uuid primary key references uniion_private.meeting_audio(id),filename text not null check(length(filename) between 1 and 180 and filename !~ '[[:cntrl:]/\\]'),
 size integer not null check(size between 1 and 20971520),sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),
 status text not null default 'pending' check(status in ('pending','clean','blocked'))
);
create table uniion_private.meeting_audio_original_parts(
 audio_id uuid not null references uniion_private.meeting_audio_originals(audio_id),part integer not null check(part between 0 and 79),
 bytes bytea not null check(octet_length(bytes) between 1 and 262144),primary key(audio_id,part)
);
alter table uniion_private.meeting_audio_originals enable row level security;
alter table uniion_private.meeting_audio_original_parts enable row level security;
revoke all on uniion_private.meeting_audio_originals,uniion_private.meeting_audio_original_parts from public,anon,authenticated;
create function public.uniion_audio_original(p_org uuid,p_meeting uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare f uniion_private.meeting_audio;o uniion_private.meeting_audio_originals;partno integer;data bytea;old bytea;
begin
 if p_action is null or p_action not in ('begin','put','progress','assemble','receipt','download') then raise insufficient_privilege;end if;
 if jsonb_typeof(p_payload) is distinct from 'object' or jsonb_typeof(p_payload->'audio') is distinct from 'string' then raise insufficient_privilege;end if;
 if p_action='download' then
  perform public.uniion_meeting_audio(p_org,p_meeting,'download',jsonb_build_object('audio',p_payload->>'audio','audit',true));
 else
  perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');
 end if;
 select * into f from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting and id=(p_payload->>'audio')::uuid for update;
 if not found or f.status='blocked' or not exists(select 1 from uniion_private.meeting_consents c join public.uniion_resources r on r.id=c.meeting_id and r.organization_id=c.organization_id where c.organization_id=p_org and c.meeting_id=p_meeting and c.version=f.consent_version and r.version=f.meeting_version and c.accepted) or (p_action<>'download' and f.actor<>auth.uid()) then raise insufficient_privilege;end if;
 if p_action='begin' then
  if not(p_payload ?& array['audio','filename','size','sha256']) or p_payload-array['audio','filename','size','sha256']<>'{}' or jsonb_typeof(p_payload->'filename') is distinct from 'string' or jsonb_typeof(p_payload->'sha256') is distinct from 'string' or jsonb_typeof(p_payload->'size') is distinct from 'number' or (p_payload->>'size') !~ '^[1-9][0-9]{0,7}$' then raise insufficient_privilege;end if;
  insert into uniion_private.meeting_audio_originals(audio_id,filename,size,sha256) values(f.id,p_payload->>'filename',(p_payload->>'size')::int,p_payload->>'sha256') on conflict do nothing;
 end if;
 select * into o from uniion_private.meeting_audio_originals where audio_id=f.id;
 if not found or o.status='blocked' then raise insufficient_privilege;end if;
 if p_action='begin' then
  if o.filename is distinct from p_payload->>'filename' or o.size is distinct from (p_payload->>'size')::int or o.sha256 is distinct from p_payload->>'sha256' then raise insufficient_privilege;end if;
 elsif p_action='put' then
  if p_payload-array['audio','part','content']<>'{}' or jsonb_typeof(p_payload->'part') is distinct from 'number' or (p_payload->>'part') !~ '^(0|[1-9][0-9]?)$' or jsonb_typeof(p_payload->'content') is distinct from 'string' or length(p_payload->>'content')>349528 then raise insufficient_privilege;end if;
  partno=(p_payload->>'part')::int;data=decode(p_payload->>'content','base64');
  if partno not between 0 and (o.size-1)/262144 or octet_length(data)<>least(262144,o.size-partno*262144) then raise insufficient_privilege;end if;
  select bytes into old from uniion_private.meeting_audio_original_parts where audio_id=f.id and part=partno;
  if found then if old<>data then raise insufficient_privilege;end if;
  else if o.status<>'pending' then raise insufficient_privilege;end if;insert into uniion_private.meeting_audio_original_parts values(f.id,partno,data);end if;
 elsif p_action in ('assemble','download') then
  if p_payload-array['audio']<>'{}' or (p_action='download' and o.status<>'clean') then raise insufficient_privilege;end if;
  select string_agg(bytes,''::bytea order by part) into data from uniion_private.meeting_audio_original_parts where audio_id=f.id;
  if data is null or octet_length(data)<>o.size then raise insufficient_privilege;end if;
  return to_jsonb(o)||jsonb_build_object('content',encode(data,'base64'));
 elsif p_action not in ('progress','receipt') or p_payload-array['audio']<>'{}' then raise insufficient_privilege;end if;
 if p_action='receipt' and o.status<>'clean' then raise insufficient_privilege;end if;
 return to_jsonb(o)||jsonb_build_object('parts',coalesce((select jsonb_agg(part order by part) from uniion_private.meeting_audio_original_parts where audio_id=f.id),'[]'));
exception when invalid_text_representation or check_violation or numeric_value_out_of_range or not_null_violation then raise insufficient_privilege;
end$$;
create function public.uniion_audio_original_finish(p_audio uuid,p_sha text,p_status text) returns void language plpgsql security definer set search_path='' as $$
declare o uniion_private.meeting_audio_originals;
begin
 if not uniion_private.is_scanner() or p_status is null or p_status not in ('clean','blocked') then raise insufficient_privilege;end if;
 select * into o from uniion_private.meeting_audio_originals where audio_id=p_audio for update;
 if not found or o.status='blocked' or o.sha256 is distinct from p_sha or o.size<>(select coalesce(sum(octet_length(bytes)),0) from uniion_private.meeting_audio_original_parts where audio_id=p_audio) then raise insufficient_privilege;end if;
 update uniion_private.meeting_audio_originals set status=p_status where audio_id=p_audio;
 insert into public.uniion_security_events(organization_id,actor,event,details) select organization_id,auth.uid(),'meeting.audio.original_scanned',jsonb_build_object('audio',p_audio,'status',p_status) from uniion_private.meeting_audio where id=p_audio;
end$$;
revoke all on function public.uniion_audio_original(uuid,uuid,text,jsonb),public.uniion_audio_original_finish(uuid,text,text) from public,anon;
grant execute on function public.uniion_audio_original(uuid,uuid,text,jsonb),public.uniion_audio_original_finish(uuid,text,text) to authenticated;
create or replace function public.uniion_meeting_audio(p_org uuid,p_meeting uuid,p_action text,p_payload jsonb)
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
  return jsonb_build_object('files',coalesce((select jsonb_agg(jsonb_build_object('id',id,'filename',filename,'size',size,'status',status,'hasOriginal',exists(select 1 from uniion_private.meeting_audio_originals o where o.audio_id=meeting_audio.id and o.status='clean'),'canDownload',g.can_download,'consentVersion',consent_version,'current',consent_version=c.version and meeting_version=r.version and not exists(select 1 from uniion_private.meeting_audio_originals o where o.audio_id=meeting_audio.id and o.status<>'clean')) order by created_at,id) from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting),'[]'));
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
   if (select count(*) from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting)>=480 then raise insufficient_privilege;end if;
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
 if exists(select 1 from uniion_private.meeting_audio_originals where audio_id=f.id and status<>'clean') then raise insufficient_privilege;end if;
 if p_action='uploaded' then return jsonb_build_object('id',f.id,'status',f.status,'sha256',f.sha256,'size',f.size);end if;
 if p_payload->>'audit'='true' then
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.'||p_action,jsonb_build_object('meeting',p_meeting,'audio',f.id));
 end if;
 return to_jsonb(f)-'participants';
exception when invalid_text_representation or check_violation or numeric_value_out_of_range or not_null_violation then raise insufficient_privilege;
end$$;
notify pgrst,'reload schema';commit;

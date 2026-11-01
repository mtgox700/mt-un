begin;
create table uniion_private.transcription_workers(user_id uuid primary key references auth.users);
create table uniion_private.transcription_jobs(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,meeting_id uuid not null,
 requester uuid not null references auth.users,source_ids uuid[] not null,source_key text not null,
 state text not null default 'pending' check(state in ('pending','running','done','error','cancelled')),
 lease uuid,worker uuid,updated_at timestamptz not null default now(),error text,
 unique(organization_id,meeting_id,requester,source_key));
create table uniion_private.transcription_parts(
 job_id uuid references uniion_private.transcription_jobs,id uuid references uniion_private.meeting_audio,
 sha256 text not null,consent_version integer not null,meeting_version integer not null,
 offset_ms bigint not null,duration_ms integer not null,result jsonb,
 primary key(job_id,id));
alter table uniion_private.transcription_workers enable row level security;
alter table uniion_private.transcription_jobs enable row level security;
alter table uniion_private.transcription_parts enable row level security;
revoke all on uniion_private.transcription_workers,uniion_private.transcription_jobs,uniion_private.transcription_parts from public,anon,authenticated;
create function uniion_private.transcription_valid(j uniion_private.transcription_jobs) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.actor_resource(j.organization_id,j.meeting_id,j.requester,true)
 and uniion_private.commercial_allowed(j.organization_id,'reunions')
 and exists(select 1 from uniion_private.meeting_audio_grants g where g.organization_id=j.organization_id and g.meeting_id=j.meeting_id and g.user_id=j.requester and g.can_read and g.can_write)
 and not exists(select 1 from uniion_private.transcription_parts p join uniion_private.meeting_audio a on a.id=p.id
 left join uniion_private.meeting_consents c on c.organization_id=a.organization_id and c.meeting_id=a.meeting_id
 left join public.uniion_resources r on r.id=a.meeting_id and r.organization_id=a.organization_id
 where p.job_id=j.id and (c.accepted is distinct from true or c.version is distinct from p.consent_version or r.version is distinct from p.meeting_version or c.meeting_version is distinct from p.meeting_version or a.sha256<>p.sha256 or a.status<>'clean' or exists(select 1 from uniion_private.meeting_audio_originals o where o.audio_id=a.id and o.status<>'clean')))
$$;
create function public.uniion_transcription(p_org uuid,p_meeting uuid,p_audio uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[];key text;j uniion_private.transcription_jobs;a uniion_private.meeting_audio;aid uuid;rec uuid;
begin
 if p_action is null or p_action not in ('start','status','cancel','retry') then raise insufficient_privilege;end if;
 perform public.uniion_meeting_audio(p_org,p_meeting,'listen',jsonb_build_object('audio',p_audio,'audit',false));
 select recording_id into rec from uniion_private.meeting_audio_sequences where audio_id=p_audio;
 select array_agg(f.id order by coalesce(s.position,0),f.id) into ids from uniion_private.meeting_audio f left join uniion_private.meeting_audio_sequences s on s.audio_id=f.id where f.organization_id=p_org and f.meeting_id=p_meeting and (case when rec is null then f.id=p_audio else s.recording_id=rec end);
 foreach aid in array ids loop perform public.uniion_meeting_audio(p_org,p_meeting,'listen',jsonb_build_object('audio',aid,'audit',false));end loop;
 key=array_to_string(ids,',');
 if p_action<>'status' then perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');end if;
 if p_action='start' then
  insert into uniion_private.transcription_jobs(organization_id,meeting_id,requester,source_ids,source_key) values(p_org,p_meeting,auth.uid(),ids,key) on conflict do nothing;
 end if;
 select * into j from uniion_private.transcription_jobs where organization_id=p_org and meeting_id=p_meeting and requester=auth.uid() and source_key=key for update;
 if not found then return jsonb_build_object('state','absent');end if;
 if p_action='start' then
  insert into uniion_private.transcription_parts(job_id,id,sha256,consent_version,meeting_version,offset_ms,duration_ms)
  select j.id,f.id,f.sha256,f.consent_version,f.meeting_version,coalesce(s.offset_ms,0),f.duration_ms from uniion_private.meeting_audio f left join uniion_private.meeting_audio_sequences s on s.audio_id=f.id where f.id=any(ids) on conflict do nothing;
 elsif p_action='cancel' and j.state in ('pending','running','error') then
  update uniion_private.transcription_jobs set state='cancelled',lease=null,worker=null,updated_at=now() where id=j.id returning * into j;
 elsif p_action='retry' and j.state in ('error','cancelled') then
  update uniion_private.transcription_jobs set state='pending',lease=null,worker=null,error=null,updated_at=now() where id=j.id returning * into j;
 end if;
 if p_action<>'status' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.transcription.'||p_action,jsonb_build_object('meeting',p_meeting,'job',j.id));end if;
 return jsonb_build_object('id',j.id,'state',j.state,'error',j.error,'total',cardinality(ids),'completed',(select count(*) from uniion_private.transcription_parts where job_id=j.id and result is not null),'parts',case when j.state='done' then (select jsonb_agg(jsonb_build_object('audio',id,'offsetMs',offset_ms,'result',result) order by offset_ms,id) from uniion_private.transcription_parts where job_id=j.id) else '[]'::jsonb end);
end$$;
create function public.uniion_transcription_worker(p_action text,p_job uuid default null,p_lease uuid default null,p_audio uuid default null,p_result jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare j uniion_private.transcription_jobs;p uniion_private.transcription_parts;s jsonb;
begin
 if not uniion_private.session_allowed() or not exists(select 1 from uniion_private.transcription_workers where user_id=auth.uid()) or p_action is null or p_action not in ('claim','next','finish','error') then raise insufficient_privilege;end if;
 if p_action='claim' then
  select * into j from uniion_private.transcription_jobs q where (state='pending' or state='running' and updated_at<now()-interval '6 minutes') and uniion_private.transcription_valid(q) order by updated_at for update skip locked limit 1;
  if not found then return '{}'::jsonb;end if;
  update uniion_private.transcription_jobs set state='running',lease=gen_random_uuid(),worker=auth.uid(),updated_at=now(),error=null where id=j.id returning * into j;
  return jsonb_build_object('id',j.id,'lease',j.lease);
 end if;
 select * into j from uniion_private.transcription_jobs where id=p_job and state='running' and lease=p_lease and worker=auth.uid() and updated_at>now()-interval '6 minutes' for update;
 if not found or not uniion_private.transcription_valid(j) then raise insufficient_privilege;end if;
 if p_action='error' then
  update uniion_private.transcription_jobs set state='error',error='local_engine_unavailable',lease=null,worker=null,updated_at=now() where id=j.id;return jsonb_build_object('ok',true);
 end if;
 if p_action='finish' then
  select * into p from uniion_private.transcription_parts where job_id=j.id and id=p_audio and result is null for update;
  if not found or p_result is null or jsonb_typeof(p_result) is distinct from 'object' or p_result-array['engine','model','segments']<>'{}' or p_result->>'engine' is distinct from 'faster-whisper/1.2.1' or p_result->>'model' is distinct from 'ebe41f70d5b6dfa9166e2c581c45c9c0cfc57b66' or jsonb_typeof(p_result->'segments') is distinct from 'array' or octet_length(p_result::text)>200000 then raise insufficient_privilege;end if;
  for s in select value from jsonb_array_elements(p_result->'segments') loop
   if jsonb_typeof(s->'text') is distinct from 'string' or length(s->>'text')>10000 or (s->>'startMs')::bigint<0 or (s->>'endMs')::bigint>(p.duration_ms) or (s->>'endMs')::bigint<=(s->>'startMs')::bigint or not(s ?& array['startMs','endMs','text']) then raise insufficient_privilege;end if;
  end loop;
  update uniion_private.transcription_parts set result=p_result where job_id=j.id and id=p_audio;
 end if;
 update uniion_private.transcription_jobs set updated_at=now() where id=j.id;
 select * into p from uniion_private.transcription_parts where job_id=j.id and result is null order by offset_ms,id limit 1;
 if not found then
  update uniion_private.transcription_jobs set state='done',lease=null,worker=null where id=j.id;
  return jsonb_build_object('done',true);
 end if;
 return (select jsonb_build_object('audio',a.id,'path',a.path,'sha256',p.sha256,'size',a.size) from uniion_private.meeting_audio a where a.id=p.id);
end$$;
create function uniion_private.transcription_storage(path text) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.session_allowed() and exists(select 1 from uniion_private.transcription_workers where user_id=auth.uid()) and exists(select 1 from uniion_private.transcription_jobs j join uniion_private.transcription_parts p on p.job_id=j.id join uniion_private.meeting_audio a on a.id=p.id where a.path=path and p.result is null and j.worker=auth.uid() and j.state='running' and j.updated_at>now()-interval '6 minutes' and uniion_private.transcription_valid(j))
$$;
create policy transcription_leased_audio on storage.objects for select to authenticated using(bucket_id='uniion-private' and uniion_private.transcription_storage(name));
revoke all on function uniion_private.transcription_valid(uniion_private.transcription_jobs),uniion_private.transcription_storage(text) from public,anon,authenticated;
grant execute on function uniion_private.transcription_storage(text) to authenticated;
revoke all on function public.uniion_transcription(uuid,uuid,uuid,text),public.uniion_transcription_worker(text,uuid,uuid,uuid,jsonb) from public,anon;
grant execute on function public.uniion_transcription(uuid,uuid,uuid,text),public.uniion_transcription_worker(text,uuid,uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

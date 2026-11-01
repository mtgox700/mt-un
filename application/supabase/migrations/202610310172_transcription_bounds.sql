begin;
create or replace function public.uniion_transcription_worker(p_action text,p_job uuid default null,p_lease uuid default null,p_audio uuid default null,p_result jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
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
   if jsonb_typeof(s) is distinct from 'object' or jsonb_typeof(s->'startMs') is distinct from 'number' or jsonb_typeof(s->'endMs') is distinct from 'number' or (s->>'startMs') !~ '^[0-9]{1,9}$' or (s->>'endMs') !~ '^[0-9]{1,9}$' or jsonb_typeof(s->'text') is distinct from 'string' or length(s->>'text')>10000 or (s->>'startMs')::bigint<0 or (s->>'endMs')::bigint>(p.duration_ms) or (s->>'endMs')::bigint<=(s->>'startMs')::bigint or not(s ?& array['startMs','endMs','text']) then raise insufficient_privilege;end if;
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
create or replace function uniion_private.transcription_storage(path text) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.session_allowed() and exists(select 1 from uniion_private.transcription_workers where user_id=auth.uid()) and exists(select 1 from uniion_private.transcription_jobs j join uniion_private.transcription_parts p on p.job_id=j.id join uniion_private.meeting_audio a on a.id=p.id where a.path=$1 and p.result is null and j.worker=auth.uid() and j.state='running' and j.updated_at>now()-interval '6 minutes' and uniion_private.transcription_valid(j))
$$;
notify pgrst,'reload schema';commit;

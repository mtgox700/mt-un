begin;
create or replace function public.uniion_business_records(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;rows jsonb;d uniion_private.meeting_minutes;r public.uniion_resources;
begin
 select * into d from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(p_payload->>'id')::uuid;
 if found and p_action='save' then
  -- Only the draft prose/title may change. Source snapshots cannot be overwritten by the client.
  perform public.uniion_module_use(p_org,'reunions');
  select * into r from public.uniion_resources where id=d.resource_id and organization_id=p_org for update;
  if p_module is distinct from 'reunions' or not uniion_private.actor_resource(p_org,r.id,auth.uid(),true) or r.version is distinct from (p_payload->>'version')::int or p_payload-array['id','version','data']<>'{}'
   or (p_payload->'data')-array['title','minutes'] is distinct from r.body-array['title','minutes']
   or jsonb_typeof(p_payload->'data'->'title') is distinct from 'string' or length(btrim(p_payload->'data'->>'title')) not between 1 and 200
   or jsonb_typeof(p_payload->'data'->'minutes') is distinct from 'string' or octet_length((p_payload->'data')::text)>6291456 then raise insufficient_privilege;end if;
  update public.uniion_resources set title=p_payload->'data'->>'title',body=p_payload->'data',version=version+1 where id=r.id returning * into r;
  update uniion_private.business_records set updated_at=now() where id=r.id;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.save',jsonb_build_object('module','reunions','id',r.id,'version',r.version));
  return r.body||jsonb_build_object('id',r.id,'version',r.version,'module','reunions','meetingPV',true,'status','Brouillon','serverRecord',true,'canWrite',true);
 end if;
 result=public.uniion_business_records_before_minutes(p_org,p_module,p_action,p_payload);
 if p_module='reunions' and p_action='list' then
  select coalesce(jsonb_agg(x||case when exists(select 1 from uniion_private.meeting_minutes where resource_id=(x->>'id')::uuid and organization_id=p_org) then '{"meetingPV":true}'::jsonb else '{}'::jsonb end),'[]') into rows from jsonb_array_elements(result->'rows')x;
  return jsonb_build_object('rows',rows);
 end if;
 if exists(select 1 from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(result->>'id')::uuid) then result=result||'{"meetingPV":true}'::jsonb;end if;
 return result;
end$$;
create or replace function public.uniion_meeting_minutes(p_org uuid,p_meeting uuid,p_audio uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare status jsonb;j uniion_private.transcription_jobs;d uniion_private.meeting_minutes;r public.uniion_resources;part uniion_private.transcription_parts;markers jsonb;item jsonb;transcript text='';marker_text text='';snap jsonb='[]';row jsonb;body jsonb;
begin
 if p_action='publications' then
  perform public.uniion_module_use(p_org,'reunions');
  if not uniion_private.authority(p_org,auth.uid(),'content_publish') or not uniion_private.actor_resource_before_minutes(p_org,p_meeting,auth.uid(),false) then raise insufficient_privilege;end if;
  return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('id',m.resource_id,'version',p.version) order by p.version desc) from uniion_private.meeting_minutes m join uniion_private.business_publications p on p.organization_id=m.organization_id and p.resource_id=m.resource_id where m.organization_id=p_org and m.meeting_id=p_meeting and p.published_at is not null and p.revoked_at is null),'[]'));
 end if;
 if p_action is null or p_action not in ('prepare','status') then raise insufficient_privilege;end if;
 perform public.uniion_meeting_audio(p_org,p_meeting,'listen',jsonb_build_object('audio',p_audio,'audit',false));
 -- Prefer this actor's job; authorised co-reviewers can find the already prepared draft.
 select m.* into d from uniion_private.meeting_minutes m join uniion_private.transcription_parts p on p.job_id=m.job_id where m.organization_id=p_org and m.meeting_id=p_meeting and p.id=p_audio order by m.created_at desc limit 1;
 if found then return public.uniion_business_records(p_org,'reunions','get',jsonb_build_object('id',d.resource_id));end if;
 if p_action='status' then return jsonb_build_object('absent',true);end if;
 perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');
 status=public.uniion_transcription(p_org,p_meeting,p_audio,'status');
 if status->>'state' is distinct from 'done' then raise insufficient_privilege;end if;
 select * into j from uniion_private.transcription_jobs where id=(status->>'id')::uuid;
 select * into r from public.uniion_resources where organization_id=p_org and id=p_meeting;
 if exists(select 1 from uniion_private.meeting_minutes where resource_id=p_meeting) then raise insufficient_privilege;end if;
 for part in select * from uniion_private.transcription_parts where job_id=j.id order by offset_ms,id loop
  markers=public.uniion_meeting_audio_markers(p_org,p_meeting,'get',jsonb_build_object('audio',part.id));
  snap=snap||jsonb_build_array(jsonb_build_object('audio',part.id,'sha256',part.sha256,'consentVersion',part.consent_version,'meetingVersion',part.meeting_version,'markerVersion',markers->'version','offsetMs',part.offset_ms));
  for item in select value from jsonb_array_elements(part.result->'segments') loop
   transcript=transcript||'['||(part.offset_ms+(item->>'startMs')::bigint)::text||'–'||(part.offset_ms+(item->>'endMs')::bigint)::text||' ms] '||(item->>'text')||E'\n';
  end loop;
  for item in select value from jsonb_array_elements(markers->'markers') loop
   marker_text=marker_text||'['||(part.offset_ms+(item->>'timeMs')::bigint)::text||' ms · '||(item->>'kind')||'] '||(item->>'note')||E'\n';
  end loop;
 end loop;
 -- Fail explicitly instead of silently omitting sources from a long meeting.
 if length(transcript)+length(marker_text)+length(coalesce((r.body->'ordre')::text,''))>3145728 then raise program_limit_exceeded using message='minutes_source_too_large';end if;
 body=jsonb_build_object('title',left('PV — '||r.title,200),'ordre',coalesce(r.body->'ordre','[]'),'transcript',transcript,'markers',jsonb_build_array(marker_text),'minutes','PROJET À RELIRE — transcription automatique, aucune décision déduite.'||E'\n\nORDRE DU JOUR\n'||coalesce((r.body->'ordre')::text,'[]')||E'\n\nTRANSCRIPTION HORODATÉE\n'||transcript||E'\nMARQUEURS DE SÉANCE\n'||marker_text);
 if octet_length(body::text)>6291456 or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='reunions' and permission='create') then raise insufficient_privilege;end if;
 insert into public.uniion_resources(organization_id,module,title,body) values(p_org,'reunions',body->>'title',body) returning * into r;
 insert into uniion_private.business_records(organization_id,id,creator) values(p_org,r.id,auth.uid());
 insert into public.uniion_resource_grants values(p_org,r.id,auth.uid(),true,false,'infinity',null);
 row=body||jsonb_build_object('id',r.id,'version',r.version,'module','reunions','status','Brouillon','serverRecord',true,'canWrite',true);
 insert into uniion_private.meeting_minutes values(p_org,(row->>'id')::uuid,p_meeting,j.id,snap,auth.uid(),now());
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.minutes.prepared',jsonb_build_object('meeting',p_meeting,'resource',row->>'id','job',j.id,'sources',snap));
 return row||'{"meetingPV":true}'::jsonb;
end$$;
notify pgrst,'reload schema';commit;

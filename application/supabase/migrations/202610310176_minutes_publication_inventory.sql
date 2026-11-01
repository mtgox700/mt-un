begin;
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
 if length(transcript)+length(marker_text)+length(coalesce((r.body->'ordre')::text,''))>44000 then raise program_limit_exceeded using message='minutes_source_too_large';end if;
 body=jsonb_build_object('title',left('PV — '||r.title,200),'ordre',coalesce(r.body->'ordre','[]'),'transcript',transcript,'markers',jsonb_build_array(marker_text),'minutes','PROJET À RELIRE — transcription automatique, aucune décision déduite.'||E'\n\nORDRE DU JOUR\n'||coalesce((r.body->'ordre')::text,'[]')||E'\n\nTRANSCRIPTION HORODATÉE\n'||transcript||E'\nMARQUEURS DE SÉANCE\n'||marker_text);
 row=public.uniion_business_records(p_org,'reunions','create',jsonb_build_object('data',body));
 insert into uniion_private.meeting_minutes values(p_org,(row->>'id')::uuid,p_meeting,j.id,snap,auth.uid(),now());
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.minutes.prepared',jsonb_build_object('meeting',p_meeting,'resource',row->>'id','job',j.id,'sources',snap));
 return row||'{"meetingPV":true}'::jsonb;
end$$;
notify pgrst,'reload schema';commit;

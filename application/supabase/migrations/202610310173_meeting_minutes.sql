begin;
-- Separate resource: editing minutes never changes the consent-bearing meeting version.
create table uniion_private.meeting_minutes(
 organization_id uuid not null,resource_id uuid primary key,meeting_id uuid not null,
 job_id uuid not null references uniion_private.transcription_jobs,source_snapshot jsonb not null,
 creator uuid not null references auth.users,created_at timestamptz not null default now(),
 unique(organization_id,meeting_id,job_id),
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id),
 foreign key(organization_id,meeting_id) references public.uniion_resources(organization_id,id));
alter table uniion_private.meeting_minutes enable row level security;
revoke all on uniion_private.meeting_minutes from public,anon,authenticated;
create function uniion_private.minutes_sources_allowed(o uuid,meeting uuid,job uuid,who uuid) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.actor_resource(o,meeting,who,false) and uniion_private.commercial_allowed(o,'reunions')
 and exists(select 1 from uniion_private.meeting_audio_grants where organization_id=o and meeting_id=meeting and user_id=who and can_read)
 and exists(select 1 from uniion_private.transcription_jobs where id=job and organization_id=o and meeting_id=meeting and state='done')
 and exists(select 1 from uniion_private.transcription_parts where job_id=job)
 and not exists(select 1 from uniion_private.transcription_parts p join uniion_private.meeting_audio a on a.id=p.id
 left join uniion_private.meeting_consents c on c.organization_id=a.organization_id and c.meeting_id=a.meeting_id
 left join public.uniion_resources r on r.organization_id=a.organization_id and r.id=a.meeting_id
 where p.job_id=job and (a.organization_id<>o or a.meeting_id<>meeting or c.accepted is distinct from true or c.version is distinct from p.consent_version or c.meeting_version is distinct from p.meeting_version or r.version is distinct from p.meeting_version or a.status<>'clean' or a.sha256<>p.sha256 or p.result is null or exists(select 1 from uniion_private.meeting_audio_originals x where x.audio_id=a.id and x.status<>'clean')))
$$;
alter function uniion_private.actor_resource(uuid,uuid,uuid,boolean) rename to actor_resource_before_minutes;
create function uniion_private.actor_resource(org uuid,res uuid,who uuid,wr boolean default false) returns boolean language plpgsql security definer set search_path='' as $$
declare d uniion_private.meeting_minutes;
begin
 select * into d from uniion_private.meeting_minutes where resource_id=res and organization_id=org;
 if not found then return uniion_private.actor_resource_before_minutes(org,res,who,wr);end if;
 -- Source access is cumulative. No generic grant or support role bypasses this gate.
 return uniion_private.minutes_sources_allowed(org,d.meeting_id,d.job_id,who)
 and uniion_private.actor_resource_before_minutes(org,d.meeting_id,who,wr);
end$$;
alter function uniion_private.resource_access(uuid,uuid,boolean) rename to resource_access_before_minutes;
create function uniion_private.resource_access(org uuid,resource uuid,write_access boolean) returns boolean language sql security definer set search_path='' as $$
 select case when exists(select 1 from uniion_private.meeting_minutes where resource_id=resource) then uniion_private.actor_resource(org,resource,auth.uid(),write_access) else uniion_private.resource_access_before_minutes(org,resource,write_access) end
$$;
alter function uniion_private.share_access(uuid,uuid,uuid,boolean) rename to share_access_before_minutes;
create function uniion_private.share_access(sid uuid,res uuid,who uuid,dl boolean default false) returns boolean language sql security definer set search_path='' as $$
 select not exists(select 1 from uniion_private.meeting_minutes where resource_id=res) and uniion_private.share_access_before_minutes(sid,res,who,dl)
$$;
-- Mark private draft rows for UI projection, without adding source metadata to publications.
alter function public.uniion_business_records(uuid,text,text,jsonb) rename to uniion_business_records_before_minutes;
create function public.uniion_business_records(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;rows jsonb;d uniion_private.meeting_minutes;r public.uniion_resources;
begin
 select * into d from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(p_payload->>'id')::uuid;
 if found and p_action='save' then
  -- Only the draft prose/title may change. Source snapshots cannot be overwritten by the client.
  select * into r from public.uniion_resources where id=d.resource_id and organization_id=p_org;
  if (p_payload->'data')-array['title','minutes'] is distinct from r.body-array['title','minutes'] or jsonb_typeof(p_payload->'data'->'minutes') is distinct from 'string' or length(p_payload->'data'->>'minutes')>48000 then raise insufficient_privilege;end if;
 end if;
 result=public.uniion_business_records_before_minutes(p_org,p_module,p_action,p_payload);
 if p_module='reunions' and p_action='list' then
  select coalesce(jsonb_agg(x||case when exists(select 1 from uniion_private.meeting_minutes where resource_id=(x->>'id')::uuid and organization_id=p_org) then '{"meetingPV":true}'::jsonb else '{}'::jsonb end),'[]') into rows from jsonb_array_elements(result->'rows')x;
  return jsonb_build_object('rows',rows);
 end if;
 if exists(select 1 from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(result->>'id')::uuid) then result=result||'{"meetingPV":true}'::jsonb;end if;
 return result;
end$$;
create function public.uniion_meeting_minutes(p_org uuid,p_meeting uuid,p_audio uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare status jsonb;j uniion_private.transcription_jobs;d uniion_private.meeting_minutes;r public.uniion_resources;part uniion_private.transcription_parts;markers jsonb;item jsonb;transcript text='';marker_text text='';snap jsonb='[]';row jsonb;body jsonb;
begin
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
-- Existing S08 two-actor publication owns audience, version, review and revocation.
alter function public.uniion_business_publication(uuid,text,text,jsonb) rename to uniion_business_publication_before_minutes;
create function public.uniion_business_publication(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;d uniion_private.meeting_minutes;r public.uniion_resources;
begin
 select * into d from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(p_payload->>'id')::uuid;
 if found and p_action in ('review','publish') then
  select * into r from public.uniion_resources where organization_id=p_org and id=d.resource_id;
  if jsonb_typeof(r.body->'minutes') is distinct from 'string' or length(btrim(r.body->>'minutes'))<1 then raise insufficient_privilege;end if;
 end if;
 result=public.uniion_business_publication_before_minutes(p_org,p_module,p_action,p_payload);
 if d.resource_id is not null and p_action='review' then
  update uniion_private.business_publications set body=jsonb_build_object('title',r.title,'minutes',r.body->>'minutes') where organization_id=p_org and resource_id=r.id and version=r.version and published_at is null;
 end if;
 return result;
end$$;
revoke all on function uniion_private.minutes_sources_allowed(uuid,uuid,uuid,uuid),uniion_private.actor_resource_before_minutes(uuid,uuid,uuid,boolean),uniion_private.actor_resource(uuid,uuid,uuid,boolean),uniion_private.resource_access_before_minutes(uuid,uuid,boolean),uniion_private.resource_access(uuid,uuid,boolean),uniion_private.share_access_before_minutes(uuid,uuid,uuid,boolean),uniion_private.share_access(uuid,uuid,uuid,boolean) from public,anon,authenticated;
revoke all on function public.uniion_business_records_before_minutes(uuid,text,text,jsonb),public.uniion_business_publication_before_minutes(uuid,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.uniion_business_records(uuid,text,text,jsonb),public.uniion_business_publication(uuid,text,text,jsonb),public.uniion_meeting_minutes(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.uniion_business_records(uuid,text,text,jsonb),public.uniion_business_publication(uuid,text,text,jsonb),public.uniion_meeting_minutes(uuid,uuid,uuid,text) to authenticated;
notify pgrst,'reload schema';commit;

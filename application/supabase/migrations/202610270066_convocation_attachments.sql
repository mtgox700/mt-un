begin;
-- The legacy command is no longer directly callable by an authenticated client.
alter function public.uniion_agenda_work(uuid,uuid,text,jsonb) set schema uniion_private;
alter function uniion_private.uniion_agenda_work(uuid,uuid,text,jsonb) rename to agenda_work_core;
revoke all on function uniion_private.agenda_work_core(uuid,uuid,text,jsonb) from public,anon,authenticated;
create function uniion_private.convocation_documents(p_org uuid,p_event uuid,p_version integer,p_people jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare e uniion_private.agenda_events;d uniion_private.agenda_documents;r uniion_private.agenda_publications;person uuid;
begin
perform public.uniion_module_use(p_org,'agenda');perform public.uniion_module_use(p_org,'documents');
if not uniion_private.authority(p_org,auth.uid(),'agenda_convocation') or not uniion_private.authority(p_org,auth.uid(),'agenda_publish') or not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
select * into e from uniion_private.agenda_events where id=p_event and organization_id=p_org;
if not found or not uniion_private.agenda_visible(p_org,e.data) then raise insufficient_privilege;end if;
select * into d from uniion_private.agenda_documents where event_id=p_event;
if not found or p_version is distinct from d.version then raise insufficient_privilege;end if;
select * into r from uniion_private.agenda_publications where event_id=p_event and version=p_version;
if not found or r.published_at is null or r.source_version<>e.version or r.reviewer=d.updated_by or not uniion_private.agenda_recipient_allowed(p_event,r.reviewer) or not uniion_private.authority(p_org,r.reviewer,'agenda_review') then raise insufficient_privilege;end if;
if jsonb_typeof(p_people) is distinct from 'array' or jsonb_array_length(p_people) not between 1 and 20 then raise insufficient_privilege;end if;
for person in select value::uuid from jsonb_array_elements_text(p_people) loop
 if not uniion_private.agenda_recipient_allowed(p_event,person) or not uniion_private.authority(p_org,person,'download') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=person and module='documents' and permission='read') then raise insufficient_privilege;end if;
end loop;
return jsonb_build_object('document',r.document,'version',d.version,'event',e.data||jsonb_build_object('id',e.id,'version',e.version));
end;$$;
revoke all on function uniion_private.convocation_documents(uuid,uuid,integer,jsonb) from public,anon,authenticated;
create function public.uniion_agenda_work(p_org uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;v integer;people jsonb;saved_message jsonb;
begin
if p_payload is null or jsonb_typeof(p_payload)<>'object' then raise insufficient_privilege;end if;
if p_action='attachments' then
 if p_payload-array['version','people']<>'{}'::jsonb then raise insufficient_privilege;end if;
 return uniion_private.convocation_documents(p_org,p_event,(p_payload->>'version')::integer,p_payload->'people');
elsif p_action='prepare' then
 if jsonb_typeof(p_payload->'people') is distinct from 'array' or jsonb_typeof(p_payload->'subject') is distinct from 'string' or jsonb_typeof(p_payload->'body') is distinct from 'string' then raise insufficient_privilege;end if;
 if (select count(*)<>count(distinct value) from jsonb_array_elements_text(p_payload->'people')) then raise insufficient_privilege;end if;
 if p_payload ? 'attachment_version' then
  if jsonb_typeof(p_payload->'attachment_version') is distinct from 'number' then raise insufficient_privilege;end if;
  v=(p_payload->>'attachment_version')::integer;
  perform uniion_private.convocation_documents(p_org,p_event,v,p_payload->'people');
 end if;
 result=uniion_private.agenda_work_core(p_org,p_event,p_action,p_payload-'attachment_version');
 if v is not null and not (result->>'replayed')::boolean then
  update uniion_private.agenda_convocations set message=message||jsonb_build_object('attachment_version',v,'attachments',jsonb_build_array('ordre-du-jour.pdf','evenement.ics')) where id=(p_payload->>'id')::uuid;
 end if;
 return result;
elsif p_action in ('check','finish') then
 result=uniion_private.agenda_work_core(p_org,p_event,p_action,p_payload);
 select c.message into saved_message from uniion_private.agenda_convocations c where c.id=(p_payload->>'id')::uuid and c.event_id=p_event and c.actor=auth.uid();
 if saved_message ? 'attachment_version' then perform uniion_private.convocation_documents(p_org,p_event,(saved_message->>'attachment_version')::integer,jsonb_build_array(p_payload->>'user'));end if;
 return result;
else
 result=uniion_private.agenda_work_core(p_org,p_event,p_action,p_payload);
 if p_action='recipients' then
  select version into v from uniion_private.agenda_documents where event_id=p_event;
  result=result||jsonb_build_object('documentVersion',v);
 end if;
 return result;
end if;
end;$$;
revoke all on function public.uniion_agenda_work(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_agenda_work(uuid,uuid,text,jsonb) to authenticated;
commit;

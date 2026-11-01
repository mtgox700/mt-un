begin;
create function uniion_private.agenda_file_check(p_org uuid,p_files jsonb,p_user uuid) returns void language plpgsql security definer set search_path='' as $$
declare item jsonb;a public.uniion_attachments;total bigint=0;
begin
if jsonb_typeof(p_files) is distinct from 'array' or jsonb_array_length(p_files)>5 then raise insufficient_privilege;end if;
for item in select value from jsonb_array_elements(p_files) loop
 select * into a from public.uniion_attachments where id=(item->>'id')::uuid and organization_id=p_org;
 if not found or not a.ready or a.scan_status<>'clean' or a.sha256 is distinct from item->>'sha256' or not uniion_private.attachment_access(a.id,p_user) then raise insufficient_privilege;end if;
 total=total+a.size;
end loop;
if total>10485760 then raise insufficient_privilege;end if;
end;$$;
revoke all on function uniion_private.agenda_file_check(uuid,jsonb,uuid) from public,anon,authenticated;
create function public.uniion_agenda_files(p_org uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare e uniion_private.agenda_events;d uniion_private.agenda_documents;files jsonb;aid uuid;file_record public.uniion_attachments;
begin
perform public.uniion_module_use(p_org,'agenda');perform public.uniion_module_use(p_org,'documents');
select * into e from uniion_private.agenda_events where id=p_event and organization_id=p_org;
if not found or not uniion_private.agenda_visible(p_org,e.data) or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise insufficient_privilege;end if;
select * into d from uniion_private.agenda_documents where event_id=p_event for update;
if p_action='select' then
 if not uniion_private.authority(p_org,auth.uid(),'agenda_convocation') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='write') or d.id is null or (p_payload->>'version')::integer is distinct from d.version or p_payload-array['version','files']<>'{}'::jsonb or jsonb_typeof(p_payload->'files') is distinct from 'array' or jsonb_array_length(p_payload->'files')>5 then raise insufficient_privilege;end if;
 if (select count(*)<>count(distinct value) from jsonb_array_elements_text(p_payload->'files')) then raise insufficient_privilege;end if;
 files='[]';
 for aid in select value::uuid from jsonb_array_elements_text(p_payload->'files') loop
  select * into file_record from public.uniion_attachments where id=aid and organization_id=p_org;
  if not found then raise insufficient_privilege;end if;
  files=files||jsonb_build_array(jsonb_build_object('id',file_record.id,'sha256',file_record.sha256));
 end loop;
 perform uniion_private.agenda_file_check(p_org,files,auth.uid());
 if coalesce(d.document->'convocation_files','[]')<>files then
 update uniion_private.agenda_documents set document=document||jsonb_build_object('convocation_files',files),version=version+1,updated_by=auth.uid(),updated_at=now() where event_id=p_event returning * into d;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.files.selected',jsonb_build_object('event',p_event,'version',d.version,'files',files));
 end if;
elsif p_action='context' then
 if p_payload<>'{}' then raise insufficient_privilege;end if;
else raise insufficient_privilege;end if;
return jsonb_build_object('version',d.version,'selected',coalesce(d.document->'convocation_files','[]'),
 'resources',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.title)) from public.uniion_resources r where r.organization_id=p_org and uniion_private.actor_resource(p_org,r.id,auth.uid(),true)),'[]'),
 'available',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'resource',a.resource_id,'size',a.size)) from public.uniion_attachments a where a.organization_id=p_org and a.ready and a.scan_status='clean' and uniion_private.attachment_access(a.id,auth.uid())),'[]'));
end;$$;
revoke all on function public.uniion_agenda_files(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_agenda_files(uuid,uuid,text,jsonb) to authenticated;
-- Selected source restrictions are checked at validation, publication and delivery.
alter function public.uniion_agenda_publication(uuid,uuid,text,jsonb) rename to uniion_agenda_publication_without_files;
revoke all on function public.uniion_agenda_publication_without_files(uuid,uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_agenda_publication(p_org uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare files jsonb;
begin
if p_action in ('review','publish','published','export') then
 select document->'convocation_files' into files from uniion_private.agenda_documents where event_id=p_event;
 perform uniion_private.agenda_file_check(p_org,coalesce(files,'[]'),auth.uid());
end if;
return public.uniion_agenda_publication_without_files(p_org,p_event,p_action,p_payload);
end;$$;
revoke all on function public.uniion_agenda_publication(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_agenda_publication(uuid,uuid,text,jsonb) to authenticated;
alter function uniion_private.convocation_documents(uuid,uuid,integer,jsonb) rename to convocation_documents_without_files;
create function uniion_private.convocation_documents(p_org uuid,p_event uuid,p_version integer,p_people jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;files jsonb;person uuid;reviewer uuid;
begin
result=uniion_private.convocation_documents_without_files(p_org,p_event,p_version,p_people);
files=coalesce(result->'document'->'convocation_files','[]');
perform uniion_private.agenda_file_check(p_org,files,auth.uid());
select r.reviewer into reviewer from uniion_private.agenda_publications r where event_id=p_event and version=p_version;
perform uniion_private.agenda_file_check(p_org,files,reviewer);
for person in select value::uuid from jsonb_array_elements_text(p_people) loop perform uniion_private.agenda_file_check(p_org,files,person);end loop;
return result;
end;$$;
revoke all on function uniion_private.convocation_documents(uuid,uuid,integer,jsonb) from public,anon,authenticated;
commit;

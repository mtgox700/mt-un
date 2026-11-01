begin;
alter table public.uniion_authorities drop constraint uniion_authorities_permission_check;
alter table public.uniion_authorities add constraint uniion_authorities_permission_check check(permission in ('rights','share','accept','download','history','organization_edit','collection_publish','collection_accept','agenda_audience','agenda_convocation','agenda_review','agenda_publish'));
create table uniion_private.agenda_publications(event_id uuid references uniion_private.agenda_documents(event_id),version integer,source_version integer not null,document jsonb not null,author uuid not null,reviewer uuid,reviewed_at timestamptz,published_by uuid,published_at timestamptz,primary key(event_id,version));
alter table uniion_private.agenda_publications enable row level security;
revoke all on uniion_private.agenda_publications from public,anon,authenticated;
create function public.uniion_agenda_publication(p_org uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare e uniion_private.agenda_events;d uniion_private.agenda_documents;r uniion_private.agenda_publications;
begin
perform public.uniion_module_use(p_org,'agenda');perform public.uniion_module_use(p_org,'documents');
select * into e from uniion_private.agenda_events where id=p_event and organization_id=p_org for update;
if not found or not uniion_private.agenda_visible(p_org,e.data) then raise insufficient_privilege;end if;
select * into d from uniion_private.agenda_documents where event_id=p_event for update;
if not found or p_payload is null or jsonb_typeof(p_payload)<>'object' or p_payload-array['version']<>'{}'::jsonb or (p_payload->>'version')::integer is distinct from d.version then raise insufficient_privilege;end if;
select * into r from uniion_private.agenda_publications where event_id=p_event and version=d.version;
if p_action='export' then
 if not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
elsif p_action='review' then
 if not uniion_private.authority(p_org,auth.uid(),'agenda_review') or auth.uid()=d.updated_by then raise insufficient_privilege;end if;
 insert into uniion_private.agenda_publications(event_id,version,source_version,document,author,reviewer,reviewed_at) values(p_event,d.version,e.version,d.document,d.updated_by,auth.uid(),now()) on conflict(event_id,version) do update set source_version=excluded.source_version,reviewer=excluded.reviewer,reviewed_at=excluded.reviewed_at where uniion_private.agenda_publications.published_at is null;
elsif p_action='publish' then
 if not uniion_private.authority(p_org,auth.uid(),'agenda_publish') or r.reviewer is null or r.reviewer=d.updated_by or r.source_version<>e.version then raise insufficient_privilege;end if;
 if not uniion_private.agenda_recipient_allowed(p_event,r.reviewer) or not uniion_private.authority(p_org,r.reviewer,'agenda_review') then raise insufficient_privilege;end if;
 update uniion_private.agenda_publications set published_by=auth.uid(),published_at=coalesce(published_at,now()) where event_id=p_event and version=d.version;
elsif p_action not in ('status','published') then raise insufficient_privilege;
end if;
select * into r from uniion_private.agenda_publications where event_id=p_event and version=d.version;
if p_action='published' and (r.published_at is null or r.source_version<>e.version) then raise insufficient_privilege;end if;
if p_action in ('export','review','publish') then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.document.'||p_action,jsonb_build_object('id',d.id,'version',d.version));end if;
return jsonb_build_object('version',d.version,'reviewed',r.reviewer is not null and r.source_version=e.version,'published',r.published_at is not null and r.source_version=e.version,'document',case when p_action in ('export','published') then d.document else null end);
end;$$;
revoke all on function public.uniion_agenda_publication(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_agenda_publication(uuid,uuid,text,jsonb) to authenticated;
commit;

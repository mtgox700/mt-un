begin;
create table uniion_private.convocation_archives (
 convocation uuid primary key references uniion_private.agenda_convocations,
 organization_id uuid not null references public.uniion_organizations,
 files jsonb not null, ready boolean not null default false, created_at timestamptz not null default now()
);
alter table uniion_private.convocation_archives enable row level security;
revoke all on uniion_private.convocation_archives from public,anon,authenticated;
create function public.uniion_convocation_archive(p_org uuid,p_convocation uuid,p_action text,p_files jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare a uniion_private.convocation_archives; f jsonb; expected text;
begin
 if not uniion_private.is_scanner() then raise insufficient_privilege;end if;
 if not exists(select 1 from uniion_private.agenda_convocations c join uniion_private.agenda_events e on e.id=c.event_id where c.id=p_convocation and e.organization_id=p_org and c.message ? 'attachment_version') then raise insufficient_privilege;end if;
 if p_action='reserve' then
  if jsonb_typeof(p_files) is distinct from 'array' or jsonb_array_length(p_files)<>2 then raise insufficient_privilege;end if;
  if not exists(select 1 from uniion_private.agenda_convocation_deliveries where convocation=p_convocation and status='sending') then raise insufficient_privilege;end if;
  for f in select value from jsonb_array_elements(p_files) loop
   expected=case f->>'id' when 'pdf' then 'application/pdf' when 'ics' then 'text/calendar' end;
   if expected is null or f->>'mime' is distinct from expected or f->>'sha256' !~ '^[a-f0-9]{64}$' or (f->>'size')::int not between 1 and 5242880 or f->>'path' is distinct from p_org::text||'/'||p_convocation::text||'/'||(f->>'object')::uuid::text then raise insufficient_privilege;end if;
  end loop;
  if (select count(distinct value->>'id') from jsonb_array_elements(p_files))<>2 or (select count(distinct value->>'object') from jsonb_array_elements(p_files))<>2 then raise insufficient_privilege;end if;
  insert into uniion_private.convocation_archives(convocation,organization_id,files) values(p_convocation,p_org,p_files) on conflict do nothing;
 end if;
 select * into a from uniion_private.convocation_archives where convocation=p_convocation and organization_id=p_org for update;
 if not found or (p_action='reserve' and a.files is distinct from p_files) then raise insufficient_privilege;end if;
 if p_action='finish' then
  if exists(select 1 from jsonb_array_elements(a.files) item where not exists(select 1 from storage.objects o where o.bucket_id='uniion-private' and o.name=item->>'path')) then raise insufficient_privilege;end if;
  update uniion_private.convocation_archives set ready=true where convocation=p_convocation;
 elsif p_action not in ('reserve','read') then raise insufficient_privilege;end if;
 return a.files;
end $$;
revoke all on function public.uniion_convocation_archive(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_convocation_archive(uuid,uuid,text,jsonb) to authenticated;
create function uniion_private.archive_upload(path text) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.is_scanner() and exists(select 1 from uniion_private.convocation_archives a, jsonb_array_elements(a.files) f where not a.ready and f->>'path'=path)
$$;
revoke all on function uniion_private.archive_upload(text) from public,anon;
grant execute on function uniion_private.archive_upload(text) to authenticated;
create policy uniion_archive_insert on storage.objects for insert to authenticated with check(bucket_id='uniion-private' and uniion_private.archive_upload(name));
update storage.buckets set allowed_mime_types=array_append(allowed_mime_types,'text/calendar') where id='uniion-private' and not ('text/calendar'=any(allowed_mime_types));
alter function public.uniion_agenda_work(uuid,uuid,text,jsonb) rename to uniion_agenda_work_before_archives;
revoke all on function public.uniion_agenda_work_before_archives(uuid,uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_agenda_work(p_org uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if p_action in ('check','finish') and exists(select 1 from uniion_private.agenda_convocations where id=(p_payload->>'id')::uuid and message ? 'attachment_version') and not exists(select 1 from uniion_private.convocation_archives where convocation=(p_payload->>'id')::uuid and organization_id=p_org and ready) then raise insufficient_privilege;end if;
 return public.uniion_agenda_work_before_archives(p_org,p_event,p_action,p_payload);
end $$;
revoke all on function public.uniion_agenda_work(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_agenda_work(uuid,uuid,text,jsonb) to authenticated;
create or replace function public.uniion_convocation_files(p_org uuid,p_convocation uuid,p_file text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare c uniion_private.agenda_convocations;e uniion_private.agenda_events;p uniion_private.agenda_publications;items jsonb='[]';a public.uniion_attachments;ref jsonb; archived jsonb;
begin
if not exists(select 1 from jsonb_array_elements(public.uniion_convocation_history(p_org)) h where h->>'id'=p_convocation::text) then raise insufficient_privilege;end if;
perform public.uniion_module_use(p_org,'documents');
if not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
select * into c from uniion_private.agenda_convocations where id=p_convocation;
select * into e from uniion_private.agenda_events where id=c.event_id;
if not(c.message ? 'attachment_version') then return '[]'::jsonb;end if;
select * into p from uniion_private.agenda_publications where event_id=c.event_id and version=(c.message->>'attachment_version')::integer and published_at is not null;
if not found then raise insufficient_privilege;end if;
perform uniion_private.agenda_file_check(p_org,coalesce(p.document->'convocation_files','[]'),auth.uid());
select files into archived from uniion_private.convocation_archives ar where ar.convocation=c.id and ar.organization_id=p_org and ar.ready and exists(select 1 from uniion_private.agenda_convocation_deliveries where convocation=c.id and status='sent');
if archived is not null then
 items=jsonb_build_array(jsonb_build_object('id','pdf','name','ordre-du-jour.pdf'),jsonb_build_object('id','ics','name','evenement.ics'));
end if;
for ref in select value from jsonb_array_elements(coalesce(p.document->'convocation_files','[]')) loop
 select * into a from public.uniion_attachments where id=(ref->>'id')::uuid;
 items=items||jsonb_build_array(jsonb_build_object('id',a.id,'name',a.filename));
end loop;
if p_file is null then return items;end if;
if not exists(select 1 from jsonb_array_elements(items) i where i->>'id'=p_file) then raise insufficient_privilege;end if;
if p_file in ('pdf','ics') then return jsonb_build_object('archive',(select value from jsonb_array_elements(archived) where value->>'id'=p_file));end if;
return jsonb_build_object('document',p.document,'version',p.version,'event',e.data||jsonb_build_object('id',e.id,'version',e.version));
end $$;
revoke all on function public.uniion_convocation_files(uuid,uuid,text) from public,anon;
grant execute on function public.uniion_convocation_files(uuid,uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;

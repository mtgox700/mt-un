begin;
create table public.uniion_resource_versions (
 organization_id uuid not null, resource_id uuid not null, version integer not null,
 body jsonb not null, at timestamptz not null default now(), actor uuid references auth.users,
 primary key(organization_id,resource_id,version),
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id)
);
alter table public.uniion_resource_versions enable row level security;
revoke all on public.uniion_resource_versions from public,anon,authenticated;
grant select on public.uniion_resource_versions to authenticated;
create policy readable_versions on public.uniion_resource_versions for select to authenticated
 using(uniion_private.resource_access(organization_id,resource_id,false));
-- Backfill the current version only; earlier test revisions cannot be recovered.
insert into public.uniion_resource_versions(organization_id,resource_id,version,body)
 select organization_id,id,version,body from public.uniion_resources;
create function uniion_private.record_version() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.uniion_resource_versions(organization_id,resource_id,version,body,actor)
 values(new.organization_id,new.id,new.version,new.body,auth.uid());return new;
end $$;
revoke all on function uniion_private.record_version() from public,anon,authenticated;
create trigger uniion_record_version after insert or update of body on public.uniion_resources
 for each row execute function uniion_private.record_version();
notify pgrst,'reload schema';
commit;

-- Foundation for a DEDICATED development project, not the complete S00 schema.
-- No data import, public signup grants, admin bypass or browser role assignment.
begin;
create schema if not exists uniion_private;
revoke all on schema uniion_private from public, anon, authenticated;

create table public.uniion_organizations (
 id uuid primary key default gen_random_uuid(), name text not null,
 active boolean not null default true
);
create table public.uniion_memberships (
 organization_id uuid not null references public.uniion_organizations(id),
 user_id uuid not null references auth.users(id),
 joined_at timestamptz not null default now(), revoked_at timestamptz,
 primary key(organization_id,user_id)
);
create index uniion_memberships_user on public.uniion_memberships(user_id);
create table public.uniion_module_access (
 organization_id uuid not null references public.uniion_organizations(id),
 module text not null, authorized boolean not null default false,
 enabled boolean not null default false,
 entitlement text not null check(entitlement in ('paid','commercial','included')),
 valid_until timestamptz not null,
 primary key(organization_id,module)
);
create table public.uniion_permissions (
 organization_id uuid not null, user_id uuid not null,
 module text not null, permission text not null check(permission in ('read','write')),
 primary key(organization_id,user_id,module,permission),
 foreign key(organization_id,user_id) references public.uniion_memberships,
 foreign key(organization_id,module) references public.uniion_module_access
);
create table public.uniion_resources (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null,
 module text not null, title text not null, body jsonb not null default '{}',
 created_at timestamptz not null default now(), version integer not null default 1,
 unique(organization_id,id),
 foreign key(organization_id,module) references public.uniion_module_access
);
create index uniion_resources_org on public.uniion_resources(organization_id);
create table public.uniion_resource_grants (
 organization_id uuid not null, resource_id uuid not null, user_id uuid not null,
 can_write boolean not null default false, history_approved boolean not null default false,
 valid_until timestamptz not null, revoked_at timestamptz,
 primary key(organization_id,resource_id,user_id),
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id),
 foreign key(organization_id,user_id) references public.uniion_memberships
);

create function uniion_private.member(org uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.uniion_memberships m
 join public.uniion_organizations o on o.id=m.organization_id
 where m.organization_id=org and m.user_id=auth.uid()
 and m.revoked_at is null and m.joined_at<=now() and o.active)
$$;
create function uniion_private.resource_access(org uuid, resource uuid, write_access boolean)
returns boolean language sql stable security definer set search_path = '' as $$
 select uniion_private.member(org) and exists(
 select 1 from public.uniion_resources r
 join public.uniion_resource_grants g on g.organization_id=r.organization_id and g.resource_id=r.id
 join public.uniion_memberships m on m.organization_id=g.organization_id and m.user_id=g.user_id
 join public.uniion_module_access a on a.organization_id=r.organization_id and a.module=r.module
 join public.uniion_permissions p on p.organization_id=g.organization_id and p.user_id=g.user_id and p.module=r.module
 where r.organization_id=org and r.id=resource and g.user_id=auth.uid()
 and g.revoked_at is null and g.valid_until>now()
 and (r.created_at>=m.joined_at or g.history_approved)
 and a.authorized and a.enabled and a.valid_until>now()
 and p.permission=case when write_access then 'write' else 'read' end
 and (not write_access or g.can_write))
$$;
revoke all on function uniion_private.member(uuid) from public;
revoke all on function uniion_private.resource_access(uuid,uuid,boolean) from public;
grant usage on schema uniion_private to authenticated;
grant execute on function uniion_private.member(uuid) to authenticated;
grant execute on function uniion_private.resource_access(uuid,uuid,boolean) to authenticated;

alter table public.uniion_organizations enable row level security;
alter table public.uniion_memberships enable row level security;
alter table public.uniion_module_access enable row level security;
alter table public.uniion_permissions enable row level security;
alter table public.uniion_resources enable row level security;
alter table public.uniion_resource_grants enable row level security;
revoke all on public.uniion_organizations, public.uniion_memberships,
 public.uniion_module_access, public.uniion_permissions, public.uniion_resources,
 public.uniion_resource_grants from anon, authenticated;
grant select on public.uniion_organizations,public.uniion_resources to authenticated;
create policy member_organizations on public.uniion_organizations for select to authenticated
 using (uniion_private.member(id));
create policy granted_resources on public.uniion_resources for select to authenticated
 using (uniion_private.resource_access(organization_id,id,false));
-- All mutations deliberately closed pending versioned/audited S00 commands.
-- No super-admin business bypass; no implicit federation/section access.
-- Sharing, support, files, AI and exports deliberately not exposed by this slice.
commit;

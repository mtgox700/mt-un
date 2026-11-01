begin;
create table uniion_private.module_catalog(id text primary key,name text not null,available boolean not null default true);
insert into uniion_private.module_catalog values('sondages','Sondages',true),('reunions','Réunions & comptes rendus',true),('signature','Signature électronique',true);
create table uniion_private.module_delegations(organization_id uuid references public.uniion_organizations,id text references uniion_private.module_catalog,enabled boolean not null default false,primary key(organization_id,id));
create table uniion_private.module_entitlements(id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.uniion_organizations,module text not null references uniion_private.module_catalog,kind text not null check(kind in ('paid','commercial')),starts timestamptz not null,ends timestamptz not null,reference text,reason text,created_by uuid references auth.users,revoked_at timestamptz,check(ends>starts),check((kind='paid' and length(btrim(reference))>0) or (kind='commercial' and length(btrim(reason)) between 1 and 240 and created_by is not null)));
create table uniion_private.module_events(id bigint generated always as identity primary key,organization_id uuid not null references public.uniion_organizations,module text not null,event text not null,actor uuid not null references auth.users,at timestamptz not null default now());
alter table uniion_private.module_catalog enable row level security;
alter table uniion_private.module_delegations enable row level security;
alter table uniion_private.module_entitlements enable row level security;
alter table uniion_private.module_events enable row level security;
revoke all on uniion_private.module_catalog,uniion_private.module_delegations,uniion_private.module_entitlements,uniion_private.module_events from public,anon,authenticated;
create function uniion_private.commercial_allowed(p_org uuid,p_module text) returns boolean language sql stable security definer set search_path='' as $$
select not exists(select 1 from uniion_private.module_catalog where id=p_module) or (exists(select 1 from uniion_private.module_catalog where id=p_module and available) and exists(select 1 from uniion_private.module_entitlements where organization_id=p_org and module=p_module and revoked_at is null and starts<=now() and ends>now()))
$$;
revoke all on function uniion_private.commercial_allowed(uuid,text) from public,anon,authenticated;
-- Existing resource and sharing guards retain their checks and also enforce the commercial gate.
do $patch$
declare r record;d text;n integer=0;
begin
for r in select p.oid from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname in ('public','uniion_private') and p.prokind='f' loop
 d=pg_get_functiondef(r.oid);
 if position('a.authorized and a.enabled and a.valid_until>now()' in d)>0 then
 d=replace(d,'a.authorized and a.enabled and a.valid_until>now()','a.authorized and a.enabled and a.valid_until>now() and uniion_private.commercial_allowed(a.organization_id,a.module)');execute d;n=n+1;
 elsif position('module=p_module and authorized and enabled and valid_until>now()' in d)>0 then
 d=replace(d,'module=p_module and authorized and enabled and valid_until>now()','module=p_module and authorized and enabled and valid_until>now() and uniion_private.commercial_allowed(organization_id,module)');execute d;n=n+1;
 end if;
end loop;
if n<5 then raise exception 'commercial guard coverage incomplete';end if;
end $patch$;
create function public.uniion_modules_context(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare global_admin boolean=uniion_private.super_admin();
begin
if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not exists(select 1 from public.uniion_organizations where id=p_org and active) or not (global_admin or uniion_private.actor_member(p_org,auth.uid())) then raise insufficient_privilege;end if;
return jsonb_build_object('superAdmin',global_admin,'manage',uniion_private.authority(p_org,auth.uid(),'organization_edit'),'organization',(select name from public.uniion_organizations where id=p_org),'modules',(select jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'available',c.available,'authorized',coalesce(a.authorized,false),'enabled',coalesce(a.enabled,false),'delegated',coalesce(d.enabled,false),'eligible',uniion_private.commercial_allowed(p_org,c.id),'canUse',uniion_private.actor_member(p_org,auth.uid()) and uniion_private.commercial_allowed(p_org,c.id) and coalesce(a.authorized and a.enabled and a.valid_until>now(),false) and exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=c.id and permission='read'),'entitlements',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'kind',e.kind,'from',e.starts,'until',e.ends,'reason',e.reason,'reference',e.reference,'revoked',e.revoked_at) order by e.starts) from uniion_private.module_entitlements e where e.organization_id=p_org and e.module=c.id),'[]'::jsonb)) order by c.id) from uniion_private.module_catalog c left join public.uniion_module_access a on a.organization_id=p_org and a.module=c.id left join uniion_private.module_delegations d on d.organization_id=p_org and d.id=c.id));
end $$;
create function public.uniion_module_config(p_org uuid,p_module text,p_action text,p_enabled boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
perform pg_advisory_xact_lock(72420943);
if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or p_enabled is null or p_action is null or p_action not in ('catalog','authorize','delegate','enable') or not exists(select 1 from uniion_private.module_catalog where id=p_module) or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
if not uniion_private.super_admin() then
 if p_action<>'enable' or not uniion_private.authority(p_org,auth.uid(),'organization_edit') or not uniion_private.actor_member(p_org,auth.uid()) or not exists(select 1 from uniion_private.module_delegations where organization_id=p_org and id=p_module and enabled) then raise insufficient_privilege;end if;
end if;
if p_action='enable' and p_enabled and (not uniion_private.commercial_allowed(p_org,p_module) or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized)) then raise insufficient_privilege;end if;
insert into public.uniion_module_access(organization_id,module,authorized,enabled,entitlement,valid_until) values(p_org,p_module,false,false,'commercial','infinity') on conflict do nothing;
if p_action='catalog' then update uniion_private.module_catalog set available=p_enabled where id=p_module;
elsif p_action='authorize' then update public.uniion_module_access set authorized=p_enabled where organization_id=p_org and module=p_module;
elsif p_action='delegate' then insert into uniion_private.module_delegations values(p_org,p_module,p_enabled) on conflict(organization_id,id) do update set enabled=excluded.enabled;
else update public.uniion_module_access set enabled=p_enabled where organization_id=p_org and module=p_module;end if;
insert into uniion_private.module_events(organization_id,module,event,actor) values(p_org,p_module,p_action||'.'||p_enabled::text,auth.uid());return jsonb_build_object('ok',true);
end $$;
create function public.uniion_module_commercial(p_org uuid,p_module text,p_reason text,p_from timestamptz,p_until timestamptz) returns jsonb language plpgsql security definer set search_path='' as $$
declare eid uuid;
begin
perform pg_advisory_xact_lock(72420943);
if not uniion_private.super_admin() or p_reason is null or length(btrim(p_reason)) not between 1 and 240 or p_from is null or p_until is null or p_until<=p_from or p_until<=now() or not exists(select 1 from public.uniion_organizations where id=p_org and active) or not exists(select 1 from uniion_private.module_catalog where id=p_module and available) or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized) then raise insufficient_privilege;end if;
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reason,created_by) values(p_org,p_module,'commercial',p_from,p_until,btrim(p_reason),auth.uid()) returning id into eid;
insert into uniion_private.module_events(organization_id,module,event,actor) values(p_org,p_module,'commercial.granted',auth.uid());return jsonb_build_object('id',eid);
end $$;
create function public.uniion_module_revoke(p_org uuid,p_module text,p_entitlement uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
perform pg_advisory_xact_lock(72420943);
if not uniion_private.super_admin() then raise insufficient_privilege;end if;
update uniion_private.module_entitlements set revoked_at=now() where id=p_entitlement and organization_id=p_org and module=p_module and kind='commercial' and revoked_at is null;
if not found then raise insufficient_privilege;end if;
insert into uniion_private.module_events(organization_id,module,event,actor) values(p_org,p_module,'commercial.revoked',auth.uid());return jsonb_build_object('ok',true);
end $$;
create function public.uniion_module_use(p_org uuid,p_module text) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.actor_member(p_org,auth.uid()) or not uniion_private.commercial_allowed(p_org,p_module) or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized and enabled and valid_until>now()) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission='read') then raise insufficient_privilege;end if;
return jsonb_build_object('allowed',true);
end $$;
revoke all on function public.uniion_modules_context(uuid),public.uniion_module_config(uuid,text,text,boolean),public.uniion_module_commercial(uuid,text,text,timestamptz,timestamptz),public.uniion_module_revoke(uuid,text,uuid),public.uniion_module_use(uuid,text) from public,anon;
grant execute on function public.uniion_modules_context(uuid),public.uniion_module_config(uuid,text,text,boolean),public.uniion_module_commercial(uuid,text,text,timestamptz,timestamptz),public.uniion_module_revoke(uuid,text,uuid),public.uniion_module_use(uuid,text) to authenticated;
commit;

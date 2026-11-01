begin;
create table uniion_private.super_admins(user_id uuid primary key references auth.users,active boolean not null default true);
create table uniion_private.platform_events(id bigint generated always as identity primary key,actor uuid not null references auth.users,event text not null,subject uuid not null references auth.users,at timestamptz not null default now());
alter table uniion_private.super_admins enable row level security;
alter table uniion_private.platform_events enable row level security;
revoke all on uniion_private.super_admins,uniion_private.platform_events from public,anon,authenticated;
create function uniion_private.super_admin() returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.session_allowed() and auth.jwt()->>'aal'='aal2' and exists(select 1 from uniion_private.super_admins where user_id=auth.uid() and active)
$$;
revoke all on function uniion_private.super_admin() from public,anon,authenticated;
create function public.uniion_platform_role() returns jsonb language sql stable security definer set search_path='' as $$ select jsonb_build_object('superAdmin',coalesce(uniion_private.super_admin(),false)) $$;
create function public.uniion_support_registry() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not uniion_private.super_admin() then raise insufficient_privilege;end if;
 return jsonb_build_object('agents',coalesce((select jsonb_agg(jsonb_build_object('id',user_id,'name',name,'active',active) order by name,user_id) from uniion_private.support_agents),'[]'));
end $$;
create function public.uniion_support_registry_save(p_user uuid,p_name text,p_enabled boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.super_admin() or p_user is null or p_name is null or length(btrim(p_name)) not between 1 and 120 or p_enabled is null or not exists(select 1 from auth.users where id=p_user and email_confirmed_at is not null) then raise insufficient_privilege;end if;
 -- Serialize registry changes with assignment and grant creation.
 perform pg_advisory_xact_lock(72420942);
 insert into uniion_private.support_agents(user_id,name,active) values(p_user,btrim(p_name),p_enabled) on conflict(user_id) do update set name=excluded.name,active=excluded.active;
 if not p_enabled then
 update uniion_private.support_assignments set active=false where user_id=p_user and active;
 update uniion_private.support_grants set excluded=array(select distinct v from unnest(excluded||array[p_user]) v) where p_user=any(agents);
 update uniion_private.support_requests set status='cancelled' where agent=p_user and status='pending';
 end if;
 insert into uniion_private.platform_events(actor,event,subject) values(auth.uid(),case when p_enabled then 'support.agent.enabled' else 'support.agent.disabled' end,p_user);
 return jsonb_build_object('id',p_user,'active',p_enabled,'business_access',false);
end $$;
alter function public.uniion_support_approve(uuid,uuid,uuid[],uuid[],timestamptz,boolean) rename to uniion_support_approve_before_registry;
revoke all on function public.uniion_support_approve_before_registry(uuid,uuid,uuid[],uuid[],timestamptz,boolean) from public,anon,authenticated;
create function public.uniion_support_approve(p_org uuid,p_ticket uuid,p_agents uuid[],p_resources uuid[],p_until timestamptz,p_download boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin perform pg_advisory_xact_lock(72420942);return public.uniion_support_approve_before_registry(p_org,p_ticket,p_agents,p_resources,p_until,p_download);end $$;
alter function public.uniion_support_assign(uuid,uuid,uuid[]) rename to uniion_support_assign_before_registry;
revoke all on function public.uniion_support_assign_before_registry(uuid,uuid,uuid[]) from public,anon,authenticated;
create function public.uniion_support_assign(p_org uuid,p_ticket uuid,p_agents uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
begin perform pg_advisory_xact_lock(72420942);return public.uniion_support_assign_before_registry(p_org,p_ticket,p_agents);end $$;
-- A registry role allows identity setup, never business access or organization membership.
create or replace function uniion_private.identity_in_scope() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_memberships where user_id=auth.uid()) or exists(select 1 from uniion_private.platform_operators where user_id=auth.uid()) or exists(select 1 from uniion_private.super_admins where user_id=auth.uid() and active) or exists(select 1 from uniion_private.support_agents where user_id=auth.uid() and active)
$$;
revoke all on function public.uniion_platform_role(),public.uniion_support_registry(),public.uniion_support_registry_save(uuid,text,boolean),public.uniion_support_approve(uuid,uuid,uuid[],uuid[],timestamptz,boolean),public.uniion_support_assign(uuid,uuid,uuid[]) from public,anon;
grant execute on function public.uniion_platform_role(),public.uniion_support_registry(),public.uniion_support_registry_save(uuid,text,boolean),public.uniion_support_approve(uuid,uuid,uuid[],uuid[],timestamptz,boolean),public.uniion_support_assign(uuid,uuid,uuid[]) to authenticated;
do $lock_request$
declare definition text;
begin
 select pg_get_functiondef('public.uniion_support_request(uuid,uuid,text)'::regprocedure) into definition;
 execute replace(definition,E'begin\n',E'begin\n perform pg_advisory_xact_lock(72420942);\n');
end $lock_request$;
commit;

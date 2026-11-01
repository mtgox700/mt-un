begin;
alter table public.uniion_partners add column active boolean not null default true;
create table uniion_private.partner_events(id bigint generated always as identity primary key,source_id uuid not null references public.uniion_organizations,target_id uuid not null references public.uniion_organizations,enabled boolean not null,actor uuid not null references auth.users,at timestamptz not null default now());
alter table uniion_private.partner_events enable row level security;
revoke all on uniion_private.partner_events from public,anon,authenticated;
-- Preserve directional semantics. A suspended relation cannot create new proposals or directory consents.
do $patch$
declare r record;d text;n integer=0;
begin
for r in select p.oid from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname in ('public','uniion_private') and p.prokind='f' loop
 d=pg_get_functiondef(r.oid);
 if position('public.uniion_partners' in d)>0 then
 d=replace(d,'where p.source_id=','where p.active and p.source_id=');
 d=replace(d,'where p.target_id=','where p.active and p.target_id=');
 d=replace(d,'from public.uniion_partners where source_id=','from public.uniion_partners where active and source_id=');
 execute d;n=n+1;
 end if;
end loop;
if n<5 then raise exception 'partner guard coverage incomplete';end if;
end $patch$;
create function public.uniion_partners_registry() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
if not uniion_private.super_admin() then raise insufficient_privilege;end if;
return jsonb_build_object('organizations',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'active',active) order by name,id) from public.uniion_organizations),'[]'::jsonb),'partners',coalesce((select jsonb_agg(jsonb_build_object('source',source_id,'target',target_id,'active',active) order by source_id,target_id) from public.uniion_partners),'[]'::jsonb),'events',coalesce((select jsonb_agg(to_jsonb(e) order by e.at desc,e.id desc) from (select id,source_id,target_id,enabled,at from uniion_private.partner_events order by at desc,id desc limit 100) e),'[]'::jsonb));
end $$;
create function public.uniion_partners_save(p_source uuid,p_target uuid,p_enabled boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
if not uniion_private.super_admin() or p_source is null or p_target is null or p_source=p_target or p_enabled is null then raise insufficient_privilege;end if;
perform pg_advisory_xact_lock(72420946);
if not exists(select 1 from public.uniion_organizations where id=p_source and (active or not p_enabled)) or not exists(select 1 from public.uniion_organizations where id=p_target and (active or not p_enabled)) then raise insufficient_privilege;end if;
insert into public.uniion_partners(source_id,target_id,active) values(p_source,p_target,p_enabled) on conflict(source_id,target_id) do update set active=excluded.active;
insert into uniion_private.partner_events(source_id,target_id,enabled,actor) values(p_source,p_target,p_enabled,auth.uid());
return jsonb_build_object('ok',true,'business_access',false);
end $$;
revoke all on function public.uniion_partners_registry(),public.uniion_partners_save(uuid,uuid,boolean) from public,anon;
grant execute on function public.uniion_partners_registry(),public.uniion_partners_save(uuid,uuid,boolean) to authenticated;
notify pgrst,'reload schema';
commit;

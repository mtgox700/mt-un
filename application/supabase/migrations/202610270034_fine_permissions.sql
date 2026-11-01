begin;
create or replace function public.uniion_rights_change(p_org uuid,p_user uuid,p_type text,p_module text,p_permission text,p_enabled boolean,p_resource uuid default null,p_until timestamptz default null,p_history boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare mine uuid=auth.uid();r public.uniion_resources;g public.uniion_resource_grants;
begin
 if not uniion_private.identity_admin(p_org) or p_enabled is null or p_history is null or p_type is null or p_permission is null then raise insufficient_privilege;end if;
 if mine=p_user or not uniion_private.authority(p_org,mine,'rights') or not uniion_private.actor_member(p_org,p_user) then raise insufficient_privilege; end if;
 if p_type='permission' then
  if p_module is null or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized and enabled and valid_until>now()) then raise insufficient_privilege;end if;
  if p_permission not in ('read','write','create') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=mine and module=p_module and permission=p_permission) then raise insufficient_privilege; end if;
  if p_enabled then insert into public.uniion_permissions values(p_org,p_user,p_module,p_permission) on conflict do nothing;
  else delete from public.uniion_permissions where organization_id=p_org and user_id=p_user and module=p_module and permission=p_permission; end if;
 elsif p_type='authority' then
  if not exists(select 1 from public.uniion_authorities where organization_id=p_org and user_id=mine and permission=p_permission and delegable) then raise insufficient_privilege; end if;
  if p_enabled then insert into public.uniion_authorities values(p_org,p_user,p_permission,false) on conflict do nothing;
  else delete from public.uniion_authorities where organization_id=p_org and user_id=p_user and permission=p_permission; end if;
 elsif p_type='resource' then
  select * into r from public.uniion_resources where id=p_resource and organization_id=p_org;
  if not found or not uniion_private.actor_resource(p_org,p_resource,mine,false) then raise insufficient_privilege; end if;
  select * into g from public.uniion_resource_grants where organization_id=p_org and resource_id=p_resource and user_id=mine;
  if p_permission not in ('read','write') or (p_permission='write' and not uniion_private.actor_resource(p_org,p_resource,mine,true)) then raise insufficient_privilege; end if;
  if p_enabled then
   if g.user_id is null or g.revoked_at is not null or g.valid_until is null then raise insufficient_privilege;end if;
   if p_until is null or p_until<=now() or p_until>g.valid_until or (p_history and not uniion_private.authority(p_org,mine,'history')) then raise insufficient_privilege; end if;
   -- No automatic historical unlock: a resource predating membership requires its own permission.
   insert into public.uniion_resource_grants values(p_org,p_resource,p_user,p_permission='write',p_history,p_until,null)
   on conflict(organization_id,resource_id,user_id) do update set can_write=excluded.can_write,history_approved=excluded.history_approved,valid_until=excluded.valid_until,revoked_at=null;
  else update public.uniion_resource_grants set revoked_at=now() where organization_id=p_org and resource_id=p_resource and user_id=p_user; end if;
 else raise insufficient_privilege;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,mine,'rights.changed',jsonb_build_object('user',p_user,'type',p_type,'module',p_module,'permission',p_permission,'enabled',p_enabled,'resource',p_resource,'until',p_until,'history',p_history));
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.uniion_rights_batch(p_org uuid,p_user uuid,p_changes jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c jsonb;k text;
begin
 if not uniion_private.identity_admin(p_org) or p_user=auth.uid() or not uniion_private.actor_member(p_org,p_user) then raise insufficient_privilege;end if;
 if p_changes is null or jsonb_typeof(p_changes)<>'array' or jsonb_array_length(p_changes) not between 1 and 100 then raise insufficient_privilege;end if;
 for c in select value from jsonb_array_elements(p_changes) loop
 if jsonb_typeof(c)<>'object' or jsonb_typeof(c->'enabled') is distinct from 'boolean' or not(c?'type' and c?'permission') then raise insufficient_privilege;end if;
 for k in select jsonb_object_keys(c) loop
 if k<>all(array['type','module','permission','enabled','resource','until','history']) then raise insufficient_privilege;end if;end loop;
 if c?'history' and jsonb_typeof(c->'history')<>'boolean' then raise insufficient_privilege;end if;
 perform public.uniion_rights_change(p_org,p_user,c->>'type',c->>'module',c->>'permission',(c->>'enabled')::boolean,(c->>'resource')::uuid,(c->>'until')::timestamptz,coalesce((c->>'history')::boolean,false));
 end loop;
 return jsonb_build_object('ok',true);
end $$;
create function public.uniion_identity_rights(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 result=public.uniion_admin_context(p_org);
 return jsonb_build_object('members',result->'members','resources',result->'resources','authorities',result->'authorities','permissions',coalesce((select jsonb_agg(jsonb_build_object('module',p.module,'permission',p.permission)) from public.uniion_permissions p join public.uniion_module_access a using(organization_id,module) where p.organization_id=p_org and p.user_id=auth.uid() and a.authorized and a.enabled and a.valid_until>now()),'[]'::jsonb));
end $$;
revoke all on function public.uniion_identity_rights(uuid) from public,anon;
grant execute on function public.uniion_identity_rights(uuid) to authenticated;
commit;

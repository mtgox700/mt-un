begin;
alter table public.uniion_authorities drop constraint uniion_authorities_permission_check;
alter table public.uniion_authorities add constraint uniion_authorities_permission_check check(permission in ('rights','share','accept','download','history','organization_edit','collection_publish','collection_accept','agenda_audience'));
alter table uniion_private.agenda_audiences drop constraint agenda_audiences_audience_check;
alter table uniion_private.agenda_audiences add constraint agenda_audiences_audience_check check(audience in ('none','elus','adherents','public'));
CREATE OR REPLACE FUNCTION public.uniion_rights_change(p_org uuid, p_user uuid, p_type text, p_module text, p_permission text, p_enabled boolean, p_resource uuid DEFAULT NULL::uuid, p_until timestamp with time zone DEFAULT NULL::timestamp with time zone, p_history boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare mine uuid=auth.uid();r public.uniion_resources;g public.uniion_resource_grants;
begin
 if not uniion_private.identity_admin(p_org) or p_enabled is null or p_history is null or p_type is null or p_permission is null then raise insufficient_privilege;end if;
 if mine=p_user or not uniion_private.authority(p_org,mine,'rights') or not uniion_private.actor_member(p_org,p_user) then raise insufficient_privilege; end if;
 if p_type='agenda_audience' then
  perform public.uniion_module_use(p_org,'agenda');
  if not uniion_private.authority(p_org,mine,'agenda_audience') or p_permission not in ('elus','adherents','public','none') or (not p_enabled and p_permission<>'none') or (p_enabled and p_permission='none') then raise insufficient_privilege;end if;
  if p_enabled and not exists(select 1 from uniion_private.agenda_audiences where organization_id=p_org and user_id=mine and (audience='elus' or (audience='adherents' and p_permission in ('adherents','public')) or (audience='public' and p_permission='public'))) then raise insufficient_privilege;end if;
  insert into uniion_private.agenda_audiences values(p_org,p_user,p_permission) on conflict(organization_id,user_id) do update set audience=excluded.audience;
  perform uniion_private.agenda_enqueue();
 elsif p_type='permission' then
  if p_module is null or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized and enabled and valid_until>now() and uniion_private.commercial_allowed(organization_id,module)) then raise insufficient_privilege;end if;
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
end $function$

;

create function public.uniion_agenda_audience_context(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare own text;
begin
 if not uniion_private.identity_admin(p_org) or not uniion_private.authority(p_org,auth.uid(),'agenda_audience') then return jsonb_build_object('manage',false,'members','[]'::jsonb,'options','[]'::jsonb);end if;
 perform public.uniion_module_use(p_org,'agenda');
 select audience into own from uniion_private.agenda_audiences where organization_id=p_org and user_id=auth.uid();
 return jsonb_build_object('manage',true,'options',case own when 'elus' then '["none","elus","adherents","public"]'::jsonb when 'adherents' then '["none","adherents","public"]'::jsonb when 'public' then '["none","public"]'::jsonb else '["none"]'::jsonb end,'members',coalesce((select jsonb_agg(jsonb_build_object('user',m.user_id,'audience',coalesce(a.audience,'none'))) from public.uniion_memberships m left join uniion_private.agenda_audiences a on a.organization_id=m.organization_id and a.user_id=m.user_id where m.organization_id=p_org and uniion_private.actor_member(p_org,m.user_id)),'[]'::jsonb));
end;$$;
revoke all on function public.uniion_agenda_audience_context(uuid) from public,anon;
grant execute on function public.uniion_agenda_audience_context(uuid) to authenticated;
commit;

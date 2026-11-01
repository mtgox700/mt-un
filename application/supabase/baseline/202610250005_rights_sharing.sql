begin;
create table public.uniion_authorities (
 organization_id uuid not null,user_id uuid not null,
 permission text not null check(permission in ('rights','share','accept','download','history')),
 delegable boolean not null default false,
 primary key(organization_id,user_id,permission),
 foreign key(organization_id,user_id) references public.uniion_memberships
);
create table public.uniion_partners (
 source_id uuid not null references public.uniion_organizations,target_id uuid not null references public.uniion_organizations,
 primary key(source_id,target_id),check(source_id<>target_id)
);
alter table public.uniion_resources add column external_share_allowed boolean not null default false;
create table public.uniion_shares (
 id uuid primary key default gen_random_uuid(),source_id uuid not null references public.uniion_organizations,
 target_id uuid not null references public.uniion_organizations,creator uuid not null references auth.users,
 allowed uuid[] not null,beneficiaries uuid[] not null default '{}',
 download boolean not null default false,expires_at timestamptz not null,
 created_at timestamptz not null default now(),accepted_at timestamptz,accepted_by uuid references auth.users,
 revoked_at timestamptz,revoked_by uuid references auth.users,
 check(source_id<>target_id),check(cardinality(allowed)>0),check(beneficiaries<@allowed)
);
create index uniion_shares_target on public.uniion_shares(target_id);
create index uniion_shares_source on public.uniion_shares(source_id);
create table public.uniion_share_items (
 share_id uuid not null references public.uniion_shares,organization_id uuid not null,resource_id uuid not null,version integer not null,
 primary key(share_id,resource_id),
 foreign key(organization_id,resource_id,version) references public.uniion_resource_versions(organization_id,resource_id,version)
);
create table public.uniion_security_events (
 id bigint generated always as identity primary key,organization_id uuid not null references public.uniion_organizations,
 target_id uuid references public.uniion_organizations,actor uuid not null references auth.users,
 event text not null,details jsonb not null,at timestamptz not null default now()
);
alter table public.uniion_authorities enable row level security;
alter table public.uniion_partners enable row level security;
alter table public.uniion_shares enable row level security;
alter table public.uniion_share_items enable row level security;
alter table public.uniion_security_events enable row level security;
revoke all on public.uniion_authorities,public.uniion_partners,public.uniion_shares,public.uniion_share_items,public.uniion_security_events from public,anon,authenticated;

create function uniion_private.actor_member(org uuid,who uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_memberships m join public.uniion_organizations o on o.id=m.organization_id where m.organization_id=org and m.user_id=who and m.revoked_at is null and m.joined_at<=now() and o.active)
$$;
create function uniion_private.authority(org uuid,who uuid,perm text) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.actor_member(org,who) and exists(select 1 from public.uniion_authorities where organization_id=org and user_id=who and permission=perm)
$$;
create function uniion_private.actor_resource(org uuid,res uuid,who uuid,wr boolean default false) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.actor_member(org,who) and exists(select 1 from public.uniion_resources r
 join public.uniion_resource_grants g on g.organization_id=r.organization_id and g.resource_id=r.id
 join public.uniion_memberships m on m.organization_id=g.organization_id and m.user_id=g.user_id
 join public.uniion_module_access a on a.organization_id=r.organization_id and a.module=r.module
 join public.uniion_permissions p on p.organization_id=g.organization_id and p.user_id=g.user_id and p.module=r.module
 where r.organization_id=org and r.id=res and g.user_id=who and g.revoked_at is null and g.valid_until>now()
 and (r.created_at>=m.joined_at or g.history_approved) and a.authorized and a.enabled and a.valid_until>now()
 and p.permission=case when wr then 'write' else 'read' end and (not wr or g.can_write))
$$;
create function uniion_private.share_access(sid uuid,res uuid,who uuid,dl boolean default false) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_shares s join public.uniion_share_items i on i.share_id=s.id
 join public.uniion_resources r on r.id=i.resource_id and r.organization_id=i.organization_id
 where s.id=sid and i.resource_id=res and i.organization_id=s.source_id and r.external_share_allowed
 and s.accepted_at is not null and s.revoked_at is null and s.expires_at>now() and who=any(s.beneficiaries)
 and uniion_private.actor_member(s.target_id,who)
 and uniion_private.authority(s.source_id,s.creator,'share')
 and uniion_private.actor_resource(s.source_id,res,s.creator,false)
 and exists(select 1 from public.uniion_permissions p join public.uniion_module_access a using(organization_id,module)
 where p.organization_id=s.target_id and p.user_id=who and p.module=r.module and p.permission='read' and a.authorized and a.enabled and a.valid_until>now())
 and (not dl or (s.download and uniion_private.authority(s.source_id,s.creator,'download') and uniion_private.authority(s.target_id,who,'download'))))
$$;

create function public.uniion_rights_change(p_org uuid,p_user uuid,p_type text,p_module text,p_permission text,p_enabled boolean,p_resource uuid default null,p_until timestamptz default null,p_history boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare mine uuid=auth.uid();r public.uniion_resources;g public.uniion_resource_grants;
begin
 if mine=p_user or not uniion_private.authority(p_org,mine,'rights') or not uniion_private.actor_member(p_org,p_user) then raise insufficient_privilege; end if;
 if p_type='permission' then
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

create function public.uniion_share_create(p_org uuid,p_target uuid,p_resources uuid[],p_people uuid[],p_until timestamptz,p_download boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare sid uuid;res uuid;person uuid;mine uuid=auth.uid();r public.uniion_resources;
begin
 if not uniion_private.authority(p_org,mine,'share') or p_org=p_target or not exists(select 1 from public.uniion_partners where source_id=p_org and target_id=p_target) or (p_download and not uniion_private.authority(p_org,mine,'download')) then raise insufficient_privilege; end if;
 if p_until is null or p_until<=now() or p_until>now()+interval '90 days' or coalesce(cardinality(p_resources),0) not between 1 and 20 or coalesce(cardinality(p_people),0) not between 1 and 20 then raise check_violation; end if;
 foreach person in array p_people loop if not uniion_private.actor_member(p_target,person) then raise insufficient_privilege; end if; end loop;
 insert into public.uniion_shares(source_id,target_id,creator,allowed,expires_at,download) values(p_org,p_target,mine,p_people,p_until,p_download) returning id into sid;
 foreach res in array p_resources loop
  select * into r from public.uniion_resources where id=res and organization_id=p_org;
  if not found or not r.external_share_allowed or not uniion_private.actor_resource(p_org,res,mine,false) then raise insufficient_privilege; end if;
  insert into public.uniion_share_items values(sid,p_org,res,r.version);
 end loop;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(p_org,p_target,mine,'share.created',jsonb_build_object('share',sid,'resources',p_resources,'people',p_people,'download',p_download,'expires',p_until));
 return sid;
end $$;
create function public.uniion_share_accept(p_org uuid,p_share uuid,p_people uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.uniion_shares;person uuid;
begin
 select * into s from public.uniion_shares where id=p_share for update;
 if not found or s.target_id<>p_org or not uniion_private.authority(p_org,auth.uid(),'accept') or s.revoked_at is not null or s.expires_at<=now() or s.accepted_at is not null or not uniion_private.authority(s.source_id,s.creator,'share') then raise insufficient_privilege; end if;
 if coalesce(cardinality(p_people),0)=0 or not p_people<@s.allowed then raise insufficient_privilege; end if;
 foreach person in array p_people loop if not uniion_private.actor_member(p_org,person) then raise insufficient_privilege; end if; end loop;
 update public.uniion_shares set beneficiaries=p_people,accepted_at=now(),accepted_by=auth.uid() where id=p_share;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(s.source_id,s.target_id,auth.uid(),'share.accepted',jsonb_build_object('share',p_share,'people',p_people));
 return jsonb_build_object('ok',true);
end $$;
create function public.uniion_share_revoke(p_org uuid,p_share uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.uniion_shares;
begin
 select * into s from public.uniion_shares where id=p_share for update;
 if not found or s.source_id<>p_org or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege; end if;
 update public.uniion_shares set revoked_at=coalesce(revoked_at,now()),revoked_by=auth.uid() where id=p_share;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(s.source_id,s.target_id,auth.uid(),'share.revoked',jsonb_build_object('share',p_share));
 return jsonb_build_object('ok',true);
end $$;
create function public.uniion_shared_read(p_org uuid,p_share uuid,p_resource uuid,p_download boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.uniion_shares;result jsonb;
begin
 select * into s from public.uniion_shares where id=p_share;
 if not found or s.target_id<>p_org or not uniion_private.share_access(p_share,p_resource,auth.uid(),p_download) then raise insufficient_privilege; end if;
 select jsonb_build_object('id',r.id,'title',v.body->>'title','body',v.body,'version',v.version,'source',s.source_id,'expires',s.expires_at)
 into result from public.uniion_share_items i join public.uniion_resources r on r.id=i.resource_id join public.uniion_resource_versions v on v.organization_id=i.organization_id and v.resource_id=i.resource_id and v.version=i.version where i.share_id=p_share and i.resource_id=p_resource;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(s.source_id,s.target_id,auth.uid(),case when p_download then 'share.downloaded' else 'share.read' end,jsonb_build_object('share',p_share,'resource',p_resource));
 return result;
end $$;

create function public.uniion_admin_context(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare mine uuid=auth.uid();result jsonb;manage boolean;
begin
 if not uniion_private.member(p_org) then raise insufficient_privilege; end if;
 manage=uniion_private.authority(p_org,mine,'rights');
 select jsonb_build_object(
 'authorities',coalesce((select jsonb_agg(jsonb_build_object('permission',permission,'delegable',delegable)) from public.uniion_authorities where organization_id=p_org and user_id=mine),'[]'::jsonb),
 'members',case when manage then coalesce((select jsonb_agg(jsonb_build_object('id',m.user_id,'name',u.email,
 'permissions',(select coalesce(jsonb_agg(jsonb_build_object('module',p.module,'permission',p.permission)),'[]'::jsonb) from public.uniion_permissions p where p.organization_id=p_org and p.user_id=m.user_id),
 'authorities',(select coalesce(jsonb_agg(a.permission),'[]'::jsonb) from public.uniion_authorities a where a.organization_id=p_org and a.user_id=m.user_id),
 'grants',(select coalesce(jsonb_agg(jsonb_build_object('resource',g.resource_id,'write',g.can_write,'until',g.valid_until,'history',g.history_approved,'revoked',g.revoked_at)),'[]'::jsonb) from public.uniion_resource_grants g where g.organization_id=p_org and g.user_id=m.user_id and uniion_private.actor_resource(p_org,g.resource_id,mine,false)))) from public.uniion_memberships m join auth.users u on u.id=m.user_id where m.organization_id=p_org and uniion_private.actor_member(p_org,m.user_id)),'[]'::jsonb) else '[]'::jsonb end,
 'resources',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'title',r.title,'version',r.version,'module',r.module,'shareable',r.external_share_allowed,'write',uniion_private.actor_resource(p_org,r.id,mine,true))) from public.uniion_resources r where r.organization_id=p_org and uniion_private.actor_resource(p_org,r.id,mine,false)),'[]'::jsonb),
 'partners',case when uniion_private.authority(p_org,mine,'share') then coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'members',(select coalesce(jsonb_agg(jsonb_build_object('id',m.user_id,'name',u.email)),'[]'::jsonb) from public.uniion_memberships m join auth.users u on u.id=m.user_id where m.organization_id=o.id and uniion_private.actor_member(o.id,m.user_id)))) from public.uniion_partners p join public.uniion_organizations o on o.id=p.target_id where p.source_id=p_org and o.active),'[]'::jsonb) else '[]'::jsonb end,
 'shares',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'source',s.source_id,'target',s.target_id,'source_name',so.name,'target_name',ta.name,'allowed',s.allowed,'beneficiaries',s.beneficiaries,'download',s.download,'expires',s.expires_at,'accepted',s.accepted_at,'revoked',s.revoked_at,
 'people',(select jsonb_agg(jsonb_build_object('id',u.id,'name',u.email)) from auth.users u where u.id=any(s.allowed)),
 'items',(select jsonb_agg(jsonb_build_object('id',i.resource_id,'version',i.version,'title',v.body->>'title','readable',uniion_private.share_access(s.id,i.resource_id,mine,false),'downloadable',uniion_private.share_access(s.id,i.resource_id,mine,true))) from public.uniion_share_items i join public.uniion_resource_versions v on v.organization_id=i.organization_id and v.resource_id=i.resource_id and v.version=i.version where i.share_id=s.id and (s.source_id=p_org or uniion_private.authority(p_org,mine,'accept') or uniion_private.share_access(s.id,i.resource_id,mine,false))))) from public.uniion_shares s join public.uniion_organizations so on so.id=s.source_id join public.uniion_organizations ta on ta.id=s.target_id where (s.source_id=p_org and uniion_private.authority(p_org,mine,'share') and not exists(select 1 from public.uniion_share_items i where i.share_id=s.id and not uniion_private.actor_resource(p_org,i.resource_id,mine,false))) or (s.target_id=p_org and (uniion_private.authority(p_org,mine,'accept') or (mine=any(s.beneficiaries) and exists(select 1 from public.uniion_share_items z where z.share_id=s.id and uniion_private.share_access(s.id,z.resource_id,mine,false)))))),'[]'::jsonb),
 'events',case when manage then coalesce((select jsonb_agg(x) from (select event,details,at from public.uniion_security_events where organization_id=p_org or target_id=p_org order by id desc limit 100)x),'[]'::jsonb) else '[]'::jsonb end
 ) into result;
 return result;
end $$;
-- No table access; every exposed RPC verifies its own caller and scope.
revoke all on function uniion_private.actor_member(uuid,uuid),uniion_private.authority(uuid,uuid,text),uniion_private.actor_resource(uuid,uuid,uuid,boolean),uniion_private.share_access(uuid,uuid,uuid,boolean) from public,anon,authenticated;
revoke all on function public.uniion_rights_change(uuid,uuid,text,text,text,boolean,uuid,timestamptz,boolean),public.uniion_share_create(uuid,uuid,uuid[],uuid[],timestamptz,boolean),public.uniion_share_accept(uuid,uuid,uuid[]),public.uniion_share_revoke(uuid,uuid),public.uniion_shared_read(uuid,uuid,uuid,boolean),public.uniion_admin_context(uuid) from public,anon;
grant execute on function public.uniion_rights_change(uuid,uuid,text,text,text,boolean,uuid,timestamptz,boolean),public.uniion_share_create(uuid,uuid,uuid[],uuid[],timestamptz,boolean),public.uniion_share_accept(uuid,uuid,uuid[]),public.uniion_share_revoke(uuid,uuid),public.uniion_shared_read(uuid,uuid,uuid,boolean),public.uniion_admin_context(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

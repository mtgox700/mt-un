begin;
-- Provisioned administratively, never by a browser role selector.
create table uniion_private.support_agents(user_id uuid primary key references auth.users,name text not null,active boolean not null default true);
create table uniion_private.support_assignments(ticket uuid references uniion_private.support_tickets,user_id uuid references uniion_private.support_agents,primary key(ticket,user_id));
create table uniion_private.support_grants(id uuid primary key default gen_random_uuid(),ticket uuid not null references uniion_private.support_tickets,agents uuid[] not null,expires timestamptz not null,download boolean not null,creator uuid not null references auth.users,revoked_at timestamptz);
create table uniion_private.support_items(grant_id uuid references uniion_private.support_grants,resource uuid references public.uniion_resources,version integer not null,title text not null,body jsonb not null,primary key(grant_id,resource));
alter table uniion_private.support_agents enable row level security;
alter table uniion_private.support_assignments enable row level security;
alter table uniion_private.support_grants enable row level security;
alter table uniion_private.support_items enable row level security;
revoke all on uniion_private.support_agents,uniion_private.support_assignments,uniion_private.support_grants,uniion_private.support_items from public,anon,authenticated;
create function uniion_private.support_assigned(t uuid,u uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from uniion_private.support_assignments x join uniion_private.support_agents a on a.user_id=x.user_id where x.ticket=t and a.user_id=u and a.active)
$$;
revoke all on function uniion_private.support_assigned(uuid,uuid) from public,anon,authenticated;
create function public.uniion_support_approve(p_org uuid,p_ticket uuid,p_agents uuid[],p_resources uuid[],p_until timestamptz,p_download boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uniion_private.support_tickets;gid uuid;r public.uniion_resources;rid uuid;uid uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') or p_download is null or (p_download and not uniion_private.authority(p_org,auth.uid(),'download')) then raise insufficient_privilege;end if;
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for update;
 if not found or t.state<>'open' or p_until is null or p_until<=now() or p_until>now()+interval '90 days' or coalesce(cardinality(p_agents),0) not between 1 and 20 or coalesce(cardinality(p_resources),0) not between 1 and 20 then raise insufficient_privilege;end if;
 foreach uid in array p_agents loop if uid is null or not uniion_private.support_assigned(t.id,uid) then raise insufficient_privilege;end if;end loop;
 insert into uniion_private.support_grants(ticket,agents,expires,download,creator) values(t.id,p_agents,p_until,p_download,auth.uid()) returning id into gid;
 foreach rid in array p_resources loop
 select * into r from public.uniion_resources where id=rid and organization_id=p_org;
 if not found or not r.external_share_allowed or not uniion_private.actor_resource(p_org,rid,auth.uid(),false) then raise insufficient_privilege;end if;
 insert into uniion_private.support_items values(gid,r.id,r.version,r.title,r.body);
 end loop;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.approved',jsonb_build_object('ticket',t.id,'grant',gid,'agents',p_agents,'resources',p_resources,'expires',p_until,'download',p_download));
 return jsonb_build_object('id',gid);
end $$;
create or replace function public.uniion_support_status(p_org uuid,p_ticket uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uniion_private.support_tickets;manager boolean;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 manager=uniion_private.authority(p_org,auth.uid(),'share');
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for update;
 if not found or not(manager or uniion_private.support_assigned(t.id,auth.uid())) then raise insufficient_privilege;end if;
 if p_action='close' and t.state='open' then
 update uniion_private.support_tickets set state='closed',closed_at=now(),closed_by=auth.uid() where id=t.id;
 update uniion_private.support_grants set revoked_at=now() where ticket=t.id and revoked_at is null;
 elsif p_action='reopen' and t.state='closed' and manager then update uniion_private.support_tickets set state='open' where id=t.id;
 else raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.'||p_action,jsonb_build_object('ticket',t.id));
 return jsonb_build_object('id',t.id,'state',case when p_action='close' then 'closed' else 'open' end,'business_access',false);
end $$;
create function public.uniion_support_revoke(p_org uuid,p_ticket uuid,p_grant uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege;end if;
 perform 1 from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for update;if not found then raise insufficient_privilege;end if;
 update uniion_private.support_grants set revoked_at=now() where id=p_grant and ticket=p_ticket and revoked_at is null;if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.revoked',jsonb_build_object('ticket',p_ticket,'grant',p_grant));return true;
end $$;
create function public.uniion_support_read(p_org uuid,p_ticket uuid,p_grant uuid,p_resource uuid,p_download boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uniion_private.support_tickets;g uniion_private.support_grants;i uniion_private.support_items;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or p_download is null or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for share;
 if not found or t.state<>'open' or not uniion_private.support_assigned(t.id,auth.uid()) then raise insufficient_privilege;end if;
 select * into g from uniion_private.support_grants where id=p_grant and ticket=t.id for share;
 if not found or g.revoked_at is not null or g.expires<=now() or not(auth.uid()=any(g.agents)) or (p_download and not g.download) or not uniion_private.authority(p_org,g.creator,'share') or (p_download and not uniion_private.authority(p_org,g.creator,'download')) then raise insufficient_privilege;end if;
 select * into i from uniion_private.support_items where grant_id=g.id and resource=p_resource;
 if not found or not uniion_private.actor_resource(p_org,p_resource,g.creator,false) or not exists(select 1 from public.uniion_resources where id=p_resource and organization_id=p_org and external_share_allowed) then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_download then 'support.downloaded' else 'support.read' end,jsonb_build_object('ticket',t.id,'grant',g.id,'resource',i.resource));
 return jsonb_build_object('title',i.title,'version',i.version,'body',i.body);
end $$;
create or replace function public.uniion_support_context(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manage boolean;member boolean;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 member=uniion_private.member(p_org);manage=uniion_private.authority(p_org,auth.uid(),'share');
 if not member and not exists(select 1 from uniion_private.support_tickets t where t.organization_id=p_org and uniion_private.support_assigned(t.id,auth.uid())) then raise insufficient_privilege;end if;
 return jsonb_build_object('actor',auth.uid(),'organization',(select name from public.uniion_organizations where id=p_org),'manage',manage,'member',member,
 'resources',case when manage then coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.title)) from public.uniion_resources r where r.organization_id=p_org and r.external_share_allowed and uniion_private.actor_resource(p_org,r.id,auth.uid(),false)),'[]') else '[]'::jsonb end,
 'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'state',t.state,'staff',uniion_private.support_assigned(t.id,auth.uid()),'agents',coalesce((select jsonb_agg(jsonb_build_object('id',a.user_id,'name',a.name)) from uniion_private.support_assignments x join uniion_private.support_agents a on a.user_id=x.user_id where x.ticket=t.id and a.active and (manage or a.user_id=auth.uid())),'[]'),
 'grants',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'agents',g.agents,'expires',g.expires,'download',g.download,'revoked',g.revoked_at is not null,'items',case when manage or (t.state='open' and g.revoked_at is null and g.expires>now() and uniion_private.authority(p_org,g.creator,'share')) then coalesce((select jsonb_agg(jsonb_build_object('id',i.resource,'name',i.title,'version',i.version)) from uniion_private.support_items i where i.grant_id=g.id and (manage or uniion_private.actor_resource(p_org,i.resource,g.creator,false))),'[]') else '[]'::jsonb end)) from uniion_private.support_grants g where g.ticket=t.id and (manage or auth.uid()=any(g.agents))),'[]')) order by t.created_at desc,t.id) from uniion_private.support_tickets t where t.organization_id=p_org and (manage or t.created_by=auth.uid() or uniion_private.support_assigned(t.id,auth.uid()))),'[]'));
end $$;
revoke all on function public.uniion_support_approve(uuid,uuid,uuid[],uuid[],timestamptz,boolean),public.uniion_support_revoke(uuid,uuid,uuid),public.uniion_support_read(uuid,uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.uniion_support_approve(uuid,uuid,uuid[],uuid[],timestamptz,boolean),public.uniion_support_revoke(uuid,uuid,uuid),public.uniion_support_read(uuid,uuid,uuid,uuid,boolean) to authenticated;
commit;

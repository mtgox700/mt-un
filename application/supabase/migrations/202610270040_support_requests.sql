begin;
alter table uniion_private.support_assignments add column active boolean not null default true;
alter table uniion_private.support_grants add column excluded uuid[] not null default '{}';
create table uniion_private.support_requests(id uuid primary key default gen_random_uuid(),ticket uuid not null references uniion_private.support_tickets,agent uuid not null references uniion_private.support_agents,reason text not null check(length(reason) between 1 and 240),status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),created_at timestamptz not null default now());
create unique index support_one_pending on uniion_private.support_requests(ticket,agent) where status='pending';
alter table uniion_private.support_requests enable row level security;
revoke all on uniion_private.support_requests from public,anon,authenticated;
create or replace function uniion_private.support_assigned(t uuid,u uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from uniion_private.support_assignments x join uniion_private.support_agents a on a.user_id=x.user_id where x.ticket=t and x.active and a.user_id=u and a.active)
$$;
create function public.uniion_support_assign(p_org uuid,p_ticket uuid,p_agents uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid;removed uuid[];
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') or p_agents is null or cardinality(p_agents)>20 then raise insufficient_privilege;end if;
 perform 1 from uniion_private.support_tickets where id=p_ticket and organization_id=p_org and state='open' for update;if not found then raise insufficient_privilege;end if;
 foreach u in array p_agents loop if u is null or not exists(select 1 from uniion_private.support_agents where user_id=u and active) then raise insufficient_privilege;end if;end loop;
 select coalesce(array_agg(user_id),'{}') into removed from uniion_private.support_assignments where ticket=p_ticket and active and not(user_id=any(p_agents));
 update uniion_private.support_assignments set active=false where ticket=p_ticket and user_id=any(removed);
 -- Preserve history and permanently exclude removed agents from existing grants.
 update uniion_private.support_grants set excluded=array(select distinct v from unnest(excluded||removed) v) where ticket=p_ticket and agents&&removed;
 update uniion_private.support_requests set status='cancelled' where ticket=p_ticket and agent=any(removed) and status='pending';
 foreach u in array p_agents loop insert into uniion_private.support_assignments(ticket,user_id,active) values(p_ticket,u,true) on conflict(ticket,user_id) do update set active=true;end loop;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.assigned',jsonb_build_object('ticket',p_ticket,'agents',p_agents,'removed',removed));
 return jsonb_build_object('assigned',p_agents,'business_access',false);
end $$;
create function public.uniion_support_request(p_org uuid,p_ticket uuid,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare q uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or p_reason is null or length(btrim(p_reason)) not between 1 and 240 or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 perform 1 from uniion_private.support_tickets where id=p_ticket and organization_id=p_org and state='open' for update;
 if not found or not uniion_private.support_assigned(p_ticket,auth.uid()) or exists(select 1 from uniion_private.support_requests where ticket=p_ticket and agent=auth.uid() and status='pending') then raise insufficient_privilege;end if;
 insert into uniion_private.support_requests(ticket,agent,reason) values(p_ticket,auth.uid(),btrim(p_reason)) returning id into q;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.requested',jsonb_build_object('ticket',p_ticket,'request',q));return jsonb_build_object('id',q,'status','pending');
end $$;
create function public.uniion_support_reject(p_org uuid,p_ticket uuid,p_request uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege;end if;
 perform 1 from uniion_private.support_tickets where id=p_ticket and organization_id=p_org and state='open' for update;if not found then raise insufficient_privilege;end if;
 update uniion_private.support_requests set status='rejected' where id=p_request and ticket=p_ticket and status='pending';if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.rejected',jsonb_build_object('ticket',p_ticket,'request',p_request));return jsonb_build_object('status','rejected');
end $$;
create function uniion_private.support_requests_granted() returns trigger language plpgsql security definer set search_path='' as $$
begin update uniion_private.support_requests set status='approved' where ticket=new.ticket and agent=any(new.agents) and status='pending';return new;end $$;
create trigger support_requests_granted after insert on uniion_private.support_grants for each row execute function uniion_private.support_requests_granted();
create function uniion_private.support_requests_closed() returns trigger language plpgsql security definer set search_path='' as $$
begin if new.state='closed' then update uniion_private.support_requests set status='cancelled' where ticket=new.id and status='pending';end if;return new;end $$;
create trigger support_requests_closed after update of state on uniion_private.support_tickets for each row execute function uniion_private.support_requests_closed();
revoke all on function uniion_private.support_requests_granted(),uniion_private.support_requests_closed() from public,anon,authenticated;
revoke all on function public.uniion_support_assign(uuid,uuid,uuid[]),public.uniion_support_request(uuid,uuid,text),public.uniion_support_reject(uuid,uuid,uuid) from public,anon;
grant execute on function public.uniion_support_assign(uuid,uuid,uuid[]),public.uniion_support_request(uuid,uuid,text),public.uniion_support_reject(uuid,uuid,uuid) to authenticated;
create or replace function public.uniion_support_read(p_org uuid,p_ticket uuid,p_grant uuid,p_resource uuid,p_download boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uniion_private.support_tickets;g uniion_private.support_grants;i uniion_private.support_items;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or p_download is null or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for share;
 if not found or t.state<>'open' or not uniion_private.support_assigned(t.id,auth.uid()) then raise insufficient_privilege;end if;
 select * into g from uniion_private.support_grants where id=p_grant and ticket=t.id for share;
 if not found or g.revoked_at is not null or auth.uid()=any(g.excluded) or g.expires<=now() or not(auth.uid()=any(g.agents)) or (p_download and not g.download) or not uniion_private.authority(p_org,g.creator,'share') or (p_download and not uniion_private.authority(p_org,g.creator,'download')) then raise insufficient_privilege;end if;
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
 return jsonb_build_object('availableAgents',case when manage then coalesce((select jsonb_agg(jsonb_build_object('id',user_id,'name',name) order by name) from uniion_private.support_agents where active),'[]') else '[]'::jsonb end,'actor',auth.uid(),'organization',(select name from public.uniion_organizations where id=p_org),'manage',manage,'member',member,
 'resources',case when manage then coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.title)) from public.uniion_resources r where r.organization_id=p_org and r.external_share_allowed and uniion_private.actor_resource(p_org,r.id,auth.uid(),false)),'[]') else '[]'::jsonb end,
 'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'state',t.state,'staff',uniion_private.support_assigned(t.id,auth.uid()),'agents',coalesce((select jsonb_agg(jsonb_build_object('id',a.user_id,'name',a.name)) from uniion_private.support_assignments x join uniion_private.support_agents a on a.user_id=x.user_id where x.ticket=t.id and x.active and a.active and (manage or a.user_id=auth.uid())),'[]'),
 'requests',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'agent',q.agent,'reason',q.reason,'status',q.status) order by q.created_at) from uniion_private.support_requests q where q.ticket=t.id and (manage or q.agent=auth.uid())),'[]'),'grants',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'agents',g.agents,'excluded',case when manage then to_jsonb(g.excluded) else '[]'::jsonb end,'expires',g.expires,'download',g.download,'revoked',g.revoked_at is not null or g.agents<@g.excluded or (not manage and auth.uid()=any(g.excluded)),'items',case when manage or (t.state='open' and not(auth.uid()=any(g.excluded)) and g.revoked_at is null and g.expires>now() and uniion_private.authority(p_org,g.creator,'share')) then coalesce((select jsonb_agg(jsonb_build_object('id',i.resource,'name',i.title,'version',i.version)) from uniion_private.support_items i where i.grant_id=g.id and (manage or uniion_private.actor_resource(p_org,i.resource,g.creator,false))),'[]') else '[]'::jsonb end)) from uniion_private.support_grants g where g.ticket=t.id and (manage or auth.uid()=any(g.agents))),'[]')) order by t.created_at desc,t.id) from uniion_private.support_tickets t where t.organization_id=p_org and (manage or t.created_by=auth.uid() or uniion_private.support_assigned(t.id,auth.uid()))),'[]'));
end $$;
commit;

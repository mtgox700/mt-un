begin;
create table uniion_private.support_tickets(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.uniion_organizations,
 title text not null check(length(title) between 1 and 120),created_by uuid not null references auth.users,
 created_at timestamptz not null default now(),state text not null default 'open' check(state in ('open','closed')),
 closed_at timestamptz,closed_by uuid references auth.users
);
alter table uniion_private.support_tickets enable row level security;
revoke all on uniion_private.support_tickets from public,anon,authenticated;
create function public.uniion_support_context(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) then raise insufficient_privilege;end if;
 return jsonb_build_object('manage',uniion_private.authority(p_org,auth.uid(),'share'),'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'state',state,'createdAt',created_at) order by created_at desc,id) from uniion_private.support_tickets where organization_id=p_org and (created_by=auth.uid() or uniion_private.authority(p_org,auth.uid(),'share'))),'[]'));
end $$;
create function public.uniion_support_create(p_org uuid,p_title text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or p_title is null or length(btrim(p_title)) not between 1 and 120 then raise insufficient_privilege;end if;
 insert into uniion_private.support_tickets(organization_id,title,created_by) values(p_org,btrim(p_title),auth.uid()) returning id into tid;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.created',jsonb_build_object('ticket',tid));
 return jsonb_build_object('id',tid,'state','open');
end $$;
create function public.uniion_support_status(p_org uuid,p_ticket uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uniion_private.support_tickets;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege;end if;
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for update;
 if not found then raise insufficient_privilege;end if;
 if p_action='close' and t.state='open' then
 update uniion_private.support_tickets set state='closed',closed_at=now(),closed_by=auth.uid() where id=t.id;
 elsif p_action='reopen' and t.state='closed' then
 update uniion_private.support_tickets set state='open' where id=t.id;
 else raise insufficient_privilege;end if;
 -- No support grants exist in this slice: reopening never grants any data access.
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.'||p_action,jsonb_build_object('ticket',t.id));
 return jsonb_build_object('id',t.id,'state',case when p_action='close' then 'closed' else 'open' end,'business_access',false);
end $$;
revoke all on function public.uniion_support_context(uuid),public.uniion_support_create(uuid,text),public.uniion_support_status(uuid,uuid,text) from public,anon;
grant execute on function public.uniion_support_context(uuid),public.uniion_support_create(uuid,text),public.uniion_support_status(uuid,uuid,text) to authenticated;
commit;

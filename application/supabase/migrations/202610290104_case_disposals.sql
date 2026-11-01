begin;
alter table uniion_private.case_links add column withdrawn boolean not null default false;
create table uniion_private.case_disposals(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,resource_id uuid not null,
 link uuid references uniion_private.case_links,version integer not null,reason text not null check(reason in ('obsolete','duplicate','other')),
 state text not null default 'pending' check(state in ('pending','approved','rejected','restored')),
 requester uuid not null references auth.users,created_at timestamptz not null default now(),decider uuid references auth.users,decided_at timestamptz,
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id)
);
create unique index case_disposals_active on uniion_private.case_disposals(resource_id,coalesce(link,'00000000-0000-0000-0000-000000000000')) where state in ('pending','approved');
alter table uniion_private.case_disposals enable row level security;
revoke all on uniion_private.case_disposals from public,anon,authenticated;
create function uniion_private.case_disposed(r uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from uniion_private.case_disposals where resource_id=r and link is null and state='approved')$$;
revoke all on function uniion_private.case_disposed(uuid) from public,anon,authenticated;
alter function uniion_private.actor_resource(uuid,uuid,uuid,boolean) rename to actor_resource_before_disposal;
create function uniion_private.actor_resource(org uuid,res uuid,who uuid,wr boolean default false) returns boolean language sql stable security definer set search_path='' as $$ select not uniion_private.case_disposed(res) and uniion_private.actor_resource_before_disposal(org,res,who,wr) $$;
revoke all on function uniion_private.actor_resource(uuid,uuid,uuid,boolean),uniion_private.actor_resource_before_disposal(uuid,uuid,uuid,boolean) from public,anon,authenticated;
create or replace function uniion_private.case_file_trashed(a uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_attachments where id=a and uniion_private.case_disposed(resource_id)) or exists(select 1 from uniion_private.case_file_trash t where t.state='approved' and (t.root=a or exists(select 1 from uniion_private.case_file_versions v where v.root=t.root and v.attachment=a)))
$$;
create function public.uniion_case_disposal(p_org uuid,p_action text,p_case uuid default null,p_link uuid default null,p_request uuid default null,p_expected integer default null,p_reason text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uniion_private.case_disposals; v integer; ident uuid;
begin
 if p_action in ('admin_list','approve','reject') then
  if not uniion_private.super_admin() then raise insufficient_privilege;end if;
  if p_action='admin_list' then return jsonb_build_object('requests',coalesce((select jsonb_agg(jsonb_build_object('id',id,'organization',organization_id,'root',resource_id,'kind',case when link is null then 'Dossier' else 'Référence' end,'revision',version,'reason',reason,'state',state)) from uniion_private.case_disposals where state='pending'),'[]'));end if;
  select * into t from uniion_private.case_disposals where id=p_request;
  if not found then raise insufficient_privilege;end if;
  select version into v from public.uniion_resources where id=t.resource_id and organization_id=t.organization_id for update;
  select * into t from uniion_private.case_disposals where id=p_request for update;
  if t.state<>'pending' then raise insufficient_privilege;end if;
  if p_action='approve' then
   if not uniion_private.actor_resource(t.organization_id,t.resource_id,t.requester,true) then raise insufficient_privilege;end if;
   if v<>t.version then raise serialization_failure;end if;
   update uniion_private.case_links set withdrawn=true where id=t.link;
   update public.uniion_resources set version=version+1 where id=t.resource_id;
  end if;
  update uniion_private.case_disposals set state=case when p_action='approve' then 'approved' else 'rejected' end,decider=auth.uid(),decided_at=now() where id=t.id;ident=t.id;
 else
  perform public.uniion_module_use(p_org,'dossiers');
  if p_action='list' then return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('request',t.id,'filename',case when t.link is null then 'Dossier · ' else 'Référence · ' end||r.title,'state',t.state,'deleted',t.decided_at,'case',t.resource_id)) from uniion_private.case_disposals t join public.uniion_resources r on r.id=t.resource_id where t.organization_id=p_org and (p_case is null or t.resource_id=p_case) and t.state in ('pending','approved') and uniion_private.actor_resource_before_disposal(p_org,t.resource_id,auth.uid(),false)),'[]'));end if;
  select version into v from public.uniion_resources where id=p_case and organization_id=p_org and module='dossiers' for update;
  if not found or not uniion_private.actor_resource_before_disposal(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
  if p_action='request' then
   if uniion_private.case_disposed(p_case) or p_reason is null or p_reason not in ('obsolete','duplicate','other') then raise insufficient_privilege;end if;
   if p_link is not null and not exists(select 1 from uniion_private.case_links where id=p_link and resource_id=p_case and organization_id=p_org and not withdrawn) then raise insufficient_privilege;end if;
   if p_expected is distinct from v then raise serialization_failure;end if;
   insert into uniion_private.case_disposals(organization_id,resource_id,link,version,reason,requester) values(p_org,p_case,p_link,v,p_reason,auth.uid()) returning * into t;ident=t.id;
  elsif p_action='restore' then
   select * into t from uniion_private.case_disposals where id=p_request and organization_id=p_org and resource_id=p_case for update;
   if not found or t.state<>'approved' or (t.link is not null and uniion_private.case_disposed(p_case)) then raise insufficient_privilege;end if;
   update uniion_private.case_disposals set state='restored',decider=auth.uid(),decided_at=now() where id=t.id;
   update uniion_private.case_links set withdrawn=false where id=t.link;
   update public.uniion_resources set version=version+1 where id=p_case;ident=t.id;
  else raise insufficient_privilege;end if;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(t.organization_id,auth.uid(),'case.disposal_'||p_action,jsonb_build_object('request',ident,'case',t.resource_id,'link',t.link));
 return jsonb_build_object('ok',true,'id',ident);
end$$;
revoke all on function public.uniion_case_disposal(uuid,text,uuid,uuid,uuid,integer,text) from public,anon;
grant execute on function public.uniion_case_disposal(uuid,text,uuid,uuid,uuid,integer,text) to authenticated;

create or replace function uniion_private.case_classified_files(o uuid,c uuid) returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'filename',s->>'name','created',l.created_at,'size',0,'status','reference','classified',true,'version',1,'maxVersion',1,'versions','[]'::jsonb)),'[]') from uniion_private.case_links l cross join lateral (select uniion_private.case_source(o,l.convocation,l.file) s) checked where l.organization_id=o and l.resource_id=c and l.file<>'' and not l.withdrawn and s is not null
$$;

create or replace function uniion_private.case_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$
 select base||uniion_private.case_assignment_context(o,rid)||jsonb_build_object('fileCount',jsonb_array_length(uniion_private.case_file_rows(o,rid))+jsonb_array_length(uniion_private.case_classified_files(o,rid)),'timeline',(base->'timeline')||coalesce((select jsonb_agg(jsonb_build_object('date',to_char(l.created_at at time zone 'Europe/Paris','DD/MM/YYYY HH24:MI'),'title','Message classé · '||(s->>'name'),'body',s->>'body') order by l.created_at) from uniion_private.case_links l cross join lateral (select uniion_private.case_source(o,l.convocation,l.file) s) checked where l.organization_id=o and l.resource_id=rid and l.file='' and not l.withdrawn and s is not null),'[]')) from (select uniion_private.case_json_base(o,rid) base) t
$$;

create or replace function public.uniion_case_link(p_org uuid,p_case uuid,p_link uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare l uniion_private.case_links;s jsonb;
begin
 perform public.uniion_case_files(p_org,p_case);
 select * into l from uniion_private.case_links where id=p_link and organization_id=p_org and resource_id=p_case;
 if not found or l.file='' or l.withdrawn then raise insufficient_privilege;end if;
 s=uniion_private.case_source(p_org,l.convocation,l.file);
 if s is null then raise insufficient_privilege;end if;
 return jsonb_build_object('convocation',l.convocation,'file',l.file);
end$$;
alter function uniion_private.resource_access(uuid,uuid,boolean) rename to resource_access_before_disposal;
create function uniion_private.resource_access(org uuid,resource uuid,write_access boolean) returns boolean language sql stable security definer set search_path='' as $$select not uniion_private.case_disposed(resource) and uniion_private.resource_access_before_disposal(org,resource,write_access)$$;
revoke all on function uniion_private.resource_access_before_disposal(uuid,uuid,boolean),uniion_private.resource_access(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function uniion_private.resource_access(uuid,uuid,boolean) to authenticated;
notify pgrst,'reload schema';
commit;

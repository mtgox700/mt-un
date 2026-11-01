begin;
create or replace function public.uniion_case_disposal(p_org uuid,p_action text,p_case uuid default null,p_link uuid default null,p_request uuid default null,p_expected integer default null,p_reason text default null) returns jsonb language plpgsql security definer set search_path='' as $$
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
  if p_action='list' then return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('request',entry.id,'filename',case when entry.link is null then 'Dossier · ' else 'Référence · ' end||r.title,'state',entry.state,'deleted',entry.decided_at,'case',entry.resource_id)) from uniion_private.case_disposals entry join public.uniion_resources r on r.id=entry.resource_id where entry.organization_id=p_org and (p_case is null or entry.resource_id=p_case) and entry.state in ('pending','approved') and uniion_private.actor_resource_before_disposal(p_org,entry.resource_id,auth.uid(),false)),'[]'));end if;
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
notify pgrst,'reload schema';
commit;

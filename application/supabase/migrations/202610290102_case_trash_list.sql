begin;
create or replace function public.uniion_case_trash(p_org uuid,p_case uuid,p_action text,p_root uuid default null,p_request uuid default null,p_expected integer default null,p_reason text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uniion_private.case_file_trash; current_revision integer; ident uuid; rows jsonb;
begin
 if p_action in ('admin_list','approve','reject') then
  if not uniion_private.super_admin() then raise insufficient_privilege;end if;
  if p_action='admin_list' then return jsonb_build_object('requests',coalesce((select jsonb_agg(jsonb_build_object('id',id,'organization',organization_id,'root',root,'revision',revision,'reason',reason,'requested',requested_at,'state',state) order by requested_at) from uniion_private.case_file_trash where state='pending'),'[]'));end if;
  select * into t from uniion_private.case_file_trash where id=p_request;
  if not found then raise insufficient_privilege;end if;
  perform 1 from public.uniion_resources where organization_id=t.organization_id and id=t.resource_id for update;
  select * into t from uniion_private.case_file_trash where id=p_request for update;
  if t.state<>'pending' then raise insufficient_privilege;end if;
  select coalesce(max(revision),1) into current_revision from uniion_private.case_file_versions where root=t.root;
  if p_action='approve' and not uniion_private.actor_resource(t.organization_id,t.resource_id,t.requester,true) then raise insufficient_privilege;end if;
  if p_action='approve' and current_revision<>t.revision then raise serialization_failure using message='Versions modifiées depuis la demande';end if;
  update uniion_private.case_file_trash set state=case when p_action='approve' then 'approved' else 'rejected' end,approver=auth.uid(),decided_at=now() where id=t.id;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(t.organization_id,auth.uid(),'case.trash_'||p_action,jsonb_build_object('request',t.id,'root',t.root,'revision',t.revision));
  return jsonb_build_object('ok',true);
 end if;
 perform public.uniion_case_files(p_org,p_case);
 if p_action='list' then
  select coalesce(jsonb_agg(f||jsonb_build_object('request',q.id,'deleted',q.decided_at,'state',q.state)),'[]') into rows from jsonb_array_elements(uniion_private.case_file_rows_all(p_org,p_case)) f join uniion_private.case_file_trash q on q.root=(f->>'id')::uuid where q.organization_id=p_org and q.resource_id=p_case and q.state in ('pending','approved');
  return jsonb_build_object('rows',rows);
 end if;
 perform 1 from public.uniion_resources where organization_id=p_org and id=p_case for update;
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 if p_action='request' then
  if p_reason is null or p_reason not in ('obsolete','duplicate','other') or not exists(select 1 from public.uniion_attachments where id=p_root and organization_id=p_org and resource_id=p_case) or exists(select 1 from uniion_private.case_file_versions where attachment=p_root and root<>p_root) then raise insufficient_privilege;end if;
  select coalesce(max(revision),1) into current_revision from uniion_private.case_file_versions where root=p_root;
  if p_expected is distinct from current_revision then raise serialization_failure;end if;
  insert into uniion_private.case_file_trash(organization_id,resource_id,root,revision,reason,requester) values(p_org,p_case,p_root,current_revision,p_reason,auth.uid()) returning id into ident;
 elsif p_action='restore' then
  select * into t from uniion_private.case_file_trash where id=p_request and organization_id=p_org and resource_id=p_case for update;
  if not found or t.state<>'approved' then raise insufficient_privilege;end if;
  update uniion_private.case_file_trash set state='restored',restored_by=auth.uid(),restored_at=now() where id=t.id;ident=t.id;
 else raise insufficient_privilege;
 end if;
 insert into uniion_private.case_history(organization_id,resource_id,actor,title,body) values(p_org,p_case,auth.uid(),case when p_action='request' then 'Mise en corbeille demandée' else 'Pièce restaurée depuis la corbeille' end,'Demande '||ident);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.trash_'||p_action,jsonb_build_object('request',ident));
 return jsonb_build_object('id',ident,'ok',true);
end$$;
notify pgrst,'reload schema';
commit;

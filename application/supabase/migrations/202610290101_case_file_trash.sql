begin;
create table uniion_private.case_file_trash(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, resource_id uuid not null,
 root uuid not null references public.uniion_attachments, revision integer not null,
 reason text not null check(reason in ('obsolete','duplicate','other')),
 state text not null default 'pending' check(state in ('pending','approved','rejected','restored')),
 requester uuid not null references auth.users, requested_at timestamptz not null default now(),
 approver uuid references auth.users, decided_at timestamptz, restored_by uuid references auth.users,restored_at timestamptz,
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id)
);
create unique index case_file_trash_active on uniion_private.case_file_trash(root) where state in ('pending','approved');
alter table uniion_private.case_file_trash enable row level security;
revoke all on uniion_private.case_file_trash from public,anon,authenticated;
create function uniion_private.case_file_trashed(a uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from uniion_private.case_file_trash t where t.state='approved' and (t.root=a or exists(select 1 from uniion_private.case_file_versions v where v.root=t.root and v.attachment=a)))
$$;
revoke all on function uniion_private.case_file_trashed(uuid) from public,anon,authenticated;
alter function uniion_private.case_file_rows(uuid,uuid) rename to case_file_rows_all;
create function uniion_private.case_file_rows(o uuid,c uuid) returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(f),'[]') from jsonb_array_elements(uniion_private.case_file_rows_all(o,c)) f where not uniion_private.case_file_trashed((f->>'id')::uuid)
$$;
revoke all on function uniion_private.case_file_rows(uuid,uuid) from public,anon,authenticated;
-- Gate every normal attachment gateway, including shares and designated support.
alter function public.uniion_support_file_get(uuid,uuid,uuid,uuid,boolean,boolean) rename to uniion_support_file_get_before_trash;
revoke all on function public.uniion_support_file_get_before_trash(uuid,uuid,uuid,uuid,boolean,boolean) from public,anon,authenticated;
create function public.uniion_support_file_get(p_org uuid,p_ticket uuid,p_grant uuid,p_attachment uuid,p_preview boolean,p_audit boolean) returns jsonb language plpgsql security definer set search_path='' as $$begin
 if uniion_private.case_file_trashed(p_attachment) then raise insufficient_privilege;end if;
 return public.uniion_support_file_get_before_trash(p_org,p_ticket,p_grant,p_attachment,p_preview,p_audit);
end$$;
revoke all on function public.uniion_support_file_get(uuid,uuid,uuid,uuid,boolean,boolean) from public,anon;
grant execute on function public.uniion_support_file_get(uuid,uuid,uuid,uuid,boolean,boolean) to authenticated;

alter function public.uniion_attachment_get(uuid,uuid,uuid,boolean,boolean) rename to uniion_attachment_get_before_trash;
revoke all on function public.uniion_attachment_get_before_trash(uuid,uuid,uuid,boolean,boolean) from public,anon,authenticated;
create function public.uniion_attachment_get(p_org uuid,p_attachment uuid,p_share uuid default null,p_audit boolean default true,p_preview boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$begin
 if uniion_private.case_file_trashed(p_attachment) then raise insufficient_privilege;end if;
 return public.uniion_attachment_get_before_trash(p_org,p_attachment,p_share,p_audit,p_preview);
end$$;
revoke all on function public.uniion_attachment_get(uuid,uuid,uuid,boolean,boolean) from public,anon;
grant execute on function public.uniion_attachment_get(uuid,uuid,uuid,boolean,boolean) to authenticated;
alter function public.uniion_case_file_version(uuid,uuid,uuid,integer,integer,text,text,integer,text) rename to uniion_case_file_version_before_trash;
revoke all on function public.uniion_case_file_version_before_trash(uuid,uuid,uuid,integer,integer,text,text,integer,text) from public,anon,authenticated;
create function public.uniion_case_file_version(p_org uuid,p_case uuid,p_root uuid,p_expected integer,p_restore integer default null,p_filename text default null,p_mime text default null,p_size integer default null,p_sha256 text default null) returns jsonb language plpgsql security definer set search_path='' as $$begin
 perform 1 from public.uniion_resources where organization_id=p_org and id=p_case for update;
 if uniion_private.case_file_trashed(p_root) then raise insufficient_privilege;end if;
 return public.uniion_case_file_version_before_trash(p_org,p_case,p_root,p_expected,p_restore,p_filename,p_mime,p_size,p_sha256);
end$$;
revoke all on function public.uniion_case_file_version(uuid,uuid,uuid,integer,integer,text,text,integer,text) from public,anon;
grant execute on function public.uniion_case_file_version(uuid,uuid,uuid,integer,integer,text,text,integer,text) to authenticated;
create function public.uniion_case_trash(p_org uuid,p_case uuid,p_action text,p_root uuid default null,p_request uuid default null,p_expected integer default null,p_reason text default null) returns jsonb language plpgsql security definer set search_path='' as $$
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
  select coalesce(jsonb_agg(f||jsonb_build_object('request',t.id,'deleted',t.decided_at,'state',t.state)),'[]') into rows from jsonb_array_elements(uniion_private.case_file_rows_all(p_org,p_case)) f join uniion_private.case_file_trash t on t.root=(f->>'id')::uuid where t.organization_id=p_org and t.resource_id=p_case and t.state in ('pending','approved');
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
revoke all on function public.uniion_case_trash(uuid,uuid,text,uuid,uuid,integer,text) from public,anon;
grant execute on function public.uniion_case_trash(uuid,uuid,text,uuid,uuid,integer,text) to authenticated;
notify pgrst,'reload schema';
commit;

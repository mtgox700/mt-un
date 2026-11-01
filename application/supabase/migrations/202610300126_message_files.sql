begin;
create table uniion_private.message_files(
 organization_id uuid not null, conversation uuid not null, seq bigint not null, resource uuid not null unique, attachment uuid unique,
 primary key(organization_id,conversation,seq),
 foreign key(organization_id,conversation,seq) references uniion_private.messages(organization_id,conversation,seq),
 foreign key(organization_id,resource) references public.uniion_resources(organization_id,id),
 foreign key(attachment) references public.uniion_attachments(id)
);
alter table uniion_private.message_files enable row level security;
revoke all on uniion_private.message_files from public,anon,authenticated;
-- Reuse the private vault, with message ACL replacing generic resource grants.
alter function uniion_private.actor_resource(uuid,uuid,uuid,boolean) rename to actor_resource_before_messages;
create function uniion_private.actor_resource(org uuid,res uuid,who uuid,wr boolean default false) returns boolean language plpgsql stable security definer set search_path='' as $$
declare f uniion_private.message_files;
begin
 select * into f from uniion_private.message_files where resource=res;
 if not found then return uniion_private.actor_resource_before_messages(org,res,who,wr);end if;
 if f.organization_id<>org or not uniion_private.message_current(org,f.conversation,who) then return false;end if;
 -- module_use authenticates the actual caller. Authority checks for a requester at approval use the same module state.
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.commercial_allowed(org,'messagerie') or not exists(select 1 from public.uniion_module_access where organization_id=org and module='messagerie' and authorized and enabled and valid_until>now()) or not exists(select 1 from public.uniion_permissions where organization_id=org and user_id=who and module='messagerie' and permission='read') then return false;end if;
 return exists(select 1 from public.uniion_permissions where organization_id=org and user_id=who and module='messagerie' and permission=case when wr then 'write' else 'read' end)
 and exists(select 1 from uniion_private.message_participations p where p.organization_id=org and p.conversation=f.conversation and p.user_id=who and p.left_at is null and (f.seq>=p.visible_from or exists(select 1 from uniion_private.message_history_grants g where g.organization_id=org and g.conversation=f.conversation and g.participation=p.id and g.message_seq=f.seq and g.revoked_at is null)))
 and (not wr or exists(select 1 from uniion_private.messages m where m.organization_id=org and m.conversation=f.conversation and m.seq=f.seq and m.author=who));
exception when insufficient_privilege then return false;
end$$;
revoke all on function uniion_private.actor_resource(uuid,uuid,uuid,boolean),uniion_private.actor_resource_before_messages(uuid,uuid,uuid,boolean) from public,anon,authenticated;
-- No generic share can turn a message attachment into an audience-expanding copy.
alter function uniion_private.share_access(uuid,uuid,uuid,boolean) rename to share_access_before_messages;
create function uniion_private.share_access(sid uuid,res uuid,who uuid,dl boolean default false) returns boolean language sql stable security definer set search_path='' as $$
 select not exists(select 1 from uniion_private.message_files where resource=res) and uniion_private.share_access_before_messages(sid,res,who,dl)
$$;
revoke all on function uniion_private.share_access(uuid,uuid,uuid,boolean),uniion_private.share_access_before_messages(uuid,uuid,uuid,boolean) from public,anon,authenticated;
-- A message has one immutable uploaded object. Preparation is replay-safe before uploading bytes.
create function public.uniion_message_file_prepare(p_org uuid,p_conversation uuid,p_client uuid,p_filename text,p_mime text,p_size integer,p_sha256 text) returns jsonb language plpgsql security definer set search_path='' as $$
declare m jsonb; f uniion_private.message_files;a public.uniion_attachments;r uuid;item jsonb;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 perform 1 from uniion_private.message_conversations where organization_id=p_org and id=p_conversation for update;
 if not uniion_private.message_member(p_org,p_conversation) then raise insufficient_privilege;end if;
 if exists(select 1 from uniion_private.messages m where m.organization_id=p_org and m.conversation=p_conversation and m.author=auth.uid() and m.client_id=p_client and not exists(select 1 from uniion_private.message_files f where f.organization_id=m.organization_id and f.conversation=m.conversation and f.seq=m.seq)) then raise insufficient_privilege;end if;
 m=public.uniion_messaging(p_org,'send',jsonb_build_object('id',p_conversation,'clientId',p_client,'text','Pièce jointe'));
 select * into f from uniion_private.message_files where organization_id=p_org and conversation=p_conversation and seq=(m->>'seq')::bigint;
 if found then
  select * into a from public.uniion_attachments where id=f.attachment;
  if a.filename is distinct from p_filename or a.mime is distinct from p_mime or a.size is distinct from p_size or a.sha256 is distinct from p_sha256 then raise insufficient_privilege;end if;
 else
  insert into public.uniion_resources(organization_id,module,kind,title) values(p_org,'messagerie','message_file','Pièce de message') returning id into r;
  insert into uniion_private.message_files values(p_org,p_conversation,(m->>'seq')::bigint,r,null);
  item=public.uniion_attachment_prepare(p_org,r,p_filename,p_mime,p_size,p_sha256);
  update uniion_private.message_files set attachment=(item->>'id')::uuid where resource=r;
  select * into a from public.uniion_attachments where id=(item->>'id')::uuid;
 end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'status',a.scan_status,'uploaded',exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name));
end$$;
create function public.uniion_message_file_context(p_org uuid,p_conversation uuid,p_attachment uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare f uniion_private.message_files;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 select * into f from uniion_private.message_files where organization_id=p_org and conversation=p_conversation and attachment=p_attachment;
 if not found or not uniion_private.actor_resource(p_org,f.resource,auth.uid(),false) or uniion_private.case_file_trashed(p_attachment) then raise insufficient_privilege;end if;
 return jsonb_build_object('resource',f.resource,'write',uniion_private.actor_resource(p_org,f.resource,auth.uid(),true));
end$$;
revoke all on function public.uniion_message_file_prepare(uuid,uuid,uuid,text,text,integer,text),public.uniion_message_file_context(uuid,uuid,uuid) from public,anon;
grant execute on function public.uniion_message_file_prepare(uuid,uuid,uuid,text,text,integer,text),public.uniion_message_file_context(uuid,uuid,uuid) to authenticated;
alter function uniion_private.message_json(uniion_private.messages) rename to message_json_before_files;
create function uniion_private.message_json(m uniion_private.messages) returns jsonb language sql stable security definer set search_path='' as $$
 select uniion_private.message_json_before_files(m)||jsonb_build_object('file',(select jsonb_build_object('id',a.id,'resource',f.resource,'name',a.filename,'status',case when uniion_private.case_file_trashed(a.id) then 'trash' else a.scan_status end,'size',a.size,'canWrite',m.author=auth.uid(),'download',uniion_private.authority(m.organization_id,auth.uid(),'download')) from uniion_private.message_files f join public.uniion_attachments a on a.id=f.attachment where f.organization_id=m.organization_id and f.conversation=m.conversation and f.seq=m.seq and uniion_private.message_visible(m.organization_id,m.conversation,m.seq)))
$$;
revoke all on function uniion_private.message_json(uniion_private.messages),uniion_private.message_json_before_files(uniion_private.messages) from public,anon,authenticated;
-- Existing D07 file requests and global approvals, also for a message-owned resource.
alter function public.uniion_case_trash(uuid,uuid,text,uuid,uuid,integer,text) rename to uniion_case_trash_before_messages;
revoke all on function public.uniion_case_trash_before_messages(uuid,uuid,text,uuid,uuid,integer,text) from public,anon,authenticated;
create function public.uniion_case_trash(p_org uuid,p_case uuid,p_action text,p_root uuid default null,p_request uuid default null,p_expected integer default null,p_reason text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare f uniion_private.message_files;t uniion_private.case_file_trash;ident uuid;
begin
 select * into f from uniion_private.message_files where resource=p_case and organization_id=p_org;
 if not found or p_action in ('admin_list','approve','reject') then return public.uniion_case_trash_before_messages(p_org,p_case,p_action,p_root,p_request,p_expected,p_reason);end if;
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),false) then raise insufficient_privilege;end if;
 if p_action='list' then return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'request',t.id,'state',t.state,'deleted',t.decided_at)) from uniion_private.case_file_trash t join public.uniion_attachments a on a.id=t.root where t.resource_id=p_case and t.state in ('pending','approved')),'[]'));end if;
 perform 1 from public.uniion_resources where id=p_case for update;
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 if p_action='request' then
  if p_root is distinct from f.attachment or p_expected is distinct from 1 or p_reason is null or p_reason not in ('obsolete','duplicate','other') then raise insufficient_privilege;end if;
  insert into uniion_private.case_file_trash(organization_id,resource_id,root,revision,reason,requester) values(p_org,p_case,p_root,1,p_reason,auth.uid()) returning id into ident;
 elsif p_action='restore' then
  select * into t from uniion_private.case_file_trash where id=p_request and resource_id=p_case and organization_id=p_org for update;
  if not found or t.state<>'approved' then raise insufficient_privilege;end if;
  update uniion_private.case_file_trash set state='restored',restored_by=auth.uid(),restored_at=now() where id=t.id;ident=t.id;
 else raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.file_trash_'||p_action,jsonb_build_object('request',ident));
 return jsonb_build_object('id',ident,'ok',true);
end$$;
revoke all on function public.uniion_case_trash(uuid,uuid,text,uuid,uuid,integer,text) from public,anon;
grant execute on function public.uniion_case_trash(uuid,uuid,text,uuid,uuid,integer,text) to authenticated;
-- Prevent adding a second object outside the message preparation command.
alter function public.uniion_attachment_prepare(uuid,uuid,text,text,integer,text) rename to uniion_attachment_prepare_before_messages;
revoke all on function public.uniion_attachment_prepare_before_messages(uuid,uuid,text,text,integer,text) from public,anon,authenticated;
create function public.uniion_attachment_prepare(p_org uuid,p_resource uuid,p_filename text,p_mime text,p_size integer,p_sha256 text) returns jsonb language plpgsql security definer set search_path='' as $$begin
 perform 1 from public.uniion_resources where id=p_resource and organization_id=p_org for update;
 if exists(select 1 from uniion_private.message_files where resource=p_resource and attachment is not null) then raise insufficient_privilege;end if;
 return public.uniion_attachment_prepare_before_messages(p_org,p_resource,p_filename,p_mime,p_size,p_sha256);
end$$;
revoke all on function public.uniion_attachment_prepare(uuid,uuid,text,text,integer,text) from public,anon;
grant execute on function public.uniion_attachment_prepare(uuid,uuid,text,text,integer,text) to authenticated;
notify pgrst,'reload schema';commit;

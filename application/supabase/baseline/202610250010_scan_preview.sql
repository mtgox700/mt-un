begin;
create table uniion_private.scan_workers(user_id uuid primary key references auth.users);
revoke all on uniion_private.scan_workers from public,anon,authenticated;
create function uniion_private.is_scanner() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from uniion_private.scan_workers where user_id=auth.uid())$$;
revoke all on function uniion_private.is_scanner() from public,anon;
grant execute on function uniion_private.is_scanner() to authenticated;
alter table public.uniion_attachments add column scan_status text not null default 'pending' check(scan_status in ('pending','clean','infected','invalid','error'));
alter table public.uniion_attachments add column scanned_at timestamptz;
alter table public.uniion_attachments add column scan_engine text;
alter table public.uniion_attachments add column scan_reason text;
-- Existing files are quarantined until explicitly rescanned. No deletion.
update public.uniion_attachments set ready=false;
alter table public.uniion_attachments add constraint uniion_clean_ready check(not ready or (scan_status='clean' and scanned_at is not null));
revoke all on function public.uniion_attachment_finish(uuid,uuid) from public,anon,authenticated;
create function public.uniion_scan_request(p_org uuid,p_attachment uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment and organization_id=p_org for update;
 if not found or not uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),true) then raise insufficient_privilege;end if;
 update public.uniion_attachments set ready=false,scan_status='pending',scan_reason=null where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'attachment.scan_requested',jsonb_build_object('attachment',a.id));
 return jsonb_build_object('id',a.id);
end $$;
create function public.uniion_scan_job(p_attachment uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 if not uniion_private.is_scanner() then raise insufficient_privilege;end if;
 select * into a from public.uniion_attachments where id=p_attachment;
 if not found then raise insufficient_privilege;end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'filename',a.filename,'mime',a.mime,'size',a.size,'sha256',a.sha256);
end $$;
create function public.uniion_scan_result(p_attachment uuid,p_sha256 text,p_status text,p_engine text,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 if not uniion_private.is_scanner() or p_status not in ('clean','infected','invalid','error') or length(coalesce(p_engine,''))>250 or length(coalesce(p_reason,''))>250 then raise insufficient_privilege;end if;
 select * into a from public.uniion_attachments where id=p_attachment for update;
 if not found or a.sha256<>p_sha256 or a.scan_status<>'pending' then raise insufficient_privilege;end if;
 update public.uniion_attachments set ready=(p_status='clean'),scan_status=p_status,scanned_at=now(),scan_engine=p_engine,scan_reason=p_reason where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(a.organization_id,auth.uid(),'attachment.scan_'||p_status,jsonb_build_object('attachment',a.id,'engine',p_engine));
 return jsonb_build_object('id',a.id,'filename',a.filename,'scan_status',p_status);
end $$;
-- Scanner is an isolated Auth identity with no organization membership or business role.
create policy uniion_scanner_read on storage.objects for select to authenticated using(bucket_id='uniion-private' and storage.allow_only_operation('object.get_authenticated') and uniion_private.is_scanner());
create function uniion_private.attachment_preview(aid uuid,who uuid,sid uuid default null) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_attachments a where a.id=aid and a.ready and a.scan_status='clean' and a.mime in ('application/pdf','image/png','image/jpeg') and case when sid is null then uniion_private.actor_resource(a.organization_id,a.resource_id,who,false) else exists(select 1 from public.uniion_share_attachments sa where sa.share_id=sid and sa.attachment_id=aid and sa.resource_id=a.resource_id and uniion_private.share_access(sid,a.resource_id,who,false)) end)
$$;
revoke all on function uniion_private.attachment_preview(uuid,uuid,uuid) from public,anon,authenticated;
drop function public.uniion_attachment_get(uuid,uuid,uuid,boolean);
create function public.uniion_attachment_get(p_org uuid,p_attachment uuid,p_share uuid default null,p_audit boolean default true,p_preview boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment;
 if not found or not (case when p_preview then uniion_private.attachment_preview(a.id,auth.uid(),p_share) else uniion_private.attachment_access(a.id,auth.uid(),p_share) end) or (p_share is null and a.organization_id<>p_org) or (p_share is not null and not exists(select 1 from public.uniion_shares where id=p_share and target_id=p_org)) then raise insufficient_privilege;end if;
 if p_audit then insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(a.organization_id,case when p_share is null then null else p_org end,auth.uid(),case when p_preview then 'attachment.previewed' else 'attachment.downloaded' end,jsonb_build_object('attachment',a.id,'resource',a.resource_id,'share',p_share));end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'filename',a.filename,'mime',a.mime,'size',a.size,'sha256',a.sha256);
end $$;
-- Append only authorized file metadata, including quarantine status on the source side.
alter function public.uniion_admin_context(uuid) rename to uniion_admin_context_files;
revoke all on function public.uniion_admin_context_files(uuid) from public,anon,authenticated;
create function public.uniion_admin_context(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 result=public.uniion_admin_context_files(p_org);
 return result||jsonb_build_object('attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'resource',a.resource_id,'filename',a.filename,'mime',a.mime,'size',a.size,'scan_status',a.scan_status,'scanned_at',a.scanned_at,'downloadable',uniion_private.attachment_access(a.id,auth.uid()),'previewable',uniion_private.attachment_preview(a.id,auth.uid()),'rescan',uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),true))) from public.uniion_attachments a where a.organization_id=p_org and uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),false)),'[]'::jsonb));
end $$;
alter function public.uniion_shared_read(uuid,uuid,uuid,boolean) rename to uniion_shared_read_files;
revoke all on function public.uniion_shared_read_files(uuid,uuid,uuid,boolean) from public,anon,authenticated;
create function public.uniion_shared_read(p_org uuid,p_share uuid,p_resource uuid,p_download boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 result=public.uniion_shared_read_files(p_org,p_share,p_resource,p_download);
 return result||jsonb_build_object('attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'size',a.size,'mime',a.mime,'scan_status',a.scan_status,'downloadable',uniion_private.attachment_access(a.id,auth.uid(),p_share),'previewable',uniion_private.attachment_preview(a.id,auth.uid(),p_share))) from public.uniion_share_attachments sa join public.uniion_attachments a on a.id=sa.attachment_id where sa.share_id=p_share and sa.resource_id=p_resource),'[]'::jsonb));
end $$;
revoke all on function public.uniion_scan_request(uuid,uuid),public.uniion_scan_job(uuid),public.uniion_scan_result(uuid,text,text,text,text),public.uniion_attachment_get(uuid,uuid,uuid,boolean,boolean),public.uniion_admin_context(uuid),public.uniion_shared_read(uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.uniion_scan_request(uuid,uuid),public.uniion_scan_job(uuid),public.uniion_scan_result(uuid,text,text,text,text),public.uniion_attachment_get(uuid,uuid,uuid,boolean,boolean),public.uniion_admin_context(uuid),public.uniion_shared_read(uuid,uuid,uuid,boolean) to authenticated;
notify pgrst,'reload schema';
commit;

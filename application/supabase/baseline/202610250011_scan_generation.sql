begin;
alter table public.uniion_attachments add column scan_generation uuid not null default gen_random_uuid();
create or replace function public.uniion_scan_request(p_org uuid,p_attachment uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment and organization_id=p_org for update;
 if not found or not uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),true) then raise insufficient_privilege;end if;
 update public.uniion_attachments set ready=false,scan_status='pending',scan_reason=null,scan_generation=gen_random_uuid() where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'attachment.scan_requested',jsonb_build_object('attachment',a.id));
 return jsonb_build_object('id',a.id);
end $$;
create or replace function public.uniion_scan_job(p_attachment uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 if not uniion_private.is_scanner() then raise insufficient_privilege;end if;
 select * into a from public.uniion_attachments where id=p_attachment;
 if not found then raise insufficient_privilege;end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'filename',a.filename,'mime',a.mime,'size',a.size,'sha256',a.sha256,'generation',a.scan_generation);
end $$;
drop function public.uniion_scan_result(uuid,text,text,text,text);
create function public.uniion_scan_result(p_attachment uuid,p_sha256 text,p_status text,p_engine text,p_reason text,p_generation uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 if not uniion_private.is_scanner() or p_status not in ('clean','infected','invalid','error') or length(coalesce(p_engine,''))>250 or length(coalesce(p_reason,''))>250 then raise insufficient_privilege;end if;
 select * into a from public.uniion_attachments where id=p_attachment for update;
 if not found or a.sha256<>p_sha256 or a.scan_status<>'pending' or a.scan_generation is distinct from p_generation then raise insufficient_privilege;end if;
 update public.uniion_attachments set ready=(p_status='clean'),scan_status=p_status,scanned_at=now(),scan_engine=p_engine,scan_reason=p_reason where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(a.organization_id,auth.uid(),'attachment.scan_'||p_status,jsonb_build_object('attachment',a.id,'engine',p_engine,'generation',p_generation));
 return jsonb_build_object('id',a.id,'filename',a.filename,'scan_status',p_status);
end $$;
revoke all on function public.uniion_scan_result(uuid,text,text,text,text,uuid) from public,anon;
grant execute on function public.uniion_scan_result(uuid,text,text,text,text,uuid) to authenticated;
notify pgrst,'reload schema';
commit;

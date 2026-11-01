begin;
create or replace function public.uniion_scan_request(p_org uuid,p_attachment uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment and organization_id=p_org for update;
 if not found or not uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),true) then raise insufficient_privilege;end if;
 if not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name and (metadata->>'size')::bigint=a.size) then raise insufficient_privilege;end if;
 if a.scanned_at is null then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'attachment.uploaded',jsonb_build_object('attachment',a.id,'resource',a.resource_id,'quarantined',true));end if;
 update public.uniion_attachments set ready=false,scan_status='pending',scan_reason=null,scan_generation=gen_random_uuid() where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'attachment.scan_requested',jsonb_build_object('attachment',a.id));
 return jsonb_build_object('id',a.id);
end $$;
notify pgrst,'reload schema';
commit;

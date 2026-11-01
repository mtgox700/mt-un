begin;
create function public.uniion_case_files(p_org uuid,p_case uuid,p_attachment uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform public.uniion_module_use(p_org,'dossiers');
 if not exists(select 1 from uniion_private.cases where organization_id=p_org and id=p_case) or not uniion_private.actor_resource(p_org,p_case,auth.uid(),false) then raise insufficient_privilege;end if;
 if p_attachment is not null and not exists(select 1 from public.uniion_attachments where organization_id=p_org and resource_id=p_case and id=p_attachment) then raise insufficient_privilege;end if;
 return jsonb_build_object('write',uniion_private.actor_resource(p_org,p_case,auth.uid(),true),'download',uniion_private.authority(p_org,auth.uid(),'download'),'files',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'mime',a.mime,'size',a.size,'created',a.created_at,'status',a.scan_status) order by a.created_at desc) from public.uniion_attachments a where a.organization_id=p_org and a.resource_id=p_case),'[]'));
end$$;
revoke all on function public.uniion_case_files(uuid,uuid,uuid) from public,anon;
grant execute on function public.uniion_case_files(uuid,uuid,uuid) to authenticated;
notify pgrst,'reload schema';
commit;

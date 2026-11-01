begin;
create or replace function public.uniion_document_export(p_org uuid,p_id uuid,p_version integer,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources;
begin
 perform public.uniion_module_use(p_org,'documents');
 select * into r from public.uniion_resources where organization_id=p_org and id=p_id and module='documents' for share;
 if not found or not exists(select 1 from uniion_private.documents where organization_id=p_org and id=p_id) or not uniion_private.actor_resource(p_org,p_id,auth.uid(),false) or not uniion_private.authority(p_org,auth.uid(),'download') or p_version is distinct from r.version or p_action is null or p_action not in ('prepare','complete') then raise insufficient_privilege;end if;
 if p_action='complete' then
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.export.authorized',jsonb_build_object('resource',p_id,'version',p_version,'format','pdf'));
  return jsonb_build_object('version',r.version);
 end if;
 return jsonb_build_object('version',r.version,'document',uniion_private.document_json(p_org,p_id));
end$$;
revoke all on function public.uniion_document_export(uuid,uuid,integer,text) from public,anon;
grant execute on function public.uniion_document_export(uuid,uuid,integer,text) to authenticated;
notify pgrst,'reload schema';commit;

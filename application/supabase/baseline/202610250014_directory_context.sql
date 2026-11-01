begin;
create function public.uniion_directory_context(p_org uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not uniion_private.authority(p_org,auth.uid(),'rights') or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege;end if;
 return jsonb_build_object('grants',coalesce((select jsonb_agg(jsonb_build_object('target',g.target_id,'target_name',o.name,'grantee',g.grantee,'person',g.listed_user,'name',u.email,'until',g.valid_until,'revoked',g.revoked_at)) from public.uniion_directory_grants g join public.uniion_organizations o on o.id=g.target_id join auth.users u on u.id=g.listed_user where g.organization_id=p_org),'[]'::jsonb),
 'targets',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name)) from public.uniion_partners p join public.uniion_organizations o on o.id=p.source_id where p.target_id=p_org and o.active),'[]'::jsonb));
end $$;
revoke all on function public.uniion_directory_context(uuid) from public,anon;
grant execute on function public.uniion_directory_context(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

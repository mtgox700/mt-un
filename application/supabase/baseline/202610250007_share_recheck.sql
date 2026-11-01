begin;
create function public.uniion_shared_check(p_org uuid,p_share uuid,p_resource uuid,p_download boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_shares where id=p_share and target_id=p_org)
 and uniion_private.share_access(p_share,p_resource,auth.uid(),p_download)
$$;
revoke all on function public.uniion_shared_check(uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.uniion_shared_check(uuid,uuid,uuid,boolean) to authenticated;
notify pgrst,'reload schema';
commit;

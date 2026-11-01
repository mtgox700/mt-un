begin;
create or replace function public.uniion_identity_profile(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not coalesce((public.uniion_session_status()->>'allowed')::boolean,false) or not uniion_private.member(p_org) then raise insufficient_privilege;end if;
 return (select jsonb_build_object('id',u.id,'email',u.email,'name',coalesce(nullif(u.raw_user_meta_data->>'full_name',''),u.email),'organization_id',o.id,'organization',o.name,'can_manage',uniion_private.identity_admin(p_org)) from auth.users u cross join public.uniion_organizations o where u.id=auth.uid() and o.id=p_org);
end $$;
create or replace function public.uniion_identity_directory(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not coalesce((public.uniion_session_status()->>'allowed')::boolean,false) or not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 return jsonb_build_object(
 'members',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',coalesce(nullif(u.raw_user_meta_data->>'full_name',''),u.email),'email',u.email,'joined_at',m.joined_at,'revoked_at',m.revoked_at) order by m.joined_at,u.id) from public.uniion_memberships m join auth.users u on u.id=m.user_id where m.organization_id=p_org),'[]'::jsonb),
 'invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'created_at',i.created_at,'expires_at',i.expires_at,'accepted_at',i.accepted_at,'revoked_at',i.revoked_at,'status',case when i.accepted_at is not null then 'accepted' when i.revoked_at is not null then 'revoked' when i.expires_at<=now() then 'expired' else 'pending' end) order by i.created_at desc,i.id) from uniion_private.invitations i where i.organization_id=p_org),'[]'::jsonb));
end $$;
revoke all on function public.uniion_identity_profile(uuid),public.uniion_identity_directory(uuid) from public,anon;
grant execute on function public.uniion_identity_profile(uuid),public.uniion_identity_directory(uuid) to authenticated;
commit;

begin;
-- Original bytes only through the server gateway, after user authorization.
-- Scanner remains a server-only identity; no ordinary user can bypass audit.
drop policy uniion_file_read on storage.objects;

create table public.uniion_directory_grants (
 organization_id uuid not null references public.uniion_organizations,
 target_id uuid not null references public.uniion_organizations,
 grantee uuid not null references auth.users,
 listed_user uuid not null references auth.users,
 approved_by uuid not null references auth.users,
 valid_until timestamptz not null,
 revoked_at timestamptz,
 primary key(organization_id,target_id,grantee,listed_user),
 check(organization_id<>target_id)
);
alter table public.uniion_directory_grants enable row level security;
revoke all on public.uniion_directory_grants from public,anon,authenticated;

create function public.uniion_directory_authorize(p_org uuid,p_target uuid,p_grantee uuid,p_people uuid[],p_until timestamptz,p_enabled boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 if not uniion_private.authority(p_org,auth.uid(),'rights') or not uniion_private.authority(p_org,auth.uid(),'share')
 or not uniion_private.actor_member(p_target,p_grantee)
 or not exists(select 1 from public.uniion_partners where source_id=p_target and target_id=p_org)
 or coalesce(cardinality(p_people),0) not between 1 and 20 or p_enabled is null then raise insufficient_privilege;end if;
 foreach person in array p_people loop
  if not uniion_private.actor_member(p_org,person) then raise insufficient_privilege;end if;
  if p_enabled then
   if p_until is null or p_until<=now() or p_until>now()+interval '90 days' then raise insufficient_privilege;end if;
   insert into public.uniion_directory_grants values(p_org,p_target,p_grantee,person,auth.uid(),p_until,null)
    on conflict(organization_id,target_id,grantee,listed_user) do update set approved_by=auth.uid(),valid_until=excluded.valid_until,revoked_at=null;
  else
   update public.uniion_directory_grants set revoked_at=now() where organization_id=p_org and target_id=p_target and grantee=p_grantee and listed_user=person;
  end if;
 end loop;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details)
 values(p_org,p_target,auth.uid(),'directory.consent',jsonb_build_object('grantee',p_grantee,'people',p_people,'enabled',p_enabled,'until',p_until));
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.uniion_directory_authorize(uuid,uuid,uuid,uuid[],timestamptz,boolean) from public,anon;
grant execute on function public.uniion_directory_authorize(uuid,uuid,uuid,uuid[],timestamptz,boolean) to authenticated;

alter function public.uniion_admin_context(uuid) rename to uniion_admin_context_pre_cyber;
revoke all on function public.uniion_admin_context_pre_cyber(uuid) from public,anon,authenticated;
create function public.uniion_admin_context(p_org uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 result=public.uniion_admin_context_pre_cyber(p_org);
 return result||jsonb_build_object('partners',case when uniion_private.authority(p_org,auth.uid(),'share') then coalesce((
  select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'members',coalesce((
   select jsonb_agg(jsonb_build_object('id',u.id,'name',u.email)) from public.uniion_directory_grants g join auth.users u on u.id=g.listed_user
   where g.organization_id=o.id and g.target_id=p_org and g.grantee=auth.uid() and g.revoked_at is null and g.valid_until>now()
    and uniion_private.actor_member(o.id,g.listed_user) and uniion_private.authority(o.id,g.approved_by,'rights') and uniion_private.authority(o.id,g.approved_by,'share')
  ),'[]'::jsonb))) from public.uniion_partners p join public.uniion_organizations o on o.id=p.target_id where p.source_id=p_org and o.active
 ),'[]'::jsonb) else '[]'::jsonb end);
end $$;
revoke all on function public.uniion_admin_context(uuid) from public,anon;
grant execute on function public.uniion_admin_context(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

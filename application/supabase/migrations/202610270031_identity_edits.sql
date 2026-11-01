begin;
alter table public.uniion_authorities drop constraint uniion_authorities_permission_check;
alter table public.uniion_authorities add constraint uniion_authorities_permission_check check(permission in ('rights','share','accept','download','history','organization_edit'));
create table uniion_private.identity_profiles (
 organization_id uuid not null,user_id uuid not null,name text not null,role_label text not null,
 primary key(organization_id,user_id),foreign key(organization_id,user_id) references public.uniion_memberships
);
create table uniion_private.organization_details (
 organization_id uuid primary key references public.uniion_organizations, details jsonb not null
);
alter table uniion_private.identity_profiles enable row level security;
alter table uniion_private.organization_details enable row level security;
revoke all on uniion_private.identity_profiles,uniion_private.organization_details from public,anon,authenticated;
create or replace function public.uniion_identity_profile(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not coalesce((public.uniion_session_status()->>'allowed')::boolean,false) or not uniion_private.member(p_org) then raise insufficient_privilege;end if;
 return (select jsonb_build_object('id',u.id,'email',u.email,'name',coalesce(p.name,nullif(u.raw_user_meta_data->>'full_name',''),u.email),'role_label',coalesce(p.role_label,''),'organization_id',o.id,'organization',o.name,'organization_details',coalesce(d.details,'{}'::jsonb)||jsonb_build_object('nom',o.name),'can_manage',uniion_private.identity_admin(p_org),'can_edit_organization',auth.jwt()->>'aal'='aal2' and uniion_private.authority(p_org,auth.uid(),'organization_edit')) from auth.users u cross join public.uniion_organizations o left join uniion_private.identity_profiles p on p.organization_id=o.id and p.user_id=auth.uid() left join uniion_private.organization_details d on d.organization_id=o.id where u.id=auth.uid() and o.id=p_org);
end $$;
create function public.uniion_identity_profile_save(p_org uuid,p_name text,p_role text,p_email text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform public.uniion_identity_profile(p_org);
 if p_name is null or length(trim(p_name)) not between 1 and 160 or p_role is null or length(trim(p_role)) not between 1 and 160 or p_email is distinct from (select email from auth.users where id=auth.uid()) then raise insufficient_privilege;end if;
 insert into uniion_private.identity_profiles values(p_org,auth.uid(),trim(p_name),trim(p_role)) on conflict(organization_id,user_id) do update set name=excluded.name,role_label=excluded.role_label;
 return public.uniion_identity_profile(p_org);
end $$;
create function public.uniion_identity_organization_save(p_org uuid,p_details jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare k text;v jsonb;
begin
 perform public.uniion_identity_profile(p_org);
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.authority(p_org,auth.uid(),'organization_edit') then raise insufficient_privilege;end if;
 if p_details is null or jsonb_typeof(p_details)<>'object' or length(p_details::text)>12000 then raise insufficient_privilege;end if;
 for k,v in select * from jsonb_each(p_details) loop
 if k<>all(array['type','nom','sigle','siret','idcc','effectif','sieges','mandatDebut','mandatFin','adresse','email','tel','secretaire','tresorier']) or jsonb_typeof(v)<>'string' or length(v#>>'{}')>500 then raise insufficient_privilege;end if;
 end loop;
 if coalesce(length(trim(p_details->>'nom')),0)=0 or coalesce(p_details->>'type','') not in ('cse','ud','section') then raise insufficient_privilege;end if;
 if coalesce(p_details->>'siret','')<>'' and (p_details->>'siret')!~'^[0-9]{14}$' then raise insufficient_privilege;end if;
 if coalesce(p_details->>'email','')<>'' and (p_details->>'email')!~'^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise insufficient_privilege;end if;
 foreach k in array array['effectif','sieges'] loop
 if coalesce(p_details->>k,'')<>'' and (p_details->>k)!~'^[0-9]{1,9}$' then raise insufficient_privilege;end if;
 end loop;
 foreach k in array array['mandatDebut','mandatFin'] loop
 if coalesce(p_details->>k,'')<>'' then
 if (p_details->>k)!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise insufficient_privilege;end if;
 perform (p_details->>k)::date;
 end if;end loop;
 if coalesce(p_details->>'mandatDebut','')<>'' and coalesce(p_details->>'mandatFin','')<>'' and p_details->>'mandatFin'<=p_details->>'mandatDebut' then raise insufficient_privilege;end if;
 update public.uniion_organizations set name=trim(p_details->>'nom') where id=p_org;
 insert into uniion_private.organization_details values(p_org,p_details) on conflict(organization_id) do update set details=excluded.details;
 return public.uniion_identity_profile(p_org);
end $$;
revoke all on function public.uniion_identity_profile_save(uuid,text,text,text),public.uniion_identity_organization_save(uuid,jsonb) from public,anon;
grant execute on function public.uniion_identity_profile_save(uuid,text,text,text),public.uniion_identity_organization_save(uuid,jsonb) to authenticated;
commit;

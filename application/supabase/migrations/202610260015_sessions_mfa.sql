begin;
create table uniion_private.mfa_requirements(user_id uuid primary key references auth.users(id),required boolean not null default true);
revoke all on uniion_private.mfa_requirements from public,anon,authenticated;
create function uniion_private.session_allowed() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id' and (s.not_after is null or s.not_after>now()))
 and (coalesce(auth.jwt()->>'aal','aal1')='aal2' or (
 not exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified')
 and not exists(select 1 from uniion_private.mfa_requirements m where m.user_id=auth.uid() and m.required)))
$$;
revoke all on function uniion_private.session_allowed() from public,anon,authenticated;
-- Both direct RLS and security-definer business functions use these membership gates.
create or replace function uniion_private.member(org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.session_allowed() and exists(select 1 from public.uniion_memberships m join public.uniion_organizations o on o.id=m.organization_id where m.organization_id=org and m.user_id=auth.uid() and m.revoked_at is null and m.joined_at<=now() and o.active)
$$;
create or replace function uniion_private.actor_member(org uuid,who uuid) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.session_allowed() and exists(select 1 from public.uniion_memberships m join public.uniion_organizations o on o.id=m.organization_id where m.organization_id=org and m.user_id=who and m.revoked_at is null and m.joined_at<=now() and o.active)
$$;
create function public.uniion_session_status() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('active',exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id' and (s.not_after is null or s.not_after>now())),
 'aal',coalesce(auth.jwt()->>'aal','aal1'),
 'required',exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified') or exists(select 1 from uniion_private.mfa_requirements m where m.user_id=auth.uid() and m.required),
 'allowed',uniion_private.session_allowed())
$$;
create function public.uniion_require_mfa() returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified') then raise insufficient_privilege;end if;
 insert into uniion_private.mfa_requirements values(auth.uid(),true) on conflict(user_id) do update set required=true;
 return true;
end $$;
revoke all on function public.uniion_session_status(),public.uniion_require_mfa() from public,anon;
grant execute on function public.uniion_session_status(),public.uniion_require_mfa() to authenticated;
notify pgrst,'reload schema';
commit;

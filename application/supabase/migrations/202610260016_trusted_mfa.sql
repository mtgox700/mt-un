begin;
-- A valid Supabase AAL2 alone must not authorize a replacement factor after loss.
create table uniion_private.trusted_mfa_factors (
 factor_id uuid primary key,user_id uuid not null references auth.users(id),
 authorized_at timestamptz not null default now()
);
revoke all on uniion_private.trusted_mfa_factors from public,anon,authenticated;
-- Adopt only factors verified before this controlled migration, for this application.
insert into uniion_private.trusted_mfa_factors(factor_id,user_id)
 select f.id,f.user_id from auth.mfa_factors f where f.status='verified'
 and exists(select 1 from public.uniion_memberships m where m.user_id=f.user_id);
create or replace function uniion_private.session_allowed() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id'
 and (s.not_after is null or s.not_after>now())
 and ((auth.jwt()->>'aal'='aal2' and exists(select 1 from uniion_private.trusted_mfa_factors t
 join auth.mfa_factors f on f.id=t.factor_id and f.user_id=t.user_id
 where t.user_id=s.user_id and t.factor_id=s.factor_id and f.status='verified'))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal1'
 and not exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified')
 and not exists(select 1 from uniion_private.mfa_requirements m where m.user_id=auth.uid() and m.required))))
$$;
create function public.uniion_mfa_authorize_factor(p_factor uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 perform 1 from auth.users where id=auth.uid() for update;
 if not uniion_private.session_allowed() then raise insufficient_privilege;end if;
 if exists(select 1 from uniion_private.mfa_requirements where user_id=auth.uid() and required)
 and auth.jwt()->>'aal' is distinct from 'aal2' then raise insufficient_privilege;end if;
 if not exists(select 1 from auth.mfa_factors where id=p_factor and user_id=auth.uid() and status='unverified' and factor_type='totp') then raise insufficient_privilege;end if;
 insert into uniion_private.trusted_mfa_factors(factor_id,user_id) values(p_factor,auth.uid()) on conflict do nothing;
 return true;
end $$;
revoke all on function public.uniion_mfa_authorize_factor(uuid) from public,anon;
grant execute on function public.uniion_mfa_authorize_factor(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

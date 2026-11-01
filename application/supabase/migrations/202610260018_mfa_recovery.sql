begin;
create table uniion_private.platform_operators(user_id uuid primary key references auth.users(id));
create table uniion_private.mfa_recovery_requests(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users,
 factor_id uuid not null unique,requested_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '30 minutes',
 approved_by uuid references auth.users,approved_at timestamptz,verification_reference text
);
revoke all on uniion_private.platform_operators,uniion_private.mfa_recovery_requests from public,anon,authenticated;
alter table uniion_private.trusted_mfa_factors add column valid_until timestamptz;
create or replace function uniion_private.session_allowed() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id'
 and (s.not_after is null or s.not_after>now())
 and ((auth.jwt()->>'aal'='aal2' and exists(select 1 from uniion_private.trusted_mfa_factors t
 join auth.mfa_factors f on f.id=t.factor_id and f.user_id=t.user_id
 where t.user_id=s.user_id and t.factor_id=s.factor_id and f.status='verified' and (t.valid_until is null or t.valid_until>now())))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal1'
 and not exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified')
 and not exists(select 1 from uniion_private.mfa_requirements m where m.user_id=auth.uid() and m.required))))
$$;
create or replace function public.uniion_require_mfa() returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified') then raise insufficient_privilege;end if;
 insert into uniion_private.mfa_requirements values(auth.uid(),true) on conflict(user_id) do update set required=true;
 update uniion_private.trusted_mfa_factors set valid_until=null where user_id=auth.uid() and factor_id=(select factor_id from auth.sessions where id::text=auth.jwt()->>'session_id' and user_id=auth.uid());
 return true;
end $$;
create function public.uniion_mfa_recovery_request(p_factor uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare ident uuid;
begin
 if not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now()))
 or not exists(select 1 from uniion_private.mfa_requirements where user_id=auth.uid() and required)
 or not exists(select 1 from auth.mfa_factors where id=p_factor and user_id=auth.uid() and status='unverified' and factor_type='totp') then raise insufficient_privilege;end if;
 if (select count(*) from uniion_private.mfa_recovery_requests where user_id=auth.uid() and expires_at>now() and approved_at is null)>=3 then raise insufficient_privilege;end if;
 insert into uniion_private.mfa_recovery_requests(user_id,factor_id) values(auth.uid(),p_factor) returning id into ident;
 return jsonb_build_object('id',ident,'expires_in_seconds',1800,'approval_required',true);
end $$;
create function public.uniion_mfa_recovery_approve(p_request uuid,p_verification_reference text) returns jsonb language plpgsql security definer set search_path='' as $$
declare req uniion_private.mfa_recovery_requests;
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2'
 or not exists(select 1 from uniion_private.platform_operators where user_id=auth.uid())
 or p_verification_reference is null or length(trim(p_verification_reference)) not between 12 and 200 then raise insufficient_privilege;end if;
 select * into req from uniion_private.mfa_recovery_requests where id=p_request for update;
 if not found or req.user_id=auth.uid() or req.approved_at is not null or req.expires_at<=now()
 or not exists(select 1 from auth.mfa_factors where id=req.factor_id and user_id=req.user_id and status='unverified') then raise insufficient_privilege;end if;
 -- Replace trust, not the user's credentials. Keep all records for audit.
 update uniion_private.trusted_mfa_factors set valid_until=now() where user_id=req.user_id;
 insert into uniion_private.trusted_mfa_factors(factor_id,user_id,valid_until) values(req.factor_id,req.user_id,now()+interval '30 minutes');
 update auth.sessions set not_after=now() where user_id=req.user_id;
 update uniion_private.mfa_recovery_requests set approved_by=auth.uid(),approved_at=now(),verification_reference=trim(p_verification_reference) where id=req.id;
 return jsonb_build_object('ok',true,'relogin_required',true,'activation_expires_in_seconds',1800);
end $$;
revoke all on function public.uniion_mfa_recovery_request(uuid),public.uniion_mfa_recovery_approve(uuid,text) from public,anon;
grant execute on function public.uniion_mfa_recovery_request(uuid),public.uniion_mfa_recovery_approve(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;

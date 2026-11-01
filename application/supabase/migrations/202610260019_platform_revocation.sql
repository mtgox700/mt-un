begin;
alter table uniion_private.platform_operators add column active boolean not null default true;
create or replace function public.uniion_mfa_recovery_approve(p_request uuid,p_verification_reference text) returns jsonb language plpgsql security definer set search_path='' as $$
declare req uniion_private.mfa_recovery_requests;
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2'
 or not exists(select 1 from uniion_private.platform_operators where user_id=auth.uid() and active)
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
notify pgrst,'reload schema';
commit;

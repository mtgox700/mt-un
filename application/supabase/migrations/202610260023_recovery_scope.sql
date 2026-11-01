begin;
-- Auth can be shared locally: only identities already belonging to UNIION qualify.
create or replace function public.uniion_lost_factor_request() returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[];job uuid;
begin
 perform 1 from auth.users where id=auth.uid() for update;
 if not (exists(select 1 from public.uniion_memberships where user_id=auth.uid())
 or exists(select 1 from uniion_private.mfa_requirements where user_id=auth.uid())
 or exists(select 1 from uniion_private.platform_operators where user_id=auth.uid())) then raise insufficient_privilege;end if;
 if not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now())) then raise insufficient_privilege;end if;
 select array_agg(id order by id) into ids from auth.mfa_factors where user_id=auth.uid() and status='verified';
 if coalesce(cardinality(ids),0)=0 or (select count(*) from uniion_private.lost_factor_jobs where user_id=auth.uid() and expires_at>now() and state in ('pending','approved','processing','cleared'))>=3 then raise insufficient_privilege;end if;
 insert into uniion_private.lost_factor_jobs(user_id,factors) values(auth.uid(),ids) returning id into job;
 return jsonb_build_object('id',job,'approval_required',true);
end $$;
notify pgrst,'reload schema';
commit;

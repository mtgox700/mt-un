begin;
create table uniion_private.lost_factor_jobs(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users,
 factors uuid[] not null,requested_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '30 minutes',
 approved_by uuid references auth.users,verification_reference text,
 state text not null default 'pending' check(state in ('pending','approved','processing','cleared','enrolled','cancelled')),
 lease uuid,lease_until timestamptz,replacement_factor uuid,
 check(cardinality(factors)>0)
);
revoke all on uniion_private.lost_factor_jobs from public,anon,authenticated,service_role;
create function public.uniion_lost_factor_request() returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[];job uuid;
begin
 if not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now())) then raise insufficient_privilege;end if;
 select array_agg(id order by id) into ids from auth.mfa_factors where user_id=auth.uid() and status='verified';
 if coalesce(cardinality(ids),0)=0 or (select count(*) from uniion_private.lost_factor_jobs where user_id=auth.uid() and expires_at>now() and state in ('pending','approved','processing','cleared'))>=3 then raise insufficient_privilege;end if;
 insert into uniion_private.lost_factor_jobs(user_id,factors) values(auth.uid(),ids) returning id into job;
 return jsonb_build_object('id',job,'approval_required',true);
end $$;
create function public.uniion_lost_factor_approve(p_request uuid,p_verification_reference text) returns jsonb language plpgsql security definer set search_path='' as $$
declare job uniion_private.lost_factor_jobs;ids uuid[];
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2'
 or not exists(select 1 from uniion_private.platform_operators where user_id=auth.uid() and active)
 or p_verification_reference is null or length(trim(p_verification_reference)) not between 12 and 200 then raise insufficient_privilege;end if;
 select * into job from uniion_private.lost_factor_jobs where id=p_request for update;
 if not found or job.user_id=auth.uid() or job.state<>'pending' or job.expires_at<=now() then raise insufficient_privilege;end if;
 select array_agg(id order by id) into ids from auth.mfa_factors where user_id=job.user_id and status='verified';
 if ids is distinct from job.factors then raise insufficient_privilege;end if;
 update uniion_private.lost_factor_jobs set state='approved',approved_by=auth.uid(),verification_reference=trim(p_verification_reference),expires_at=now()+interval '30 minutes' where id=job.id;
 update uniion_private.trusted_mfa_factors set valid_until=now() where user_id=job.user_id;
 update auth.sessions set not_after=now() where user_id=job.user_id;
 return jsonb_build_object('ok',true,'worker_required',true);
end $$;
create function public.uniion_lost_factor_claim(p_request uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare job uniion_private.lost_factor_jobs;ticket uuid=gen_random_uuid();
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 select * into job from uniion_private.lost_factor_jobs where id=p_request for update;
 if not found or job.expires_at<=now() or not exists(select 1 from uniion_private.platform_operators where user_id=job.approved_by and active)
 or not (job.state='approved' or (job.state='processing' and job.lease_until<now())) then raise insufficient_privilege;end if;
 update uniion_private.lost_factor_jobs set state='processing',lease=ticket,lease_until=now()+interval '2 minutes' where id=job.id;
 return jsonb_build_object('user_id',job.user_id,'factors',job.factors,'lease',ticket);
end $$;
create function public.uniion_lost_factor_finish(p_request uuid,p_lease uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare job uniion_private.lost_factor_jobs;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 select * into job from uniion_private.lost_factor_jobs where id=p_request for update;
 if not found or job.state<>'processing' or job.lease is distinct from p_lease or job.lease_until<=now() or job.expires_at<=now()
 or not exists(select 1 from uniion_private.platform_operators where user_id=job.approved_by and active)
 or exists(select 1 from auth.mfa_factors where user_id=job.user_id and status='verified') then raise insufficient_privilege;end if;
 update uniion_private.lost_factor_jobs set state='cleared',expires_at=now()+interval '30 minutes',lease=null,lease_until=null where id=job.id;
 insert into uniion_private.mfa_requirements values(job.user_id,true) on conflict(user_id) do update set required=true;
 update auth.sessions set not_after=now() where user_id=job.user_id;
 return jsonb_build_object('ok',true,'relogin_required',true);
end $$;
create function uniion_private.reenrollment_allowed() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now()))
 and not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified')
 and exists(select 1 from uniion_private.lost_factor_jobs j join uniion_private.platform_operators p on p.user_id=j.approved_by and p.active where j.user_id=auth.uid() and j.state='cleared' and j.expires_at>now())
$$;
revoke all on function uniion_private.reenrollment_allowed() from public,anon,authenticated,service_role;
create or replace function public.uniion_session_status() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('active',exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id' and (s.not_after is null or s.not_after>now())),
 'aal',coalesce(auth.jwt()->>'aal','aal1'),
 'required',exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified') or exists(select 1 from uniion_private.mfa_requirements m where m.user_id=auth.uid() and m.required),
 'allowed',uniion_private.session_allowed(),'enrollment_allowed',uniion_private.reenrollment_allowed())
$$;
create or replace function public.uniion_mfa_authorize_factor(p_factor uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare job uuid;
begin
 perform 1 from auth.users where id=auth.uid() for update;
 if not exists(select 1 from auth.mfa_factors where id=p_factor and user_id=auth.uid() and status='unverified' and factor_type='totp') then raise insufficient_privilege;end if;
 if uniion_private.reenrollment_allowed() then
  select j.id into job from uniion_private.lost_factor_jobs j join uniion_private.platform_operators p on p.user_id=j.approved_by and p.active where j.user_id=auth.uid() and j.state='cleared' and j.expires_at>now() order by j.requested_at limit 1 for update of j;
  if not found then raise insufficient_privilege;end if;
  update uniion_private.lost_factor_jobs set state='enrolled',replacement_factor=p_factor where id=job;
  insert into uniion_private.trusted_mfa_factors(factor_id,user_id,valid_until) values(p_factor,auth.uid(),now()+interval '10 minutes');
 else
  if not uniion_private.session_allowed() or (exists(select 1 from uniion_private.mfa_requirements where user_id=auth.uid() and required) and auth.jwt()->>'aal' is distinct from 'aal2') then raise insufficient_privilege;end if;
  insert into uniion_private.trusted_mfa_factors(factor_id,user_id) values(p_factor,auth.uid()) on conflict do nothing;
 end if;
 return true;
end $$;
revoke all on function public.uniion_lost_factor_request(),public.uniion_lost_factor_approve(uuid,text),public.uniion_lost_factor_claim(uuid),public.uniion_lost_factor_finish(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.uniion_lost_factor_request(),public.uniion_lost_factor_approve(uuid,text) to authenticated;
grant execute on function public.uniion_lost_factor_claim(uuid),public.uniion_lost_factor_finish(uuid,uuid) to service_role;
notify pgrst,'reload schema';
commit;

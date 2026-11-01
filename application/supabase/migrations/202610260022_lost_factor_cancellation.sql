begin;
alter table uniion_private.lost_factor_jobs add column cancelled_at timestamptz;
create function public.uniion_lost_factor_check(p_request uuid,p_lease uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.role()='service_role' and exists(select 1 from uniion_private.lost_factor_jobs j join uniion_private.platform_operators p on p.user_id=j.approved_by and p.active
 where j.id=p_request and j.lease=p_lease and j.state='processing' and j.lease_until>now() and j.expires_at>now())
$$;
create function public.uniion_lost_factor_cancel(p_request uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare job uniion_private.lost_factor_jobs;mine uuid=auth.uid();
begin
 if not exists(select 1 from auth.sessions where user_id=mine and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now())) then raise insufficient_privilege;end if;
 select * into job from uniion_private.lost_factor_jobs where id=p_request for update;
 if not found or job.state not in ('pending','approved','processing','cleared') then raise insufficient_privilege;end if;
 if mine<>job.user_id and not (uniion_private.session_allowed() and auth.jwt()->>'aal'='aal2' and exists(select 1 from uniion_private.platform_operators where user_id=mine and active)) then raise insufficient_privilege;end if;
 update uniion_private.lost_factor_jobs set state='cancelled',cancelled_at=now(),lease=null,lease_until=null where id=job.id;
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.uniion_lost_factor_check(uuid,uuid),public.uniion_lost_factor_cancel(uuid) from public,anon,authenticated,service_role;
grant execute on function public.uniion_lost_factor_check(uuid,uuid) to service_role;
grant execute on function public.uniion_lost_factor_cancel(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

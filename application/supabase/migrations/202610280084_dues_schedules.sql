begin;
create table uniion_private.dues_schedules(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,adherent_id uuid not null,
 anchor date not null,months int not null check(months in(1,3,12)),amount_cents bigint not null check(amount_cents>0),
 next_index int not null default 0 check(next_index>=0),state text not null default 'active' check(state in('active','paused','review','conflict')),
 actor uuid not null references auth.users,created_at timestamptz not null default now(),
 unique(organization_id,adherent_id),unique(organization_id,id),
 foreign key(organization_id,adherent_id) references uniion_private.adherents(organization_id,id));
alter table uniion_private.dues_schedules enable row level security;
revoke all on uniion_private.dues_schedules from public,anon,authenticated;
alter table uniion_private.dues_entries add column schedule_id uuid,add column occurrence int,
 add constraint dues_schedule_org_fk foreign key(organization_id,schedule_id) references uniion_private.dues_schedules(organization_id,id),
 add constraint dues_schedule_occurrence unique(schedule_id,occurrence);
create function uniion_private.dues_occurrence(anchor date,months int,n int) returns date language sql immutable set search_path='' as $$select (anchor+make_interval(months=>months*n))::date$$;
revoke all on function uniion_private.dues_occurrence(date,int,int) from public,anon,authenticated;
-- Explicit persisted authority of the original financial writer, rechecked on each run.
create function uniion_private.schedule_allowed(o uuid,u uuid) returns boolean language sql stable set search_path='' as $$
select exists(select 1 from public.uniion_memberships where organization_id=o and user_id=u and revoked_at is null and joined_at<=now()) and not exists(select 1 from uniion_private.membership_suspensions where organization_id=o and user_id=u and suspended) and exists(select 1 from public.uniion_organizations where id=o and active)
 and uniion_private.commercial_allowed(o,'adherents')
 and not exists(select 1 from (values('adherents','read'),('cotisations','read'),('cotisations','write')) required(module,permission)
 where not exists(select 1 from public.uniion_permissions p where p.organization_id=o and p.user_id=u and p.module=required.module and p.permission=required.permission))
 and (select count(*)=2 from public.uniion_module_access where organization_id=o and module in('adherents','cotisations') and authorized and enabled and valid_until>now());
$$;
revoke all on function uniion_private.schedule_allowed(uuid,uuid) from public,anon,authenticated;
create function uniion_private.run_dues_schedules(p_org uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare s uniion_private.dues_schedules;a uniion_private.adherents;d date;today date=(now() at time zone 'Europe/Paris')::date;made int=0;blocked int=0;loops int;entry uuid;
begin
 for s in select * from uniion_private.dues_schedules where state='active' and (p_org is null or organization_id=p_org) order by id for update skip locked loop
  select * into a from uniion_private.adherents where id=s.adherent_id and organization_id=s.organization_id for update;
  if not uniion_private.schedule_allowed(s.organization_id,s.actor) then continue;end if;
  if a.joined_on is distinct from s.anchor or (a.dues_terms->>'cents')::bigint is distinct from s.amount_cents or (case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end) is distinct from s.months then
   update uniion_private.dues_schedules set state='review' where id=s.id;blocked=blocked+1;continue;
  end if;
  loops=0;
  loop
   d=uniion_private.dues_occurrence(s.anchor,s.months,s.next_index);exit when d>today or loops>=24;
   -- An existing manual charge for this calendar period needs human reconciliation.
   if exists(select 1 from uniion_private.dues_entries where organization_id=s.organization_id and adherent_id=s.adherent_id and period>=date_trunc('month',d)::date and period<(date_trunc('month',d)+make_interval(months=>s.months))::date) then
    update uniion_private.dues_schedules set state='conflict' where id=s.id;blocked=blocked+1;exit;
   end if;
   insert into uniion_private.dues_entries(organization_id,adherent_id,amount_cents,period,due_on,created_by,request_id,schedule_id,occurrence)
    values(s.organization_id,s.adherent_id,s.amount_cents,date_trunc('month',d)::date,d,s.actor,gen_random_uuid(),s.id,s.next_index) returning id into entry;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(s.organization_id,s.actor,'dues.scheduled',jsonb_build_object('schedule',s.id,'entry',entry,'occurrence',s.next_index));
   s.next_index=s.next_index+1;update uniion_private.dues_schedules set next_index=s.next_index where id=s.id;made=made+1;loops=loops+1;
  end loop;
 end loop;
 return jsonb_build_object('created',made,'blocked',blocked);
end $$;
revoke all on function uniion_private.run_dues_schedules(uuid) from public,anon,authenticated;
-- Only NEW records acquire a plan. Historical dates advance to the next non-past occurrence.
create function uniion_private.new_dues_schedule() returns trigger language plpgsql security definer set search_path='' as $$
declare m int;n int=0;today date=(now() at time zone 'Europe/Paris')::date;
begin
 m=case new.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
 if new.joined_on is null or m is null or coalesce((new.dues_terms->>'cents')::bigint,0)<=0 or not uniion_private.schedule_allowed(new.organization_id,auth.uid()) then return new;end if;
 n=greatest(0,((extract(year from today)::int-extract(year from new.joined_on)::int)*12+extract(month from today)::int-extract(month from new.joined_on)::int)/m);
 if uniion_private.dues_occurrence(new.joined_on,m,n)<today then n=n+1;end if;
 insert into uniion_private.dues_schedules(organization_id,adherent_id,anchor,months,amount_cents,next_index,actor) values(new.organization_id,new.id,new.joined_on,m,(new.dues_terms->>'cents')::bigint,n,auth.uid());
 insert into public.uniion_security_events(organization_id,actor,event,details) values(new.organization_id,auth.uid(),'dues.schedule_created',jsonb_build_object('adherent',new.id));
 return new;
end $$;
revoke all on function uniion_private.new_dues_schedule() from public,anon,authenticated;
create trigger new_dues_schedule after insert on uniion_private.adherents for each row execute function uniion_private.new_dues_schedule();
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_schedules;
revoke all on function public.uniion_adherents_before_schedules(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 if p_action='schedule_pause' then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or not(p_payload ? 'id') or p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
  update uniion_private.dues_schedules set state='paused' where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid;
  if not found then raise insufficient_privilege;end if;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.schedule_paused',p_payload);
  r=public.uniion_adherents_before_schedules(p_org,'list','{}');
 else
  -- Serialize manual creation with the automatic worker for this member.
  if p_action='charge' then perform 1 from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'adherent_id')::uuid for update;end if;
  r=public.uniion_adherents_before_schedules(p_org,p_action,p_payload);
  if p_action='import' then perform uniion_private.run_dues_schedules(p_org);r=public.uniion_adherents_before_schedules(p_org,'list','{}');end if;
 end if;
 if coalesce((r->>'financial')::boolean,false) then
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('schedule',(select jsonb_build_object('state',s.state,'nextDue',uniion_private.dues_occurrence(s.anchor,s.months,s.next_index),'cents',s.amount_cents,'months',s.months) from uniion_private.dues_schedules s where s.organization_id=p_org and s.adherent_id=(x->>'id')::uuid))) from jsonb_array_elements(r->'rows') x),'[]'));
 end if;
 return r;
exception when invalid_text_representation then raise insufficient_privilege;
end $$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

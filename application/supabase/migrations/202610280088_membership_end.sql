begin;
alter table uniion_private.adherents add column ended_on date,add constraint adherent_end_after_join check(ended_on is null or joined_on is null or ended_on>=joined_on);
alter table uniion_private.dues_schedules drop constraint dues_schedules_state_check;
alter table uniion_private.dues_schedules add constraint dues_schedules_state_check check(state in('active','paused','review','conflict','stopped'));
create table uniion_private.adherent_endings(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,adherent_id uuid not null,
 actor uuid not null references auth.users,created_at timestamptz not null default now(),request_id uuid not null,
 payload jsonb not null,before_state jsonb not null,after_state jsonb not null,
 unique(organization_id,request_id),unique(organization_id,adherent_id),
 foreign key(organization_id,adherent_id) references uniion_private.adherents(organization_id,id));
alter table uniion_private.adherent_endings enable row level security;
revoke all on uniion_private.adherent_endings from public,anon,authenticated;
-- Defense in depth: no new ledger entry after the effective end, including delayed work.
create function uniion_private.entry_membership_end() returns trigger language plpgsql set search_path='' as $$declare ending date;begin
 select ended_on into ending from uniion_private.adherents where organization_id=new.organization_id and id=new.adherent_id for update;
 if ending is not null and (new.due_on>=ending or (now() at time zone 'Europe/Paris')::date>=ending) then raise insufficient_privilege;end if;return new;
end$$;
create trigger entry_membership_end before insert on uniion_private.dues_entries for each row execute function uniion_private.entry_membership_end();
revoke all on function uniion_private.entry_membership_end() from public,anon,authenticated;
create function uniion_private.schedule_end_guard() returns trigger language plpgsql set search_path='' as $$begin
 if new.state='active' and exists(select 1 from uniion_private.adherents where organization_id=new.organization_id and id=new.adherent_id and ended_on<=(now() at time zone 'Europe/Paris')::date) then raise insufficient_privilege;end if;return new;
end$$;
create trigger schedule_end_guard before insert or update on uniion_private.dues_schedules for each row execute function uniion_private.schedule_end_guard();
revoke all on function uniion_private.schedule_end_guard() from public,anon,authenticated;
do $$declare d text;begin
 d=pg_get_functiondef('uniion_private.run_dues_schedules(uuid)'::regprocedure);
 d=replace(d,'if not uniion_private.schedule_allowed',E'if a.ended_on is not null and a.ended_on<=today then update uniion_private.dues_schedules set state=''stopped'' where id=s.id;continue;end if;\n  if not uniion_private.schedule_allowed');
 d=replace(d,'exit when d>today or loops>=24;','exit when d>today or loops>=24 or (a.ended_on is not null and d>=a.ended_on);');execute d;
end$$;
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_ending;
revoke all on function public.uniion_adherents_before_ending(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare a uniion_private.adherents;s uniion_private.dues_schedules;ending date;previous uniion_private.adherent_endings;r jsonb;before jsonb;
begin
 if p_action='membership_end' then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'adherents','write') or not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
  if not(p_payload ?& array['id','version','date','reason','request_id']) or p_payload-array['id','version','date','reason','request_id']<>'{}' or jsonb_typeof(p_payload->'reason')<>'string' or coalesce(length(btrim(p_payload->>'reason')),0) not between 5 and 500 or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
  select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
  select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
  if not found then raise insufficient_privilege;end if;
  select * into previous from uniion_private.adherent_endings where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if previous.actor<>auth.uid() or previous.payload<>p_payload then raise insufficient_privilege;end if;
  else
   ending=uniion_private.adherent_date(p_payload->>'date');
   if ending is null or a.joined_on is null or ending<a.joined_on or a.ended_on is not null or a.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
   before=jsonb_build_object('version',a.version,'endedOn',a.ended_on,'scheduleState',s.state);
   update uniion_private.adherents set ended_on=ending,version=version+1,updated_at=now() where id=a.id returning * into a;
   update uniion_private.dues_schedules set state=case when ending<=(now() at time zone 'Europe/Paris')::date then 'stopped' else state end where id=s.id;
   insert into uniion_private.adherent_endings(organization_id,adherent_id,actor,request_id,payload,before_state,after_state) values(p_org,a.id,auth.uid(),(p_payload->>'request_id')::uuid,p_payload,before,jsonb_build_object('version',a.version,'endedOn',ending));
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherent.ended',jsonb_build_object('id',a.id,'date',ending,'reason',btrim(p_payload->>'reason'),'before',before,'version',a.version));
  end if;
  r=public.uniion_adherents_before_ending(p_org,'list','{}');
 else
  if p_action in ('schedule_preview','schedule_resume','schedule_resolve_preview','schedule_resolve','schedule_pause') then
   perform public.uniion_module_use(p_org,'adherents');
   perform 1 from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
   select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
   if a.ended_on<=(now() at time zone 'Europe/Paris')::date then raise insufficient_privilege;end if;
  end if;
  r=public.uniion_adherents_before_ending(p_org,p_action,p_payload);
 end if;
 if r ? 'rows' then
  r=r||jsonb_build_object('canEndMembership',uniion_private.adherent_permission(p_org,'adherents','write') and uniion_private.adherent_permission(p_org,'cotisations','write'));
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('endedOn',a2.ended_on,'membershipActive',a2.ended_on is null or a2.ended_on>(now() at time zone 'Europe/Paris')::date)) from jsonb_array_elements(r->'rows') x join uniion_private.adherents a2 on a2.organization_id=p_org and a2.id=(x->>'id')::uuid),'[]'));
 end if;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or unique_violation or check_violation then raise insufficient_privilege;
end$$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

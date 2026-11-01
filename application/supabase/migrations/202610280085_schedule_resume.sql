begin;
alter table uniion_private.dues_schedules add column revision bigint not null default 1;
create function uniion_private.schedule_revision() returns trigger language plpgsql set search_path='' as $$begin new.revision=old.revision+1;return new;end$$;
create trigger schedule_revision before update on uniion_private.dues_schedules for each row execute function uniion_private.schedule_revision();
revoke all on function uniion_private.schedule_revision() from public,anon,authenticated;
create table uniion_private.schedule_changes(id uuid primary key default gen_random_uuid(),organization_id uuid not null,schedule_id uuid not null,actor uuid not null references auth.users,created_at timestamptz not null default now(),request_id uuid not null,payload jsonb not null,before_state jsonb not null,after_state jsonb not null,unique(organization_id,request_id),foreign key(organization_id,schedule_id) references uniion_private.dues_schedules(organization_id,id));
alter table uniion_private.schedule_changes enable row level security;
revoke all on uniion_private.schedule_changes from public,anon,authenticated;
create function uniion_private.schedule_proposal(s uniion_private.dues_schedules,a uniion_private.adherents) returns jsonb language plpgsql stable set search_path='' as $$
declare today date=(now() at time zone 'Europe/Paris')::date;n int;d date;m int;
begin
 m=case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
 if a.joined_on is distinct from s.anchor or m is distinct from s.months or coalesce((a.dues_terms->>'cents')::bigint,0)<=0 or s.state='conflict' then raise insufficient_privilege;end if;
 n=greatest(s.next_index,0,((extract(year from today)::int-extract(year from s.anchor)::int)*12+extract(month from today)::int-extract(month from s.anchor)::int)/s.months);
 if uniion_private.dues_occurrence(s.anchor,s.months,n)<today then n=n+1;end if;
 d=uniion_private.dues_occurrence(s.anchor,s.months,n);
 if exists(select 1 from uniion_private.dues_entries where organization_id=s.organization_id and adherent_id=s.adherent_id and period>=date_trunc('month',d)::date and period<(date_trunc('month',d)+make_interval(months=>s.months))::date) then raise insufficient_privilege;end if;
 return jsonb_build_object('revision',s.revision,'memberVersion',a.version,'nextIndex',n,'nextDue',d,'oldCents',s.amount_cents,'cents',(a.dues_terms->>'cents')::bigint,'months',s.months,'skipped',n-s.next_index);
end$$;
revoke all on function uniion_private.schedule_proposal(uniion_private.dues_schedules,uniion_private.adherents) from public,anon,authenticated;
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_resume;
revoke all on function public.uniion_adherents_before_resume(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;s uniion_private.dues_schedules;a uniion_private.adherents;proposal jsonb;previous uniion_private.schedule_changes;old_state jsonb;
begin
 if p_action in ('schedule_preview','schedule_resume') then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or not(p_payload ? 'id') then raise insufficient_privilege;end if;
  select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
  if not found then raise insufficient_privilege;end if;
  select * into a from uniion_private.adherents where organization_id=p_org and id=s.adherent_id for update;
  if p_action='schedule_preview' then
   if p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
   return jsonb_build_object('preview',uniion_private.schedule_proposal(s,a));
  end if;
  if p_payload->>'request_id' is null or not(p_payload ?& array['revision','memberVersion','nextDue','request_id']) or p_payload-array['id','revision','memberVersion','nextDue','request_id']<>'{}' then raise insufficient_privilege;end if;
  select * into previous from uniion_private.schedule_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if previous.payload<>p_payload or previous.actor<>auth.uid() then raise insufficient_privilege;end if;
  else
   proposal=uniion_private.schedule_proposal(s,a);
   if s.revision is distinct from (p_payload->>'revision')::bigint or a.version is distinct from (p_payload->>'memberVersion')::int or proposal->>'nextDue' is distinct from p_payload->>'nextDue' then raise insufficient_privilege;end if;
   old_state=to_jsonb(s);
   update uniion_private.dues_schedules set state='active',amount_cents=(proposal->>'cents')::bigint,next_index=(proposal->>'nextIndex')::int,actor=auth.uid() where id=s.id returning * into s;
   insert into uniion_private.schedule_changes(organization_id,schedule_id,actor,request_id,payload,before_state,after_state) values(p_org,s.id,auth.uid(),(p_payload->>'request_id')::uuid,p_payload,old_state,to_jsonb(s));
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.schedule_resumed',jsonb_build_object('schedule',s.id,'revision',s.revision,'skipped',proposal->'skipped','previousCents',proposal->'oldCents','cents',proposal->'cents','nextDue',proposal->'nextDue'));
  end if;
  r=public.uniion_adherents_before_resume(p_org,'list','{}');
 else r=public.uniion_adherents_before_resume(p_org,p_action,p_payload);end if;
 if coalesce((r->>'financial')::boolean,false) then
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('schedule',(select jsonb_build_object('state',s2.state,'revision',s2.revision,'nextDue',uniion_private.dues_occurrence(s2.anchor,s2.months,s2.next_index),'cents',s2.amount_cents,'months',s2.months,'needsReview',a2.joined_on is distinct from s2.anchor or a2.dues_terms->>'cents' is distinct from s2.amount_cents::text or (case a2.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end) is distinct from s2.months) from uniion_private.dues_schedules s2 join uniion_private.adherents a2 on a2.id=s2.adherent_id and a2.organization_id=s2.organization_id where s2.organization_id=p_org and s2.adherent_id=(x->>'id')::uuid))) from jsonb_array_elements(r->'rows') x),'[]'));
 end if;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or unique_violation then raise insufficient_privilege;
end$$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

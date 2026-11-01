begin;
alter table uniion_private.dues_schedules add column member_anchor date,add column occurrence_offset int not null default 0;
update uniion_private.dues_schedules set member_anchor=anchor;
alter table uniion_private.dues_schedules alter column member_anchor set not null;
alter table uniion_private.dues_entries add column coverage_end date;
update uniion_private.dues_entries e set coverage_end=(date_trunc('month',e.period)+make_interval(months=>s.months))::date from uniion_private.dues_schedules s where e.schedule_id=s.id and e.organization_id=s.organization_id;
alter table uniion_private.dues_entries add constraint positive_coverage check(coverage_end is null or coverage_end>period);
create function uniion_private.schedule_overlap(o uuid,m uuid,first_day date,end_day date) returns boolean language sql stable set search_path='' as $$select exists(select 1 from uniion_private.dues_entries where organization_id=o and adherent_id=m and (coverage_end is null or (period<end_day and coverage_end>first_day)))$$;
revoke all on function uniion_private.schedule_overlap(uuid,uuid,date,date) from public,anon,authenticated;
create function uniion_private.entry_coverage() returns trigger language plpgsql set search_path='' as $$
declare months int;
begin
 perform 1 from uniion_private.adherents where organization_id=new.organization_id and id=new.adherent_id for update;
 if new.schedule_id is not null then
  select s.months into months from uniion_private.dues_schedules s where s.id=new.schedule_id and s.organization_id=new.organization_id;
  new.coverage_end=(date_trunc('month',new.period)+make_interval(months=>months))::date;
  if uniion_private.schedule_overlap(new.organization_id,new.adherent_id,new.period,new.coverage_end) then raise insufficient_privilege;end if;
 elsif exists(select 1 from uniion_private.dues_entries where organization_id=new.organization_id and adherent_id=new.adherent_id and (period=new.period or (coverage_end is not null and period<=new.period and coverage_end>new.period))) then raise insufficient_privilege;
 end if;
 return new;
end$$;
revoke all on function uniion_private.entry_coverage() from public,anon,authenticated;
create trigger entry_coverage before insert on uniion_private.dues_entries for each row execute function uniion_private.entry_coverage();
-- Keep the existing worker and initial activation; separate membership date from cadence anchor.
do $$declare d text;begin
 d=pg_get_functiondef('uniion_private.new_dues_schedule()'::regprocedure);
 d=replace(d,'anchor,months,amount_cents,next_index,actor)','anchor,member_anchor,months,amount_cents,next_index,actor)');
 d=replace(d,'new.id,new.joined_on,m,','new.id,new.joined_on,new.joined_on,m,');execute d;
 d=pg_get_functiondef('uniion_private.run_dues_schedules(uuid)'::regprocedure);
 d=replace(d,'a.joined_on is distinct from s.anchor','a.joined_on is distinct from s.member_anchor');
 d=replace(d,'s.id,s.next_index)','s.id,s.occurrence_offset+s.next_index)');
 d=replace(d,$q$exists(select 1 from uniion_private.dues_entries where organization_id=s.organization_id and adherent_id=s.adherent_id and period>=date_trunc('month',d)::date and period<(date_trunc('month',d)+make_interval(months=>s.months))::date)$q$,$q$uniion_private.schedule_overlap(s.organization_id,s.adherent_id,date_trunc('month',d)::date,(date_trunc('month',d)+make_interval(months=>s.months))::date)$q$);execute d;
 d=pg_get_functiondef('uniion_private.schedule_proposal(uniion_private.dues_schedules,uniion_private.adherents)'::regprocedure);
 d=replace(d,'a.joined_on is distinct from s.anchor','a.joined_on is distinct from s.member_anchor');
 d=replace(d,$q$exists(select 1 from uniion_private.dues_entries where organization_id=s.organization_id and adherent_id=s.adherent_id and period>=date_trunc('month',d)::date and period<(date_trunc('month',d)+make_interval(months=>s.months))::date)$q$,$q$uniion_private.schedule_overlap(s.organization_id,s.adherent_id,date_trunc('month',d)::date,(date_trunc('month',d)+make_interval(months=>s.months))::date)$q$);execute d;
end$$;
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_cadence;
revoke all on function public.uniion_adherents_before_cadence(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;s uniion_private.dues_schedules;a uniion_private.adherents;e uniion_private.dues_entries;d date;ending date;m int;unknowns jsonb;conflicts jsonb;old_state jsonb;previous uniion_private.schedule_changes;
begin
 if p_action in ('schedule_resolve_preview','schedule_resolve','schedule_coverage') then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
  select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
  if not found then raise insufficient_privilege;end if;
  select * into a from uniion_private.adherents where organization_id=p_org and id=s.adherent_id for update;
  if p_action='schedule_coverage' then
   if not(p_payload ?& array['id','entry','lastDay']) or p_payload-array['id','entry','lastDay']<>'{}' then raise insufficient_privilege;end if;
   select * into e from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and id=(p_payload->>'entry')::uuid for update;
   ending=uniion_private.adherent_date(p_payload->>'lastDay')+1;
   if not found or ending is null or ending<=e.period or e.schedule_id is not null then raise insufficient_privilege;end if;
   if e.coverage_end is not null then
    if e.coverage_end<>ending then raise insufficient_privilege;end if;
   else
    if exists(select 1 from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and id<>e.id and coverage_end is not null and period<ending and coverage_end>e.period) then raise insufficient_privilege;end if;
    update uniion_private.dues_entries set coverage_end=ending where id=e.id;
    update uniion_private.dues_schedules set state=state where id=s.id;
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.coverage_confirmed',jsonb_build_object('entry',e.id,'from',e.period,'untilExclusive',ending));
   end if;
   r=public.uniion_adherents_before_cadence(p_org,'list','{}');
  else
   if p_payload-array['id','start','revision','memberVersion','request_id']<>'{}' then raise insufficient_privilege;end if;
   if p_action='schedule_resolve' and p_payload->>'request_id' is not null then
    select * into previous from uniion_private.schedule_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
    if found then
     if previous.actor<>auth.uid() or previous.payload<>p_payload then raise insufficient_privilege;end if;
     return public.uniion_adherents(p_org,'list','{}');
    end if;
   end if;
   d=uniion_private.adherent_date(p_payload->>'start');m=case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
   if d is null or d<=(now() at time zone 'Europe/Paris')::date or m is null or coalesce((a.dues_terms->>'cents')::bigint,0)<=0 or a.joined_on is distinct from s.member_anchor or d<a.joined_on then raise insufficient_privilege;end if;
   ending=(date_trunc('month',d)+make_interval(months=>m))::date;
   select coalesce(jsonb_agg(jsonb_build_object('id',id,'period',period,'cents',amount_cents) order by period,id),'[]') into unknowns from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and coverage_end is null;
   -- A future existing charge would collide with a later recurrence: resolve after its coverage.
   select coalesce(jsonb_agg(jsonb_build_object('id',id,'period',period,'lastDay',coverage_end-1) order by period,id),'[]') into conflicts from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and coverage_end>date_trunc('month',d)::date;
   if p_action='schedule_resolve_preview' then
    return jsonb_build_object('preview',jsonb_build_object('revision',s.revision,'memberVersion',a.version,'oldMonths',s.months,'months',m,'oldCents',s.amount_cents,'cents',(a.dues_terms->>'cents')::bigint,'start',d,'periodStart',date_trunc('month',d)::date,'lastDay',ending-1,'unknown',unknowns,'conflicts',conflicts,'canConfirm',unknowns='[]' and conflicts='[]'));
   end if;
   if not(p_payload ?& array['revision','memberVersion','request_id']) or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
   select * into previous from uniion_private.schedule_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
   if found then
    if previous.actor<>auth.uid() or previous.payload<>p_payload then raise insufficient_privilege;end if;
   else
    if unknowns<>'[]' or conflicts<>'[]' or s.revision is distinct from (p_payload->>'revision')::bigint or a.version is distinct from (p_payload->>'memberVersion')::int then raise insufficient_privilege;end if;
    old_state=to_jsonb(s);
    update uniion_private.dues_schedules set anchor=d,months=m,amount_cents=(a.dues_terms->>'cents')::bigint,next_index=0,occurrence_offset=greatest(occurrence_offset+next_index,coalesce((select max(occurrence)+1 from uniion_private.dues_entries where schedule_id=s.id),0)),state='active',actor=auth.uid() where id=s.id returning * into s;
    insert into uniion_private.schedule_changes(organization_id,schedule_id,actor,request_id,payload,before_state,after_state) values(p_org,s.id,auth.uid(),(p_payload->>'request_id')::uuid,p_payload,old_state,to_jsonb(s));
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.schedule_reconfigured',jsonb_build_object('schedule',s.id,'fromMonths',old_state->'months','months',m,'start',d));
   end if;
   r=public.uniion_adherents_before_cadence(p_org,'list','{}');
  end if;
 else r=public.uniion_adherents_before_cadence(p_org,p_action,p_payload);end if;
 if coalesce((r->>'financial')::boolean,false) then
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(case when x->'schedule' is null or x->'schedule'='null' then x else jsonb_set(x,'{schedule,needsReview}',to_jsonb((select a2.joined_on is distinct from s2.member_anchor or a2.dues_terms->>'cents' is distinct from s2.amount_cents::text or (case a2.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end) is distinct from s2.months from uniion_private.dues_schedules s2 join uniion_private.adherents a2 on a2.id=s2.adherent_id where s2.organization_id=p_org and s2.adherent_id=(x->>'id')::uuid))) end) from jsonb_array_elements(r->'rows') x),'[]'));
 end if;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or unique_violation then raise insufficient_privilege;
end$$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

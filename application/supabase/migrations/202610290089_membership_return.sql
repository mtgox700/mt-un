begin;
alter table uniion_private.adherents add column membership_cycle int not null default 0;
alter table uniion_private.adherent_endings add column cycle int not null default 0;
alter table uniion_private.adherent_endings drop constraint adherent_endings_organization_id_adherent_id_key;
alter table uniion_private.adherent_endings add unique(organization_id,adherent_id,cycle);
alter table uniion_private.dues_schedules add column requires_reanchor boolean not null default false;
create table uniion_private.membership_changes(id uuid primary key default gen_random_uuid(),organization_id uuid not null,adherent_id uuid not null,actor uuid not null references auth.users,created_at timestamptz not null default now(),request_id uuid not null,action text not null,payload jsonb not null,before_state jsonb not null,after_state jsonb not null,unique(organization_id,request_id),foreign key(organization_id,adherent_id) references uniion_private.adherents(organization_id,id));
alter table uniion_private.membership_changes enable row level security;
revoke all on uniion_private.membership_changes from public,anon,authenticated;
-- Preserve the immutable ending of every membership cycle.
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_adherents(uuid,text,jsonb)'::regprocedure);
 d=replace(d,'request_id,payload,before_state,after_state) values(p_org,a.id','request_id,payload,before_state,after_state,cycle) values(p_org,a.id');
 d=replace(d,$q$jsonb_build_object('version',a.version,'endedOn',ending));$q$,$q$jsonb_build_object('version',a.version,'endedOn',ending),a.membership_cycle);$q$);execute d;
end$$;
-- New entries cannot be dated before a new membership period, including a future return.
create or replace function uniion_private.entry_membership_end() returns trigger language plpgsql set search_path='' as $$declare a uniion_private.adherents;begin
 select * into a from uniion_private.adherents where organization_id=new.organization_id and id=new.adherent_id for update;
 if (a.ended_on is not null and (new.due_on>=a.ended_on or (now() at time zone 'Europe/Paris')::date>=a.ended_on)) or (a.membership_cycle>0 and (new.due_on<a.joined_on or (now() at time zone 'Europe/Paris')::date<a.joined_on)) then raise insufficient_privilege;end if;return new;
end$$;
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_return;
revoke all on function public.uniion_adherents_before_return(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare a uniion_private.adherents;s uniion_private.dues_schedules;d date;first_due date;m int;today date=(now() at time zone 'Europe/Paris')::date;old_state jsonb;previous uniion_private.membership_changes;r jsonb;issues jsonb;can_manage boolean;
begin
 if p_action in ('membership_return_preview','membership_return','membership_end_correct') then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'adherents','write') or not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
  select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
  select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
  if not found then raise insufficient_privilege;end if;
  if p_action<>'membership_return_preview' then
   if p_payload->>'request_id' is null or jsonb_typeof(p_payload->'reason')<>'string' or coalesce(length(btrim(p_payload->>'reason')),0) not between 5 and 500 then raise insufficient_privilege;end if;
   select * into previous from uniion_private.membership_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
   if found then
    if previous.actor<>auth.uid() or previous.action<>p_action or previous.payload<>p_payload then raise insufficient_privilege;end if;
    return public.uniion_adherents(p_org,'list','{}');
   end if;
  end if;
  d=uniion_private.adherent_date(p_payload->>'date');
  if a.ended_on is null or d is null or a.joined_on is null then raise insufficient_privilege;end if;
  old_state=jsonb_build_object('joinedOn',a.joined_on,'endedOn',a.ended_on,'cycle',a.membership_cycle,'version',a.version,'schedule',to_jsonb(s));
  if p_action='membership_end_correct' then
   if not(p_payload ?& array['id','version','date','reason','request_id']) or p_payload-array['id','version','date','reason','request_id']<>'{}' or a.version is distinct from (p_payload->>'version')::int or d<a.joined_on or d=a.ended_on then raise insufficient_privilege;end if;
   update uniion_private.adherents set ended_on=d,version=version+1,updated_at=now() where id=a.id returning * into a;
   update uniion_private.dues_schedules set state=case when d<=today then 'stopped' else 'paused' end where id=s.id;
  else
   if p_payload-array['id','version','date','mode','firstDue','reason','request_id','scheduleRevision']<>'{}' or coalesce(p_payload->>'mode','') not in ('paused','resume') or d<today or d<a.ended_on or a.ended_on>today then raise insufficient_privilege;end if;
   issues='[]';first_due=null;m=null;
   if p_payload->>'mode'='resume' then
    first_due=uniion_private.adherent_date(p_payload->>'firstDue');m=case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
    if s.id is null or first_due is null or first_due<d or first_due<today or m is null or coalesce((a.dues_terms->>'cents')::bigint,0)<=0 then raise insufficient_privilege;end if;
    select coalesce(jsonb_agg(jsonb_build_object('period',period,'lastDay',coverage_end-1) order by period,id),'[]') into issues from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and (coverage_end is null or coverage_end>date_trunc('month',first_due)::date);
   end if;
   if p_action='membership_return_preview' then return jsonb_build_object('preview',jsonb_build_object('version',a.version,'scheduleRevision',s.revision,'date',d,'mode',p_payload->>'mode','firstDue',first_due,'months',m,'cents',a.dues_terms->'cents','conflicts',issues,'canConfirm',issues='[]'));end if;
   if not(p_payload ?& array['id','version','date','mode','reason','request_id','scheduleRevision']) or a.version is distinct from (p_payload->>'version')::int or s.revision is distinct from (p_payload->>'scheduleRevision')::bigint or issues<>'[]' then raise insufficient_privilege;end if;
   update uniion_private.adherents set ended_on=null,data=jsonb_set(data,'{since}',to_jsonb(d::text)),membership_cycle=membership_cycle+1,version=version+1,updated_at=now() where id=a.id returning * into a;
   if p_payload->>'mode'='resume' then
    update uniion_private.dues_schedules set member_anchor=d,anchor=first_due,months=m,amount_cents=(a.dues_terms->>'cents')::bigint,next_index=0,occurrence_offset=greatest(occurrence_offset+next_index,coalesce((select max(occurrence)+1 from uniion_private.dues_entries where schedule_id=s.id),0)),state='active',actor=auth.uid(),requires_reanchor=false where id=s.id;
   else
    update uniion_private.dues_schedules set member_anchor=d,state='paused',requires_reanchor=true where id=s.id;
   end if;
  end if;
  insert into uniion_private.membership_changes(organization_id,adherent_id,actor,request_id,action,payload,before_state,after_state) values(p_org,a.id,auth.uid(),(p_payload->>'request_id')::uuid,p_action,p_payload,old_state,jsonb_build_object('joinedOn',a.joined_on,'endedOn',a.ended_on,'cycle',a.membership_cycle,'version',a.version,'schedule',(select to_jsonb(ds) from uniion_private.dues_schedules ds where ds.id=s.id)));
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_action='membership_return' then 'adherent.rejoined' else 'adherent.end_corrected' end,jsonb_build_object('id',a.id,'date',d,'mode',p_payload->>'mode','reason',btrim(p_payload->>'reason'),'version',a.version));
  if p_action='membership_return' and p_payload->>'mode'='resume' then perform uniion_private.run_dues_schedules(p_org);end if;
  r=public.uniion_adherents_before_return(p_org,'list','{}');
 else
  if p_action in ('schedule_preview','schedule_resume','schedule_resolve_preview','schedule_resolve') then
   select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
   if s.requires_reanchor and p_action in ('schedule_preview','schedule_resume') then raise insufficient_privilege;end if;
  end if;
  r=public.uniion_adherents_before_return(p_org,p_action,p_payload);
  if p_action='schedule_resolve' and s.requires_reanchor then update uniion_private.dues_schedules set requires_reanchor=false where id=s.id and state='active' and anchor>=member_anchor;r=public.uniion_adherents_before_return(p_org,'list','{}');end if;
 end if;
 if r ? 'rows' then
  can_manage=coalesce((r->>'canEndMembership')::boolean,false);
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('membershipActive',(a2.ended_on is null or a2.ended_on>today) and (a2.membership_cycle=0 or a2.joined_on<=today),'rejoinedOn',case when a2.membership_cycle>0 then a2.joined_on end,'canRejoin',a2.ended_on<=today,'requiresReanchor',coalesce((select requires_reanchor from uniion_private.dues_schedules ds where ds.organization_id=p_org and ds.adherent_id=a2.id),false))||(case when can_manage then jsonb_build_object('membershipHistory',(select coalesce(jsonb_agg(jsonb_build_object('date',h.created_at,'action',h.action,'before',h.before_state-'schedule','after',h.after_state-'schedule','reason',h.payload->>'reason','actor',h.actor) order by h.created_at,h.id),'[]') from uniion_private.membership_changes h where h.organization_id=p_org and h.adherent_id=a2.id)) else '{}' end)) from jsonb_array_elements(r->'rows') x join uniion_private.adherents a2 on a2.organization_id=p_org and a2.id=(x->>'id')::uuid),'[]'));
 end if;return r;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or unique_violation or check_violation then raise insufficient_privilege;
end$$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

begin;
alter table uniion_private.dues_payments add constraint payments_org_id unique(organization_id,id);
create table uniion_private.dues_corrections(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,payment_id uuid not null,
 revision integer not null check(revision>0),amount_cents bigint not null check(amount_cents>=0 and amount_cents<=99999999999),
 reason text not null check(length(trim(reason)) between 3 and 500),actor uuid not null references auth.users,
 recorded_at timestamptz not null default now(),request_id uuid not null,
 unique(organization_id,request_id),unique(payment_id,revision),
 foreign key(organization_id,payment_id) references uniion_private.dues_payments(organization_id,id)
);
alter table uniion_private.dues_corrections enable row level security;
revoke all on uniion_private.dues_corrections from public,anon,authenticated;
create function uniion_private.dues_effective(p_id uuid) returns bigint language sql stable security definer set search_path='' as $$
select coalesce((select amount_cents from uniion_private.dues_corrections where payment_id=p_id order by revision desc limit 1),(select amount_cents from uniion_private.dues_payments where id=p_id))
$$;
revoke all on function uniion_private.dues_effective(uuid) from public,anon,authenticated;
create or replace function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; entry uniion_private.dues_entries; amount bigint; period_date date; due_date date; remaining bigint; previous uniion_private.dues_payments; request_key uuid; target uniion_private.dues_payments; correction uniion_private.dues_corrections; rev integer; reason_text text;
begin
 perform public.uniion_module_use(p_org,'adherents');
 if p_action in ('charge','settle','payment','correct') then
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
  if p_action='correct' then
   if not(p_payload ?& array['id','revision','amount_cents','reason','request_id']) or p_payload-array['id','revision','amount_cents','reason','request_id']<>'{}' or jsonb_typeof(p_payload->'amount_cents') is distinct from 'number' or p_payload->>'amount_cents' !~ '^[0-9]+$' or jsonb_typeof(p_payload->'revision') is distinct from 'number' or p_payload->>'revision' !~ '^[0-9]+$' or jsonb_typeof(p_payload->'reason') is distinct from 'string' or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
   amount=(p_payload->>'amount_cents')::bigint;reason_text=trim(p_payload->>'reason');request_key=(p_payload->>'request_id')::uuid;
   if amount not between 0 and 99999999999 or length(reason_text) not between 3 and 500 then raise insufficient_privilege;end if;
   perform pg_advisory_xact_lock(hashtextextended(p_org::text||request_key::text,0));
   select * into target from uniion_private.dues_payments where id=(p_payload->>'id')::uuid and organization_id=p_org;
   if not found then raise insufficient_privilege;end if;
   select * into entry from uniion_private.dues_entries where id=target.entry_id and organization_id=p_org for update;
   select * into correction from uniion_private.dues_corrections where organization_id=p_org and request_id=request_key;
   if found then
    if correction.payment_id<>target.id or correction.amount_cents<>amount or correction.reason<>reason_text or correction.revision<>(p_payload->>'revision')::int+1 then raise insufficient_privilege;end if;
   else
    select coalesce(max(revision),0) into rev from uniion_private.dues_corrections where payment_id=target.id;
    if rev<>(p_payload->>'revision')::int then raise insufficient_privilege;end if;
    select entry.amount_cents-coalesce(sum(uniion_private.dues_effective(id)),0) into remaining from uniion_private.dues_payments where organization_id=p_org and entry_id=entry.id and id<>target.id;
    if amount>remaining then raise insufficient_privilege;end if;
    insert into uniion_private.dues_corrections(organization_id,payment_id,revision,amount_cents,reason,actor,request_id) values(p_org,target.id,rev+1,amount,reason_text,auth.uid(),request_key);
    update uniion_private.dues_entries set paid_at=case when amount=remaining then coalesce(paid_at,now()) else null end,paid_by=case when amount=remaining then coalesce(paid_by,auth.uid()) else null end where id=entry.id;
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.corrected',jsonb_build_object('payment',target.id,'revision',rev+1,'request',request_key));
   end if;
  elsif p_action='charge' then
   if not(p_payload ?& array['adherent_id','amount_cents','period','due_on','request_id']) or p_payload-array['adherent_id','amount_cents','period','due_on','request_id']<>'{}' then raise insufficient_privilege;end if;
   if jsonb_typeof(p_payload->'amount_cents')<>'number' or p_payload->>'amount_cents' !~ '^[0-9]+$' then raise insufficient_privilege;end if;
   amount=(p_payload->>'amount_cents')::bigint;
   period_date=uniion_private.adherent_date(p_payload->>'period');due_date=uniion_private.adherent_date(p_payload->>'due_on');
   if p_payload->>'request_id' is null then raise insufficient_privilege;end if;
   if amount not between 1 and 99999999999 or period_date is null or due_date is null or not exists(select 1 from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'adherent_id')::uuid) then raise insufficient_privilege;end if;
   perform pg_advisory_xact_lock(hashtextextended(p_org::text||(p_payload->>'request_id'),0));
   select * into entry from uniion_private.dues_entries where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
   if found then
    if entry.adherent_id<>(p_payload->>'adherent_id')::uuid or entry.amount_cents<>amount or entry.period<>period_date or entry.due_on<>due_date then raise insufficient_privilege;end if;
   else
    insert into uniion_private.dues_entries(organization_id,adherent_id,amount_cents,period,due_on,created_by,request_id) values(p_org,(p_payload->>'adherent_id')::uuid,amount,period_date,due_date,auth.uid(),(p_payload->>'request_id')::uuid) returning * into entry;
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.created',jsonb_build_object('id',entry.id));
   end if;
  else
   if p_action='settle' then
    if not(p_payload ?& array['id']) or p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
    request_key=(p_payload->>'id')::uuid;
   else
    if not(p_payload ?& array['id','amount_cents','request_id']) or p_payload-array['id','amount_cents','request_id']<>'{}' or jsonb_typeof(p_payload->'amount_cents') is distinct from 'number' or p_payload->>'amount_cents' !~ '^[0-9]+$' or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
    amount=(p_payload->>'amount_cents')::bigint;request_key=(p_payload->>'request_id')::uuid;
    if amount not between 1 and 99999999999 then raise insufficient_privilege;end if;
   end if;
   perform pg_advisory_xact_lock(hashtextextended(p_org::text||request_key::text,0));
   select * into entry from uniion_private.dues_entries where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
   if not found then raise insufficient_privilege;end if;
   select * into previous from uniion_private.dues_payments where organization_id=p_org and request_id=request_key;
   if found then
    if previous.entry_id<>entry.id or (p_action='payment' and previous.amount_cents<>amount) then raise insufficient_privilege;end if;
   else
    select entry.amount_cents-coalesce(sum(uniion_private.dues_effective(id)),0) into remaining from uniion_private.dues_payments where organization_id=p_org and entry_id=entry.id;
    if p_action='settle' then amount=remaining;end if;
    if amount>remaining or (p_action='payment' and amount<=0) then raise insufficient_privilege;end if;
    if amount>0 then
     insert into uniion_private.dues_payments(organization_id,entry_id,amount_cents,actor,request_id) values(p_org,entry.id,amount,auth.uid(),request_key);
     if amount=remaining then update uniion_private.dues_entries set paid_at=now(),paid_by=auth.uid() where id=entry.id;end if;
     insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_action='settle' then 'dues.settled' else 'dues.payment_recorded' end,jsonb_build_object('id',entry.id,'request',request_key));
    end if;
   end if;
  end if;
  result=uniion_private.adherents_register(p_org,'list','{}');
 else result=uniion_private.adherents_register(p_org,p_action,p_payload);end if;
 if (result->>'financial')::boolean then
  result=jsonb_set(result,'{rows}',coalesce((select jsonb_agg(r||jsonb_build_object('duesLedger',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'cents',e.amount_cents,'period',e.period,'dueOn',e.due_on,'paidAt',e.paid_at,'paidCents',coalesce((select sum(uniion_private.dues_effective(id)) from uniion_private.dues_payments where entry_id=e.id and organization_id=p_org),0),'payments',coalesce((select jsonb_agg(jsonb_build_object('id',id,'cents',uniion_private.dues_effective(id),'originalCents',amount_cents,'revision',coalesce((select max(revision) from uniion_private.dues_corrections where payment_id=dues_payments.id),0),'corrections',coalesce((select jsonb_agg(jsonb_build_object('revision',revision,'cents',amount_cents,'reason',reason,'actor',actor,'recordedAt',recorded_at) order by revision) from uniion_private.dues_corrections where payment_id=dues_payments.id),'[]'::jsonb),'recordedAt',recorded_at) order by recorded_at,id) from uniion_private.dues_payments where entry_id=e.id and organization_id=p_org),'[]'::jsonb)) order by e.due_on,e.id) from uniion_private.dues_entries e where e.organization_id=p_org and e.adherent_id=(r->>'id')::uuid),'[]'::jsonb))) from jsonb_array_elements(result->'rows') r),'[]'::jsonb));
 end if;
 return result;
exception when invalid_text_representation or numeric_value_out_of_range or unique_violation or check_violation then raise insufficient_privilege;
end $$;
notify pgrst,'reload schema';
commit;

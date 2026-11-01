begin;
alter table uniion_private.dues_entries add constraint dues_org_id_unique unique(organization_id,id);
create table uniion_private.dues_payments(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,entry_id uuid not null,
 amount_cents bigint not null check(amount_cents>0),recorded_at timestamptz not null default now(),actor uuid not null references auth.users,
 request_id uuid not null,unique(organization_id,request_id),
 foreign key(organization_id,entry_id) references uniion_private.dues_entries(organization_id,id)
);
alter table uniion_private.dues_payments enable row level security;
revoke all on uniion_private.dues_payments from public,anon,authenticated;
-- Preserve already-declared full payments exactly once, without creating new receipts.
insert into uniion_private.dues_payments(organization_id,entry_id,amount_cents,recorded_at,actor,request_id)
 select organization_id,id,amount_cents,paid_at,paid_by,id from uniion_private.dues_entries where paid_at is not null;
create or replace function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; entry uniion_private.dues_entries; amount bigint; period_date date; due_date date; remaining bigint; previous uniion_private.dues_payments; request_key uuid;
begin
 perform public.uniion_module_use(p_org,'adherents');
 if p_action in ('charge','settle','payment') then
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
  if p_action='charge' then
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
    select entry.amount_cents-coalesce(sum(amount_cents),0) into remaining from uniion_private.dues_payments where organization_id=p_org and entry_id=entry.id;
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
  result=jsonb_set(result,'{rows}',coalesce((select jsonb_agg(r||jsonb_build_object('duesLedger',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'cents',e.amount_cents,'period',e.period,'dueOn',e.due_on,'paidAt',e.paid_at,'paidCents',coalesce((select sum(amount_cents) from uniion_private.dues_payments where entry_id=e.id and organization_id=p_org),0),'payments',coalesce((select jsonb_agg(jsonb_build_object('id',id,'cents',amount_cents,'recordedAt',recorded_at) order by recorded_at,id) from uniion_private.dues_payments where entry_id=e.id and organization_id=p_org),'[]'::jsonb)) order by e.due_on,e.id) from uniion_private.dues_entries e where e.organization_id=p_org and e.adherent_id=(r->>'id')::uuid),'[]'::jsonb))) from jsonb_array_elements(result->'rows') r),'[]'::jsonb));
 end if;
 return result;
exception when invalid_text_representation or numeric_value_out_of_range or unique_violation or check_violation then raise insufficient_privilege;
end $$;
notify pgrst,'reload schema';
commit;

begin;
create table uniion_private.dues_receipts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,payment_id uuid not null,revision integer not null,
 snapshot jsonb not null,created_at timestamptz not null default now(),created_by uuid not null references auth.users,
 unique(payment_id,revision),foreign key(organization_id,payment_id) references uniion_private.dues_payments(organization_id,id)
);
alter table uniion_private.dues_receipts enable row level security;
revoke all on uniion_private.dues_receipts from public,anon,authenticated;
create function uniion_private.dues_export_snapshot(p_org uuid,p_member uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('organization',(select name from public.uniion_organizations where id=p_org),'memberId',a.id,'member',trim((a.data->>'prenom')||' '||(a.data->>'nom')),'payments',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'period',e.period,'dueOn',e.due_on,'chargeCents',e.amount_cents,'originalCents',p.amount_cents,'cents',uniion_private.dues_effective(p.id),'recordedAt',p.recorded_at,'effectiveOn',coalesce((select c.effective_on from uniion_private.dues_corrections c where c.payment_id=p.id and c.effective_on is not null order by revision desc limit 1),p.effective_on),'revision',coalesce((select max(revision) from uniion_private.dues_corrections where payment_id=p.id),0)) order by e.period,p.recorded_at,p.id) from uniion_private.dues_entries e join uniion_private.dues_payments p on p.entry_id=e.id and p.organization_id=e.organization_id where e.organization_id=p_org and e.adherent_id=a.id),'[]')) from uniion_private.adherents a where a.organization_id=p_org and a.id=p_member
$$;
revoke all on function uniion_private.dues_export_snapshot(uuid,uuid) from public,anon,authenticated;
create function public.uniion_dues_export(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare data jsonb;item jsonb;r uniion_private.dues_receipts;pid uuid;mid uuid;rev integer;
begin
 perform public.uniion_module_use(p_org,'adherents');
 if not uniion_private.adherent_permission(p_org,'adherents','read') or not uniion_private.adherent_permission(p_org,'cotisations','read') or not uniion_private.authority(p_org,auth.uid(),'download') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action in ('csv','csv_finish') then
  if not(p_payload ? 'member') or p_payload-array['member','hash']<>'{}' then raise insufficient_privilege;end if;
  data=uniion_private.dues_export_snapshot(p_org,(p_payload->>'member')::uuid);
  if data is null then raise insufficient_privilege;end if;
  if p_action='csv_finish' then
   if p_payload->>'hash' is distinct from md5(data::text) then raise insufficient_privilege;end if;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.csv.exported',jsonb_build_object('member',p_payload->>'member','hash',md5(data::text),'count',jsonb_array_length(data->'payments')));
  end if;
  return jsonb_build_object('data',data,'hash',md5(data::text));
 elsif p_action in ('receipt','receipt_finish') then
  if p_payload-array['payment','receipt']<>'{}' or not(p_payload ? 'payment') then raise insufficient_privilege;end if;
  pid=(p_payload->>'payment')::uuid;
  select e.adherent_id into mid from uniion_private.dues_payments p join uniion_private.dues_entries e on e.id=p.entry_id and e.organization_id=p.organization_id where p.id=pid and p.organization_id=p_org for update of e;
  if not found then raise insufficient_privilege;end if;
  data=uniion_private.dues_export_snapshot(p_org,mid);
  select value into item from jsonb_array_elements(data->'payments') where value->>'id'=pid::text;
  if (item->>'cents')::bigint<=0 or item->>'effectiveOn' is null then raise insufficient_privilege;end if;
  rev=(item->>'revision')::int;
  if p_action='receipt' then
   insert into uniion_private.dues_receipts(organization_id,payment_id,revision,snapshot,created_by) values(p_org,pid,rev,(data-'payments')||jsonb_build_object('payment',item),auth.uid()) on conflict do nothing;
  end if;
  select * into r from uniion_private.dues_receipts where payment_id=pid and organization_id=p_org and revision=rev;
  if not found or (p_action='receipt_finish' and r.id::text is distinct from p_payload->>'receipt') then raise insufficient_privilege;end if;
  if p_action='receipt_finish' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.receipt.exported',jsonb_build_object('receipt',r.id,'payment',pid,'revision',rev));end if;
  return jsonb_build_object('id',r.id,'createdAt',r.created_at,'revision',r.revision,'data',r.snapshot);
 else raise insufficient_privilege;end if;
exception when invalid_text_representation or numeric_value_out_of_range then raise insufficient_privilege;
end $$;
revoke all on function public.uniion_dues_export(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_dues_export(uuid,text,jsonb) to authenticated;
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_exports;
revoke all on function public.uniion_adherents_before_exports(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 r=public.uniion_adherents_before_exports(p_org,p_action,p_payload);
 return r||jsonb_build_object('canExport',coalesce((r->>'financial')::boolean,false) and uniion_private.authority(p_org,auth.uid(),'download'));
end $$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

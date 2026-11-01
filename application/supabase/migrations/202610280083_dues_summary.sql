begin;
-- Aggregate the already-authorized, complete register response in one server call.
create function uniion_private.dues_summary(rows jsonb,as_of date) returns jsonb
language sql immutable set search_path='' as $$
with members as (select value r from jsonb_array_elements(rows)),
entries as (select r->>'id' member,e from members cross join lateral jsonb_array_elements(coalesce(r->'duesLedger','[]')) e),
ledger as (select member,e,(e->>'cents')::bigint amount,(e->>'paidCents')::bigint paid,(e->>'dueOn')::date due from entries),
per_member as (select member,sum(amount-paid) filter(where due<as_of) overdue,min(due) filter(where due<as_of and amount>paid) oldest,
 count(*) filter(where due<=as_of) due_count,coalesce(sum(amount-paid) filter(where due<=as_of),0) remaining from ledger group by member),
payments as (select p from entries cross join lateral jsonb_array_elements(e->'payments') p),
modes as (select coalesce(nullif(btrim(r->>'mode'),''),'Non renseigné') label,count(*) n from members group by 1)
select jsonb_build_object('asOf',as_of,'quarterStart',date_trunc('quarter',as_of)::date,
 'dueCents',coalesce((select sum(amount) from ledger where due<=as_of),0),
 'paidDueCents',coalesce((select sum(paid) from ledger where due<=as_of),0),
 'remainingCents',coalesce((select sum(amount-paid) from ledger where due<=as_of),0),
 'overdueCents',coalesce((select sum(amount-paid) from ledger where due<as_of),0),
 'quarterCents',coalesce((select sum((p->>'cents')::bigint) from payments where (p->>'effectiveOn')::date between date_trunc('quarter',as_of)::date and as_of),0),
 'undatedCents',coalesce((select sum((p->>'cents')::bigint) from payments where p->>'effectiveOn' is null),0),
 'assessedMembers',(select count(*) from per_member where due_count>0),
 'upToDateMembers',(select count(*) from per_member where due_count>0 and remaining=0),
 'modes',coalesce((select jsonb_agg(jsonb_build_object('label',label,'n',n) order by label) from modes),'[]'),
 'arrears',coalesce((select jsonb_agg(jsonb_build_object('id',member,'cents',overdue,'dueOn',oldest) order by oldest,member) from per_member where overdue>0),'[]'));
$$;
revoke all on function uniion_private.dues_summary(jsonb,date) from public,anon,authenticated;
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_summary;
revoke all on function public.uniion_adherents_before_summary(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 r=public.uniion_adherents_before_summary(p_org,p_action,p_payload);
 if coalesce((r->>'financial')::boolean,false) then
  r=r||jsonb_build_object('financialSummary',uniion_private.dues_summary(r->'rows',(now() at time zone 'Europe/Paris')::date));
 end if;
 return r;
end $$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

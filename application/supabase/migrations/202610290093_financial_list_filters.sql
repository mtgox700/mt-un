begin;
create function uniion_private.member_dues_status(o uuid,m uuid) returns text language sql stable set search_path='' as $$
with ledger as (select e.due_on,e.amount_cents-coalesce((select sum(uniion_private.dues_effective(p.id)) from uniion_private.dues_payments p where p.organization_id=o and p.entry_id=e.id),0) remaining from uniion_private.dues_entries e where e.organization_id=o and e.adherent_id=m)
select case when exists(select 1 from ledger where due_on<(now() at time zone 'Europe/Paris')::date and remaining>0) then 'retard'
when exists(select 1 from ledger where due_on<=(now() at time zone 'Europe/Paris')::date) and not exists(select 1 from ledger where due_on<=(now() at time zone 'Europe/Paris')::date and remaining>0) then 'ajour' else 'nouveau' end
$$;
revoke all on function uniion_private.member_dues_status(uuid,uuid) from public,anon,authenticated;
do $$declare d text;begin
 d=pg_get_functiondef('uniion_private.member_criteria(jsonb)'::regprocedure);
 d=replace(d,$q$coalesce(c->>'statut','Tous')<>'Tous'$q$,$q$coalesce(c->>'statut','Tous') not in ('Tous','ajour','retard','nouveau')$q$);execute d;
 d=pg_get_functiondef('public.uniion_adherents(uuid,text,jsonb)'::regprocedure);
 d=replace(d,$q$crit=uniion_private.member_criteria(p_payload->'criteria');$q$,$q$crit=uniion_private.member_criteria(p_payload->'criteria');if coalesce(crit->>'statut','Tous')<>'Tous' and not uniion_private.adherent_permission(p_org,'cotisations','read') then raise insufficient_privilege;end if;$q$);
 d=replace(d,$q$crit=g.criteria;$q$,$q$crit=g.criteria;if coalesce(crit->>'statut','Tous')<>'Tous' and not uniion_private.adherent_permission(p_org,'cotisations','read') then raise insufficient_privilege;end if;$q$);
 d=replace(d,$q$and version=(p_payload->>'version')::int returning * into g;$q$,$q$and version=(p_payload->>'version')::int and (coalesce(criteria->>'statut','Tous')='Tous' or uniion_private.adherent_permission(p_org,'cotisations','read')) returning * into g;$q$);
 d=replace(d,$q$and uniion_private.member_matches(data,crit);$q$,$q$and uniion_private.member_matches(data,crit) and (coalesce(crit->>'statut','Tous')='Tous' or uniion_private.member_dues_status(p_org,id)=crit->>'statut');$q$);
 d=replace(d,$q$from uniion_private.member_lists where organization_id=p_org),'[]'))$q$,$q$from uniion_private.member_lists where organization_id=p_org and (coalesce(criteria->>'statut','Tous')='Tous' or uniion_private.adherent_permission(p_org,'cotisations','read'))),'[]'))$q$);
 d=replace(d,$q$if r ? 'rows' then$q$,$q$if r ? 'rows' then
  if coalesce((r->>'financial')::boolean,false) then r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('statut',uniion_private.member_dues_status(p_org,(x->>'id')::uuid))) from jsonb_array_elements(r->'rows') x),'[]'));end if;$q$);
 execute d;
end$$;
notify pgrst,'reload schema';
commit;

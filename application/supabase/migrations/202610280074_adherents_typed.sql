begin;
-- Preserve source text; derive precise values without guessing missing dates or cadence.
create function uniion_private.adherent_date(p_text text) returns date
language plpgsql immutable set search_path='' as $$
declare t text=trim(coalesce(p_text,'')); d date; parts text[];
begin
 if t ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' then
  parts=string_to_array(t,'/'); d=make_date(parts[3]::int,parts[2]::int,parts[1]::int);
 elsif t ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
  parts=string_to_array(t,'-'); d=make_date(parts[1]::int,parts[2]::int,parts[3]::int);
 else return null;end if;
 return d;
exception when datetime_field_overflow then return null;
end $$;
create function uniion_private.adherent_dues(p_text text) returns jsonb
language plpgsql immutable set search_path='' as $$
declare t text=lower(trim(coalesce(p_text,''))); m text[];
begin
 if t='' then return jsonb_build_object('status','empty');end if;
 m=regexp_match(t,'^([0-9]{1,9})([.,]([0-9]{1,2}))?[[:space:]]*(€|eur)([[:space:]]*/[[:space:]]*(mois|trimestre|an))?$');
 if m is null then return jsonb_build_object('status','review');end if;
 return jsonb_build_object('status','valid','cents',m[1]::bigint*100+coalesce(rpad(m[3],2,'0'),'0')::int,'currency','EUR','period',case m[6] when 'mois' then 'month' when 'trimestre' then 'quarter' when 'an' then 'year' else null end);
end $$;
revoke all on function uniion_private.adherent_date(text),uniion_private.adherent_dues(text) from public,anon,authenticated;
alter table uniion_private.adherents
 add column joined_on date generated always as (uniion_private.adherent_date(data->>'since')) stored,
 add column dues_terms jsonb generated always as (uniion_private.adherent_dues(data->>'montant')) stored;
-- Old ambiguous texts remain available for review. Reject only new/changed invalid values.
create function uniion_private.adherent_validate_typed() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' or new.data->>'since' is distinct from old.data->>'since' then
  if coalesce(new.data->>'since','')<>'' and uniion_private.adherent_date(new.data->>'since') is null then raise insufficient_privilege;end if;
 end if;
 if tg_op='INSERT' or new.data->>'montant' is distinct from old.data->>'montant' then
  if uniion_private.adherent_dues(new.data->>'montant')->>'status'='review' then raise insufficient_privilege;end if;
 end if;
 return new;
end $$;
revoke all on function uniion_private.adherent_validate_typed() from public,anon,authenticated;
create trigger adherent_typed before insert or update on uniion_private.adherents for each row execute function uniion_private.adherent_validate_typed();
-- A dormant/expired permission namespace cannot reveal financial content.
create or replace function uniion_private.adherent_permission(p_org uuid,p_module text,p_permission text) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission=p_permission)
 and exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized and enabled and valid_until>now())
 and (p_module<>'cotisations' or p_permission='read' or exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission='read'))
$$;
create or replace function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare old uniion_private.adherents; d jsonb; rowdata jsonb; count_added integer=0; financial boolean; ids jsonb='[]';
begin
perform public.uniion_module_use(p_org,'adherents');
financial=uniion_private.adherent_permission(p_org,'cotisations','read');
if p_action='import' then
 if not uniion_private.adherent_permission(p_org,'adherents','create') or jsonb_typeof(p_payload) is distinct from 'array' or jsonb_array_length(p_payload) not between 1 and 100 then raise insufficient_privilege;end if;
 for rowdata in select value from jsonb_array_elements(p_payload) loop
  d=uniion_private.adherent_payload(rowdata);
  if (d->>'mode'<>'' or d->>'montant'<>'') and not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
  insert into uniion_private.adherents(organization_id,data) values(p_org,d) returning * into old;
  ids=ids||jsonb_build_array(old.id);count_added=count_added+1;
 end loop;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherents.imported',jsonb_build_object('count',count_added,'ids',ids));
elsif p_action='save' then
 if not uniion_private.adherent_permission(p_org,'adherents','write') or jsonb_typeof(p_payload) is distinct from 'object' or p_payload-array['id','version','data']<>'{}' or not(p_payload ?& array['id','version','data']) then raise insufficient_privilege;end if;
 select * into old from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
 if not found or old.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
 d=uniion_private.adherent_payload(p_payload->'data');
 if not uniion_private.adherent_permission(p_org,'cotisations','write') then
  if (p_payload->'data') ? 'mode' or (p_payload->'data') ? 'montant' then raise insufficient_privilege;end if;
  d=d||jsonb_build_object('mode',old.data->>'mode','montant',old.data->>'montant');
 end if;
 update uniion_private.adherents set data=d,version=version+1,updated_at=now() where id=old.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherent.saved',jsonb_build_object('id',old.id,'version',old.version+1));
elsif p_action<>'list' or p_payload<>'{}'::jsonb then raise insufficient_privilege;end if;
return jsonb_build_object('rows',coalesce((select jsonb_agg((case when financial then data else data-array['mode','montant'] end)||jsonb_build_object('id',id,'version',version,'joinedOn',joined_on,'dateNeedsReview',coalesce(data->>'since','')<>'' and joined_on is null)||(case when financial then jsonb_build_object('dues',dues_terms) else '{}'::jsonb end) order by data->>'nom',data->>'prenom',id) from uniion_private.adherents where organization_id=p_org),'[]'::jsonb),'financial',financial,'financialWrite',financial and uniion_private.adherent_permission(p_org,'cotisations','write'));
exception when unique_violation then raise insufficient_privilege;
end $$;
notify pgrst,'reload schema';
commit;

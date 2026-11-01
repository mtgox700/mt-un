begin;
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
return jsonb_build_object('rows',coalesce((select jsonb_agg((case when financial then data else data-array['mode','montant'] end)||jsonb_build_object('id',id,'version',version) order by data->>'nom',data->>'prenom',id) from uniion_private.adherents where organization_id=p_org),'[]'::jsonb),'financial',financial,'financialWrite',financial and uniion_private.adherent_permission(p_org,'cotisations','write'));
exception when unique_violation then raise insufficient_privilege;
end $$;
notify pgrst,'reload schema';
commit;

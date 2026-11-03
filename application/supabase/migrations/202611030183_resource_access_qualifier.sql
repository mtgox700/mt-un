begin;
-- Correctif : la migration 0155 qualifiait le paramètre par le nom de la fonction
-- (resource_access.resource). Le renommage de 0173 en resource_access_before_minutes a rendu
-- cette qualification invalide : chaque appel échouait (« missing FROM-clause entry for table
-- resource_access »), donc toute lecture RLS de uniion_resources et uniion_resource_versions
-- hors procès-verbaux. Redéfinition complète, même signature et mêmes attributs : l'OID, les
-- privilèges et les politiques qui l'appellent sont conservés.
create or replace function uniion_private.resource_access_before_minutes(org uuid,resource uuid,write_access boolean) returns boolean language sql security definer set search_path='' as $$
 select uniion_private.resource_access_before_ai_case(org,resource,write_access)
 and (not exists(select 1 from uniion_private.ai_case_derivatives d where d.resource=resource_access_before_minutes.resource)
      or uniion_private.actor_resource(org,resource,auth.uid(),write_access))
$$;
revoke all on function uniion_private.resource_access_before_minutes(uuid,uuid,boolean) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;

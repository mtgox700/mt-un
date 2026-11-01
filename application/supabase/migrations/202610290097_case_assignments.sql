begin;
do $$declare definition text;begin
 select pg_get_constraintdef(oid) into definition from pg_constraint where conrelid='public.uniion_authorities'::regclass and conname='uniion_authorities_permission_check';
 alter table public.uniion_authorities drop constraint uniion_authorities_permission_check;
 execute 'alter table public.uniion_authorities add constraint uniion_authorities_permission_check '||replace(definition,'CHECK (','CHECK (permission = ''dossiers_assign'' OR ');
end$$;
create function uniion_private.case_assignment_context(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$
select jsonb_build_object('ownerId',c.owner,'canAssign',uniion_private.authority(o,auth.uid(),'dossiers_assign') and uniion_private.actor_resource(o,rid,auth.uid(),true),
 'assignees',coalesce((select jsonb_agg(jsonb_build_object('id',g.user_id,'name',coalesce(nullif(p.name,''),'Membre habilité'),'role',coalesce(p.role_label,'')) order by p.name,g.user_id)
 from public.uniion_resource_grants g left join uniion_private.identity_profiles p on p.organization_id=g.organization_id and p.user_id=g.user_id
 where g.organization_id=o and g.resource_id=rid and uniion_private.actor_resource(o,rid,g.user_id,false) and uniion_private.actor_resource(o,rid,g.user_id,true)
 and (g.user_id=c.owner or (uniion_private.authority(o,auth.uid(),'dossiers_assign') and uniion_private.actor_resource(o,rid,auth.uid(),true) and g.user_id<>auth.uid()))),'[]'))
 from uniion_private.cases c where c.organization_id=o and c.id=rid
$$;
revoke all on function uniion_private.case_assignment_context(uuid,uuid) from public,anon,authenticated;
do $$declare definition text;begin
 definition=pg_get_functiondef('uniion_private.case_json(uuid,uuid)'::regprocedure);
 definition=replace(definition,'''canWrite'',uniion_private.actor_resource(o,rid,auth.uid(),true)', '''canWrite'',uniion_private.actor_resource(o,rid,auth.uid(),true)');
 -- Enrich the existing projection without duplicating its history query.
 alter function uniion_private.case_json(uuid,uuid) rename to case_json_base;
end$$;
create function uniion_private.case_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$select uniion_private.case_json_base(o,rid)||uniion_private.case_assignment_context(o,rid)$$;
revoke all on function uniion_private.case_json(uuid,uuid) from public,anon,authenticated;
create function public.uniion_case_assign(p_org uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare rid uuid;target uuid;prior uuid;ver integer;target_name text;
begin
 perform public.uniion_module_use(p_org,'dossiers');
 if jsonb_typeof(p_payload) is distinct from 'object' or p_payload-ARRAY['id','version','user']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'dossiers_assign') then raise insufficient_privilege;end if;
 rid=(p_payload->>'id')::uuid;target=(p_payload->>'user')::uuid;
 select version into ver from public.uniion_resources where organization_id=p_org and id=rid and module='dossiers' for update;
 if not found or ver is distinct from (p_payload->>'version')::integer or target=auth.uid() or not uniion_private.actor_resource(p_org,rid,auth.uid(),true) then raise insufficient_privilege;end if;
 select owner into prior from uniion_private.cases where organization_id=p_org and id=rid for update;
 if not found or target is null or target=prior then raise insufficient_privilege;end if;
 -- Serialize grant changes and recheck both read/write; assignment never creates a grant.
 perform 1 from public.uniion_resource_grants where organization_id=p_org and resource_id=rid and user_id in (prior,target,auth.uid()) order by user_id for update;
 if not uniion_private.actor_resource(p_org,rid,target,false) or not uniion_private.actor_resource(p_org,rid,target,true) or not uniion_private.actor_resource(p_org,rid,auth.uid(),true) then raise insufficient_privilege;end if;
 update uniion_private.cases set owner=target where organization_id=p_org and id=rid;
 update public.uniion_resource_grants set revoked_at=now() where organization_id=p_org and resource_id=rid and user_id=prior;
 update public.uniion_resources set version=version+1 where organization_id=p_org and id=rid;
 select name into target_name from uniion_private.identity_profiles where organization_id=p_org and user_id=target;
 insert into uniion_private.case_history(organization_id,resource_id,actor,title,body) values(p_org,rid,auth.uid(),'Référent modifié',coalesce(target_name,'Membre habilité')||' devient référent. Accès direct de l’ancien référent retiré.');
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.assigned',jsonb_build_object('resource',rid,'previous',prior,'target',target,'version',ver+1));
 -- Do not return the protected document to the outgoing assignee.
 return jsonb_build_object('ok',true,'accessRetained',uniion_private.actor_resource(p_org,rid,auth.uid(),false));
end$$;
revoke all on function public.uniion_case_assign(uuid,jsonb) from public,anon;
grant execute on function public.uniion_case_assign(uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

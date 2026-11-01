begin;
create or replace function public.uniion_ai_native(p_org uuid,p_kind text,p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare context jsonb;item record;agenda jsonb;name text;dependencies jsonb='[]';
begin
 if p_kind<>'workspace' then return public.uniion_ai_native_before_workspace(p_org,p_kind,p_id);end if;
 perform public.uniion_module_use(p_org,'assistant');if p_id<>p_org then raise insufficient_privilege;end if;
 select o.name into name from public.uniion_organizations o where o.id=p_org and o.active;
 context=jsonb_build_object('description','Espace uniion : droits de modules et de ressources distincts. Extrait limité aux dossiers sans source classée et aux réunions autorisés, ainsi qu’aux événements visibles. Une absence n’atteste pas l’absence de travail.','dateDeLecture',current_date,'dossiersEtReunions','[]'::jsonb,'agenda','[]'::jsonb);
 -- Exclude conversation derivatives before traversing their ACLs: no dependency cycle.
 for item in select r.* from public.uniion_resources r where r.organization_id=p_org and r.module in ('dossiers','reunions') and not exists(select 1 from uniion_private.ai_case_derivatives d where d.resource=r.id) and not exists(select 1 from uniion_private.case_links l where l.resource_id=r.id) order by r.created_at desc limit 40 loop
  if uniion_private.actor_resource(p_org,item.id,auth.uid(),false) then
   dependencies=dependencies||jsonb_build_array(jsonb_build_object('kind',case item.module when 'dossiers' then 'case' else item.module end,'id',item.id));
   context=jsonb_set(context,'{dossiersEtReunions}',(context->'dossiersEtReunions')||jsonb_build_array(jsonb_build_object('id',item.id,'module',item.module,'titre',item.title,'version',item.version,'date',item.body->>'date','description',left(coalesce(item.body->>'text',''),500),'echeance',(select due from uniion_private.cases where id=item.id),'statut',(select status from uniion_private.cases where id=item.id))));
  end if;
 end loop;
 begin
  select coalesce(jsonb_agg(jsonb_build_object('id',e->>'id','titre',e->>'title','date',e->>'date','debut',e->>'start','fin',e->>'end','lieu',e->>'lieu')),'[]') into agenda from (select value e from jsonb_array_elements(public.uniion_agenda_list(p_org)) limit 20) events;
  context=jsonb_set(context,'{agenda}',agenda);
  dependencies=dependencies||coalesce((select jsonb_agg(jsonb_build_object('kind','agenda','id',e->>'id')) from jsonb_array_elements(agenda)e),'[]');
 exception when insufficient_privilege then null;end;
 return jsonb_build_object('title',name,'version',1,'description',context::text,'dependencies',dependencies);
end$$;
do $$declare d text;begin d=pg_get_functiondef('uniion_private.ai_refs_readable(uuid,jsonb)'::regprocedure);execute replace(d,'not between 1 and 8','not between 1 and 64');end$$;
notify pgrst,'reload schema';commit;

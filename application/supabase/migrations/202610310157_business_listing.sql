begin;
create or replace function public.uniion_business_records_base150(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources;rid uuid;d jsonb;
begin
 if p_module is null or p_module not in ('reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 perform public.uniion_module_use(p_org,p_module);
 if p_action='list' and p_payload='{}' then
  return jsonb_build_object('rows',coalesce((select jsonb_agg(recordrow.body||jsonb_build_object('id',recordrow.id,'version',recordrow.version,'module',recordrow.module,'status','Brouillon','serverRecord',true,'canWrite',uniion_private.actor_resource(p_org,recordrow.id,auth.uid(),true)) order by stored.updated_at desc) from public.uniion_resources recordrow join uniion_private.business_records stored on stored.organization_id=recordrow.organization_id and stored.id=recordrow.id where recordrow.organization_id=p_org and recordrow.module=p_module and uniion_private.actor_resource(p_org,recordrow.id,auth.uid(),false)),'[]'));
 end if;
 if p_action='create' then
  if p_payload-array['data']<>'{}' or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission='create') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission='write') then raise insufficient_privilege;end if;
  d=uniion_private.business_payload(p_module,p_payload->'data');
  insert into public.uniion_resources(organization_id,module,title,body) values(p_org,p_module,d->>'title',d) returning * into r;
  insert into uniion_private.business_records(organization_id,id,creator) values(p_org,r.id,auth.uid());
  insert into public.uniion_resource_grants values(p_org,r.id,auth.uid(),true,false,'infinity',null);
 else
  select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module=p_module for update;
  if not found or not exists(select 1 from uniion_private.business_records where organization_id=p_org and id=r.id) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),p_action<>'get') then raise insufficient_privilege;end if;
  if p_action='get' and p_payload-array['id']='{}' then
   return r.body||jsonb_build_object('id',r.id,'version',r.version,'module',r.module,'status','Brouillon','serverRecord',true,'canWrite',uniion_private.actor_resource(p_org,r.id,auth.uid(),true));
  end if;
  if p_action<>'save' or p_payload-array['id','version','data']<>'{}' or r.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
  d=uniion_private.business_payload(p_module,p_payload->'data');
  update public.uniion_resources set title=d->>'title',body=d,version=version+1 where id=r.id returning * into r;
  update uniion_private.business_records set updated_at=now() where id=r.id;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.'||p_action,jsonb_build_object('module',p_module,'id',r.id,'version',r.version));
 return r.body||jsonb_build_object('id',r.id,'version',r.version,'module',r.module,'status','Brouillon','serverRecord',true,'canWrite',true);
end$$;
notify pgrst,'reload schema';commit;

begin;
-- Revocation remains available for an approved older version after draft edits.
create or replace function public.uniion_business_publication(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources;p uniion_private.business_publications;targets uuid[];em text;uid uuid;
begin
 perform public.uniion_module_use(p_org,p_module);
 if p_module not in ('mobile','communication','intranet','reunions') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='feed' and p_payload='{}' then
  -- Approved version has its own audience. No source ids, actors or private citations metadata.
  return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('id',id,'version',version,'body',body,'source',case when uniion_private.actor_resource(p_org,resource_id,auth.uid(),false) then resource_id else null end,'published',published_at,'download',false) order by published_at desc) from uniion_private.business_publications where organization_id=p_org and module=p_module and published_at is not null and revoked_at is null and auth.uid()=any(recipients)),'[]'));
 end if;
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module=p_module for update;
 if not found or not exists(select 1 from uniion_private.business_records where id=r.id and organization_id=p_org) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),false) or (p_action not in ('revoke','status') and r.version is distinct from (p_payload->>'version')::int) then raise insufficient_privilege;end if;
 select * into p from uniion_private.business_publications where organization_id=p_org and resource_id=r.id and version=(p_payload->>'version')::int for update;
 if p_action='status' and p.id is null and r.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
 if p_action='review' then
  if p_payload-array['id','version','recipients']<>'{}' or jsonb_typeof(p_payload->'recipients')<>'array' or jsonb_array_length(p_payload->'recipients') not between 1 and 50 or not uniion_private.authority(p_org,auth.uid(),'content_review') or exists(select 1 from public.uniion_resource_versions where organization_id=p_org and resource_id=r.id and version<=r.version and (actor=auth.uid() or actor is null)) then raise insufficient_privilege;end if;
  targets=array[]::uuid[];
  for em in select jsonb_array_elements_text(p_payload->'recipients') loop
   select u.id into uid from auth.users u where lower(u.email)=lower(trim(em)) and uniion_private.actor_member(p_org,u.id);
   if uid is null then raise insufficient_privilege;end if;
   if not uid=any(targets) then targets=array_append(targets,uid);end if;
  end loop;
  if p.published_at is not null then raise insufficient_privilege;end if;
  insert into uniion_private.business_publications(organization_id,resource_id,version,module,body,recipients,reviewer) values(p_org,r.id,r.version,p_module,r.body,targets,auth.uid()) on conflict(organization_id,resource_id,version) do update set body=excluded.body,recipients=excluded.recipients,reviewer=excluded.reviewer,reviewed_at=now(),revoked_at=null;
 elsif p_action='publish' then
  if p_payload-array['id','version']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'content_publish') or p.reviewer is null or p.revoked_at is not null or not uniion_private.actor_resource(p_org,r.id,p.reviewer,false) or not uniion_private.authority(p_org,p.reviewer,'content_review') then raise insufficient_privilege;end if;
  update uniion_private.business_publications set publisher=auth.uid(),published_at=now() where id=p.id and published_at is null;
 elsif p_action='revoke' then
  if p.id is null or p_payload-array['id','version']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'content_publish') then raise insufficient_privilege;end if;
  update uniion_private.business_publications set revoked_at=now() where id=p.id;
 elsif p_action<>'status' or p_payload-array['id','version']<>'{}' then raise insufficient_privilege;end if;
 if p_action<>'status' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.'||p_action,jsonb_build_object('id',r.id,'version',(p_payload->>'version')::int));end if;
 select * into p from uniion_private.business_publications where organization_id=p_org and resource_id=r.id and version=(p_payload->>'version')::int;
 return jsonb_build_object('id',r.id,'version',(p_payload->>'version')::int,'currentVersion',r.version,'reviewed',p.reviewer is not null and p.revoked_at is null,'published',p.published_at is not null and p.revoked_at is null,'audienceCount',coalesce(cardinality(p.recipients),0),'download',false);
end$$;
notify pgrst,'reload schema';commit;

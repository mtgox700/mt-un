begin;
-- Withdrawal may block reading a draft, but must never prevent revoking its published copy.
create or replace function public.uniion_business_publication(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;d uniion_private.meeting_minutes;r public.uniion_resources;p uniion_private.business_publications;
begin
 select * into d from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(p_payload->>'id')::uuid;
 if found and p_action='revoke' then
  perform public.uniion_module_use(p_org,'reunions');
  if p_module is distinct from 'reunions' or p_payload-array['id','version']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'content_publish') or not uniion_private.actor_resource_before_minutes(p_org,d.meeting_id,auth.uid(),false) then raise insufficient_privilege;end if;
  update uniion_private.business_publications set revoked_at=coalesce(revoked_at,now()) where organization_id=p_org and resource_id=d.resource_id and version=(p_payload->>'version')::int returning * into p;
  if not found then raise insufficient_privilege;end if;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.revoke',jsonb_build_object('id',d.resource_id,'version',p.version));
  return jsonb_build_object('id',d.resource_id,'version',p.version,'reviewed',false,'published',false,'download',false);
 end if;
 if d.resource_id is not null and p_action in ('review','publish') then
  select * into r from public.uniion_resources where organization_id=p_org and id=d.resource_id;
  if jsonb_typeof(r.body->'minutes') is distinct from 'string' or length(btrim(r.body->>'minutes'))<1 then raise insufficient_privilege;end if;
 end if;
 result=public.uniion_business_publication_before_minutes(p_org,p_module,p_action,p_payload);
 if d.resource_id is not null and p_action='review' then
  update uniion_private.business_publications set body=jsonb_build_object('title',r.title,'minutes',r.body->>'minutes') where organization_id=p_org and resource_id=r.id and version=r.version and published_at is null;
 end if;
 return result;
end$$;
notify pgrst,'reload schema';commit;

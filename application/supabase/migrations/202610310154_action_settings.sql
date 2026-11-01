begin;
create or replace function public.uniion_ai_action_policy(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d uniion_private.ai_action_definitions;c uniion_private.ai_action_settings;roles jsonb;enabled boolean;v int;member_id uuid;manage boolean;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 manage=uniion_private.authority(p_org,auth.uid(),'organization_edit');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='list' and p_payload='{}' then
  return jsonb_build_object('manage',manage,'roles',coalesce((select jsonb_agg(role) from uniion_private.ai_business_roles where organization_id=p_org and user_id=auth.uid()),'[]'),'settings',coalesce((select jsonb_agg(jsonb_build_object('id',definition.id,'enabled',coalesce(setting.enabled,true),'roles',coalesce(setting.roles,definition.roles),'version',coalesce(setting.version,0))) from uniion_private.ai_action_definitions definition left join uniion_private.ai_action_settings setting on setting.organization_id=p_org and setting.action=definition.id),'[]'));
 end if;
 if p_action='assign_role' then
  if p_payload-array['user','email','role','enabled']<>'{}' or not(p_payload ?& array['role','enabled']) or ((p_payload ? 'user')=(p_payload ? 'email')) or jsonb_typeof(p_payload->'enabled')<>'boolean' or not uniion_private.authority(p_org,auth.uid(),'rights') then raise insufficient_privilege;end if;
  if p_payload ? 'email' then select id into member_id from auth.users where lower(email)=lower(trim(p_payload->>'email'));else member_id=(p_payload->>'user')::uuid;end if;
  if member_id is null or member_id=auth.uid() or not uniion_private.actor_member(p_org,member_id) or p_payload->>'role' not in ('secretaire','tresorier','titulaire','suppleant','ds','ssct') then raise insufficient_privilege;end if;
  if (p_payload->>'enabled')::boolean then insert into uniion_private.ai_business_roles values(p_org,member_id,p_payload->>'role') on conflict do nothing;
  else delete from uniion_private.ai_business_roles where organization_id=p_org and user_id=member_id and role=p_payload->>'role';end if;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'ai.role_assigned',p_payload);return '{"updated":true}';
 end if;
 select * into d from uniion_private.ai_action_definitions where id=p_payload->>'id';if not found then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||d.id,0));
 select * into c from uniion_private.ai_action_settings where organization_id=p_org and action=d.id;
 roles=coalesce(c.roles,d.roles);enabled=coalesce(c.enabled,true);v=coalesce(c.version,0);
 if p_action='configure' then
  if not manage or p_payload-array['id','version','enabled','roles']<>'{}' or not(p_payload ?& array['id','version','enabled','roles']) or jsonb_typeof(p_payload->'enabled')<>'boolean' or jsonb_typeof(p_payload->'roles')<>'array' or jsonb_array_length(p_payload->'roles')>6 or v is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_array_elements_text(p_payload->'roles') x where x not in ('secretaire','tresorier','titulaire','suppleant','ds','ssct')) then raise insufficient_privilege;end if;
  insert into uniion_private.ai_action_settings values(p_org,d.id,(p_payload->>'enabled')::boolean,p_payload->'roles',v+1) on conflict(organization_id,action) do update set enabled=excluded.enabled,roles=excluded.roles,version=excluded.version;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'ai.action_configured',p_payload);return jsonb_build_object('updated',true,'version',v+1);
 end if;
 if p_action<>'authorize' or p_payload-array['id']<>'{}' or not enabled then raise insufficient_privilege;end if;
 perform public.uniion_module_use(p_org,d.module);
 if roles<>'[]' and not exists(select 1 from uniion_private.ai_business_roles where organization_id=p_org and user_id=auth.uid() and roles ? role) then raise insufficient_privilege;end if;
 return jsonb_build_object('allowed',true,'version',v,'roles',roles);
end$$;
notify pgrst,'reload schema';commit;

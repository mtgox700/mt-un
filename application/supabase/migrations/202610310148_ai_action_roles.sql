begin;
create table uniion_private.ai_action_definitions(id text primary key,module text not null,roles jsonb not null);
insert into uniion_private.ai_action_definitions values
('acc-week','assistant','[]'::jsonb),
('acc-first','assistant','[]'::jsonb),
('dos-next','dossiers','[]'::jsonb),
('dos-sum','dossiers','[]'::jsonb),
('dos-delais','dossiers','[]'::jsonb),
('dos-mail','dossiers','["titulaire", "ds", "secretaire"]'::jsonb),
('dos-prio','dossiers','[]'::jsonb),
('reu-prep','reunions','[]'::jsonb),
('reu-dec','reunions','[]'::jsonb),
('reu-salaries','reunions','[]'::jsonb),
('reu-pv','reunions','["secretaire"]'::jsonb),
('doc-relire','documents','[]'::jsonb),
('doc-simpl','documents','[]'::jsonb),
('doc-risk','documents','["titulaire", "ds", "secretaire"]'::jsonb),
('doc-idea','documents','[]'::jsonb),
('msg-sum','messagerie','[]'::jsonb),
('msg-reply','messagerie','[]'::jsonb),
('ag-prep','agenda','[]'::jsonb),
('ag-delais','agenda','["secretaire"]'::jsonb),
('com-month','communication','[]'::jsonb),
('com-reform','communication','[]'::jsonb),
('mob-page','mobile','[]'::jsonb),
('mob-short','mobile','[]'::jsonb),
('mob-push','mobile','[]'::jsonb),
('mob-check','mobile','[]'::jsonb),
('mob-ideas','mobile','[]'::jsonb),
('fm-reco','formations','[]'::jsonb),
('adh-msg','adherents','[]'::jsonb),
('adh-relance','adherents','["tresorier"]'::jsonb),
('pol-q','sondages','[]'::jsonb),
('pol-ana','sondages','[]'::jsonb),
('web-lis','intranet','[]'::jsonb),
('rep-explain','reporting','[]'::jsonb),
('rep-bilan','reporting','["secretaire", "tresorier"]'::jsonb),
('rac-sugg','raccourcis','[]'::jsonb),
('par-help','assistant','[]'::jsonb),
('par-roles','assistant','["secretaire", "ds"]'::jsonb);
create table uniion_private.ai_action_settings(organization_id uuid not null references public.uniion_organizations,action text not null references uniion_private.ai_action_definitions,enabled boolean not null,roles jsonb not null,version int not null,primary key(organization_id,action));
create table uniion_private.ai_business_roles(organization_id uuid not null,user_id uuid not null,role text not null check(role in ('secretaire','tresorier','titulaire','suppleant','ds','ssct')),primary key(organization_id,user_id,role),foreign key(organization_id,user_id) references public.uniion_memberships);
alter table uniion_private.ai_action_definitions enable row level security;
alter table uniion_private.ai_action_settings enable row level security;
alter table uniion_private.ai_business_roles enable row level security;
revoke all on uniion_private.ai_action_definitions,uniion_private.ai_action_settings,uniion_private.ai_business_roles from public,anon,authenticated;
create function public.uniion_ai_action_policy(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d uniion_private.ai_action_definitions;c uniion_private.ai_action_settings;roles jsonb;enabled boolean;v int;member_id uuid;manage boolean;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 manage=uniion_private.authority(p_org,auth.uid(),'organization_edit');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='list' and p_payload='{}' then
  return jsonb_build_object('manage',manage,'roles',coalesce((select jsonb_agg(role) from uniion_private.ai_business_roles where organization_id=p_org and user_id=auth.uid()),'[]'),'settings',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'enabled',coalesce(c.enabled,true),'roles',coalesce(c.roles,d.roles),'version',coalesce(c.version,0))) from uniion_private.ai_action_definitions d left join uniion_private.ai_action_settings c on c.organization_id=p_org and c.action=d.id),'[]'));
 end if;
 if p_action='assign_role' then
  if p_payload-array['user','role','enabled']<>'{}' or not(p_payload ?& array['user','role','enabled']) or jsonb_typeof(p_payload->'enabled')<>'boolean' or not uniion_private.authority(p_org,auth.uid(),'rights') then raise insufficient_privilege;end if;
  member_id=(p_payload->>'user')::uuid;
  if member_id=auth.uid() or not uniion_private.actor_member(p_org,member_id) or p_payload->>'role' not in ('secretaire','tresorier','titulaire','suppleant','ds','ssct') then raise insufficient_privilege;end if;
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
revoke all on function public.uniion_ai_action_policy(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_ai_action_policy(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

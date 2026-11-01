begin;
create or replace function public.uniion_save(p_org uuid,p_changes jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c jsonb; r public.uniion_resources; mod text; new_id uuid; result jsonb='[]'::jsonb;
begin
 if not uniion_private.member(p_org) then raise insufficient_privilege; end if;
 if jsonb_typeof(p_changes)<>'array' or jsonb_array_length(p_changes)>100 then raise check_violation; end if;
 for c in select value from jsonb_array_elements(p_changes) loop
  mod=case c->>'kind' when 'dossiers' then 'socle' when 'docs' then 'socle' when 'pollsData' then 'sondages' when 'reunions' then 'reunions' else null end;
  if mod is null or jsonb_typeof(c->'body')<>'object' or coalesce(length(c->>'client_id'),0) not between 1 and 100 or c->'body'->>'id' is distinct from c->>'client_id' or octet_length((c->'body')::text)>100000 then raise check_violation; end if;
  if coalesce(length(c->'body'->>'title'),0) not between 1 and 300 then raise check_violation; end if;
  if c->>'kind'='dossiers' and (jsonb_typeof(c->'body'->'timeline') is distinct from 'array' or c->'body'->>'status' not in ('todo','doing','done') or c->'body'->>'status' is null) then raise check_violation; end if;
  if c->>'kind'='docs' and jsonb_typeof(c->'body'->'blocks') is distinct from 'array' then raise check_violation; end if;
  if c->>'kind'='reunions' and (jsonb_typeof(c->'body'->'markers') is distinct from 'array' or jsonb_typeof(c->'body'->'ordre') is distinct from 'array') then raise check_violation; end if;
  if c->>'kind'='pollsData' then raise insufficient_privilege; end if; -- Publication/answers require dedicated commands.
  if not exists(select 1 from public.uniion_module_access a join public.uniion_permissions p using(organization_id,module) where a.organization_id=p_org and a.module=mod and a.authorized and a.enabled and a.valid_until>now() and p.user_id=auth.uid() and p.permission='write') then raise insufficient_privilege; end if;
  select * into r from public.uniion_resources where organization_id=p_org and kind=c->>'kind' and client_id=c->>'client_id' for update;
  if found then
   if c->>'kind'='docs' and c->'body'->>'status' is distinct from r.body->>'status' then raise insufficient_privilege; end if;
   if c->>'kind'='reunions' and (c->'body'->>'pv' is distinct from r.body->>'pv' or c->'body'->>'audio' is distinct from r.body->>'audio') then raise insufficient_privilege; end if;
   if not uniion_private.resource_access(p_org,r.id,true) then raise insufficient_privilege; end if;
   if (c->>'version')::integer is distinct from r.version then raise exception 'Version conflict' using errcode='40001'; end if;
   update public.uniion_resources set body=c->'body',title=left(coalesce(c->'body'->>'title',c->'body'->>'titre','Sans titre'),300),version=version+1 where id=r.id returning * into r;
  else
   if c->>'kind'='docs' and c->'body'->>'status' is distinct from 'Brouillon' then raise insufficient_privilege; end if;
   if c->>'kind'='reunions' then raise insufficient_privilege; end if; -- Audio storage not connected.
   if c->>'version' is not null or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=mod and permission='create') then raise insufficient_privilege; end if;
   insert into public.uniion_resources(organization_id,module,kind,client_id,title,body) values(p_org,mod,c->>'kind',c->>'client_id',left(coalesce(c->'body'->>'title',c->'body'->>'titre','Sans titre'),300),c->'body') returning * into r;
   insert into public.uniion_resource_grants values(p_org,r.id,auth.uid(),true,false,now()+interval '365 days',null);
  end if;
  insert into public.uniion_events(organization_id,actor,resource_id,event,version) values(p_org,auth.uid(),r.id,'save',r.version);
  result=result||jsonb_build_array(jsonb_build_object('id',r.id,'kind',r.kind,'client_id',r.client_id,'version',r.version));
 end loop;
 return result;
end $$;
notify pgrst,'reload schema';
commit;

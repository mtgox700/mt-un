begin;
do $$declare d text;begin
 select pg_get_constraintdef(oid) into d from pg_constraint where conrelid='public.uniion_authorities'::regclass and conname='uniion_authorities_permission_check';
 alter table public.uniion_authorities drop constraint uniion_authorities_permission_check;
 execute 'alter table public.uniion_authorities add constraint uniion_authorities_permission_check '||replace(d,'CHECK (','CHECK (permission in (''content_review'',''content_publish'') OR ');
end$$;
create table uniion_private.business_publications(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,resource_id uuid not null,version int not null,module text not null,
 body jsonb not null,recipients uuid[] not null,reviewer uuid not null references auth.users,reviewed_at timestamptz not null default now(),publisher uuid references auth.users,published_at timestamptz,revoked_at timestamptz,
 unique(organization_id,resource_id,version),foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id)
);
alter table uniion_private.business_publications enable row level security;
revoke all on uniion_private.business_publications from public,anon,authenticated;
create function public.uniion_business_publication(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources;p uniion_private.business_publications;targets uuid[];em text;uid uuid;
begin
 perform public.uniion_module_use(p_org,p_module);
 if p_module not in ('mobile','communication','intranet','reunions') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='feed' and p_payload='{}' then
  -- Approved version has its own audience. No source ids, actors or private citations metadata.
  return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('id',id,'version',version,'body',body,'published',published_at,'download',false) order by published_at desc) from uniion_private.business_publications where organization_id=p_org and module=p_module and published_at is not null and revoked_at is null and auth.uid()=any(recipients)),'[]'));
 end if;
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module=p_module for update;
 if not found or not exists(select 1 from uniion_private.business_records where id=r.id and organization_id=p_org) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),false) or r.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
 select * into p from uniion_private.business_publications where organization_id=p_org and resource_id=r.id and version=r.version for update;
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
  if p_payload-array['id','version']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'content_publish') then raise insufficient_privilege;end if;
  update uniion_private.business_publications set revoked_at=now() where id=p.id;
 elsif p_action<>'status' or p_payload-array['id','version']<>'{}' then raise insufficient_privilege;end if;
 if p_action<>'status' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.'||p_action,jsonb_build_object('id',r.id,'version',r.version));end if;
 select * into p from uniion_private.business_publications where organization_id=p_org and resource_id=r.id and version=r.version;
 return jsonb_build_object('id',r.id,'version',r.version,'reviewed',p.reviewer is not null and p.revoked_at is null,'published',p.published_at is not null and p.revoked_at is null,'audienceCount',coalesce(cardinality(p.recipients),0),'download',false);
end$$;
revoke all on function public.uniion_business_publication(uuid,text,text,jsonb) from public,anon;
grant execute on function public.uniion_business_publication(uuid,text,text,jsonb) to authenticated;
-- Current draft status reflects only this version. Older approved versions stay immutable.
alter function public.uniion_business_records(uuid,text,text,jsonb) rename to uniion_business_records_base150;
revoke all on function public.uniion_business_records_base150(uuid,text,text,jsonb) from public,anon,authenticated;
create function public.uniion_business_records(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;row jsonb;status text;rows jsonb='[]';
begin
 result=public.uniion_business_records_base150(p_org,p_module,p_action,p_payload);
 if p_action='list' then
  for row in select value from jsonb_array_elements(result->'rows') loop
   select case when revoked_at is not null then 'Brouillon' when published_at is not null then 'En ligne' else 'En relecture' end into status from uniion_private.business_publications where organization_id=p_org and resource_id=(row->>'id')::uuid and version=(row->>'version')::int;
   rows=rows||jsonb_build_array(row||jsonb_build_object('status',coalesce(status,'Brouillon')));
  end loop;
  return jsonb_build_object('rows',rows);
 end if;
 select case when revoked_at is not null then 'Brouillon' when published_at is not null then 'En ligne' else 'En relecture' end into status from uniion_private.business_publications where organization_id=p_org and resource_id=(result->>'id')::uuid and version=(result->>'version')::int;
 return result||jsonb_build_object('status',coalesce(status,'Brouillon'));
end$$;
revoke all on function public.uniion_business_records(uuid,text,text,jsonb) from public,anon;
grant execute on function public.uniion_business_records(uuid,text,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

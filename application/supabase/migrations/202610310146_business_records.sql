begin;
-- Module-owned objects replacing prototype-only collections. No implicit import.
insert into uniion_private.module_catalog(id,name) values
 ('communication','Communication'),('mobile','Application mobile'),('formations','Formations'),
 ('intranet','Intranet'),('reporting','Reporting'),('raccourcis','Raccourcis') on conflict do nothing;
create table uniion_private.business_records(
 organization_id uuid not null,id uuid primary key,creator uuid not null references auth.users,
 updated_at timestamptz not null default now(),
 foreign key(organization_id,id) references public.uniion_resources(organization_id,id)
);
alter table uniion_private.business_records enable row level security;
revoke all on uniion_private.business_records from public,anon,authenticated;
create function uniion_private.business_payload(m text,d jsonb) returns jsonb language plpgsql set search_path='' as $$
declare fields text[];item jsonb;
begin
 fields=case m
 when 'reunions' then array['title','type','date','ordre','markers','transcript','minutes','participants']
 when 'communication' then array['title','date','fmt','canal','obj','ton','sujet','content','items']
 when 'mobile' then array['title','type','aud','blocks','pushOn','push','subject']
 when 'formations' then array['title','theme','dur','level','role','goal','modules','intro','retenir','sources','cur','done','ans','ex','fb','chat','finished']
 when 'sondages' then array['title','question','options','description','mode','results','respondents']
 when 'intranet' then array['title','blocks','description','type']
 when 'reporting' then array['title','period','indicators','description']
 when 'raccourcis' then array['title','items','description'] end;
 if fields is null or jsonb_typeof(d) is distinct from 'object' or d-fields<>'{}' or jsonb_typeof(d->'title') is distinct from 'string' or length(btrim(d->>'title')) not between 1 and 200 or octet_length(d::text)>100000 then raise insufficient_privilege;end if;
 -- These values are data only. Neither status, audience grants nor approval can be supplied here.
 if exists(select 1 from jsonb_each(d) where key=any(array['type','date','fmt','canal','obj','ton','sujet','aud','push','subject','theme','level','role','goal','intro','sources','question','description','mode','period']) and (jsonb_typeof(value)<>'string' or length(value#>>'{}')>12000)) then raise insufficient_privilege;end if;
 if exists(select 1 from jsonb_each(d) where key=any(array['ordre','markers','participants','items','blocks','modules','retenir','done','chat','options','indicators']) and (jsonb_typeof(value)<>'array' or jsonb_array_length(value)>100)) then raise insufficient_privilege;end if;
 if d ? 'blocks' then
  for item in select value from jsonb_array_elements(d->'blocks') loop
   if jsonb_typeof(item)<>'array' or jsonb_array_length(item)<>2 or item->>0 not in ('h','p','info','btn') or jsonb_typeof(item->1)<>'string' or length(item->>1)>12000 then raise insufficient_privilege;end if;
  end loop;
 end if;
 -- Poll answers/results are owned by the voting subsystem, never arbitrary record saves.
 if m='sondages' and (d ? 'results' or d ? 'respondents') then raise insufficient_privilege;end if;
 return d;
end$$;
create function public.uniion_business_records(p_org uuid,p_module text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources;rid uuid;d jsonb;
begin
 if p_module is null or p_module not in ('reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 perform public.uniion_module_use(p_org,p_module);
 if p_action='list' and p_payload='{}' then
  return jsonb_build_object('rows',coalesce((select jsonb_agg(r.body||jsonb_build_object('id',r.id,'version',r.version,'module',r.module,'status','Brouillon','serverRecord',true,'canWrite',uniion_private.actor_resource(p_org,r.id,auth.uid(),true)) order by b.updated_at desc) from public.uniion_resources r join uniion_private.business_records b on b.organization_id=r.organization_id and b.id=r.id where r.organization_id=p_org and r.module=p_module and uniion_private.actor_resource(p_org,r.id,auth.uid(),false)),'[]'));
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
revoke all on function uniion_private.business_payload(text,jsonb),public.uniion_business_records(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.uniion_business_records(uuid,text,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

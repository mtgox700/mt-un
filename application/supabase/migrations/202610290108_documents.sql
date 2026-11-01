begin;
create table uniion_private.documents(organization_id uuid not null,id uuid primary key,model text not null,updated_at timestamptz not null default now(),foreign key(organization_id,id) references public.uniion_resources(organization_id,id));
alter table uniion_private.documents enable row level security;
revoke all on uniion_private.documents from public,anon,authenticated;
create function uniion_private.document_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$
 select r.body||jsonb_build_object('id',r.id,'version',r.version,'title',r.title,'model',d.model,'status','Brouillon','serverDocument',true,'updated',to_char(d.updated_at at time zone 'Europe/Paris','DD/MM/YYYY HH24:MI'),'canWrite',uniion_private.actor_resource(o,rid,auth.uid(),true)) from public.uniion_resources r join uniion_private.documents d on d.id=r.id and d.organization_id=r.organization_id where r.organization_id=o and r.id=rid
$$;
create function public.uniion_documents(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare rid uuid;r public.uniion_resources;doc jsonb;item jsonb;
begin
 perform public.uniion_module_use(p_org,'documents');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='list' and p_payload='{}' then return jsonb_build_object('rows',coalesce((select jsonb_agg(uniion_private.document_json(p_org,d.id) order by d.updated_at desc) from uniion_private.documents d where d.organization_id=p_org and uniion_private.actor_resource(p_org,d.id,auth.uid(),false)),'[]'));end if;
 if p_action='create' then
  if p_payload-array['model','document']<>'{}' or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='create') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='write') then raise insufficient_privilege;end if;
  if jsonb_typeof(p_payload->'model') is distinct from 'string' or length(p_payload->>'model') not between 1 and 60 then raise insufficient_privilege;end if;
 else
  rid=(p_payload->>'id')::uuid;
  select * into r from public.uniion_resources where id=rid and organization_id=p_org and module='documents' for update;
  if not found or not exists(select 1 from uniion_private.documents where id=rid and organization_id=p_org) or not uniion_private.actor_resource(p_org,rid,auth.uid(),p_action<>'get') then raise insufficient_privilege;end if;
  if p_action='get' and p_payload-array['id']='{}' then return uniion_private.document_json(p_org,rid);end if;
  if p_action<>'save' or p_payload-array['id','version','document']<>'{}' or (p_payload->>'version')::integer is distinct from r.version then raise insufficient_privilege;end if;
 end if;
 doc=p_payload->'document';
 if jsonb_typeof(doc) is distinct from 'object' or not(doc ?& array['title','format','blocks']) or doc-array['title','format','blocks','charte']<>'{}' or jsonb_typeof(doc->'title') is distinct from 'string' or length(btrim(doc->>'title')) not between 1 and 200 or doc->>'format' is null or doc->>'format' not in ('a4','a5','square','story','wide') or jsonb_typeof(doc->'blocks') is distinct from 'array' or jsonb_array_length(doc->'blocks') not between 0 and 100 or octet_length(doc::text)>200000 then raise insufficient_privilege;end if;
 for item in select value from jsonb_array_elements(doc->'blocks') loop
  if jsonb_typeof(item) is distinct from 'object' or item-array['id','type','text']<>'{}' or jsonb_typeof(item->'id') is distinct from 'string' or length(item->>'id') not between 1 and 100 or item->>'type' is null or item->>'type' not in ('tag','h1','h2','h3','p','ul','quote','table','pagebreak') or jsonb_typeof(item->'text') is distinct from 'string' or length(item->>'text')>20000 then raise insufficient_privilege;end if;
 end loop;
 if doc ? 'charte' then
  item=doc->'charte';
  if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']) or item-array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']<>'{}' then raise insufficient_privilege;end if;
  if item->>'accent' !~ '^#[0-9a-fA-F]{6}$' or item->>'ink' !~ '^#[0-9a-fA-F]{6}$' or item->>'titleFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'bodyFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'density' not in ('standard','compact','confort') or item->>'logo' not in ('','uniion-logo.png') then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_each(item) x where (x.key in ('header','footer','caps','emetteurOverride') and jsonb_typeof(x.value) is distinct from 'boolean') or (x.key not in ('header','footer','caps','emetteurOverride') and (jsonb_typeof(x.value) is distinct from 'string' or length(x.value#>>'{}')>300))) then raise insufficient_privilege;end if;
 end if;
 if p_action='create' then
  insert into public.uniion_resources(organization_id,module,title,body) values(p_org,'documents',doc->>'title',doc) returning id into rid;
  insert into uniion_private.documents(organization_id,id,model) values(p_org,rid,p_payload->>'model');
  insert into public.uniion_resource_grants values(p_org,rid,auth.uid(),true,false,'infinity',null);
 else
  update public.uniion_resources set title=doc->>'title',body=doc,version=version+1 where id=rid;
  update uniion_private.documents set updated_at=now() where id=rid;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.'||p_action,jsonb_build_object('resource',rid));
 return uniion_private.document_json(p_org,rid);
end$$;
revoke all on function uniion_private.document_json(uuid,uuid),public.uniion_documents(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.uniion_documents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

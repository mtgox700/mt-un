begin;
-- Receipts contain only a digest, scope and audit information. No direct table access.
create table uniion_private.document_image_receipts(document_id uuid not null references uniion_private.documents(id),digest text not null,engine text not null,scanned_at timestamptz not null default now(),primary key(document_id,digest));
alter table uniion_private.document_image_receipts enable row level security;
revoke all on uniion_private.document_image_receipts from public,anon,authenticated;
create function public.uniion_document_image_receipt(p_document uuid,p_image text,p_engine text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.is_scanner() or p_image is null or p_engine is null or length(p_engine) not between 1 and 250 or length(p_image)>2800000 or p_image !~ '^data:image/(png|jpeg|svg\+xml);base64,[A-Za-z0-9+/]+={0,2}$' then raise insufficient_privilege;end if;
 insert into uniion_private.document_image_receipts(document_id,digest,engine) values(p_document,encode(extensions.digest(p_image,'sha256'),'hex'),p_engine) on conflict do nothing;
 return jsonb_build_object('ok',true);
end;$$;
revoke all on function public.uniion_document_image_receipt(uuid,text,text) from public,anon;
grant execute on function public.uniion_document_image_receipt(uuid,text,text) to authenticated;
create function uniion_private.document_image_allowed(p_document uuid,p_image text) returns boolean language sql stable security definer set search_path='' as $$
 select p_image is not null and (p_image in ('','uniion-logo.png') or exists(select 1 from uniion_private.document_image_receipts where document_id=p_document and digest=encode(extensions.digest(p_image,'sha256'),'hex')))
$$;
revoke all on function uniion_private.document_image_allowed(uuid,text) from public,anon,authenticated;
create or replace function public.uniion_documents(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
 if jsonb_typeof(doc) is distinct from 'object' or not(doc ?& array['title','format','blocks']) or doc-array['title','format','blocks','charte','style','styleOpts']<>'{}' or jsonb_typeof(doc->'title') is distinct from 'string' or length(btrim(doc->>'title')) not between 1 and 200 or doc->>'format' is null or doc->>'format' not in ('a4','a5','square','story','wide') or jsonb_typeof(doc->'blocks') is distinct from 'array' or jsonb_array_length(doc->'blocks') not between 0 and 100 or octet_length(doc::text)>7000000 then raise insufficient_privilege;end if;
 if doc ? 'style' and doc->'style'<>'null'::jsonb and (jsonb_typeof(doc->'style')<>'string' or doc->>'style' not in ('choc','journal','infographie','institutionnel','photo','serigraphie','bulletin','qr','satirique','bd','annonce','retro')) then raise insufficient_privilege;end if;
 if doc ? 'styleOpts' then
  if jsonb_typeof(doc->'styleOpts') is distinct from 'object' or (doc->'styleOpts')-array['palette','font']<>'{}'::jsonb then raise insufficient_privilege;end if;
  for item in select value from jsonb_each(doc->'styleOpts') loop
   if jsonb_typeof(item) is distinct from 'number' or (item#>>'{}') !~ '^[0-9]+$' then raise insufficient_privilege;end if;
  end loop;
  if coalesce((doc->'styleOpts'->>'palette')::int,0)>=(case doc->>'style' when 'choc' then 4 when 'journal' then 4 when 'infographie' then 4 when 'institutionnel' then 4 when 'photo' then 3 when 'serigraphie' then 4 when 'bulletin' then 4 when 'qr' then 4 when 'satirique' then 3 when 'bd' then 3 when 'annonce' then 2 when 'retro' then 3 else 1 end) or coalesce((doc->'styleOpts'->>'font')::int,0)>=(case doc->>'style' when 'choc' then 3 when 'journal' then 3 when 'infographie' then 3 when 'institutionnel' then 3 when 'photo' then 3 when 'serigraphie' then 3 when 'bulletin' then 3 when 'qr' then 3 when 'satirique' then 2 when 'bd' then 2 when 'annonce' then 2 when 'retro' then 2 else 1 end) then raise insufficient_privilege;end if;
 end if;
 for item in select value from jsonb_array_elements(doc->'blocks') loop
  if item ? 'img' and not uniion_private.document_image_allowed(rid,item->>'img') then raise insufficient_privilege;end if;
  if item->>'type'='studio.photo' and item->>'text' ~* '^\s*(https?:|data:|//)' then raise insufficient_privilege;end if;

  if jsonb_typeof(item) is distinct from 'object' or item-array['id','type','text','img']<>'{}' or jsonb_typeof(item->'id') is distinct from 'string' or length(item->>'id') not between 1 and 100 or item->>'type' is null or item->>'type' not in ('tag','h1','h2','h3','p','ul','quote','table','pagebreak','studio.chiffre','studio.compare','studio.frise','studio.photo','studio.qr','studio.coupon','studio.trombi','studio.tampon','studio.surligne','studio.signature','studio.bulles','studio.exige') or jsonb_typeof(item->'text') is distinct from 'string' or length(item->>'text')>20000 then raise insufficient_privilege;end if;
 end loop;
 if doc ? 'charte' then
  item=doc->'charte';
  if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']) or item-array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']<>'{}' then raise insufficient_privilege;end if;
  if item->>'accent' !~ '^#[0-9a-fA-F]{6}$' or item->>'ink' !~ '^#[0-9a-fA-F]{6}$' or item->>'titleFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'bodyFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'density' not in ('standard','compact','confort') or not uniion_private.document_image_allowed(rid,item->>'logo') then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_each(item) x where (x.key in ('header','footer','caps','emetteurOverride') and jsonb_typeof(x.value) is distinct from 'boolean') or (x.key not in ('header','footer','caps','emetteurOverride') and (jsonb_typeof(x.value) is distinct from 'string' or length(x.value#>>'{}')>case when x.key='logo' then 2800000 else 300 end))) then raise insufficient_privilege;end if;
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
notify pgrst,'reload schema';commit;

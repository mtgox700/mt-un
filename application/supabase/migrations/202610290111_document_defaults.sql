begin;
create table uniion_private.document_defaults(organization_id uuid primary key references public.uniion_organizations(id),logo text not null,version integer not null,updated_at timestamptz not null default now());
create table uniion_private.document_default_versions(organization_id uuid not null references public.uniion_organizations(id),version integer not null,logo text not null,actor uuid not null,created_at timestamptz not null default now(),primary key(organization_id,version));
create table uniion_private.document_default_receipts(organization_id uuid not null references public.uniion_organizations(id),digest text not null,engine text not null,scanned_at timestamptz not null default now(),primary key(organization_id,digest));
alter table uniion_private.document_defaults enable row level security;
alter table uniion_private.document_default_versions enable row level security;
alter table uniion_private.document_default_receipts enable row level security;
revoke all on uniion_private.document_defaults,uniion_private.document_default_versions,uniion_private.document_default_receipts from public,anon,authenticated;
create function public.uniion_document_defaults_image_receipt(p_document uuid,p_image text,p_engine text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.is_scanner() or p_engine is null or length(p_engine) not between 1 and 250 or p_image is null or length(p_image)>2800000 or p_image !~ '^data:image/(png|jpeg|svg\+xml);base64,[A-Za-z0-9+/]+={0,2}$' then raise insufficient_privilege;end if;
 insert into uniion_private.document_default_receipts values(p_document,encode(extensions.digest(p_image,'sha256'),'hex'),p_engine,now()) on conflict do nothing;
 return '{"ok":true}'::jsonb;
end$$;
create function public.uniion_document_defaults(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare current_logo text;v integer;manage boolean;
begin
 perform public.uniion_module_use(p_org,'documents');
 manage=uniion_private.authority(p_org,auth.uid(),'organization_edit');
 if p_action='save' then
  if not manage or jsonb_typeof(p_payload) is distinct from 'object' or p_payload-array['logo','version']<>'{}' or jsonb_typeof(p_payload->'logo') is distinct from 'string' then raise insufficient_privilege;end if;
  perform 1 from public.uniion_organizations where id=p_org for update;
 elsif p_action<>'get' or p_payload<>'{}' then raise insufficient_privilege;
 end if;
 select logo,version into current_logo,v from uniion_private.document_defaults where organization_id=p_org;
 current_logo=coalesce(current_logo,'uniion-logo.png');v=coalesce(v,0);
 if p_action='save' then
  if (p_payload->>'version')::integer is distinct from v then raise insufficient_privilege;end if;
  current_logo=p_payload->>'logo';
  if current_logo not in ('','uniion-logo.png') and not exists(select 1 from uniion_private.document_default_receipts where organization_id=p_org and digest=encode(extensions.digest(current_logo,'sha256'),'hex')) then raise insufficient_privilege;end if;
  v=v+1;
  insert into uniion_private.document_defaults values(p_org,current_logo,v,now()) on conflict(organization_id) do update set logo=excluded.logo,version=excluded.version,updated_at=excluded.updated_at;
  insert into uniion_private.document_default_versions values(p_org,v,current_logo,auth.uid(),now());
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.defaults',jsonb_build_object('version',v));
 end if;
 return jsonb_build_object('logo',current_logo,'version',v,'canWrite',manage);
end$$;
revoke all on function public.uniion_document_defaults(uuid,text,jsonb),public.uniion_document_defaults_image_receipt(uuid,text,text) from public,anon;
grant execute on function public.uniion_document_defaults(uuid,text,jsonb),public.uniion_document_defaults_image_receipt(uuid,text,text) to authenticated;
do $patch$
declare d text;
begin
 d=pg_get_functiondef('public.uniion_documents(uuid,text,jsonb)'::regprocedure);
 d=replace(d,$old$doc=p_payload->'document';$old$,$new$doc=p_payload->'document';
 if p_action='create' then
  item=public.uniion_document_defaults(p_org,'get','{}');
  doc=jsonb_set(doc,'{charte}',coalesce(doc->'charte','{"accent":"#DC2626","ink":"#111827","titleFont":"philosopher","bodyFont":"inter","density":"standard","header":true,"footer":true,"caps":false,"emetteur":"","section":"","email":"","phone":"","emetteurOverride":true}'::jsonb)||jsonb_build_object('logo',item->>'logo'));
 end if;$new$);
 d=replace(d,$old$not uniion_private.document_image_allowed(rid,item->>'logo')$old$,$new$(p_action<>'create' and not uniion_private.document_image_allowed(rid,item->>'logo'))$new$);
 d=replace(d,$old$insert into uniion_private.documents(organization_id,id,model) values(p_org,rid,p_payload->>'model');$old$,$new$insert into uniion_private.documents(organization_id,id,model) values(p_org,rid,p_payload->>'model');
 insert into uniion_private.document_image_receipts(document_id,digest,engine,scanned_at) select rid,digest,engine,scanned_at from uniion_private.document_default_receipts where organization_id=p_org and digest=encode(extensions.digest(doc->'charte'->>'logo','sha256'),'hex') on conflict do nothing;$new$);
 d=replace(d,$old$if p_action='list' and p_payload='{}' then return jsonb_build_object('rows',$old$,$new$if p_action='list' and p_payload='{}' then return jsonb_build_object('defaults',public.uniion_document_defaults(p_org,'get','{}'),'rows',$new$);
 execute d;
end$patch$;
notify pgrst,'reload schema';commit;

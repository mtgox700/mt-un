begin;
create table uniion_private.document_archives(organization_id uuid not null,resource_id uuid not null,version integer not null,pdf bytea not null check(octet_length(pdf) between 1 and 20971520),digest text not null,primary key(organization_id,resource_id,version),foreign key(organization_id,resource_id,version) references public.uniion_resource_versions(organization_id,resource_id,version));
create table uniion_private.document_corrections(id uuid primary key default gen_random_uuid(),organization_id uuid not null,resource_id uuid not null,version integer not null,actor uuid not null references auth.users,reason text not null check(length(btrim(reason)) between 5 and 2000),created_at timestamptz not null default now(),foreign key(organization_id,resource_id,version) references public.uniion_resource_versions(organization_id,resource_id,version));
create table uniion_private.document_notices(id uuid primary key default gen_random_uuid(),organization_id uuid not null,resource_id uuid not null,version integer not null,user_id uuid not null references auth.users,read_at timestamptz,created_at timestamptz not null default now(),unique(resource_id,version,user_id),foreign key(organization_id,resource_id,version) references uniion_private.document_publications);
alter table uniion_private.document_archives enable row level security;alter table uniion_private.document_corrections enable row level security;alter table uniion_private.document_notices enable row level security;
revoke all on uniion_private.document_archives,uniion_private.document_corrections,uniion_private.document_notices from public,anon,authenticated;
create function public.uniion_document_archive_store(p_org uuid,p_id uuid,p_version integer,p_pdf text) returns jsonb language plpgsql security definer set search_path='' as $$declare b bytea;begin
 if not uniion_private.is_scanner() or p_pdf is null or length(p_pdf)>28000000 then raise insufficient_privilege;end if;b=decode(p_pdf,'base64');if substring(b from 1 for 5)<>convert_to('%PDF-','UTF8') then raise insufficient_privilege;end if;
 insert into uniion_private.document_archives values(p_org,p_id,p_version,b,encode(extensions.digest(b,'sha256'),'hex')) on conflict do nothing;return jsonb_build_object('ok',true);end$$;
revoke all on function public.uniion_document_archive_store(uuid,uuid,integer,text) from public,anon;grant execute on function public.uniion_document_archive_store(uuid,uuid,integer,text) to authenticated;
alter function public.uniion_document_publication(uuid,text,jsonb) rename to uniion_document_publication_base;
revoke all on function public.uniion_document_publication_base(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_document_publication(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$declare r public.uniion_resources;result jsonb;begin
 perform public.uniion_module_use(p_org,'documents');
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module='documents' for update;
 if not found or not exists(select 1 from uniion_private.documents where id=r.id) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),false) or r.version is distinct from (p_payload->>'version')::integer then raise insufficient_privilege;end if;
 if p_action='correction' then
  if p_payload-array['id','version','reason']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'document_review') or exists(select 1 from public.uniion_resource_versions where resource_id=r.id and (actor=auth.uid() or actor is null)) or exists(select 1 from uniion_private.document_publications where resource_id=r.id and version=r.version and published_at is not null) or jsonb_typeof(p_payload->'reason') is distinct from 'string' then raise insufficient_privilege;end if;
  insert into uniion_private.document_corrections(organization_id,resource_id,version,actor,reason) values(p_org,r.id,r.version,auth.uid(),p_payload->>'reason');
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.correction',jsonb_build_object('resource',r.id,'version',r.version));
  return jsonb_build_object('id',r.id,'version',r.version,'reviewed',false,'published',false,'correction',p_payload->>'reason');
 end if;
 if p_action in ('review','publish') and exists(select 1 from uniion_private.document_corrections where resource_id=r.id and version=r.version) then raise insufficient_privilege;end if;
 if p_action='prepare' then
  result=public.uniion_document_publication_base(p_org,'status',p_payload);
  if not uniion_private.authority(p_org,auth.uid(),'document_publish') or not (result->>'reviewed')::boolean or exists(select 1 from uniion_private.document_corrections where resource_id=r.id and version=r.version) then raise insufficient_privilege;end if;
  return jsonb_build_object('version',r.version,'document',uniion_private.document_json(p_org,r.id));
 end if;
 if p_action='publish' and not exists(select 1 from uniion_private.document_archives where resource_id=r.id and version=r.version) then raise insufficient_privilege;end if;
 result=public.uniion_document_publication_base(p_org,p_action,p_payload);
 if p_action='publish' then
  insert into uniion_private.document_notices(organization_id,resource_id,version,user_id) select p_org,r.id,r.version,m.user_id from public.uniion_memberships m where m.organization_id=p_org and uniion_private.actor_resource(p_org,r.id,m.user_id,false) on conflict do nothing;
 end if;
 return result||jsonb_build_object('correction',(select reason from uniion_private.document_corrections where resource_id=r.id and version=r.version order by created_at desc limit 1));
end$$;
revoke all on function public.uniion_document_publication(uuid,text,jsonb) from public,anon;grant execute on function public.uniion_document_publication(uuid,text,jsonb) to authenticated;
create function public.uniion_document_history(p_org uuid,p_id uuid,p_version integer default null) returns jsonb language plpgsql security definer set search_path='' as $$declare a uniion_private.document_archives;begin
 perform public.uniion_module_use(p_org,'documents');if not uniion_private.actor_resource(p_org,p_id,auth.uid(),false) then raise insufficient_privilege;end if;
 if p_version is not null then
  if not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
  select ar.* into a from uniion_private.document_archives ar join uniion_private.document_publications p using(organization_id,resource_id,version) where ar.organization_id=p_org and ar.resource_id=p_id and ar.version=p_version and p.published_at is not null;
  if not found then raise insufficient_privilege;end if;
  return jsonb_build_object('base64',encode(a.pdf,'base64'),'mime','application/pdf','filename','document-'||p_id||'-v'||p_version||'.pdf','sha256',a.digest);
 end if;
 return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('version',p.version,'published',p.published_at,'archived',a.digest is not null) order by p.version desc) from uniion_private.document_publications p left join uniion_private.document_archives a using(organization_id,resource_id,version) where p.organization_id=p_org and p.resource_id=p_id and p.published_at is not null),'[]'));
end$$;
create function public.uniion_document_notices(p_org uuid,p_read uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$begin
 perform public.uniion_module_use(p_org,'documents');
 if p_read is not null then update uniion_private.document_notices set read_at=coalesce(read_at,now()) where organization_id=p_org and user_id=auth.uid() and (id=p_read or p_read='00000000-0000-0000-0000-000000000000') and uniion_private.actor_resource(p_org,resource_id,auth.uid(),false);end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'resource',n.resource_id,'version',n.version,'title',v.body->>'title','read',n.read_at is not null,'created',n.created_at) order by n.created_at desc) from uniion_private.document_notices n join public.uniion_resource_versions v using(organization_id,resource_id,version) where n.organization_id=p_org and n.user_id=auth.uid() and uniion_private.actor_resource(p_org,n.resource_id,auth.uid(),false)),'[]');end$$;
revoke all on function public.uniion_document_history(uuid,uuid,integer),public.uniion_document_notices(uuid,uuid) from public,anon;grant execute on function public.uniion_document_history(uuid,uuid,integer),public.uniion_document_notices(uuid,uuid) to authenticated;
notify pgrst,'reload schema';commit;

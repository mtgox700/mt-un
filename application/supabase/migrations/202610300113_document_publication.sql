begin;
do $$declare d text;begin
 select pg_get_constraintdef(oid) into d from pg_constraint where conrelid='public.uniion_authorities'::regclass and conname='uniion_authorities_permission_check';
 alter table public.uniion_authorities drop constraint uniion_authorities_permission_check;
 execute 'alter table public.uniion_authorities add constraint uniion_authorities_permission_check '||replace(d,'CHECK (','CHECK (permission in (''document_review'',''document_publish'') OR ');
end$$;
create table uniion_private.document_publications(
 organization_id uuid not null,resource_id uuid not null,version integer not null,
 reviewer uuid not null references auth.users,reviewed_at timestamptz not null default now(),
 publisher uuid references auth.users,published_at timestamptz,
 primary key(organization_id,resource_id,version),
 foreign key(organization_id,resource_id,version) references public.uniion_resource_versions(organization_id,resource_id,version)
);
alter table uniion_private.document_publications enable row level security;
revoke all on uniion_private.document_publications from public,anon,authenticated;
create function public.uniion_document_publication(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources;p uniion_private.document_publications;changed boolean:=false;
begin
 perform public.uniion_module_use(p_org,'documents');
 if jsonb_typeof(p_payload) is distinct from 'object' or not(p_payload ?& array['id','version']) or p_payload-array['id','version']<>'{}' or p_action is null or p_action not in ('status','review','publish') then raise insufficient_privilege;end if;
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module='documents' for update;
 if not found or not exists(select 1 from uniion_private.documents where organization_id=p_org and id=r.id) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),false) or r.version is distinct from (p_payload->>'version')::integer then raise insufficient_privilege;end if;
 select * into p from uniion_private.document_publications where organization_id=p_org and resource_id=r.id and version=r.version;
 if p_action='review' then
  if not uniion_private.authority(p_org,auth.uid(),'document_review') or exists(select 1 from public.uniion_resource_versions where organization_id=p_org and resource_id=r.id and version<=r.version and (actor=auth.uid() or actor is null)) then raise insufficient_privilege;end if;
  if p.published_at is null then
   insert into uniion_private.document_publications(organization_id,resource_id,version,reviewer) values(p_org,r.id,r.version,auth.uid()) on conflict(organization_id,resource_id,version) do update set reviewer=excluded.reviewer,reviewed_at=now() where document_publications.reviewer<>excluded.reviewer;
   changed=found;
  end if;
 elsif p_action='publish' then
  if not uniion_private.authority(p_org,auth.uid(),'document_publish') or p.reviewer is null or not uniion_private.actor_resource(p_org,r.id,p.reviewer,false) or not uniion_private.authority(p_org,p.reviewer,'document_review') then raise insufficient_privilege;end if;
  update uniion_private.document_publications set publisher=auth.uid(),published_at=now() where organization_id=p_org and resource_id=r.id and version=r.version and published_at is null;
  changed=found;
 end if;
 if changed then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.'||p_action,jsonb_build_object('resource',r.id,'version',r.version));end if;
 select * into p from uniion_private.document_publications where organization_id=p_org and resource_id=r.id and version=r.version;
 return jsonb_build_object('id',r.id,'version',r.version,'reviewed',p.reviewer is not null,'published',p.published_at is not null);
end$$;
revoke all on function public.uniion_document_publication(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_document_publication(uuid,text,jsonb) to authenticated;
-- Only current-version approval affects the visible status. Older approvals are preserved.
do $$declare d text;begin
 d=pg_get_functiondef('uniion_private.document_json(uuid,uuid)'::regprocedure);
 d=replace(d,'''status'',''Brouillon''','''status'',coalesce((select case when p.published_at is not null then ''Diffusé'' else ''Validé'' end from uniion_private.document_publications p where p.organization_id=o and p.resource_id=rid and p.version=r.version),''Brouillon'')');
 execute d;
end$$;
notify pgrst,'reload schema';commit;

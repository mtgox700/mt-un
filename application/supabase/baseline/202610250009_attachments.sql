begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('uniion-private','uniion-private',false,5242880,array['text/plain','application/pdf','image/png','image/jpeg']);
create table public.uniion_attachments(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null,resource_id uuid not null,
 filename text not null check(length(filename) between 1 and 180 and filename !~ '[[:cntrl:]/\\]'),
 mime text not null check(mime in ('text/plain','application/pdf','image/png','image/jpeg')),
 size integer not null check(size between 1 and 5242880),sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),
 object_name text not null unique,creator uuid not null references auth.users,created_at timestamptz not null default now(),ready boolean not null default false,
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id)
);
create table public.uniion_share_attachments(share_id uuid not null,resource_id uuid not null,attachment_id uuid not null references public.uniion_attachments,
 primary key(share_id,attachment_id),foreign key(share_id,resource_id) references public.uniion_share_items(share_id,resource_id));
alter table public.uniion_attachments enable row level security;
alter table public.uniion_share_attachments enable row level security;
revoke all on public.uniion_attachments,public.uniion_share_attachments from public,anon,authenticated;
create function uniion_private.attachment_access(aid uuid,who uuid,sid uuid default null) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_attachments a where a.id=aid and a.ready and
 case when sid is null then uniion_private.actor_resource(a.organization_id,a.resource_id,who,false) and uniion_private.authority(a.organization_id,who,'download')
 else exists(select 1 from public.uniion_share_attachments sa where sa.attachment_id=a.id and sa.share_id=sid and sa.resource_id=a.resource_id and uniion_private.share_access(sid,a.resource_id,who,true)) end)
$$;
create function uniion_private.storage_read(path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_attachments a where a.object_name=path and (uniion_private.attachment_access(a.id,auth.uid()) or exists(select 1 from public.uniion_share_attachments sa where sa.attachment_id=a.id and uniion_private.attachment_access(a.id,auth.uid(),sa.share_id))))
$$;
create function uniion_private.storage_insert(path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_attachments a where a.object_name=path and not a.ready and a.creator=auth.uid() and a.created_at>now()-interval '15 minutes' and uniion_private.actor_resource(a.organization_id,a.resource_id,auth.uid(),true))
$$;
revoke all on function uniion_private.attachment_access(uuid,uuid,uuid),uniion_private.storage_read(text),uniion_private.storage_insert(text) from public,anon,authenticated;
grant execute on function uniion_private.storage_read(text),uniion_private.storage_insert(text) to authenticated;
create policy uniion_file_insert on storage.objects for insert to authenticated with check(bucket_id='uniion-private' and uniion_private.storage_insert(name));
create policy uniion_file_read on storage.objects for select to authenticated using(bucket_id='uniion-private' and storage.allow_only_operation('object.get_authenticated') and uniion_private.storage_read(name));
-- No UPDATE/DELETE policies: an attachment is immutable; deletion requires a future super-admin workflow.
create function public.uniion_attachment_prepare(p_org uuid,p_resource uuid,p_filename text,p_mime text,p_size integer,p_sha256 text) returns jsonb language plpgsql security definer set search_path='' as $$
declare aid uuid=gen_random_uuid();path text;
begin
 if not uniion_private.actor_resource(p_org,p_resource,auth.uid(),true) then raise insufficient_privilege;end if;
 path=p_org::text||'/'||p_resource::text||'/'||aid::text;
 insert into public.uniion_attachments(id,organization_id,resource_id,filename,mime,size,sha256,object_name,creator) values(aid,p_org,p_resource,p_filename,p_mime,p_size,p_sha256,path,auth.uid());
 return jsonb_build_object('id',aid,'path',path);
end $$;
create function public.uniion_attachment_finish(p_org uuid,p_attachment uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment and organization_id=p_org for update;
 if not found or a.creator<>auth.uid() or not uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),true) or not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name and (metadata->>'size')::bigint=a.size) then raise insufficient_privilege;end if;
 update public.uniion_attachments set ready=true where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'attachment.uploaded',jsonb_build_object('attachment',a.id,'resource',a.resource_id));
 return jsonb_build_object('id',a.id,'filename',a.filename);
end $$;
create function public.uniion_attachment_get(p_org uuid,p_attachment uuid,p_share uuid default null,p_audit boolean default true) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment;
 if not found or not uniion_private.attachment_access(a.id,auth.uid(),p_share) or (p_share is null and a.organization_id<>p_org) or (p_share is not null and not exists(select 1 from public.uniion_shares where id=p_share and target_id=p_org)) then raise insufficient_privilege;end if;
 if p_audit then insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(a.organization_id,case when p_share is null then null else p_org end,auth.uid(),'attachment.downloaded',jsonb_build_object('attachment',a.id,'resource',a.resource_id,'share',p_share));end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'filename',a.filename,'mime',a.mime,'size',a.size,'sha256',a.sha256);
end $$;
-- Keep the existing creation transaction, adding an explicit immutable list of files.
alter function public.uniion_share_create(uuid,uuid,uuid[],uuid[],timestamptz,boolean,jsonb) rename to uniion_share_create_core;
revoke all on function public.uniion_share_create_core(uuid,uuid,uuid[],uuid[],timestamptz,boolean,jsonb) from public,anon,authenticated;
create function public.uniion_share_create(p_org uuid,p_target uuid,p_resources uuid[],p_people uuid[],p_until timestamptz,p_download boolean default false,p_versions jsonb default null,p_attachments uuid[] default '{}') returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;aid uuid;a public.uniion_attachments;
begin
 if p_attachments is null or cardinality(p_attachments)>20 then raise check_violation;end if;
 sid=public.uniion_share_create_core(p_org,p_target,p_resources,p_people,p_until,p_download,p_versions);
 foreach aid in array p_attachments loop
  select * into a from public.uniion_attachments where id=aid and organization_id=p_org and ready;
  if not found or not a.resource_id=any(p_resources) or not uniion_private.attachment_access(a.id,auth.uid()) then raise insufficient_privilege;end if;
  insert into public.uniion_share_attachments values(sid,a.resource_id,a.id);
 end loop;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(p_org,p_target,auth.uid(),'share.files_selected',jsonb_build_object('share',sid,'attachments',p_attachments));
 return sid;
end $$;
alter function public.uniion_admin_context(uuid) rename to uniion_admin_context_core;
revoke all on function public.uniion_admin_context_core(uuid) from public,anon,authenticated;
create function public.uniion_admin_context(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 result=public.uniion_admin_context_core(p_org);
 result=result||jsonb_build_object('attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'resource',a.resource_id,'filename',a.filename,'mime',a.mime,'size',a.size,'downloadable',uniion_private.attachment_access(a.id,auth.uid()))) from public.uniion_attachments a where a.organization_id=p_org and a.ready and uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),false)),'[]'::jsonb));
 result=jsonb_set(result,'{shares}',coalesce((select jsonb_agg(g||jsonb_build_object('attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'resource',a.resource_id,'filename',a.filename,'size',a.size)) from public.uniion_share_attachments sa join public.uniion_attachments a on a.id=sa.attachment_id where sa.share_id=(g->>'id')::uuid and exists(select 1 from jsonb_array_elements(g->'items') i where (i->>'id')::uuid=a.resource_id)),'[]'::jsonb))) from jsonb_array_elements(result->'shares') g),'[]'::jsonb));
 return result;
end $$;
alter function public.uniion_shared_read(uuid,uuid,uuid,boolean) rename to uniion_shared_read_core;
revoke all on function public.uniion_shared_read_core(uuid,uuid,uuid,boolean) from public,anon,authenticated;
create function public.uniion_shared_read(p_org uuid,p_share uuid,p_resource uuid,p_download boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 result=public.uniion_shared_read_core(p_org,p_share,p_resource,p_download);
 return result||jsonb_build_object('kind',(select kind from public.uniion_resources where id=p_resource),'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'size',a.size,'mime',a.mime,'downloadable',uniion_private.attachment_access(a.id,auth.uid(),p_share))) from public.uniion_share_attachments sa join public.uniion_attachments a on a.id=sa.attachment_id where sa.share_id=p_share and sa.resource_id=p_resource),'[]'::jsonb));
end $$;
revoke all on function public.uniion_attachment_prepare(uuid,uuid,text,text,integer,text),public.uniion_attachment_finish(uuid,uuid),public.uniion_attachment_get(uuid,uuid,uuid,boolean),public.uniion_share_create(uuid,uuid,uuid[],uuid[],timestamptz,boolean,jsonb,uuid[]),public.uniion_admin_context(uuid),public.uniion_shared_read(uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.uniion_attachment_prepare(uuid,uuid,text,text,integer,text),public.uniion_attachment_finish(uuid,uuid),public.uniion_attachment_get(uuid,uuid,uuid,boolean),public.uniion_share_create(uuid,uuid,uuid[],uuid[],timestamptz,boolean,jsonb,uuid[]),public.uniion_admin_context(uuid),public.uniion_shared_read(uuid,uuid,uuid,boolean) to authenticated;
notify pgrst,'reload schema';
commit;

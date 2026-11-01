begin;
create table uniion_private.case_file_versions(
 root uuid not null references public.uniion_attachments, revision integer not null check(revision>0),
 attachment uuid not null references public.uniion_attachments, actor uuid not null references auth.users,
 created_at timestamptz not null default now(), primary key(root,revision)
);
alter table uniion_private.case_file_versions enable row level security;
revoke all on uniion_private.case_file_versions from public,anon,authenticated;
create function uniion_private.case_file_rows(o uuid,c uuid) returns jsonb language sql stable set search_path='' as $$
with entries as (
 select a.id root,1 revision,a.id attachment,a.created_at from public.uniion_attachments a where a.organization_id=o and a.resource_id=c and not exists(select 1 from uniion_private.case_file_versions v where v.attachment=a.id)
 union all select v.root,v.revision,v.attachment,v.created_at from uniion_private.case_file_versions v join public.uniion_attachments a on a.id=v.attachment where a.organization_id=o and a.resource_id=c
), rows as (select e.*,a.filename,a.mime,a.size,a.scan_status from entries e join public.uniion_attachments a on a.id=e.attachment), currents as (
 select distinct on(root) * from rows order by root,(scan_status='clean') desc,revision desc
)
select coalesce(jsonb_agg(jsonb_build_object('id',x.root,'attachment',x.attachment,'version',x.revision,'maxVersion',(select max(revision) from rows where root=x.root),'filename',x.filename,'mime',x.mime,'size',x.size,'created',x.created_at,'status',x.scan_status,'versions',(select jsonb_agg(jsonb_build_object('version',r.revision,'attachment',r.attachment,'status',r.scan_status,'created',r.created_at) order by r.revision desc) from rows r where r.root=x.root)) order by x.created_at desc),'[]') from currents x
$$;
revoke all on function uniion_private.case_file_rows(uuid,uuid) from public,anon,authenticated;
create or replace function public.uniion_case_files(p_org uuid,p_case uuid,p_attachment uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform public.uniion_module_use(p_org,'dossiers');
 if not exists(select 1 from uniion_private.cases where organization_id=p_org and id=p_case) or not uniion_private.actor_resource(p_org,p_case,auth.uid(),false) then raise insufficient_privilege;end if;
 if p_attachment is not null and not exists(select 1 from public.uniion_attachments where organization_id=p_org and resource_id=p_case and id=p_attachment) then raise insufficient_privilege;end if;
 return jsonb_build_object('write',uniion_private.actor_resource(p_org,p_case,auth.uid(),true),'download',uniion_private.authority(p_org,auth.uid(),'download'),'files',uniion_private.case_file_rows(p_org,p_case));
end$$;
create function public.uniion_case_file_version(p_org uuid,p_case uuid,p_root uuid,p_expected integer,p_restore integer default null,p_filename text default null,p_mime text default null,p_size integer default null,p_sha256 text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.uniion_attachments; item jsonb; next_revision integer; source_id uuid;
begin
 perform public.uniion_case_files(p_org,p_case,p_root);
 perform 1 from public.uniion_resources where organization_id=p_org and id=p_case for update;
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 select * into a from public.uniion_attachments where id=p_root and organization_id=p_org and resource_id=p_case for update;
 if not found or exists(select 1 from uniion_private.case_file_versions where attachment=p_root and root<>p_root) then raise insufficient_privilege;end if;
 insert into uniion_private.case_file_versions(root,revision,attachment,actor,created_at) values(p_root,1,p_root,a.creator,a.created_at) on conflict do nothing;
 select max(revision)+1 into next_revision from uniion_private.case_file_versions where root=p_root;
 if p_expected is null or p_expected<>next_revision-1 then raise serialization_failure using message='Version modifiée';end if;
 if p_restore is not null then
  select v.attachment into source_id from uniion_private.case_file_versions v join public.uniion_attachments f on f.id=v.attachment where v.root=p_root and v.revision=p_restore and f.scan_status='clean' and f.ready and f.organization_id=p_org and f.resource_id=p_case;
  if source_id is null then raise insufficient_privilege;end if;
  item=jsonb_build_object('id',source_id);
 else
  item=public.uniion_attachment_prepare(p_org,p_case,p_filename,p_mime,p_size,p_sha256);
  source_id=(item->>'id')::uuid;
 end if;
 insert into uniion_private.case_file_versions(root,revision,attachment,actor) values(p_root,next_revision,source_id,auth.uid());
 insert into uniion_private.case_history(organization_id,resource_id,actor,title,body) values(p_org,p_case,auth.uid(),case when p_restore is null then 'Version déposée — analyse requise' else 'Version restaurée' end,'Pièce '||p_root||' · version '||next_revision||case when p_restore is null then '' else ' depuis v'||p_restore end);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.file_version',jsonb_build_object('root',p_root,'revision',next_revision,'restored_from',p_restore));
 return item||jsonb_build_object('revision',next_revision);
end$$;
revoke all on function public.uniion_case_file_version(uuid,uuid,uuid,integer,integer,text,text,integer,text) from public,anon;
grant execute on function public.uniion_case_file_version(uuid,uuid,uuid,integer,integer,text,text,integer,text) to authenticated;
create or replace function uniion_private.case_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$select uniion_private.case_json_base(o,rid)||uniion_private.case_assignment_context(o,rid)||jsonb_build_object('fileCount',jsonb_array_length(uniion_private.case_file_rows(o,rid)))$$;
notify pgrst,'reload schema';
commit;

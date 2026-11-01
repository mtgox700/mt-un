begin;
create table uniion_private.document_export_jobs(id uuid primary key default gen_random_uuid(),organization_id uuid not null,resource_id uuid not null,version integer not null,requester uuid not null references auth.users,state text not null default 'pending' check(state in ('pending','running','done','error')),lease uuid,updated_at timestamptz not null default now(),result jsonb,error text,unique(resource_id,version,requester),foreign key(organization_id,resource_id,version) references public.uniion_resource_versions(organization_id,resource_id,version));
alter table uniion_private.document_export_jobs enable row level security;revoke all on uniion_private.document_export_jobs from public,anon,authenticated;
create function public.uniion_document_job(p_org uuid,p_id uuid,p_version integer,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$declare j uniion_private.document_export_jobs;begin
 perform public.uniion_document_export(p_org,p_id,p_version,'prepare');
 if p_action not in ('start','status','claim') or p_action is null then raise insufficient_privilege;end if;
 if p_action='start' then insert into uniion_private.document_export_jobs(organization_id,resource_id,version,requester) values(p_org,p_id,p_version,auth.uid()) on conflict do nothing;end if;
 select * into j from uniion_private.document_export_jobs where organization_id=p_org and resource_id=p_id and version=p_version and requester=auth.uid() for update;
 if not found then raise insufficient_privilege;end if;
 if p_action='claim' and (j.state in ('pending','error') or (j.state='running' and j.updated_at<now()-interval '5 minutes')) then
 update uniion_private.document_export_jobs set state='running',lease=gen_random_uuid(),updated_at=now(),error=null where id=j.id returning * into j;
 return jsonb_build_object('id',j.id,'state',j.state,'lease',j.lease);
 end if;
 return jsonb_build_object('id',j.id,'state',j.state,'result',case when p_action='status' and j.state='done' then j.result else null end,'error',j.error);
end$$;
create function public.uniion_document_job_finish(p_job uuid,p_lease uuid,p_result jsonb,p_error text) returns jsonb language plpgsql security definer set search_path='' as $$begin
 if not uniion_private.is_scanner() or (p_result is not null and octet_length(p_result::text)>29000000) or (p_error is not null and p_error not in ('pdf_overflow','unavailable')) then raise insufficient_privilege;end if;
 update uniion_private.document_export_jobs set state=case when p_result is null then 'error' else 'done' end,result=p_result,error=p_error,updated_at=now() where id=p_job and lease=p_lease and state='running';
 return jsonb_build_object('ok',found);end$$;
revoke all on function public.uniion_document_job(uuid,uuid,integer,text),public.uniion_document_job_finish(uuid,uuid,jsonb,text) from public,anon;
grant execute on function public.uniion_document_job(uuid,uuid,integer,text),public.uniion_document_job_finish(uuid,uuid,jsonb,text) to authenticated;
notify pgrst,'reload schema';commit;

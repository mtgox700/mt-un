begin;
create table uniion_private.support_files(grant_id uuid references uniion_private.support_grants,attachment uuid references public.uniion_attachments,sha256 text not null,primary key(grant_id,attachment));
alter table uniion_private.support_files enable row level security;
revoke all on uniion_private.support_files from public,anon,authenticated;
create function public.uniion_support_approve_files(p_org uuid,p_ticket uuid,p_agents uuid[],p_resources uuid[],p_until timestamptz,p_download boolean,p_attachments uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;fid uuid;a public.uniion_attachments;
begin
 if p_attachments is null or cardinality(p_attachments)>20 then raise insufficient_privilege;end if;
 result=public.uniion_support_approve(p_org,p_ticket,p_agents,p_resources,p_until,p_download);
 foreach fid in array p_attachments loop
 select * into a from public.uniion_attachments where id=fid and organization_id=p_org;
 if not found or not(a.resource_id=any(p_resources)) or not a.ready or a.scan_status<>'clean' then raise insufficient_privilege;end if;
 insert into uniion_private.support_files values((result->>'id')::uuid,a.id,a.sha256);
 end loop;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.files.selected',jsonb_build_object('ticket',p_ticket,'grant',result->>'id','attachments',p_attachments));
 return result;
end $$;
create function public.uniion_support_file_get(p_org uuid,p_ticket uuid,p_grant uuid,p_attachment uuid,p_preview boolean,p_audit boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uniion_private.support_tickets;g uniion_private.support_grants;i uniion_private.support_items;a public.uniion_attachments;p_resource uuid;p_download boolean;
begin
 if p_preview is null or p_audit is null then raise insufficient_privilege;end if;p_download=not p_preview;
 select * into a from public.uniion_attachments where id=p_attachment and organization_id=p_org;
 if not found or not a.ready or a.scan_status<>'clean' or (p_preview and a.mime not in ('application/pdf','image/png','image/jpeg')) or not exists(select 1 from uniion_private.support_files where grant_id=p_grant and attachment=a.id and sha256=a.sha256) then raise insufficient_privilege;end if;
 p_resource=a.resource_id;
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or p_download is null or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for share;
 if not found or t.state<>'open' or not uniion_private.support_assigned(t.id,auth.uid()) then raise insufficient_privilege;end if;
 select * into g from uniion_private.support_grants where id=p_grant and ticket=t.id for share;
 if not found or g.revoked_at is not null or auth.uid()=any(g.excluded) or g.expires<=now() or not(auth.uid()=any(g.agents)) or (p_download and not g.download) or not uniion_private.authority(p_org,g.creator,'share') or (p_download and not uniion_private.authority(p_org,g.creator,'download')) then raise insufficient_privilege;end if;
 select * into i from uniion_private.support_items where grant_id=g.id and resource=p_resource;
 if not found or not uniion_private.actor_resource(p_org,p_resource,g.creator,false) or not exists(select 1 from public.uniion_resources where id=p_resource and organization_id=p_org and external_share_allowed) then raise insufficient_privilege;end if;
 if p_audit then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_preview then 'support.file.previewed' else 'support.file.downloaded' end,jsonb_build_object('ticket',t.id,'grant',g.id,'attachment',a.id));end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'filename',a.filename,'mime',a.mime,'size',a.size,'sha256',a.sha256);
end $$;
alter function public.uniion_support_context(uuid) rename to uniion_support_context_without_files;
revoke all on function public.uniion_support_context_without_files(uuid) from public,anon,authenticated;
create function public.uniion_support_context(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;ts jsonb='[]';gs jsonb;t jsonb;g jsonb;files jsonb;
begin
 result=public.uniion_support_context_without_files(p_org);
 result=result||jsonb_build_object('attachments',case when (result->>'manage')::boolean then coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'resource',a.resource_id,'filename',a.filename)) from public.uniion_attachments a where a.organization_id=p_org and a.ready and a.scan_status='clean' and exists(select 1 from jsonb_array_elements(result->'resources') r where r->>'id'=a.resource_id::text)),'[]') else '[]'::jsonb end);
 for t in select value from jsonb_array_elements(result->'tickets') loop
 gs='[]';
 for g in select value from jsonb_array_elements(t->'grants') loop
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'size',a.size,'previewable',a.ready and a.scan_status='clean' and a.mime in ('application/pdf','image/png','image/jpeg'),'downloadable',a.ready and a.scan_status='clean' and (g->>'download')::boolean)),'[]') into files from uniion_private.support_files f join public.uniion_attachments a on a.id=f.attachment where f.grant_id=(g->>'id')::uuid and exists(select 1 from jsonb_array_elements(g->'items') i where i->>'id'=a.resource_id::text);
 gs=gs||jsonb_build_array(g||jsonb_build_object('attachments',files));end loop;
 ts=ts||jsonb_build_array(t||jsonb_build_object('grants',gs));end loop;
 return result||jsonb_build_object('tickets',ts);
end $$;
revoke all on function public.uniion_support_context(uuid),public.uniion_support_file_get(uuid,uuid,uuid,uuid,boolean,boolean),public.uniion_support_approve_files(uuid,uuid,uuid[],uuid[],timestamptz,boolean,uuid[]) from public,anon;
grant execute on function public.uniion_support_context(uuid),public.uniion_support_file_get(uuid,uuid,uuid,uuid,boolean,boolean),public.uniion_support_approve_files(uuid,uuid,uuid[],uuid[],timestamptz,boolean,uuid[]) to authenticated;
commit;

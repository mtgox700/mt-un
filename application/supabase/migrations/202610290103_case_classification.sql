begin;
create table uniion_private.case_links(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, resource_id uuid not null,
 convocation uuid not null references uniion_private.agenda_convocations, file text not null default '',
 actor uuid not null references auth.users, created_at timestamptz not null default now(),
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id),
 unique(organization_id,resource_id,convocation,file)
);
alter table uniion_private.case_links enable row level security;
revoke all on uniion_private.case_links from public,anon,authenticated;
create function uniion_private.case_source(o uuid,c uuid,f text) returns jsonb language plpgsql stable set search_path='' as $$
declare item jsonb; document jsonb;
begin
 select value into item from jsonb_array_elements(public.uniion_convocation_history(o)) where value->>'id'=c::text;
 if item is null then return null;end if;
 if f<>'' then
  select value into document from jsonb_array_elements(public.uniion_convocation_files(o,c,null)) where value->>'id'=f;
  if document is null then return null;end if;
  if f not in ('pdf','ics') then perform public.uniion_attachment_get(o,f::uuid,null,false,true);end if;
  return jsonb_build_object('name',document->>'name');
 end if;
 return jsonb_build_object('name',item->>'subject','body',item->>'body');
exception when insufficient_privilege then return null;
end$$;
revoke all on function uniion_private.case_source(uuid,uuid,text) from public,anon,authenticated;
create function public.uniion_case_classify(p_org uuid,p_case uuid,p_expected integer,p_convocation uuid,p_file text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare source jsonb; v integer; ident uuid;
begin
 perform public.uniion_case_files(p_org,p_case);
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 source=uniion_private.case_source(p_org,p_convocation,p_file);
 if source is null or p_file is null then raise insufficient_privilege;end if;
 select version into v from public.uniion_resources where id=p_case and organization_id=p_org for update;
 select id into ident from uniion_private.case_links where organization_id=p_org and resource_id=p_case and convocation=p_convocation and file=p_file;
 if ident is not null then return jsonb_build_object('id',ident,'already',true);end if;
 if p_expected is distinct from v then raise serialization_failure;end if;
 insert into uniion_private.case_links(organization_id,resource_id,convocation,file,actor) values(p_org,p_case,p_convocation,p_file,auth.uid()) returning id into ident;
 update public.uniion_resources set version=version+1 where id=p_case;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.classified',jsonb_build_object('case',p_case,'link',ident));
 return jsonb_build_object('id',ident,'already',false);
end$$;
revoke all on function public.uniion_case_classify(uuid,uuid,integer,uuid,text) from public,anon;
grant execute on function public.uniion_case_classify(uuid,uuid,integer,uuid,text) to authenticated;
create function public.uniion_case_link(p_org uuid,p_case uuid,p_link uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare l uniion_private.case_links;s jsonb;
begin
 perform public.uniion_case_files(p_org,p_case);
 select * into l from uniion_private.case_links where id=p_link and organization_id=p_org and resource_id=p_case;
 if not found or l.file='' then raise insufficient_privilege;end if;
 s=uniion_private.case_source(p_org,l.convocation,l.file);
 if s is null then raise insufficient_privilege;end if;
 return jsonb_build_object('convocation',l.convocation,'file',l.file);
end$$;
revoke all on function public.uniion_case_link(uuid,uuid,uuid) from public,anon;
grant execute on function public.uniion_case_link(uuid,uuid,uuid) to authenticated;
create function uniion_private.case_classified_files(o uuid,c uuid) returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'filename',s->>'name','created',l.created_at,'size',0,'status','reference','classified',true,'version',1,'maxVersion',1,'versions','[]'::jsonb)),'[]') from uniion_private.case_links l cross join lateral (select uniion_private.case_source(o,l.convocation,l.file) s) checked where l.organization_id=o and l.resource_id=c and l.file<>'' and s is not null
$$;
revoke all on function uniion_private.case_classified_files(uuid,uuid) from public,anon,authenticated;
alter function public.uniion_case_files(uuid,uuid,uuid) rename to uniion_case_files_before_links;
revoke all on function public.uniion_case_files_before_links(uuid,uuid,uuid) from public,anon,authenticated;
create function public.uniion_case_files(p_org uuid,p_case uuid,p_attachment uuid default null) returns jsonb language sql security definer set search_path='' as $$
 select base||jsonb_build_object('files',(base->'files')||uniion_private.case_classified_files(p_org,p_case)) from (select public.uniion_case_files_before_links(p_org,p_case,p_attachment) base) t
$$;
revoke all on function public.uniion_case_files(uuid,uuid,uuid) from public,anon;
grant execute on function public.uniion_case_files(uuid,uuid,uuid) to authenticated;
create or replace function uniion_private.case_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$
 select base||uniion_private.case_assignment_context(o,rid)||jsonb_build_object('fileCount',jsonb_array_length(uniion_private.case_file_rows(o,rid))+jsonb_array_length(uniion_private.case_classified_files(o,rid)),'timeline',(base->'timeline')||coalesce((select jsonb_agg(jsonb_build_object('date',to_char(l.created_at at time zone 'Europe/Paris','DD/MM/YYYY HH24:MI'),'title','Message classé · '||(s->>'name'),'body',s->>'body') order by l.created_at) from uniion_private.case_links l cross join lateral (select uniion_private.case_source(o,l.convocation,l.file) s) checked where l.organization_id=o and l.resource_id=rid and l.file='' and s is not null),'[]')) from (select uniion_private.case_json_base(o,rid) base) t
$$;
notify pgrst,'reload schema';
commit;

begin;
create or replace function public.uniion_case_classify(p_org uuid,p_case uuid,p_expected integer,p_convocation uuid,p_file text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare source jsonb; v integer; ident uuid;
begin
 perform public.uniion_case_files(p_org,p_case);
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 source=uniion_private.case_source(p_org,p_convocation,p_file);
 if source is null or p_file is null then raise insufficient_privilege;end if;
 select version into v from public.uniion_resources where id=p_case and organization_id=p_org for update;
 select id into ident from uniion_private.case_links where organization_id=p_org and resource_id=p_case and convocation=p_convocation and file=p_file;
 if ident is not null and exists(select 1 from uniion_private.case_links where id=ident and withdrawn) then raise insufficient_privilege;end if;
 if ident is not null then return jsonb_build_object('id',ident,'already',true);end if;
 if p_expected is distinct from v then raise serialization_failure;end if;
 insert into uniion_private.case_links(organization_id,resource_id,convocation,file,actor) values(p_org,p_case,p_convocation,p_file,auth.uid()) returning id into ident;
 update public.uniion_resources set version=version+1 where id=p_case;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.classified',jsonb_build_object('case',p_case,'link',ident));
 return jsonb_build_object('id',ident,'already',false);
end$$;
create or replace function uniion_private.case_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$
 select base||uniion_private.case_assignment_context(o,rid)||jsonb_build_object('fileCount',jsonb_array_length(uniion_private.case_file_rows(o,rid))+jsonb_array_length(uniion_private.case_classified_files(o,rid)),'timeline',(base->'timeline')||coalesce((select jsonb_agg(jsonb_build_object('link',l.id,'date',to_char(l.created_at at time zone 'Europe/Paris','DD/MM/YYYY HH24:MI'),'title','Message classé · '||(s->>'name'),'body',s->>'body') order by l.created_at) from uniion_private.case_links l cross join lateral (select uniion_private.case_source(o,l.convocation,l.file) s) checked where l.organization_id=o and l.resource_id=rid and l.file='' and not l.withdrawn and s is not null),'[]')) from (select uniion_private.case_json_base(o,rid) base) t
$$;
notify pgrst,'reload schema';
commit;

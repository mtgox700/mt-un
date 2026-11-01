begin;
create table uniion_private.ai_case_derivatives(
 organization_id uuid not null,request uuid not null,actor uuid not null,resource uuid not null unique,refs jsonb not null,
 primary key(organization_id,actor,request),foreign key(organization_id,resource) references public.uniion_resources(organization_id,id)
);
alter table uniion_private.ai_case_derivatives enable row level security;
revoke all on uniion_private.ai_case_derivatives from public,anon,authenticated;
create function uniion_private.ai_refs_readable(o uuid,refs jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare ref jsonb;
begin
 if jsonb_typeof(refs)<>'array' or jsonb_array_length(refs) not between 1 and 8 then return false;end if;
 for ref in select value from jsonb_array_elements(refs) loop
  if ref->>'kind'='case' then perform public.uniion_cases(o,'get',jsonb_build_object('id',ref->>'id'));
  elsif ref->>'kind'='document' then perform public.uniion_documents(o,'get',jsonb_build_object('id',ref->>'id'));
  elsif ref->>'kind'='message' then perform public.uniion_messaging(o,'locate',jsonb_build_object('id',ref->>'id','seq',ref->>'seq'));
  else perform public.uniion_ai_native(o,ref->>'kind',(ref->>'id')::uuid);end if;
 end loop;
 return true;
exception when insufficient_privilege or invalid_text_representation then return false;
end$$;
alter function uniion_private.actor_resource(uuid,uuid,uuid,boolean) rename to actor_resource_before_ai_case;
create function uniion_private.actor_resource(org uuid,res uuid,who uuid,wr boolean default false) returns boolean language plpgsql security definer set search_path='' as $$
declare d uniion_private.ai_case_derivatives;
begin
 if not uniion_private.actor_resource_before_ai_case(org,res,who,wr) then return false;end if;
 select * into d from uniion_private.ai_case_derivatives where resource=res;
 if not found then return true;end if;
 -- A private conversation stays private even if a generic grant is added.
 return d.organization_id=org and d.actor=who and who=auth.uid() and uniion_private.ai_refs_readable(org,d.refs);
end$$;
alter function uniion_private.resource_access(uuid,uuid,boolean) rename to resource_access_before_ai_case;
create function uniion_private.resource_access(org uuid,resource uuid,write_access boolean) returns boolean language sql security definer set search_path='' as $$
 select uniion_private.resource_access_before_ai_case(org,resource,write_access) and (not exists(select 1 from uniion_private.ai_case_derivatives where resource=resource_access.resource) or uniion_private.actor_resource(org,resource,auth.uid(),write_access))
$$;
alter function uniion_private.share_access(uuid,uuid,uuid,boolean) rename to share_access_before_ai_case;
create function uniion_private.share_access(sid uuid,res uuid,who uuid,dl boolean default false) returns boolean language sql security definer set search_path='' as $$select not exists(select 1 from uniion_private.ai_case_derivatives where resource=res) and uniion_private.share_access_before_ai_case(sid,res,who,dl)$$;
create function public.uniion_ai_case_create(p_org uuid,p_request uuid,p_refs jsonb,p_title text,p_text text) returns jsonb language plpgsql security definer set search_path='' as $$
declare existing uuid;row jsonb;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||auth.uid()::text||p_request::text,0));
 select resource into existing from uniion_private.ai_case_derivatives where organization_id=p_org and actor=auth.uid() and request=p_request;
 if found then perform public.uniion_cases(p_org,'get',jsonb_build_object('id',existing));return jsonb_build_object('id',existing);end if;
 if not uniion_private.ai_refs_readable(p_org,p_refs) then raise insufficient_privilege;end if;
 row=public.uniion_cases(p_org,'create',jsonb_build_object('title',p_title,'long',p_text,'tag','Juridique','due',''));
 insert into uniion_private.ai_case_derivatives values(p_org,p_request,auth.uid(),(row->>'id')::uuid,p_refs);
 return jsonb_build_object('id',row->>'id');
end$$;
revoke all on function uniion_private.ai_refs_readable(uuid,jsonb),uniion_private.actor_resource(uuid,uuid,uuid,boolean),uniion_private.actor_resource_before_ai_case(uuid,uuid,uuid,boolean),uniion_private.resource_access(uuid,uuid,boolean),uniion_private.resource_access_before_ai_case(uuid,uuid,boolean),uniion_private.share_access(uuid,uuid,uuid,boolean),uniion_private.share_access_before_ai_case(uuid,uuid,uuid,boolean) from public,anon,authenticated;
revoke all on function public.uniion_ai_case_create(uuid,uuid,jsonb,text,text) from public,anon;
grant execute on function public.uniion_ai_case_create(uuid,uuid,jsonb,text,text) to authenticated;
notify pgrst,'reload schema';commit;

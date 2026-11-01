begin;
create table uniion_private.ai_draft_applications(
 organization_id uuid not null references public.uniion_organizations,
 actor uuid not null references auth.users, request_id uuid not null,
 resource_id uuid not null, version integer not null, kind text not null check(kind in ('case','document')),
 created_at timestamptz not null default now(), primary key(organization_id,actor,request_id),
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id)
);
alter table uniion_private.ai_draft_applications enable row level security;
revoke all on uniion_private.ai_draft_applications from public,anon,authenticated;
create function public.uniion_ai_draft_apply(p_org uuid,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare receipt uniion_private.ai_draft_applications;r public.uniion_resources;rid uuid;result jsonb;doc jsonb;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 if p_action is null or p_action not in ('status','apply') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='status' and p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
 if p_action='apply' and (not(p_payload ?& array['id','source','kind','version','text']) or p_payload-array['id','source','kind','version','text']<>'{}') then raise insufficient_privilege;end if;
 rid=(p_payload->>'id')::uuid;if rid is null then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||auth.uid()::text||rid::text,0));
 select * into receipt from uniion_private.ai_draft_applications where organization_id=p_org and actor=auth.uid() and request_id=rid;
 if found then
  if not uniion_private.actor_resource(p_org,receipt.resource_id,auth.uid(),false) then raise insufficient_privilege;end if;
  return jsonb_build_object('applied',true,'resource',receipt.resource_id,'version',receipt.version,'kind',receipt.kind);
 end if;
 if p_action='status' then return jsonb_build_object('applied',false);end if;
 if p_payload->>'kind' is null or p_payload->>'kind' not in ('case','document') or jsonb_typeof(p_payload->'text') is distinct from 'string' or length(btrim(p_payload->>'text')) not between 1 and 6000 then raise insufficient_privilege;end if;
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'source')::uuid for update;
 if not found or r.version is distinct from (p_payload->>'version')::integer or not uniion_private.actor_resource(p_org,r.id,auth.uid(),true) then raise insufficient_privilege;end if;
 if p_payload->>'kind'='case' then
  -- Classified sources can have narrower ACL than the dossier. Never flatten them into an ordinary note.
  if r.module<>'dossiers' or exists(select 1 from uniion_private.case_links where organization_id=p_org and resource_id=r.id) or length(p_payload->>'text')>5000 then raise insufficient_privilege;end if;
  result=public.uniion_cases(p_org,'note',jsonb_build_object('id',r.id,'version',r.version,'text',p_payload->>'text'));
 else
  if r.module<>'documents' then raise insufficient_privilege;end if;
  doc=public.uniion_documents(p_org,'get',jsonb_build_object('id',r.id));
  if doc->>'status'<>'Brouillon' then raise insufficient_privilege;end if;
  result=public.uniion_documents(p_org,'save',jsonb_build_object('id',r.id,'version',r.version,'document',r.body||jsonb_build_object('blocks',(r.body->'blocks')||jsonb_build_array(jsonb_build_object('id','ai-'||rid::text,'type','p','text',p_payload->>'text')))));
 end if;
 insert into uniion_private.ai_draft_applications values(p_org,auth.uid(),rid,r.id,(result->>'version')::integer,p_payload->>'kind',now());
 return jsonb_build_object('applied',true,'resource',r.id,'version',result->'version','kind',p_payload->>'kind');
end$$;
revoke all on function public.uniion_ai_draft_apply(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_ai_draft_apply(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

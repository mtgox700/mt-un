begin;
-- Explicitly enrolled, fully fictitious tenants only. No public enrollment endpoint.
create table uniion_private.ai_interactive_recipes(organization_id uuid primary key references public.uniion_organizations,enabled boolean not null default false,version int not null default 1);
alter table uniion_private.ai_interactive_recipes enable row level security;
revoke all on uniion_private.ai_interactive_recipes from public,anon,authenticated;
create function public.uniion_ai_interactive(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r uniion_private.ai_interactive_recipes;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 select * into r from uniion_private.ai_interactive_recipes where organization_id=p_org and enabled;
 if not found or not exists(select 1 from auth.users where id=auth.uid() and email like '%@uniion-local.example') then raise insufficient_privilege;end if;
 return jsonb_build_object('allowed',true,'version',r.version,'scope','fictitious-tenant');
end$$;
revoke all on function public.uniion_ai_interactive(uuid) from public,anon;
grant execute on function public.uniion_ai_interactive(uuid) to authenticated;
-- A new native object in an explicitly fictitious tenant can be used without a manual
-- fingerprint registration. Ordinary tenants retain exact per-version certification.
alter function public.uniion_ai_recipe(uuid,text,jsonb) rename to uniion_ai_recipe_certified151;
revoke all on function public.uniion_ai_recipe_certified151(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_ai_recipe(p_org uuid,p_action text,p_refs jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare item jsonb;
begin
 if p_action<>'check' or not exists(select 1 from uniion_private.ai_interactive_recipes where organization_id=p_org and enabled) then return public.uniion_ai_recipe_certified151(p_org,p_action,p_refs);end if;
 perform public.uniion_ai_interactive(p_org);
 if jsonb_typeof(p_refs)<>'array' or jsonb_array_length(p_refs) not between 1 and 8 then raise insufficient_privilege;end if;
 for item in select value from jsonb_array_elements(p_refs) loop
  if jsonb_typeof(item)<>'object' or not(item ?& array['kind','id','fingerprint']) or item-array['kind','id','seq','fingerprint']<>'{}' or item->>'fingerprint' !~ '^[0-9a-f]{64}$' then raise insufficient_privilege;end if;
  if item->>'kind'='case' then perform public.uniion_cases(p_org,'get',jsonb_build_object('id',item->>'id'));
  elsif item->>'kind'='document' then perform public.uniion_documents(p_org,'get',jsonb_build_object('id',item->>'id'));
  elsif item->>'kind'='message' then perform public.uniion_messaging(p_org,'locate',jsonb_build_object('id',item->>'id','seq',item->>'seq'));
  else perform public.uniion_ai_native(p_org,item->>'kind',(item->>'id')::uuid);end if;
 end loop;
 return '{"allowed":true}';
end$$;
revoke all on function public.uniion_ai_recipe(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_ai_recipe(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;

begin;
create or replace function public.uniion_ai_recipe(p_org uuid,p_action text,p_refs jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare item jsonb; f uniion_private.ai_recipe_sources; result jsonb='[]'::jsonb; projection jsonb;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 if p_action is null or p_action not in ('catalog','check') or jsonb_typeof(p_refs) is distinct from 'array' then raise insufficient_privilege;end if;
 if p_action='catalog' then
  if p_refs<>'[]' then raise insufficient_privilege;end if;
  for f in select * from uniion_private.ai_recipe_sources where organization_id=p_org and enabled order by kind,id,seq limit 64 loop
   begin
    if f.kind='case' then projection=public.uniion_cases(p_org,'get',jsonb_build_object('id',f.id));
    elsif f.kind='document' then projection=public.uniion_documents(p_org,'get',jsonb_build_object('id',f.id));
    else projection=public.uniion_messaging(p_org,'locate',jsonb_build_object('id',f.id,'seq',f.seq));
    end if;
    result=result||jsonb_build_array(jsonb_build_object('kind',f.kind,'id',f.id)||case when f.kind='message' then jsonb_build_object('seq',f.seq) else '{}'::jsonb end);
   exception when insufficient_privilege then null;
   end;
  end loop;
  return result;
 end if;
 if jsonb_array_length(p_refs) not between 1 and 8 then raise insufficient_privilege;end if;
 for item in select value from jsonb_array_elements(p_refs) loop
  if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['kind','id','fingerprint'])
   or item-array['kind','id','seq','fingerprint']<>'{}'
   or not exists(select 1 from uniion_private.ai_recipe_sources r where r.organization_id=p_org and r.kind=item->>'kind' and r.id::text=item->>'id' and r.seq=coalesce(item->>'seq','') and r.fingerprint=item->>'fingerprint' and r.enabled) then raise insufficient_privilege;end if;
  if item->>'kind'='case' then perform public.uniion_cases(p_org,'get',jsonb_build_object('id',item->>'id'));
  elsif item->>'kind'='document' then perform public.uniion_documents(p_org,'get',jsonb_build_object('id',item->>'id'));
  else perform public.uniion_messaging(p_org,'locate',jsonb_build_object('id',item->>'id','seq',item->>'seq'));end if;
 end loop;
 return jsonb_build_object('allowed',true);
end $$;
notify pgrst,'reload schema';commit;

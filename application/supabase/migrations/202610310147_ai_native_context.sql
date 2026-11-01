begin;
alter table uniion_private.ai_recipe_sources drop constraint ai_recipe_sources_kind_check;
alter table uniion_private.ai_recipe_sources add constraint ai_recipe_sources_kind_check check(kind in ('case','document','message','agenda','adherents','workspace','reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis'));
create function public.uniion_ai_native(p_org uuid,p_kind text,p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if p_kind='agenda' then
  select value into result from jsonb_array_elements(public.uniion_agenda_list(p_org)) where value->>'id'=p_id::text;
 elsif p_kind='adherents' then
  select value into result from jsonb_array_elements(public.uniion_adherents(p_org,'list','{}')->'rows') where value->>'id'=p_id::text;
 elsif p_kind='workspace' then
  perform public.uniion_module_use(p_org,'assistant');
  if p_id<>p_org then raise insufficient_privilege;end if;
  select jsonb_build_object('title',name,'description','Espace de travail uniion. Les droits des modules et des ressources sont contrôlés séparément.','version',1) into result from public.uniion_organizations where id=p_org and active;
 else
  result=public.uniion_business_records(p_org,p_kind,'get',jsonb_build_object('id',p_id));
 end if;
 if result is null then raise insufficient_privilege;end if;
 return result;
end$$;
revoke all on function public.uniion_ai_native(uuid,text,uuid) from public,anon;
grant execute on function public.uniion_ai_native(uuid,text,uuid) to authenticated;

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
    elsif f.kind='message' then projection=public.uniion_messaging(p_org,'locate',jsonb_build_object('id',f.id,'seq',f.seq));
    else projection=public.uniion_ai_native(p_org,f.kind,f.id);
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
  elsif item->>'kind'='message' then perform public.uniion_messaging(p_org,'locate',jsonb_build_object('id',item->>'id','seq',item->>'seq'));
  else perform public.uniion_ai_native(p_org,item->>'kind',(item->>'id')::uuid);end if;
 end loop;
 return jsonb_build_object('allowed',true);
end $$;
notify pgrst,'reload schema';commit;

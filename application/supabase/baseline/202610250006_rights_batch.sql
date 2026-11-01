begin;
create function public.uniion_rights_batch(p_org uuid,p_user uuid,p_changes jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c jsonb;
begin
 if jsonb_typeof(p_changes)<>'array' or jsonb_array_length(p_changes)>100 then raise check_violation; end if;
 for c in select value from jsonb_array_elements(p_changes) loop
  perform public.uniion_rights_change(p_org,p_user,c->>'type',c->>'module',c->>'permission',(c->>'enabled')::boolean,(c->>'resource')::uuid,(c->>'until')::timestamptz,coalesce((c->>'history')::boolean,false));
 end loop;
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.uniion_rights_batch(uuid,uuid,jsonb) from public,anon;
grant execute on function public.uniion_rights_batch(uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

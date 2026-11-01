begin;
-- PostgreSQL policies retain function OIDs on rename. Rebind them to the guard.
do $$declare p record;q text;c text;
begin
 for p in select pol.polname,ns.nspname,cl.relname,pg_get_expr(pol.polqual,pol.polrelid) qual,pg_get_expr(pol.polwithcheck,pol.polrelid) chk from pg_policy pol join pg_class cl on cl.oid=pol.polrelid join pg_namespace ns on ns.oid=cl.relnamespace loop
  q=replace(replace(replace(p.qual,'resource_access_before_ai_case','resource_access'),'actor_resource_before_ai_case','actor_resource'),'share_access_before_ai_case','share_access');
  c=replace(replace(replace(p.chk,'resource_access_before_ai_case','resource_access'),'actor_resource_before_ai_case','actor_resource'),'share_access_before_ai_case','share_access');
  if q is distinct from p.qual or c is distinct from p.chk then
   execute format('alter policy %I on %I.%I',p.polname,p.nspname,p.relname)||case when q is not null then ' using ('||q||')' else '' end||case when c is not null then ' with check ('||c||')' else '' end;
  end if;
 end loop;
end$$;
-- Policies execute this entry point as authenticated; its implementation is definer-owned.
grant execute on function uniion_private.resource_access(uuid,uuid,boolean) to authenticated;
notify pgrst,'reload schema';commit;

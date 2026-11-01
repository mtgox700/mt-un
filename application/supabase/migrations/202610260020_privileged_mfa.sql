begin;
-- Gate the exposed privileged commands, not ordinary shared-resource reads.
-- Preserve each existing function body, ownership, grants and business checks.
do $migration$
declare item record;definition text;changed integer=0;
begin
 for item in
  select p.oid,p.proname,l.lanname from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
  where n.nspname='public' and p.proname=any(array['uniion_rights_change','uniion_rights_batch','uniion_share_create','uniion_share_accept','uniion_share_revoke','uniion_directory_authorize','uniion_admin_context'])
 loop
  if item.lanname<>'plpgsql' then raise exception 'Unexpected privileged function language';end if;
  definition=pg_get_functiondef(item.oid);
  if position('uniion_privileged_mfa_gate' in definition)>0 then raise exception 'Migration already applied';end if;
  definition=regexp_replace(definition,'\m[Bb][Ee][Gg][Ii][Nn]\M',E'BEGIN\n -- uniion_privileged_mfa_gate\n IF NOT uniion_private.session_allowed() OR auth.jwt()->>''aal'' IS DISTINCT FROM ''aal2'' THEN RAISE insufficient_privilege; END IF;');
  if position('uniion_privileged_mfa_gate' in definition)=0 then raise exception 'Function body not recognized';end if;
  execute definition;changed=changed+1;
 end loop;
 if changed<>7 then raise exception 'Expected seven exposed privileged functions, got %',changed;end if;
end $migration$;
notify pgrst,'reload schema';
commit;

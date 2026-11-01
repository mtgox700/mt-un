begin;
create function uniion_private.identity_in_scope() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.uniion_memberships where user_id=auth.uid())
 or exists(select 1 from uniion_private.platform_operators where user_id=auth.uid())
$$;
revoke all on function uniion_private.identity_in_scope() from public,anon,authenticated,service_role;
do $migration$
declare item record;definition text;
begin
 for item in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('uniion_lost_factor_request','uniion_mfa_authorize_factor') loop
  definition=pg_get_functiondef(item.oid);
  execute regexp_replace(definition,'\m[Bb][Ee][Gg][Ii][Nn]\M',E'BEGIN\n IF NOT uniion_private.identity_in_scope() THEN RAISE insufficient_privilege; END IF;');
 end loop;
end $migration$;
notify pgrst,'reload schema';
commit;

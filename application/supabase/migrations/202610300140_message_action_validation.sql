begin;
-- SQL NULL must not fall through a three-valued IF into search/read actions.
do $$declare d text;needle text;begin
 d=pg_get_functiondef('public.uniion_messaging(uuid,text,jsonb)'::regprocedure);
 needle=E'begin\n if p_action not in (''search'',''targets'')';
 if strpos(d,needle)=0 then raise exception 'Expected messaging dispatcher missing';end if;
 execute replace(d,needle,E'begin\n if p_action is null or jsonb_typeof(p_payload) is distinct from ''object'' then raise insufficient_privilege;end if;\n if p_action not in (''search'',''targets'')');
end$$;
notify pgrst,'reload schema';commit;

-- Contrôles sur le schéma migré (constats R31 et revue SQL). Chaque requête doit renvoyer 0.
\set ON_ERROR_STOP 1
select 'R31 politiques RLS liées à une fonction *_before_*' controle, count(*) from pg_policy where pg_get_expr(polqual,polrelid) ~ '_before_' or coalesce(pg_get_expr(polwithcheck,polrelid),'') ~ '_before_'
union all select 'triggers liés à une fonction *_before_*', count(*) from pg_trigger t join pg_proc p on p.oid=t.tgfoid where p.proname ~ '_before_'
union all select 'SECURITY DEFINER sans search_path', count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','uniion_private') and p.prosecdef and not exists(select 1 from unnest(coalesce(p.proconfig,'{}')) c where c like 'search_path=%')
union all select 'fonctions exécutables par anon', count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','uniion_private') and has_function_privilege('anon',p.oid,'execute')
union all select 'tables public sans RLS', count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
union all select 'tables uniion_private sans RLS lisibles par authenticated', count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='uniion_private' and c.relkind='r' and not c.relrowsecurity and has_table_privilege('authenticated',c.oid,'select');

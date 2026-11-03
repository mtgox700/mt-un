# Contrôle du schéma migré

`run.sh` applique les migrations de `supabase/baseline` puis `supabase/migrations` sur un Postgres 17 vierge, avec des stubs minimaux des schémas Supabase (`supabase_stubs.sql` : rôles, `auth`, `storage`, `extensions`). Il vérifie :

- que chaque `replace()` des migrations par substitution de texte trouve son fragment avant d'être exécuté (`check_substitutions.py`, constat R52) ;
- les invariants de `check_schema.sql` : aucune politique RLS ni trigger liés à une fonction `*_before_*` (R31), tout `SECURITY DEFINER` avec `search_path`, aucune fonction exécutable par `anon`, RLS sur toutes les tables `public` ;
- que le schéma obtenu est identique à `schema.sql`, versionné.

Après une nouvelle migration volontaire : `application/ci/schema/run.sh --update`, puis relire le diff de `schema.sql`.

Limite : les stubs ne remplacent pas une pile Supabase. Les comportements d'Auth, de Storage et de PostgREST ne sont pas testés ici.

#!/usr/bin/env bash
# Applique toutes les migrations sur un Postgres vierge, vérifie les substitutions (R52),
# les invariants du schéma (R31 et revue SQL), puis compare au schéma versionné.
# Usage : application/ci/schema/run.sh [--update]
set -euo pipefail
cd "$(dirname "$0")"
C=uniion-schema-ci
docker rm -f "$C" >/dev/null 2>&1 || true
docker run -d --name "$C" -e POSTGRES_PASSWORD=ci postgres:17-alpine >/dev/null
trap 'docker rm -f "$C" >/dev/null 2>&1 || true' EXIT
for _ in $(seq 1 60); do docker exec "$C" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 1; done
sleep 2
docker exec -i "$C" psql -q -X -U postgres -v ON_ERROR_STOP=1 < supabase_stubs.sql
python3 check_substitutions.py "$C"
out=$(docker exec -i "$C" psql -X -At -F'|' -U postgres < check_schema.sql)
echo "$out"
if echo "$out" | awk -F'|' '$2!=0{bad=1} END{exit !bad}'; then echo "Invariant de schéma non respecté" >&2; exit 1; fi
python3 check_restore_journal.py "$C"
docker exec -i "$C" psql -q -X -U postgres -v ON_ERROR_STOP=1 < check_behaviour.sql
docker exec "$C" pg_dump -U postgres --schema-only --no-owner --no-privileges -n public -n uniion_private | grep -vE "^\\\\(un)?restrict " > schema.current.sql
if [ "${1:-}" = "--update" ]; then mv schema.current.sql schema.sql; echo "schema.sql mis à jour"; exit 0; fi
if ! diff -q schema.sql schema.current.sql >/dev/null; then
  echo "Le schéma migré diffère de schema.sql : relancer avec --update si le changement est voulu" >&2
  diff -u schema.sql schema.current.sql | head -80 >&2; exit 1
fi
rm -f schema.current.sql; echo "Schéma conforme à schema.sql"
python3 check_access_equivalence.py
python3 check_search_equivalence.py

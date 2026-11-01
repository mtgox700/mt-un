#!/usr/bin/env bash
# Test de restauration (trimestriel obligatoire, EXPLOITATION.md §3). Restaure la dernière
# sauvegarde dans un Postgres jetable, compare des comptages et vérifie la chaîne d'audit.
# Produit un compte rendu daté dans /srv/uniion/restaurations/.
set -euo pipefail
cd /srv/uniion/supabase
set -a; source .env; set +a
export RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
mkdir -p /srv/uniion/restaurations
CR=/srv/uniion/restaurations/$(date +%F)-restauration.md
T0=$(date +%s)

docker rm -f uniion-restore &>/dev/null || true
docker run -d --name uniion-restore -e POSTGRES_PASSWORD=restore supabase/postgres:15.8.1.060 >/dev/null
until docker exec uniion-restore pg_isready -U postgres &>/dev/null; do sleep 2; done
SNAP=$(restic snapshots --tag base --latest 1 --json | jq -r '.[0].short_id')
restic dump "$SNAP" uniion.dump | docker exec -i uniion-restore pg_restore -U postgres -d postgres --no-owner --exit-on-error || true

q() { docker exec "$1" psql -U postgres -d postgres -Atc "$2"; }
{
  echo "# Restauration du $(date '+%d/%m/%Y %H:%M')"
  echo; echo "Instantané : $SNAP — durée : $(( $(date +%s) - T0 )) s"
  echo; echo "| Table | Production | Restaurée |"; echo "|---|---|---|"
  for t in organisation personne dossier adherent document evenement audit; do
    echo "| $t | $(q supabase-db "select count(*) from public.$t") | $(q uniion-restore "select count(*) from public.$t") |"
  done
  echo; echo "Chaîne d'audit : $(q uniion-restore "select case when count(*) = 0 then 'intacte' else count(*) || ' rupture(s)' end from (select empreinte_prec, lag(empreinte) over (partition by organisation_id order by id) prec from public.audit) x where x.prec is not null and x.empreinte_prec is distinct from x.prec")"
  echo; echo "Écarts attendus : lignes créées depuis l'instantané (≤ 1 h). Signature de l'exploitant : ____________"
} > "$CR"
docker rm -f uniion-restore >/dev/null
echo "Compte rendu : $CR"

#!/usr/bin/env bash
# Sauvegarde chiffrée (restic, AES-256) vers un stockage objet d'un AUTRE fournisseur.
# Base : toutes les heures (perte maximale 1 h). Fichiers : chaque nuit.
# Rétention : 48 horaires, 30 quotidiennes, 12 mensuelles (EXPLOITATION.md §3).
# Usage : backup.sh base | backup.sh fichiers
set -euo pipefail
cd /srv/uniion/supabase
set -a; source .env; set +a
export RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
restic snapshots &>/dev/null || restic init

alerte() { curl -fsS -m 10 "${ALERTE_URL:-}" -d "uniion sauvegarde ÉCHEC : $1" >/dev/null 2>&1 || true; }
# Battement Uptime Kuma (moniteur « push ») : son absence déclenche l'alerte, même si le script ne démarre pas.
battement() { [ -n "${KUMA_PUSH_SAUVEGARDE:-}" ] && curl -fsS -m 10 "$KUMA_PUSH_SAUVEGARDE?status=up&msg=$1" >/dev/null 2>&1 || true; }
trap 'alerte "$1 (ligne $LINENO)"' ERR

case "${1:-base}" in
  base)
    docker exec supabase-db pg_dump -U postgres -Fc --no-owner postgres \
      | restic backup --stdin --stdin-filename uniion.dump --tag base --host "${HOTE_SAUVEGARDE:-uniion-prod}"
    restic forget --tag base --keep-hourly 48 --keep-daily 30 --keep-monthly 12 --prune --quiet
    ;;
  fichiers)
    restic backup volumes/storage --tag fichiers --host "${HOTE_SAUVEGARDE:-uniion-prod}"
    restic forget --tag fichiers --keep-daily 30 --keep-monthly 12 --prune --quiet
    restic check --read-data-subset=2% --quiet
    ;;
esac
battement "${1:-base}"

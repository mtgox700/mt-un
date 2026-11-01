#!/usr/bin/env bash
# Espace disque (seuil EXPLOITATION.md §4 : 80 %). Battement Uptime Kuma : « down » au-delà du seuil.
set -euo pipefail
set -a; source /srv/uniion/supabase/.env; set +a
P=$(df --output=pcent /srv/uniion | tail -1 | tr -dc '0-9')
S=up; [ "$P" -ge 80 ] && S=down
[ -n "${KUMA_PUSH_DISQUE:-}" ] && curl -fsS -m 10 "$KUMA_PUSH_DISQUE?status=$S&msg=${P}%25" >/dev/null

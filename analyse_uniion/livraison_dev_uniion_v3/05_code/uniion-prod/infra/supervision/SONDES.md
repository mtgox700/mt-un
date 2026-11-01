# Sondes Uptime Kuma

À créer dans l'interface Kuma après le premier lancement (compte administrateur avec double authentification). Une alerte = une notification e-mail **et** SMS à l'astreinte.

| # | Sonde | Type Kuma | Cible | Intervalle | Alerte | Seuil (EXPLOITATION §4) |
|---|---|---|---|---|---|---|
| 1 | Application | HTTP(s) | `https://app.<domaine>/` → 200 | 60 s | 2 échecs | disponibilité |
| 2 | API | HTTP(s) | `https://api.<domaine>/auth/v1/health` → 200 | 60 s | 2 échecs | disponibilité |
| 3 | Santé interne | HTTP(s), en-tête `x-sante: <SANTE_JETON>` | `https://api.<domaine>/functions/v1/sante` → 200 | 60 s | 2 échecs | rétention exécutée < 26 h ; file < 100 en attente > 30 min ; échecs IA ≤ 5 % sur 15 min |
| 4 | Sauvegarde base | Push | `KUMA_PUSH_SAUVEGARDE` | attendu toutes les 65 min | 1 absence | tout échec, immédiatement |
| 5 | Sauvegarde fichiers | Push | même URL, battement nocturne | attendu toutes les 25 h | 1 absence | tout échec |
| 6 | Disque | Push | `KUMA_PUSH_DISQUE` | toutes les 10 min (`down` ≥ 80 %) | 1 | stockage > 80 % |
| 7 | Certificats | HTTP(s) avec « expiration du certificat » | app. et api. | 1 j | < 14 jours | — |
| 8 | Recette | HTTP(s) | `https://app.recette.<domaine>/` | 5 min | 3 échecs | sans astreinte |

`ALERTE_URL` (échec immédiat de sauvegarde) pointe vers un moniteur Push dédié avec `status=down`.

## Non couverts par Kuma (lot 4 restant)

Kuma mesure la disponibilité, pas des taux. Ces trois seuils demandent l'agrégation des journaux Caddy (Grafana + Loki sur le VPS de supervision) :

- taux de 5xx > 1 % sur 5 min ;
- latence p95 des lectures > 1,5 s sur 10 min ;
- plus de 20 échecs d'authentification sur un même compte en 10 min (en attendant : limites de débit de GoTrue, actives par défaut).

Les journaux expédiés ne contiennent que méthode, route, statut, durée : aucun corps de requête, aucun paramètre (filtre Caddy `log` à appliquer avant envoi).

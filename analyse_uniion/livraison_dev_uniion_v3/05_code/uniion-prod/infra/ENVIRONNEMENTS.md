# Environnements

| | Recette | Production |
|---|---|---|
| Domaine | `app.recette.<domaine>`, `api.recette.<domaine>` | `app.<domaine>`, `api.<domaine>` |
| Machine | VPS 2 vCPU / 4 Go, même fournisseur français | VPS 4 vCPU / 16 Go / 160 Go NVMe |
| Installation | `install-vps.sh`, domaine saisi : `recette.<domaine>` | `install-vps.sh`, domaine : `<domaine>` |
| Déploiement | automatique à chaque fusion sur `main` | étiquette `v*` + approbation manuelle |
| Données | **fictives uniquement** (`seed.sql`), jamais de copie de production | réelles |
| Mistral | clé distincte, quota bas | clé de production |
| Brevo | sous-compte, envois limités aux adresses de l'équipe | compte principal |
| Sauvegardes | `HOTE_SAUVEGARDE=uniion-recette`, dépôt restic distinct | `uniion-prod` |
| Corpus | réserve « non validé » affichée | doit être entièrement vérifié (contrôle CI) |

Pas de pré-production séparée au lancement : la recette en tient lieu tant qu'il n'y a qu'une organisation pilote. À ouvrir quand plusieurs organisations sont en production (copie de la configuration de production, données fictives volumineuses pour les tests de charge).

## Environnements GitHub

Créer `recette` et `production` (Settings › Environments). `production` : approbation requise, déploiement limité aux étiquettes `v*`.

Variables par environnement : `VPS_HOST`, `VPS_HOST_KEY`, `DOMAINE`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `EXT_CLE_PUBLIQUE`.
Secrets par environnement : `VPS_SSH_KEY`, `POSTGRES_PASSWORD`, `SANTE_JETON` (lu dans le `.env` du VPS après installation).

## Livrer en production

```
git tag v1.0.0 && git push origin v1.0.0     # CI complète, puis attente d'approbation
```
Retour arrière : `ssh deploy@<vps> 'cd /srv/uniion && mv front front-bad && mv front-prev front'` ; une migration ne se défait pas, elle se corrige par une migration suivante.

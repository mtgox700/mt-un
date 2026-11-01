# uniion — dépôt de production

Application des représentants du personnel et délégués syndicaux. Supabase auto-hébergé sur VPS français.
Référence de design et de comportement : **`../../01_prototype/uniion App v3.dc.html`** (proto-v3.0, seule référence visuelle). Règles de fidélité : `../../03_fidelite/STRATEGIE.md`. Conception : `../../04_conception/`.

- **`DEPLOIEMENT.md`** — installation pas à pas : poste, recette, production, supervision
- **`RECETTE.md`** — couverture des critères d'acceptation
- **`DECISIONS.md`** — les choix techniques et pourquoi
- **`CHANTIER.md`** — avancement lot par lot

## Arborescence

```
infra/        install-vps.sh, docker-compose.override.yml, Caddyfile, .env.example, backup.sh, restore-test.sh, disque.sh,
              crontab, publier-extension.sh, ENVIRONNEMENTS.md, supervision/ (Uptime Kuma, SONDES.md)
supabase/
  migrations/ 14 migrations
  functions/  ai-ask (IA + corpus), coffre (chiffrement), membres, pieces (antivirus), file-taches, desinscription, sante, _shared
  tests/      pgTAP : cloisonnement, fonctions, lot3, lot3b (80 tests)
  seed.sql    données synthétiques de développement
front/        React + Vite + TypeScript, PWA : 13 écrans métier, chargeur d'extensions signées
.github/      CI : secrets, base, fonctions, front ; déploiement recette (main) et production (v*)
```

## Développer en local

```bash
supabase start                      # Postgres, Auth, Storage, Edge Functions en local
supabase db reset                   # applique les migrations + seed.sql
supabase test db                    # tests de cloisonnement
deno test supabase/functions/_shared/
supabase secrets set --env-file supabase/functions/.env   # AI_*, COFFRE_CLE_MAITRE, *_JETON, BREVO_API_KEY, EXPEDITEUR_*
docker run -d --name clamav -p 3310:3310 clamav/clamav:stable   # puis CLAMAV_HOST=host.docker.internal
supabase functions serve
cd front && cp .env.example .env && npm i && npm run dev
```
Comptes de démo : `sophie@demo.test` (admin) et `marc@demo.test` (trésorier), mot de passe `Demo-uniion-2026!`.
La double authentification sera demandée aux deux (rôles protégés).

## Mettre en production

1. Sur le VPS neuf (root) : `git clone <dépôt> /root/uniion && bash /root/uniion/infra/install-vps.sh`
2. Copier `/srv/uniion/supabase/.env` dans le coffre de l'équipe. **Sans `COFFRE_CLE_MAITRE`, les notes et messages sont perdus.**
3. Compléter dans ce `.env` : SMTP Brevo, `AI_API_KEY`, `RESTIC_*` ; puis `docker compose up -d`.
4. Renseigner les secrets du dépôt et pousser sur `main` : la CI applique les migrations par tunnel SSH, déploie fonctions et front (approbation manuelle).
5. Ouvrir la première organisation et ses **deux** administrateurs :
   `curl -X POST https://api.<domaine>/functions/v1/membres -H "x-ouverture: $OUVERTURE_JETON" -H 'content-type: application/json' -d '{"action":"organisation.ouvrir","nom":"…","sigle":"…","type":"section","administrateurs":[{"prenom":"…","nom":"…","email":"…"},{…}]}'`
6. Installer la crontab des sauvegardes et lancer un premier `restore-test.sh`.

## Règles non négociables

- Aucune clé `service_role` ni clé de modèle côté front — la CI casse le build.
- Aucune table sans RLS ; aucun droit `anon` sur `public` — contrôlé en CI.
- Aucun contenu métier dans les journaux techniques : identifiants opaques et empreintes seulement.
- Aucune donnée de production en recette, même anonymisée à la main.
- Studio Supabase uniquement par tunnel SSH.

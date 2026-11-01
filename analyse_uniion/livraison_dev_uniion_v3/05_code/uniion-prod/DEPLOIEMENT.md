# Déploiement — tous environnements

Guide d'installation de bout en bout : poste de développement, recette, production, supervision. À suivre dans l'ordre la première fois. Durée : environ une journée, plus les délais des fournisseurs (contrat Mistral, authentification du domaine Brevo).

Documents liés : `infra/ENVIRONNEMENTS.md` (différences recette / production), `infra/supervision/SONDES.md` (alertes), `RECETTE.md` (critères d'acceptation), `DECISIONS.md` (pourquoi).

---

## 0. Prérequis à réunir

| Élément | Pour | Remarque |
|---|---|---|
| Nom de domaine (ex. `uniion.fr`) | tous | accès à la zone DNS |
| VPS production — 4 vCPU / 16 Go / 160 Go NVMe, Ubuntu 24.04 | production | hébergeur français, datacenter en France |
| VPS recette — 2 vCPU / 4 Go, Ubuntu 24.04 | recette | même hébergeur |
| VPS supervision — 1 vCPU / 1 Go | supervision | **autre fournisseur** que la production |
| Stockage objet S3 | sauvegardes | **autre fournisseur** que la production ; un compartiment par environnement |
| Compte Mistral AI, contrat sans rétention ni entraînement, hébergement UE | IA | une clé par environnement |
| Compte Brevo, domaine expéditeur authentifié (SPF, DKIM, DMARC) | e-mails | sous-compte pour la recette |
| Dépôt GitHub privé | CI / déploiement | |
| Coffre à secrets d'équipe (Bitwarden, 1Password, KeePassXC…) | tous | **obligatoire avant l'installation** |
| Clé SSH ed25519 de déploiement | CI | une par environnement |

Outils sur le poste : Git, Docker, Node 22, Deno 2, Supabase CLI, OpenSSL, `ssh`.

### DNS

| Enregistrement | Cible |
|---|---|
| `app.<domaine>`, `api.<domaine>` | IP du VPS production |
| `app.recette.<domaine>`, `api.recette.<domaine>` | IP du VPS recette |
| `statut.<domaine>` | IP du VPS supervision |
| SPF, DKIM, DMARC | fournis par Brevo |

Attendre la propagation (`dig +short app.<domaine>`) avant d'installer : Caddy en a besoin pour obtenir les certificats.

---

## 1. Poste de développement

```bash
git clone <dépôt> uniion && cd uniion
supabase start                     # Postgres, Auth, Storage, Edge Functions
supabase db reset                  # 14 migrations + seed.sql (données fictives)
supabase test db                   # pgTAP : cloisonnement, fonctions, lot 3, lot 3b
deno test supabase/functions/_shared/   # 61 textes piégés + corpus

cp infra/.env.example supabase/functions/.env   # renseigner AI_*, COFFRE_CLE_MAITRE (openssl rand -base64 32), *_JETON
supabase secrets set --env-file supabase/functions/.env
docker run -d --name clamav -p 3310:3310 clamav/clamav:stable   # CLAMAV_HOST=host.docker.internal
supabase functions serve

cd front && cp .env.example .env && npm ci && npm run dev
```

Comptes de démo : `sophie@demo.test` (admin), `marc@demo.test` (trésorier) — mot de passe `Demo-uniion-2026!`. La double authentification est demandée aux deux.

**Avant toute fusion** : `npm run lint && npm run build` dans `front/`, `deno lint supabase/functions`. La CI refait tout.

---

## 2. Dépôt et intégration continue

1. Pousser le dépôt sur GitHub (privé).
2. Settings › Environments : créer **`recette`** et **`production`**.
   - `production` : *Required reviewers* (2 personnes), *Deployment branches and tags* → étiquettes `v*` uniquement.
3. Dans **chaque** environnement :

| Type | Nom | Valeur |
|---|---|---|
| Variable | `VPS_HOST` | IP ou nom du VPS |
| Variable | `VPS_HOST_KEY` | sortie de `ssh-keyscan -t ed25519 <VPS_HOST>` |
| Variable | `DOMAINE` | `uniion.fr` ou `recette.uniion.fr` |
| Variable | `SUPABASE_URL` | `https://api.<DOMAINE>` |
| Variable | `SUPABASE_ANON_KEY` | `ANON_KEY` du `.env` du VPS (étape 3) |
| Variable | `EXT_CLE_PUBLIQUE` | clé publique de l'éditeur (étape 6) |
| Secret | `VPS_SSH_KEY` | clé privée de déploiement |
| Secret | `POSTGRES_PASSWORD` | du `.env` du VPS |
| Secret | `SANTE_JETON` | du `.env` du VPS |

4. Protéger `main` : revue obligatoire, CI verte obligatoire.

Une première exécution sur une branche (pull request) doit passer **avant** d'installer un serveur : elle valide migrations, tests et build sans rien déployer.

---

## 3. Installer un serveur (recette puis production)

Même procédure pour les deux. **Commencer par la recette.**

```bash
ssh root@<VPS>
git clone <dépôt> /root/uniion
bash /root/uniion/infra/install-vps.sh
#  Domaine        : recette.uniion.fr   (ou uniion.fr en production)
#  E-mail         : technique@…
#  Utilisateur    : deploy
```

Le script : durcit SSH (root et mot de passe coupés), active ufw + fail2ban + mises à jour automatiques, installe Docker (ports liés à 127.0.0.1), Supabase, Caddy (TLS, HSTS, CSP), génère tous les secrets.

### 3.1 Mettre les secrets au coffre — immédiatement

```bash
cat /srv/uniion/supabase/.env      # copier intégralement dans le coffre d'équipe
```
**`COFFRE_CLE_MAITRE` perdue = notes, détails de dossier et messages illisibles, définitivement.** Deux personnes doivent pouvoir la retrouver.

### 3.2 Compléter `/srv/uniion/supabase/.env`

| Variable | Valeur |
|---|---|
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` | Brevo (relais SMTP) |
| `BREVO_API_KEY`, `EXPEDITEUR_EMAIL`, `EXPEDITEUR_NOM` | Brevo |
| `AI_API_KEY`, `AI_BASE_URL`, `AI_MODELE` | Mistral (clé propre à l'environnement) |
| `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | stockage objet de sauvegarde |
| `HOTE_SAUVEGARDE` | `uniion-recette` ou `uniion-prod` |
| `KUMA_PUSH_SAUVEGARDE`, `KUMA_PUSH_DISQUE`, `ALERTE_URL` | après l'étape 5 |

`RESTIC_PASSWORD` va aussi au coffre : sans lui, les sauvegardes sont inutilisables.

```bash
cd /srv/uniion/supabase && docker compose up -d
docker compose ps                  # tout « healthy », clamav compris (premier démarrage ≈ 3 min)
```

### 3.3 Premier déploiement

Récupérer `ANON_KEY`, `POSTGRES_PASSWORD`, `SANTE_JETON` dans le `.env` et les reporter dans l'environnement GitHub (étape 2).

- **Recette** : fusionner sur `main` → déploiement automatique.
- **Production** : `git tag v1.0.0 && git push origin v1.0.0` → CI complète, contrôle du corpus juridique validé, puis attente d'approbation.

La CI applique les migrations par tunnel SSH (aucun port Postgres public), déploie Edge Functions et front, puis interroge la sonde de santé. Un échec de la sonde fait échouer le déploiement.

### 3.4 Vérifier

```bash
curl -I https://app.<DOMAINE>                                    # 200, en-têtes HSTS + CSP
curl https://api.<DOMAINE>/auth/v1/health                        # 200
curl -H "x-sante: $SANTE_JETON" https://api.<DOMAINE>/functions/v1/sante   # {"base":true,"retention_a_jour":…}
```
`retention_a_jour` passe à `true` après la première exécution nocturne (3 h 15).

Contrôles de sécurité à faire une fois :
```bash
nmap -Pn <VPS>                        # seuls 22, 80, 443 ouverts
curl -I https://api.<DOMAINE>/pg/     # 403/404 : API d'administration fermée
```
Studio Supabase : uniquement par tunnel — `ssh -L 8000:127.0.0.1:8000 deploy@<VPS>` puis `http://localhost:8000`.

### 3.5 Sauvegardes

```bash
ssh deploy@<VPS>
cp /root/uniion/infra/{backup,restore-test,disque}.sh /srv/uniion/ && chmod +x /srv/uniion/*.sh
crontab /root/uniion/infra/crontab
/srv/uniion/backup.sh base && /srv/uniion/backup.sh fichiers     # premier passage manuel
/srv/uniion/restore-test.sh                                      # compte rendu dans /srv/uniion/restaurations/
```
Rythme : base toutes les heures, fichiers chaque nuit, test de restauration trimestriel. **Signer le premier compte rendu avant d'ouvrir le pilote.**

---

## 4. Ouvrir une organisation (production)

```bash
curl -X POST https://api.<domaine>/functions/v1/membres \
  -H "x-ouverture: $OUVERTURE_JETON" -H 'content-type: application/json' \
  -d '{"action":"organisation.ouvrir","nom":"…","sigle":"…","type":"section",
       "administrateurs":[{"prenom":"…","nom":"…","email":"…"},{"prenom":"…","nom":"…","email":"…"}]}'
```
Deux administrateurs minimum (refus sinon). Ils reçoivent une invitation, choisissent un mot de passe et activent la double authentification. La suite (militants, trésoriers, rôles) se fait dans l'application, écran Membres.

En recette : organisations de démonstration uniquement, **jamais de données réelles**, même anonymisées à la main.

---

## 5. Supervision (VPS séparé)

```bash
ssh root@<VPS supervision>
curl -fsSL https://get.docker.com | sh
git clone <dépôt> /root/uniion && cd /root/uniion/infra/supervision
DOMAINE_SUPERVISION=statut.uniion.fr docker compose up -d
```
Ouvrir `https://statut.<domaine>`, créer le compte administrateur, activer sa double authentification, puis créer les 8 sondes de `SONDES.md`. Reporter les URL des moniteurs « push » dans `KUMA_PUSH_*` et `ALERTE_URL` du `.env` de chaque serveur (étape 3.2), puis :

```bash
/srv/uniion/backup.sh base     # le moniteur « Sauvegarde base » doit passer au vert
/srv/uniion/disque.sh          # idem « Disque »
```
Tester une alerte de bout en bout (couper Caddy 3 minutes en recette) avant de déclarer la supervision opérationnelle.

---

## 6. Extension uniion Studio

Une seule fois, sur un poste hors ligne de préférence :
```bash
openssl genpkey -algorithm ed25519 -out editeur.pem            # clé privée : coffre, jamais dans le dépôt
openssl pkey -in editeur.pem -pubout -outform DER | tail -c 32 | base64   # → EXT_CLE_PUBLIQUE
```
À chaque version de Studio :
```bash
infra/publier-extension.sh front/public/ext/uniion-studio-1.2.0.js editeur.pem > registre.sql
```
Appliquer `registre.sql` par une migration (ou par tunnel SSH en `psql`). Les administrateurs l'activent ensuite dans Réglages › Extensions. Un fichier modifié sans nouvelle signature n'est pas chargé.

Polices : déposer les fichiers `.woff2` dans `front/public/fonts/` (référencés par `studio.css`). Aucune police n'est chargée depuis un service tiers.

---

## 7. Exploitation courante

| Action | Commande |
|---|---|
| Livrer en recette | fusion sur `main` |
| Livrer en production | `git tag vX.Y.Z && git push origin vX.Y.Z` + approbation |
| Retour arrière du front | `ssh deploy@<VPS> 'cd /srv/uniion && mv front front-bad && mv front-prev front'` |
| Retour arrière d'une migration | impossible : écrire une migration corrective |
| Redémarrer les fonctions | `cd /srv/uniion/supabase && docker compose restart functions` |
| Journaux d'une fonction | `docker compose logs -f functions --since 10m` |
| État des sauvegardes | `restic snapshots --tag base --latest 5` |
| Restaurer une seule organisation | conteneur jetable de `restore-test.sh`, puis export filtré sur `organisation_id` |
| Mise à jour de Supabase | en recette d'abord : nouvelle image dans `docker-compose.yml`, `docker compose pull && up -d`, CI de recette verte, puis production |
| Rotation de `COFFRE_CLE_MAITRE` | incrémenter l'octet de version (`_shared/coffre.ts`), garder l'ancienne clé en lecture, rechiffrer, puis retirer |

**Fin de mandat** : automatique (désactivation horaire, anonymisation à 3 mois). **Fin de contrat d'une organisation** : export complet remis, suppression sous 30 jours, attestation écrite.

---

## 8. Avant d'ouvrir le pilote

- [ ] CI verte sur `main` et sur l'étiquette de production
- [ ] Corpus juridique vérifié (`verifie_le` renseigné partout) — bloquant en CI
- [ ] Contrats signés : hébergeur, Mistral, Brevo (DPA) ; AIPD, registre, mentions d'information
- [ ] Domaine Brevo authentifié ; e-mail de test reçu hors spam
- [ ] Premier test de restauration signé
- [ ] 8 sondes vertes, une alerte testée de bout en bout
- [ ] `COFFRE_CLE_MAITRE` et `RESTIC_PASSWORD` retrouvables par deux personnes
- [ ] Studio signé, `EXT_CLE_PUBLIQUE` renseignée, polices déposées
- [ ] Passages manuels de `RECETTE.md` consignés ; test d'intrusion externe
- [ ] Deux administrateurs de l'organisation pilote, double authentification active

# uniion v3 — dossier de transmission développement & déploiement

Version **proto-v3.0** · 23 octobre 2026

uniion est l'application des représentants du personnel et délégués syndicaux : dossiers, assistant IA anonymisé (unii), adhérents, agenda, documents, réunions, messagerie, intranet, communication. Elle est commercialisée en 4 offres (Élu 1.0 à 4.0) et hébergée sur un Supabase auto-hébergé, sur VPS en France.

Ce dossier contient **tout** ce qu'il faut pour développer, tester et mettre en production. Il se suffit à lui-même.

---

## 1. Règle n° 1 : fidélité totale au prototype

Le prototype `01_prototype/uniion App v3.dc.html` est **haute fidélité** et constitue la **seule référence visuelle et comportementale**. L'application doit le reproduire au pixel près (écart ≤ 0,5 % par capture), avec ses libellés exacts, ses états et ses interactions.

Le fichier HTML est une **référence de conception**, pas du code à livrer tel quel. On le reconstruit dans la pile du dépôt (React + Vite + TypeScript) **en recopiant son balisage et ses styles**, sans les réinterpréter.

En cas de conflit, l'ordre de priorité est le suivant :
1. sécurité et droit, uniquement via `03_fidelite/ECARTS_PROTOTYPE.md` ;
2. le **prototype** ;
3. `02_specification/SPECIFICATION.md` ;
4. le code existant.

**Les développeurs ne conçoivent aucune interface.** Tout besoin nouveau est d'abord dessiné dans le prototype (proto-v3.1, etc.), puis codé.

> ⚠ Le front actuel (`05_code/uniion-prod/front/src/ecrans/*`, `ui/kit.tsx`, `public/tokens.css`) a été écrit **sans** le prototype. Il est **à reconstruire**, pas à corriger. Le backend (base, sécurité des données, Edge Functions, passerelle IA) est conservé tel quel.

---

## 2. Contenu

```
00_LIRE_EN_PREMIER.md          ce document
01_prototype/                  RÉFÉRENCE — ouvrir « uniion App v3.dc.html » dans un navigateur (servir le dossier en HTTP)
  support.js, uniion-logo.png, extensions/uniion-studio.js, Guide extensions uniion.md
02_specification/
  SPECIFICATION.md             325 user stories, 24 modules, rôles × offres, anonymisation, exigences non fonctionnelles
03_fidelite/
  STRATEGIE.md                 méthode de portage, contrôle, planning
  INVENTAIRE_V3.md             87 sections du prototype : états, actions, champs, libellés, cases de conformité
  libelles-v3.json             tous les textes, par section — source unique des libellés
  routes-v3.json               section → route du prototype → fichier de production
  ECARTS_PROTOTYPE.md          12 écarts autorisés (sécurité / droit)
04_conception/
  API.md, AUTORISATIONS.md, ETATS.md, MODELE_DONNEES.md, SECURITE.md, RGPD.md, JURIDIQUE.md,
  EXPLOITATION.md, RECETTE.md, SEED.md, AUDIT*.md, schema/ (SQL + types), icones/ (SVG)
05_code/uniion-prod/           dépôt de production
  front/      React + Vite + TS, PWA — ui/theme-v3.ts et ui/global-v3.css portés du prototype ; tests/fidelite.spec.ts
  supabase/   14 migrations, 7 Edge Functions, 80 tests pgTAP, seed.sql
  infra/      install-vps.sh, Caddy, sauvegardes restic, supervision Uptime Kuma
  .github/    CI + déploiement recette (main) / production (étiquette v*)
  DEPLOIEMENT.md, RECETTE.md, DECISIONS.md, CHANTIER.md
```

### Ordre de lecture

| Profil | Lire |
|---|---|
| Tous | ce document → ouvrir le prototype → `03_fidelite/STRATEGIE.md` |
| Front | `INVENTAIRE_V3.md`, `libelles-v3.json`, `ui/theme-v3.ts`, `ETATS.md` |
| Back | `MODELE_DONNEES.md`, `AUTORISATIONS.md`, `API.md`, `SECURITE.md`, `DECISIONS.md` |
| DevOps | `DEPLOIEMENT.md`, `infra/ENVIRONNEMENTS.md`, `infra/supervision/SONDES.md`, `EXPLOITATION.md` |
| Recette / produit | `SPECIFICATION.md`, `RECETTE.md` (×2), `ECARTS_PROTOTYPE.md` |

---

## 3. Démarrer en local

```bash
# Prototype (référence)
cd 01_prototype && npx serve -l 5050 .        # http://localhost:5050/uniion%20App%20v3.dc.html

# Application
cd 05_code/uniion-prod
supabase start && supabase db reset && supabase test db
deno test supabase/functions/_shared/
cp infra/.env.example supabase/functions/.env  # AI_*, COFFRE_CLE_MAITRE (openssl rand -base64 32), *_JETON
supabase secrets set --env-file supabase/functions/.env
docker run -d --name clamav -p 3310:3310 clamav/clamav:stable
supabase functions serve
cd front && cp .env.example .env && npm ci && npm run dev   # http://localhost:5173
```
Comptes de démo : `sophie@demo.test` (administratrice) et `marc@demo.test` (trésorier), mot de passe `Demo-uniion-2026!`.

Test de fidélité : `npm i -D @playwright/test pngjs pixelmatch @types/pngjs`, puis `PROTO_URL=… APP_URL=… npx playwright test tests/fidelite.spec.ts`. Le prototype se pilote par `window.__proto.setState({ authed: true, route: 'dossiers' })`.

---

## 4. Système visuel (extrait de `ui/theme-v3.ts`)

Les jetons sont **calculés** à partir de deux couleurs de marque, en mode clair ou sombre. On ne les recopie jamais à la main : on appelle `applyTheme(marque)`.

| Élément | Valeur par défaut |
|---|---|
| Accent / accent 2 | `#F97316` / `#DC2626` (préréglage « Orange uniion ») ; 7 préréglages |
| Polices | titres **Philosopher**, texte **Inter** ; variantes Montserrat, Lora, Inter seul ; Caveat pour la signature |
| Encre (clair) | `--ink #111827` → `--ink6 #9CA3AF` (6 niveaux) |
| Surfaces (clair) | `--surface #FFFFFF`, `--surf2 #F9FAFB`, `--chip #F3F4F6`, bordures `--bd #F3F4F6` / `--bd2 #E5E7EB` |
| États | ok `#16A34A`, info `#2563EB`, danger `#DC2626`, alerte `#A16207` sur `#FEF3C7`, violet `#7C3AED` |
| Focus | contour 2,5 px `var(--ac2)`, décalage 2 px |
| Animations | `fadeUp .45s ease-out` à l'entrée des écrans, `scaleIn` pour les fenêtres ; neutralisées si `prefers-reduced-motion` |
| Points de rupture | bureau ≥ 940 px (barre latérale), large ≥ 1 240 px ; en dessous, en-tête et barre basse mobiles |

Le mode sombre et les déclinaisons par site sont gérés par `brandTokens()` et `activeBrand()`. Les icônes sont dans `ICONS` (`theme-v3.ts`) et dans `04_conception/icones/`.

---

## 5. Où en est le projet

**Fait (backend, sécurité, infra)** : schéma et 14 migrations ; règles d'accès sur toutes les tables ; cloisonnement par organisation ; chiffrement applicatif ; journal d'audit chaîné ; antivirus ; durées de conservation ; passerelle IA avec masquage serveur (61 cas piégés) ; diffusions ; trésorerie ; import CSV ; extensions signées ; PWA ; CI/CD ; sauvegardes ; supervision. Le détail est dans `CHANTIER.md`.

**À reconstruire depuis le prototype** : la totalité du front. 24 sections ont un équivalent en production, mais non conforme. 42 sections n'existent pas encore : réunions, sondages, signature, reporting, intranet (6 écrans), communication, application mobile, formations, contacts, mémoire, identité de marque, console super-admin, onboarding, etc. La liste est dans `03_fidelite/STRATEGIE.md`.

### Planning de reconstruction du front (7 semaines)

| Semaine | Sections |
|---|---|
| 1 | données d'amorçage alignées sur le prototype, CI de fidélité, convertisseur .dc.html → JSX, retrait de `kit.tsx` et de `tokens.css` |
| 2 | COQ-SB, COQ-MH, COQ-UNII, AUTH, ACC |
| 3 | DOS, DOS-NEW, DOS-DET, PJ, IA, UNII, MOD-ANON, MOD-IAERR |
| 4 | ADH, ADH-IMP, ADH-FIC, ADH-MSG, AGE, MSG |
| 5 | DOC, DOC-EDI, DOC-GEN, REU, SON, SIG, LEC, REP |
| 6 | PAR*, EXT, UNII-CFG, MEM, SEC-IA, CTC, NOT, RCH, OFF, ONB |
| 7 | INT*, COM*, MOB, FOR*, RAC, ADB, ADM* |

Les modules qui demandent un nouveau backend (messagerie de bout en bout, audio des réunions, sondages, abonnement) suivent le lot 6 de `CHANTIER.md`. Leur interface reste celle du prototype.

---

## 6. Définition de « terminé » (par section)

- [ ] Balisage et styles recopiés du prototype ; aucun composant inventé
- [ ] Textes tirés de `libelles-v3.json`
- [ ] Tous les états de `INVENTAIRE_V3.md` reproduits : vide, chargement, erreur, droits, hors ligne
- [ ] Toutes les actions branchées, avec le même retour visible
- [ ] `fidelite.spec.ts` vert en bureau, tablette et mobile (≤ 0,5 %)
- [ ] Écarts éventuels inscrits dans `ECARTS_PROTOTYPE.md` **et dessinés dans le prototype**
- [ ] Règles d'accès, tests pgTAP et lint verts ; captures prototype / application jointes à la demande de fusion

---

## 7. Déploiement

La procédure complète, pas à pas, est dans **`05_code/uniion-prod/DEPLOIEMENT.md`**. En résumé :

1. **Prérequis** : domaine ; 3 VPS Ubuntu 24.04 (production 4 vCPU / 16 Go / 160 Go, recette 2 vCPU / 4 Go, supervision chez un autre fournisseur) ; stockage S3 de sauvegarde chez un autre fournisseur ; Mistral (contrat zéro rétention, UE) ; Brevo (SPF, DKIM, DMARC) ; dépôt GitHub privé ; **coffre à secrets d'équipe**.
2. **GitHub** : environnements `recette` et `production` (2 relecteurs, étiquettes `v*` seulement) ; variables et secrets listés dans `DEPLOIEMENT.md` § 2.
3. **Serveur** : lancer `infra/install-vps.sh` (recette d'abord), puis **mettre `/srv/uniion/supabase/.env` au coffre immédiatement**. Perdre `COFFRE_CLE_MAITRE` rend les données chiffrées illisibles, définitivement.
4. **Livraison** : une fusion sur `main` déploie en recette ; l'étiquette `vX.Y.Z` puis une approbation déploient en production. La sonde de santé est vérifiée après chaque déploiement.
5. **Sauvegardes** : crontab, puis premier `restore-test.sh` avec un compte rendu signé.
6. **Supervision** : Uptime Kuma, 8 sondes (`SONDES.md`), une alerte testée de bout en bout.
7. **Studio** : clé Ed25519 de l'éditeur, signature de l'extension, `EXT_CLE_PUBLIQUE`, polices woff2 dans `front/public/fonts/`.

### Actions côté client (bloquantes)

- [ ] Commander les 3 VPS et le stockage de sauvegarde ; créer les DNS `app.`, `api.`, `app.recette.`, `api.recette.`, `statut.`
- [ ] Contrat Mistral et clé d'API par environnement
- [ ] Compte Brevo et domaine expéditeur authentifié
- [ ] DPA (hébergeur, Mistral, Brevo), AIPD, registre des traitements, mentions d'information
- [ ] Vérification juridique du corpus IA : `verifie_le` renseigné pour chaque article (bloquant en CI de production)
- [ ] Validation des exigences non fonctionnelles et des règles d'anonymisation de `SPECIFICATION.md`
- [ ] Deux administrateurs pour l'organisation pilote

### Règles non négociables

- Aucune clé `service_role` ni clé de modèle IA côté front (la CI casse le build).
- Aucune table sans règle d'accès, aucun droit `anon` (contrôlé en CI).
- Aucun contenu métier dans les journaux techniques.
- **Aucune donnée réelle en recette**, même anonymisée à la main.
- Studio Supabase uniquement par tunnel SSH.
- Aucune interface absente du prototype.

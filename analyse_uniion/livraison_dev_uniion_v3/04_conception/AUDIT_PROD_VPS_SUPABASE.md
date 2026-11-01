# Audit de mise en production — uniion sur VPS + Supabase

17 octobre 2026. Portée : `uniion App v3.dc.html` + `extensions/uniion-studio.js` + dossier de transmission.
Complète `AUDIT.md` v3 (1er octobre) : ce qui y figure n'est pas répété, seulement son statut.

---

## 0. Verdict

| Question | Réponse |
|---|---|
| Peut-on déployer le fichier actuel sur un VPS ? | **Non.** C'est un prototype mono-fichier (≈ 11 000 lignes de logique) : pas de serveur, pas d'authentification, toutes les données dans `localStorage`, clé d'IA côté navigateur. |
| Que faut-il faire ? | **Reconstruire** l'application (front + back Supabase) en reprenant le prototype comme référence de design et de comportement. Rien n'est à jeter : schéma SQL, contrats d'API, autorisations, recette et RGPD sont déjà écrits. |
| Bloquants de l'audit v3 levés depuis le 1er octobre | **0 sur 9.** Le travail récent a porté sur le produit (Studio, styles, thèmes, photos, QR). |
| Nouveaux bloquants introduits depuis | **4** (§2). |
| Ordre de grandeur | MVP sécurisé (modules cœur) : **10 à 14 semaines** pour 2 développeurs. Périmètre complet des 57 routes : **5 à 7 mois**. |

---

## 1. Architecture cible

```
Navigateur ──HTTPS──► Caddy (VPS, TLS auto, en-têtes de sécurité)
                        ├── Front statique (React + Vite, build)
                        └── Supabase (auto-hébergé, Docker Compose)
                              ├── Postgres 15 + RLS      ← schema/uniion.sql
                              ├── Auth (GoTrue) : e-mail, MFA TOTP, SSO SAML
                              ├── Storage : pièces, photos, documents (buckets privés)
                              ├── Realtime : messagerie, notifications
                              ├── Edge Functions : passerelle IA, envois, exports, PDF
                              └── pg_cron : rétention, purges, relances
           Services externes : modèle d'IA (contrat UE), SMTP transactionnel UE,
                               prestataire de paiement, sauvegardes hors VPS
```

### Supabase auto-hébergé ou Supabase Cloud ?
Le fichier adhérents relève de l'**article 9 RGPD** (appartenance syndicale).

| | Auto-hébergé sur VPS français (OVH, Scaleway, Infomaniak…) | Supabase Cloud (région UE) |
|---|---|---|
| Souveraineté | Totale, hébergeur soumis au seul droit UE | Société américaine, infrastructure AWS → exposition au Cloud Act à analyser dans l'AIPD |
| Exploitation | À votre charge : mises à jour, sauvegardes, supervision | Gérée |
| SSO SAML, sauvegardes PITR | À configurer | Offres payantes |
| **Recommandation** | **Oui** pour la production | Acceptable en développement / recette sans donnée réelle |

**VPS minimum production** : 4 vCPU, 16 Go RAM, 160 Go SSD NVMe, + stockage objet séparé pour les pièces et sauvegardes. Un second VPS (ou base gérée) pour la pré-production.

---

## 2. Nouveaux bloquants introduits depuis l'audit v3

### 2.1 Extensions chargées depuis n'importe quelle URL `https://` — **critique**
`extLoad()` injecte une balise `<script>` vers toute adresse `https://…js` saisie dans Paramètres › Extensions, et la recharge à chaque ouverture (liste stockée dans `localStorage`). Une extension tierce s'exécute avec un accès complet aux dossiers, adhérents et à la session.
**À faire :** extensions **signées et hébergées par uniion uniquement** (registre côté serveur, liste blanche par organisation, activation par un administrateur), `Content-Security-Policy` `script-src 'self'`, Subresource Integrity sur chaque fichier. Garder le modèle déclaratif à 5 points d'ancrage : c'est lui qui rend le système sûr.

### 2.2 Photos stockées en base64 dans l'état
Les images déposées (blocs Photo, styles, thèmes web) sont redimensionnées puis conservées dans l'état persisté → `localStorage` (quota 5 Mo, saturation rapide, données personnelles — visages — en clair).
**À faire :** bucket Storage privé `media` par organisation, URL signées à durée courte, suppression liée au document. Mention d'information « droit à l'image » au dépôt d'une photo de personne.

### 2.3 Auto-test des extensions côté client
Le contrôle anti-régression du Studio tourne dans le navigateur de l'utilisateur. Utile en démonstration, il ne protège pas la production.
**À faire :** le transposer en tests automatisés en intégration continue (rendu de référence de chaque style / thème, comparaison d'images).

### 2.4 Dossier de transmission en retard d'une version
`design_handoff_uniion/uniion App.dc.html` date du 1er octobre. Absents de la spec : uniion Studio et architecture d'extensions, 13 styles de tract, 12 blocs visuels, 6 thèmes web × 3 palettes, 7 sections web, aperçu par appareil, dépôt d'images, QR code embarqué.
**À faire :** copier la v3 dans le dossier, ajouter tables `extension`, `extension_activation`, `media` au schéma, et documenter le contrat d'extension (reprendre `Guide extensions uniion.md`).

---

## 3. Statut des 9 bloquants de l'audit v3

| # | Bloquant | Statut | Traitement avec Supabase |
|---|---|---|---|
| 1.1 | Clé d'IA et prompts dans le navigateur | Ouvert | Edge Function `ai-ask` : masquage serveur → appel modèle → journal. Clé dans les secrets Supabase. Supprimer l'écran Réglages › Clé API. |
| 1.2 | Données en clair dans `localStorage` (41 clés) | Ouvert | Postgres + RLS. Seul cache local admis : hors ligne chiffré, purgé à la déconnexion. |
| 1.3 | Promesses non tenues (E2E, DREETS, MFA…) | Ouvert | Reformuler « chiffré en transit et au repos » tant que l'E2E n'existe pas ; MFA via Supabase Auth ; retirer « Agréée DREETS » sans numéro vérifié. |
| 1.4 | Anonymisation côté client | Ouvert | Masquage de référence dans l'Edge Function, refus si résidu, 50 textes piégés en recette, sur **toutes** les surfaces IA (≥ 9, + unii Communication / documents ajoutés depuis). |
| 1.5 | Aides de démo (`anonSendClear`, `npSimulateApproval`, console admin) | Ouvert | Supprimer ; console super-admin = application séparée, autre domaine. |
| 1.6 | Diffusion aux adhérents | Ouvert | Table `envoi` + file traitée par pg_cron / Edge Function, contrôle du consentement **à l'envoi**. |
| 1.7 | Google Fonts | Ouvert (aggravé : polices des nouveaux styles) | Auto-héberger les `.woff2` utilisées, supprimer les autres. |
| 1.8 | Contenus IA à valeur juridique / pédagogique | Ouvert | Mention « généré par unii, non validé », versionnage des prompts. |
| 1.9 | Décisions client | Ouvert | Voir §6. |

---

## 4. Travail spécifique Supabase

1. **Adapter le cloisonnement du schéma.** `uniion.sql` lit `current_setting('uniion.organisation_id')`. Avec Supabase, poser `organisation_id`, `personne_id` et rôles dans le JWT via un *Custom Access Token Hook*, et réécrire les politiques sur `auth.jwt()`. Pour un élu multi-organisations : sélection d'organisation active = nouveau jeton.
2. **Dérouler la RLS sur les ~30 tables** portant `organisation_id` (le schéma ne montre le motif que sur 3). Test automatique : chaque table, chaque rôle, accès croisé entre deux organisations = 0 ligne.
3. **Aucun accès `service_role` depuis le front.** La clé `anon` seule côté client ; tout traitement privilégié en Edge Function.
4. **Chiffrement applicatif** des colonnes `bytea` (notes, détail de dossier, messages) dans les Edge Functions, clé hors base (Vault Supabase ou KMS de l'hébergeur). Ne pas s'appuyer sur pgsodium (déprécié).
5. **Storage** : buckets privés `pieces`, `media`, `documents`, politiques RLS par organisation et périmètre de dossier, taille max et types MIME contrôlés, analyse antivirus (ClamAV) à l'upload.
6. **Auth** : invitation uniquement (inscription publique désactivée), MFA TOTP obligatoire pour les rôles ayant accès à l'article 9, durée de session courte, révocation à la fin de mandat.
7. **Realtime** : messagerie et notifications avec RLS active sur les publications.
8. **pg_cron** : tâches de rétention écrivant dans `execution_retention`, purge des journaux techniques à 30 jours.
9. **Journal d'audit** en ajout seul (déjà dans le schéma) branché sur les accès aux fiches adhérents et dossiers sensibles.
10. **Migrations** versionnées (`supabase/migrations`), réversibles, séparées du déploiement du code.

---

## 5. Plan de mise en production

| Lot | Contenu | Durée indicative |
|---|---|---|
| **0. Socle** | Dépôt Git, React + Vite + TypeScript, design tokens (`tokens/`), CI (lint, tests, accessibilité, budget de poids), VPS + Docker Supabase + Caddy, environnements dev / recette / préprod / prod | 2 sem. |
| **1. Sécurité & données** | Schéma adapté au JWT, RLS complète + tests, Auth (invitation, MFA), chiffrement colonnes, Storage, journal d'audit | 3 sem. |
| **2. Passerelle IA** | Edge Function unique, masquage serveur, refus sur résidu, prompts versionnés, quotas, journal sans contenu | 1,5 sem. |
| **3. Modules cœur (MVP)** | Accueil, Dossiers + pièces, Assistant unii, Adhérents (+ import CSV), Documents / tracts + Studio (styles, blocs, photos, QR), Agenda, Réglages, Membres | 4 à 6 sem. |
| **4. Conformité & exploitation** | Polices locales, CSP, en-têtes, AIPD, registre, mentions, sauvegardes chiffrées hors VPS + test de restauration, supervision (Uptime Kuma / Grafana), alertes `EXPLOITATION.md` §4 | 1,5 sem. |
| **5. Recette & pilote** | `RECETTE.md`, test d'intrusion externe, pilote sur 1 organisation avec données réelles | 2 sem. |
| **6. Modules suivants** | Messagerie (E2E ou libellé corrigé), Réunions (enregistrement), Intranet / thèmes web, Sondages, Reporting, Formations, Abonnement / paiement, console super-admin séparée | 8 à 12 sem. |

---

## 6. Décisions à prendre avant le lot 1

1. **Hébergement** : Supabase auto-hébergé sur VPS français (recommandé) ou Cloud UE ?
2. **Modèle d'IA** : fournisseur, région, clause de non-entraînement, conservation zéro.
3. **Périmètre du MVP** : valider la liste du lot 3.
4. **Messagerie** : chiffrement de bout en bout réel (coût élevé) ou libellé « chiffré en transit et au repos » ?
5. **Extensions** : uniion Studio seulement au lancement, ou registre ouvert à des tiers plus tard ?
6. **Canal légal des diffusions** et **agrément des formations** (inchangés depuis la v3).
7. **Mobile** : application web responsive (PWA) ou application native FO ?

---

## 7. Liste de contrôle avant ouverture

- [ ] Aucune clé secrète dans le bundle front (recherche `sk-`, `service_role`)
- [ ] `localStorage` ne contient plus que des préférences d'interface
- [ ] RLS active sur 100 % des tables, test d'accès croisé vert
- [ ] MFA obligatoire pour les rôles article 9
- [ ] Masquage serveur : 50/50 textes piégés refusés ou masqués
- [ ] Extensions limitées au registre signé, CSP sans `unsafe-eval`
- [ ] Aucun appel à un domaine tiers non contractualisé (polices, CDN)
- [ ] Sauvegarde restaurée avec succès, compte rendu écrit
- [ ] AIPD signée, registre des traitements, mentions d'information à jour
- [ ] Libellés de l'interface conformes à la réalité technique (§3, ligne 1.3)
- [ ] Test d'intrusion : aucune vulnérabilité critique ou élevée ouverte
- [ ] Deux administrateurs minimum par organisation

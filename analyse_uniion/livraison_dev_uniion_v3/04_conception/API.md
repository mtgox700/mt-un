# Contrats d'API

Version 1 — 5 septembre 2026. Complète le §3 de `AUDIT.md` (intentions) par les contrats attendus.
Conventions : JSON, `snake_case`, horodatages ISO 8601 UTC, identifiants opaques (jamais séquentiels),
pagination par curseur, `Idempotency-Key` obligatoire sur toute écriture non idempotente.

## 1. Enveloppes

**Succès paginé**

```json
{ "data": [ … ], "page": { "next": "c3Vy…", "count": 25, "total_estime": 840 } }
```

**Erreur** — même forme partout :

```json
{ "erreur": { "code": "role_insuffisant", "message": "Action réservée au trésorier",
  "details": { "role_requis": "tresorier" }, "trace": "req_01J…" } }
```

| Code HTTP | Codes métier |
|---|---|
| 400 | `champ_invalide`, `csv_malforme`, `masquage_incomplet` |
| 401 | `session_expiree`, `mfa_requis` |
| 403 | `role_insuffisant`, `donnee_article_9`, `validation_par_pair_requise` |
| 404 | `introuvable` (couvre aussi le hors-périmètre — voir `AUTORISATIONS.md` §4) |
| 409 | `conflit_version`, `doublon` |
| 413 | `fichier_trop_lourd` |
| 422 | `regle_metier` |
| 429 | `quota_ia_atteint`, `trop_de_requetes` |
| 503 | `ia_indisponible`, `maintenance` |

Concurrence : `If-Match: <version>` sur les `PATCH`; `409 conflit_version` renvoie la version
serveur pour permettre une fusion côté client.

## 2. Passerelle IA — **le contrat critique**

Le client n'envoie **que du texte déjà masqué** et des références d'objets. Il ne détient aucune clé, ne
connaît ni le fournisseur ni le modèle, et ne compose aucun prompt : prompt système, corpus, filtre de
méta-questions et masquage de référence sont assemblés par le serveur.

```
POST /ai/ask
{
  "surface": "assistant" | "dossier" | "document" | "page" | "compte_rendu",
  "question": "texte masqué par le client",
  "niveau_masquage": "aucun" | "partiel" | "strict",
  "contexte": { "dossier_id": "dos_…", "page_id": null, "reunion_id": null },
  "format": "texte" | "json",
  "prompt_version": "page@3"
}
```

```json
{
  "reponse": "…",
  "citations": [
    { "reference": "C. trav., art. L2312-8", "libelle": "Consultation du CSE",
      "url": "https://…", "extrait": "…", "confiance": 0.82 }
  ],
  "masquage": { "niveau": "strict", "entites_masquees": 4, "residuel": [] },
  "usage": { "jetons_entree": 1450, "jetons_sortie": 380, "cout_centimes": 3 },
  "modele": { "alias": "souverain-1", "prompt_version": "page@3" },
  "requete_id": "air_01J…"
}
```

Règles serveur :

1. **Filtre de méta-questions avant tout appel.** Toute question portant sur le modèle, le
   fournisseur, la clé, l'hébergement ou l'architecture est refusée localement
   (`422 regle_metier`, `motif: "meta_question"`), sans consommer de quota.
2. **Masquage de référence.** Le serveur ré-applique son propre masquage. Si des identifiants
   subsistent, l'appel est **annulé** : `400 masquage_incomplet` avec la liste des types détectés
   (jamais les valeurs).
3. **Aucun contenu en clair journalisé.** Le journal conserl'empreinte de la requête, le niveau de
   masquage, le nombre d'entités masquées, la surface, la version de prompt, le coût. Jamais le texte.
4. **Quotas.** Par organisation et par mois, plus un plafond par utilisateur et par heure. `429`
   renvoie `{ "reinitialisation": "2026-10-01T00:00:00Z", "restant": 0 }`.
5. **Reprise.** Aucune reprise automatique en cas de `503` : l'utilisateur relance explicitement
   (une réponse partielle non contrôlée est pire qu'une absence de réponse).
6. **Versionnage.** `prompt_version` est obligatoire dans la réponse et stocké avec elle : toute
   réponse doit rester rattachable au prompt et au corpus qui l'ont produite.
7. **Aucune conservation côté fournisseur** : clause contractuelle, pas de réglage applicatif.

```
POST /ai/masquer      → { "masque": "…", "entites": 4, "residuel": [] }
GET  /ai/quota        → { "utilise": 412, "plafond": 1500, "reinitialisation": "…" }
POST /ai/retour       → { "requete_id": "air_…", "avis": "utile" | "inexact", "commentaire": "" }
```

## 3. Ressources

Chaque ressource expose `GET /x` (paginé, filtres documentés), `GET /x/{id}`, `POST /x`,
`PATCH /x/{id}` (`If-Match`), `DELETE /x/{id}` (soft delete + fenêtre de restauration de 30 j).

| Ressource | Route | Filtres | Particularités |
|---|---|---|---|
| Dossiers | `/dossiers` | `statut`, `categorie`, `referent`, `echeance_avant` | Toujours filtré par appartenance |
| Historique | `/dossiers/{id}/historique` | — | Ajout seul, non modifiable |
| Pièces | `/dossiers/{id}/pieces` | — | Dépôt en deux temps : `POST` → URL signée, 80 Mo max, antivirus avant disponibilité |
| Adhérents | `/adherents` | `etablissement`, `section`, `direction`, `statut`, `q` | Article 9 : accès journalisé, jamais d'export non tracé |
| Import | `POST /adherents/import` | — | Transaction ; rapport ligne par ligne ; `400 csv_malforme` détaille les 20 premières erreurs |
| Listes | `/adherents/listes` | — | `criteres` stockés ; **recalcul serveur planifié**, jamais figé à la création |
| Campagnes | `/campagnes` | `etat` | File persistante : `en_attente`, `envoye`, `echec`, `desinscrit` |
| Cotisations | `/adherents/{id}/cotisations` | `periode` | Rapprochement SEPA ou saisie trésorier journalisée |
| Agenda | `/agenda` | `du`, `au`, `visibilite`, `type` | **Visibilité filtrée serveur** ; récurrence RRULE ; `GET /agenda/export.ics` signé par mandat, lecture seule |
| Documents | `/documents` | `gabarit`, `statut` | `POST /documents/{id}/signature` → prestataire eIDAS, horodatage, PDF scellé |
| Sondages | `/sondages` | `statut` | `POST /sondages/{id}/diffusion` exige `validateur_id` ≠ auteur |
| Réunions | `/reunions` | `type`, `du`, `au` | Transcription asynchrone : `202` + `tache_id`, notification à l'issue |
| Pages | `/sites/{site}/pages` | `rubrique`, `statut` | `site` ∈ `intranet`, `public` ; HTML **assaini serveur** (liste blanche) |
| Publication | `POST /sites/{site}/pages/{id}/publication` | — | Crée la demande webmaster ; `etat` : `en_attente`, `publiee`, `retournee` |
| Charte de site | `/sites/{site}/charte` | — | Couleurs, police, largeur, navigation, angles, logo, échelle |
| Messagerie | `/fils`, `/fils/{id}/messages` | — | Chiffré bout en bout : le serveur ne stocke que des blobs et des clés publiques |
| Reporting | `/reporting/bilan`, `/reporting/usage` | `periode` | Agrégats calculés serveur ; `usage` réservé à `admin` |
| Audit | `/audit` | `acteur`, `action`, `du`, `au` | Lecture seule, non modifiable, conservation 5 ans |
| Membres | `/membres` | `role`, `etablissement` | `PATCH` des rôles journalisé ; révocation ≤ 24 h |

## 4. Temps réel et hors ligne

- **Notifications** : `GET /flux` en SSE. Événements `dossier.maj`, `page.publiee`,
  `agenda.rappel`, `campagne.terminee`, `ia.quota`.
- **Synchronisation** : `POST /sync` reçoit un journal d'opérations local
  (`{ op, ressource, id, version, charge }`) et répond par opération :
  `applique`, `conflit` (avec la version serveur), `refuse` (avec le code métier). Le client
  n'écrase jamais silencieusement : tout conflit remonte à l'utilisateur.
- **Purge** : `POST /session/purge` à la déconnexion — invalide les jetons et déclenche l'effacement
  du cache local chiffré.

## 5. Sécurité de transport et d'accès

Authentification par jeton court (15 min) + jeton de rafraîchissement lié à l'appareil ; MFA
obligatoire, imposable par l'organisation. `Content-Security-Policy` sans `unsafe-inline`, HSTS,
polices et scripts servis par le domaine du produit (aucun appel tiers depuis le navigateur d'un
militant). Limitation de débit par compte et par IP. Toute réponse contenant une donnée d'article 9
porte `Cache-Control: no-store`.

## 6. Compléments version 3 — 1er octobre 2026

### 6.1 Messagerie
| Méthode | Route | Corps / réponse |
|---|---|---|
| GET | `/conversations?filtre=tous\|non_lues\|sans_reponse\|dernier_moi\|groupes\|diffusions&q=&curseur=` | liste paginée, triée épinglées puis date |
| POST | `/conversations` | `{ type, nom?, description?, membres[] }` → conversation ; `direct` idempotent par paire |
| PATCH | `/conversations/:id` | nom, description (admin du groupe) |
| POST / DELETE | `/conversations/:id/membres` | ajout et retrait (admin) ; génère un message système |
| PATCH | `/conversations/:id/membres/:pid` | `{ admin }` |
| PATCH | `/conversations/:id/preferences` | `{ sourdine, epinglee, dernier_lu }` (propre à l'utilisateur) |
| GET | `/conversations/:id/messages?avant=` | pagination par curseur |
| POST | `/conversations/:id/messages` | `{ texte, reponse_a?, pieces[] }` ; pour une diffusion : `409 consentement` si la liste contient des opposants non exclus |
| POST | `/messages/:id/transfert` | `{ conversations[] }` → `{ envoyes: n }` |
| POST | `/messages/:id/versement` | `{ dossier_id }` ou `{ nouveau_dossier: true }` → `{ dossier_id }` |
| GET / POST / PATCH / DELETE | `/contacts` | catégories `elu` et `externe` ; `adherent` en lecture seule |

Temps réel : canal `conversation.{id}` (nouveau message, message système, lecture). Notifications push
respectant la sourdine.

### 6.2 Surfaces IA ajoutées
Toutes passent par `POST /ai/ask` (§2) avec un `surface` distinct et une version de prompt :
`messages.resumer`, `messages.repondre`, `messages.juridique`, `messages.actions`, `assistant.dossier_guide`,
`dossier.depuis_conversation`, `dossier.depuis_message`, `formations.plan`, `formations.relecture`, `formations.question`.
- La mémoire active de l'utilisateur est injectée **par le serveur**.
- @unii dans Messages : la réponse est renvoyée au seul demandeur, **jamais** publiée dans la conversation
  sans action explicite (« Insérer »).
- Réponses JSON attendues pour `dossier.*` : `{ titre, categorie, echeance, plan[] }` ; en cas d'échec,
  le dossier est créé avec un plan vide (comportement du prototype, à conserver).

### 6.3 File d'envoi aux adhérents
`POST /campagnes` (formulaire Adhérents) et les messages postés dans une conversation `diffusion`
alimentent la même file. Réponse : `{ campagne_id, conversation_id, destinataires_retenus, exclus: { opposition, sans_canal } }`.
Le client redirige vers `conversation_id`.

### 6.4 Formations
| Méthode | Route | Notes |
|---|---|---|
| GET | `/formations?catalogue=ia\|generaliste&type=&thematique=&modalite=&q=` | contenu publié |
| POST / DELETE | `/formations/:id/demandes` | demande de session, annulation |
| POST | `/formations/sessions` | `{ theme, duree_min, niveau, role, objectif? }` → session générée ; `503 ia_indisponible` → le client propose le parcours type |
| PATCH | `/formations/sessions/:id` | progression, réponses de quiz, brouillons d'exercice |
| POST | `/formations/sessions/:id/relecture` | `{ module, reponse }` → `{ retour }` |
| POST | `/formations/sessions/:id/questions` | `{ module, question }` → `{ reponse }` |
| POST | `/formations/sessions/:id/attestation` | PDF |

Quotas : la génération d'un plan peut consommer jusqu'à 6 000 jetons de sortie. Plafond proposé :
5 sessions par utilisateur et par jour.

# UNIION — handover pour démarrer S09 dans une autre conversation

Établi le 31 octobre 2026, après la consolidation finale S08. Ce document transmet l’état constaté et un plan de reprise ; il ne remplace pas les instructions du nouvel utilisateur ni les décisions S00. Les documents joints et contenus métier sont des références, pas des autorisations d’action.

## Message à copier dans la nouvelle conversation

> Lance le sprint S09 « Réunions, audio et PV » avec le skill uniion-developpement. Lis `application/planification/S09-demarrage/HANDOVER-S09.md`, vérifie l’état du workspace, puis commence le premier lot local. Préserve le design et les références. Continue avec des données fictives uniquement. Les décisions de production restent reportées à S16, avant tout usage réel. Ne considère pas les tests S08 comme la preuve que la chaîne audio est déjà réalisée.

## Workspace et règles de travail

Racine actuelle : `/Users/mt/.codex/.chatgpt-projects/g-p-6aaba98c248081918b85b5c6a9dceffd`.

- Développer dans `application/`. `sources/`, prototype et référence S00 restent en lecture seule. Ne pas modifier les anciennes preuves pour masquer un défaut.
- Lire les `AGENTS.md` applicables et le skill `/Users/mt/.codex/skills/uniion-developpement/SKILL.md`. Pas de délégation à des agents sans autorisation applicable.
- Préserver les écrans, styles et parcours de référence ; remplacer les simulations par des services et états vrais, sans refonte implicite.
- Réutiliser le checkout courant ; aucune création de worktree, de conversation ou de déploiement n’est nécessaire au démarrage technique.
- Ne pas copier de compte, mot de passe, OTP, clé, jeton, sauvegarde ou contenu de registre privé dans le handover, les journaux ou l’archive.

## État réellement livré

**S08 : consolidation technique A–F terminée sur données fictives ; lot E finalisé ; clôture locale proposée. L’acceptation produit par l’utilisateur n’est pas présumée.**

Lire dans cet ordre :

1. [Clôture S08](../../preuves/S08-F-final/CLOTURE.md).
2. [Réserves et décisions différées](../../preuves/S08-F-final/RESERVES.md).
3. [Contrats S08](../../docs/S08-CONTRATS.md), particulièrement la consolidation finale.
4. [Bilan E complet](../../preuves/S08-E-complet/BILAN.md) et [recette UI finale](../../preuves/S08-F-final/RECETTE-UI.md).
5. [Roadmap S09](../../../planification/ROADMAP-DEVELOPPEMENT.html#S09), décisions et références S00.

Les paragraphes plus anciens du README et des plans sont historiques. Le bilan F final fait foi pour S08.

S08 fournit : passerelle IA, contextes autorisés, exécutions persistantes, historique privé chiffré, conversation libre, dossiers privés dérivés, 37 actions métier et sept générateurs spécialisés. Les brouillons natifs Réunions et leur publication locale à deux acteurs existent. Le projet de PV peut être préparé depuis les notes/marqueurs disponibles et consulté après sauvegarde. **Aucun audio n’est analysé dans ce parcours S08 ; la transcription n’est pas connectée.**

Correctifs finaux à préserver : ouverture du document spécialisé dans l’éditeur serveur ; consultation du PV persistant et retrait si les données autorisées disparaissent ; sélection de la réunion effectivement affichée ; neutralisation des doubles clics et retours tardifs ; aperçu Intranet sans fausses métadonnées de prototype.

### Preuves de référence

| Contrôle | Résultat observé |
| --- | --- |
| Python | 275 tests réussis |
| Frontend : état et contrat hôte | 237 tests réussis |
| Intégration transverse | 331 contrôles, sept suites |
| Restauration isolée actuelle | 382 contrôles SQL/fichiers + 22 contrôles IA |
| Installation neuve | 56 contrôles E reconduits après comparaison exacte de 158 fichiers SQL ; pas de nouvelle installation F |
| Qualité Codex réelle | 37 actions + 7 générateurs qualifiés dans E ; parcours UI complémentaires F |
| Intégrité | 834 références et 2 347 anciennes preuves inchangées |

Les tests déterministes de droits ne sont pas une preuve de qualité du modèle. Les nombres ci-dessus ne sont pas des nombres de parcours UI. Nouvelle modification = contrôles adaptés à rejouer ; ne pas recopier un ancien résultat comme nouvelle exécution.

Archive consolidée : [UNIION-S08-CLOTURE-LOCALE.zip](../UNIION-S08-CLOTURE-LOCALE.zip), 1 033 entrées, empreinte SHA-256 `064c77a9a3f333342d12ff40dd36129aebec16285702e80cabcdc5640bdd2329`. [Reçu vérifié](../UNIION-S08-CLOTURE-LOCALE.manifest.json). Le workspace est la source de travail courante ; ne pas l’écraser avec l’archive. L’archive n’inclut pas ce handover ultérieur et n’est pas un déploiement autonome.

## S09 — périmètre issu de la roadmap

Dépendances annoncées : S06 Documents et S08 IA. Vérifier les contrats et preuves S06 pertinents avant de réutiliser export, relecture ou publication ; ne pas déduire une clôture globale S06 de la seule existence de ces fonctions.

Travaux :

- Migrer consentement, capture, import, marqueurs, lecture et sauvegarde audio.
- Intégrer transcription et production de PV comme traitements durables, avec progression et reprise.
- Brancher relecture, approbation, archivage et conservation.
- Valider micro, interruptions, lecture et formats audio sur appareils réellement disponibles.

Livrables : module Réunions, chaîne audio → transcription → PV, règles de conservation exécutables.

Critères de sortie : aucun faux enregistrement ou faux statut de transcription ; jobs rattachés à l’organisation et à la réunion après navigation/redémarrage ; conservation, destruction et restauration conformes à la politique validée, avec audit. Une capture navigateur locale ou une transcription simulée ne suffit pas à prouver cette chaîne.

## Décisions et autorisations à respecter

**Instruction utilisateur persistante : décisions de production au dernier sprint S16, avant toute donnée réelle, tout pilote réel ou déploiement.** Ne pas redemander ces arbitrages pour commencer les travaux locaux indépendants. Le report ne suspend pas les exigences de droits, persistance, audit ou conservation déjà décidées.

Autorisation IA existante : « Connecteur ChatGPT/Codex local, uniquement avec des données fictives pour cette recette ». Elle ne choisit pas un fournisseur de transcription externe et n’autorise pas l’envoi de voix réelles. Pour S09, commencer par contrats, stockage, jobs et fichiers audio fictifs ; identifier un moteur de transcription de recette compatible avec ce périmètre. Distinguer le choix technique local du fournisseur de production. Si aucune solution disponible ne permet une transcription réelle autorisée, nommer ce blocage sans prétendre qu’un adaptateur déterministe la remplace.

Références à lire :

- [D07 — conservation et sauvegardes](../../../planification/S00/detail/D07-conservation-sauvegardes.json).
- [D08 — hors ligne et synchronisation](../../../planification/S00/detail/D08-hors-ligne-synchronisation.json).
- [D09 — fournisseurs et flux](../../../planification/S00/detail/D09-fournisseurs-et-flux.json).
- [D12 — dérivés et diffusion](../../../planification/S00/detail/D12-derives-et-diffusion.json).
- [D13 — validation et signature](../../../planification/S00/detail/D13-validation-et-signature.json).
- Matrice des droits, contrats et référence visuelle dans `planification/S00/consolidation/`.

**D07, point critique audio :** 30 jours après validation de la transcription ou du compte rendu, l’échéance déclenche une **demande** de suppression, sauf conservation autorisée. Toute suppression requiert validation préalable du super admin sur un lot identifié ; aucune lecture métier automatique ne lui est accordée. Sans validation, conserver en attente et signaler le dépassement. Ne pas implémenter une destruction automatique des originaux. L’exception D08 concerne uniquement les copies locales dont la version courante est confirmée sauvegardée sur le serveur, pas le travail non synchronisé ni les sauvegardes.

D07 fixe également corbeille 30 jours, sauvegardes base/fichiers 30 jours, RPO visé 1 heure et RTO visé 8 heures à mesurer, audit des accès/habilitations 12 mois. Les paramètres et garanties de production restent à qualifier en S16 ; la logique locale doit respecter les règles déjà validées. Réappliquer suppressions et révocations avant remise en service d’une restauration.

## Points d’entrée techniques

| Fichier / dossier relatif à application/ | Utilité |
| --- | --- |
| `frontend/modules/business/service.js` | Objets natifs, sauvegarde différée, revalidation et raccordements Réunions |
| `frontend/modules/business/publication.js` | Circuit de publication locale |
| `frontend/modules/ai/specialists.js` | `pvFromReunion`, génération et consultation du PV |
| `frontend/modules/ai/actions.js` | Panneau unii, sources autorisées, affichage du PV enregistré |
| `frontend/logic/shared.jsfrag` | Parcours de référence réunion, capture/lecture et marqueurs à auditer ; présence ne signifie pas migration achevée |
| `frontend/host/shell.html` | Interface native compilée ; ne pas modifier seulement le résultat généré |
| `uniion/adapters/business_records.py` | Contrats et persistance des objets métier |
| `uniion/adapters/ai_native.py`, `ai_runs.py`, `ai_artifacts.py` | Contextes natifs, exécutions et validation des sorties IA |
| `uniion/ai_http.py`, `uniion/core/ai_action_catalog.json` | Frontière HTTP et catalogue |
| `supabase/migrations/` | Migrations existantes ; ajouter une nouvelle migration sans réécrire les précédentes |
| `tests/s08_native_integration.py`, `tests/s08_native_followup.py` | Invariants de droits, sources dérivées et persistance |
| `frontend/state/business-native.test.mjs`, `ai-actions.test.mjs` | Régressions de navigation, concurrence et consultation |
| `operations/s08_final_*.py` | Exemples de recette isolée, restauration, intégrité et packaging ; ne pas réécrire leurs preuves S08 |

## Plan de démarrage proposé, non encore exécuté

Créer `application/preuves/S09-demarrage/` et un plan S09 avant les mutations importantes. Photographier l’intégrité des références. Inspecter les fonctions audio existantes et classifier chacune : réelle, locale seulement, simulée ou absente.

Découpage de travail proposé, à confronter aux contrats réels :

1. **A — contrats et persistance** : réunion, audio, consentement, marqueurs, états, permissions, stockage et migrations ; refus interorganisation et introrganisation.
2. **B — capture/import/lecture** : fichiers fictifs, formats, interruption, reprise et sauvegarde ; distinguer copie locale et original serveur.
3. **C — transcription durable** : moteur réel de recette autorisé, jobs persistants, progression, annulation, idempotence, redémarrage et sources invalidées.
4. **D — PV** : génération depuis transcription/notes, corrections, versions, relecture et approbation ; raccordement aux documents et copies diffusées sans élargir les accès source.
5. **E — conservation et restauration** : demandes à échéance, validation explicite, audit, protection des originaux et reprise cohérente ; tester les suppressions uniquement dans le périmètre autorisé.
6. **F — recette et transmission** : parcours complets, contrôles adverses, erreurs/reprise, formats disponibles et captures ; bilan honnête des appareils non testés, archive et registre des réserves.

Ne pas déclarer toute la chaîne terminée à partir de six sous-lots isolés : rejouer capture/import → fichier serveur → transcription → PV → validation → conservation/restauration. Tester les réponses tardives, changement de compte, révocation pendant un job, source modifiée, téléchargement/export et reprise après panne. Contrôler l’UI aux largeurs 360, 390, 768, 1024 et 1440 px sur les parcours affectés, avec clavier et faible hauteur.

## Environnement et vérification

Au dernier contrôle : application `http://127.0.0.1:5068`, Supabase local `http://127.0.0.1:54321`, base Docker `supabase_db_unii`. Ce sont des repères à vérifier, pas une garantie que les services sont toujours lancés. Ne pas tuer un processus sur la seule base du port.

Python 3.11+ requis. Runtimes observés :

- `/Users/mt/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`
- `/Users/mt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node`

Depuis `application/`, avec les runtimes adaptés :

```sh
python3 -B -m unittest discover -s tests -p 'test_*.py'
python3 -B scripts/check_boundaries.py
node --test frontend/state/*.test.mjs frontend/host/*.test.mjs
```

Depuis `application/frontend/` : `node build.mjs`.

Démarrage local si nécessaire depuis `application/` :

```sh
UNIION_ENV=development-local UNIION_SUPABASE_URL=http://127.0.0.1:54321 UNIION_HTTP_PORT=5068 UNIION_AI_CODEX_FIXTURES=1 python3 -B -m uniion.app
```

Ne pas afficher les fichiers `.local-*`. Les fixtures et clés locales restent privées ; les tests d’intégration créent/modifient des données fictives, donc lire leur portée avant exécution. Créer des preuves S09 séparées. Les scripts S08 ne doivent pas être relancés aveuglément s’ils écrasent des preuves historiques.

## État à la transmission

Ce handover prépare S09 ; aucun lot S09, aucune migration S09 ni intégration de transcription n’a été réalisé dans cette demande. Le prochain agent doit vérifier l’état actuel puis démarrer le lot A local sur instruction de la nouvelle conversation. Les décisions de production restent ouvertes en S16.

## Actualisation S09 — lot B finalisé localement (31 octobre 2026)

Le contexte S08 ci-dessus est historique. Pour poursuivre S09, lire désormais `../../preuves/S09-B-final/BILAN.md`, `../../preuves/S09-B-final/RECETTE-UI.md` et `../../preuves/S09-B-final/RESTE-A-FAIRE.md`. A puis B ont été réalisés sur données fictives, sans refonte ni déploiement. Migrations courantes : jusqu’à 170. Prochaine étape : C, transcription locale avec jobs durables ; D, E et F restent ouverts. Ne pas annoncer S09 clos, ni huit heures d’enregistrement matériel testées, ni tous les codecs/navigateurs qualifiés.


## 31 octobre 2026 — lot C local réalisé

Transcription réelle faster-whisper/base hors ligne, tâches durables et checkpoints par segment, worker dédié à accès Storage limité, annulation/reprise/idempotence et texte horodaté dans le panneau existant. Migrations 171–172. 57 contrôles C et 56 contrôles audio A2, 287 tests Python, 256 tests frontend ; build/frontières réussis. Recette UI desktop/tablette/mobile réalisée.

Référence : `../../preuves/S09-C/BILAN.md` ; reste : `../../preuves/S09-C/RESTE-A-FAIRE.md` ; démarrage moteur : `../../docs/S09-TRANSCRIPTION-LOCALE.md`. Aucun fournisseur de production, suppression ni changement de charte. La transcription peut comporter des erreurs et doit être relue ; PV encore fondé sur les notes. Prochain lot **D**, puis E/F et préparation S16. S09 reste ouvert.


## 31 octobre 2026 — lot D local réalisé

PV distinct alimenté par transcription et marqueurs, provenance et restrictions cumulatives, corrections versionnées, relecture par second acteur et publication S08 d’une copie limitée au titre/texte. Révocation disponible après retrait du consentement ; aucun partage direct du brouillon. Migrations 173–179.

86 contrôles de chaîne D et 57 de non-régression C, 287 tests Python, 266 tests frontend ; build et frontières réussis. Parcours UI à deux comptes, retrait et révocation, desktop/tablette/mobile vérifiés. L’assemblage n’est pas une synthèse IA simulée ; le contexte de l’assistant existant reste soumis à S08.

Bilan : `../../preuves/S09-D/BILAN.md` ; contrat : `../../docs/S09-PV-DERIVES.md` ; reste : `../../preuves/S09-D/RESTE-A-FAIRE.md`. Prochain lot **E**, puis F et préparation S16. S09 reste ouvert.


## 31 octobre 2026 — lot E local réalisé

Conservation audio à 30 jours après relecture du PV, demande/inventaire, prolongation motivée, approbation super admin MFA et exécution distincte reprenable. Effacement réel WAV/blocs/originaux sur données fictives, tombstones contre réinjection ; copies de PV distinctes conservées/révocables. Reçus pour nettoyage des seules copies locales entièrement sauvegardées. Migrations 180–182. Console d’exploitation documentée, carte existante raccordée, aucun nouveau design ni ordonnanceur.

99 contrôles de chaîne C/D/E, 470 contrôles de snapshot restauré et 16 contrôles complémentaires de réconciliation/reconnexion ; 287 tests Python et 274 frontend, build/frontières réussis. Reprise locale vérifiée en 37,958 s ; âge du snapshot 39,162 s, sans garantie de production. Anciennes sauvegardes conservées ; journal courant obligatoire avant admission d’une restauration.

Bilan : `../../preuves/S09-E/BILAN.md` ; contrat/commandes : `../../docs/S09-CONSERVATION-RESTAURATION.md` ; reste : `../../preuves/S09-E/RESTE-A-FAIRE.md`. Prochain lot **F**, puis qualification S16. Appareils physiques, endurance et acceptation produit restent à F ; aucune clôture globale S09 ni production annoncée.

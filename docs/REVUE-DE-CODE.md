# Revue de code — ordre de travail

Revue initialement en lecture seule. Ne pas lancer les scripts de mutation ou de restauration sans environnement fictif isolé. Ne pas confondre code actuel, prototypes et preuves historiques.

1. **État et exigences** : README racine → `application/preuves/S09-E/BILAN.md` → `RESTE-A-FAIRE.md` → handover S09 → `planification/S00/decisions.json`, `detail/`, puis `consolidation/droits-consolides.json`, `schema-consolide.json` et `contrats-commandes.json`.
2. **Architecture** : `application/pyproject.toml` → `frontend/package.json`/lock → `uniion/config.py` → `app.py` → `core/contracts.py`/`registry.py` → `modules/` → `scripts/check_boundaries.py`.
3. **Identité** : `uniion/http_sessions.py` → `adapters/sessions.py`, `durable_sessions.py`, `identity.py`, `supabase_transport.py`, `resources.py` → migrations et tests MFA/sessions/partages/support.
4. **SQL** : baseline puis migrations chronologiques. Retrouver la définition finale de chaque fonction, ses privilèges, les politiques RLS qui l’appellent et les effets des renommages. Vérifier isolement, SECURITY DEFINER/search_path, versions, verrouillages et accès directs.
5. **Fichiers** : `attachments.py`, `antivirus.py`, `office_files.py`, `safe_svg.py`, `document_images.py`, `evidence_preview.py`, documents/jobs/exports et adaptateurs de pièces jointes → Storage/RLS → frontend/tests.
6. **Métier/publication** : `business_records.py` → frontend `modules/business/service.js` et `publication.js` → migrations. Puis Agenda, Dossiers, Documents, Messages, Adhérents/cotisations et autres modules, chacun de bout en bout.
7. **IA** : `ai_http.py` → catalogue d’actions → `ai_context_service.py`, `ai_context.py`, `ai_native.py` → gateway/connecteur → runs/historique → propositions/drafts/artifacts → frontend IA/tests S08. Contrôler revalidation des sources, révocation, injection dans les sources, effets de sorties et fournisseurs implicites.
8. **S09 audio** : contrats S09 → `meeting_audio.py` → migrations 164–170 → frontend meetings `service.js`, `pcm-recorder.js`, `audio-files.js`, `audio-vault.js` → tests consentement/audio/PCM.
9. **S09 transcription/PV** : documentation locale → migrations 171–179 → `operations/transcription_worker.py` → commandes business → `minutes.js` → tests transcription/minutes. Vérifier leases, annulations, réponses tardives, sources exactes, versions et double validation.
10. **S09 conservation** : documentation conservation → migrations 180–182 → `audio_retention_admin.py`/`audio_retention.py` → `retention.js`/nettoyage du coffre → tests. Vérifier approbation exacte, inventaire périmé, prolongation, interruption, révocation d’approbateur, anti-réinjection et copies non synchronisées.
11. **Reprise** : `backup_restore.py` → `scheduled_backups.py`/configuration → `restore_services.py` → `audio_retention_restore.py`/`s09_e_restore.py` → déploiement. Contrôler couverture, snapshot, clés, journal courant, réconciliation, échecs partiels et admission.
12. **Frontend** : host React → shell → logique partagée → modules/services/runtime/state/theme → scripts de build → références visuelles. Ne pas corriger un fichier généré à la place de sa source. Tester chargement, erreurs, modales, navigation, clavier et responsive.
13. **Tests** : exécuter les contrôles non destructifs du README ; intégrations seulement après lecture et préparation isolée. Reproduire les anomalies importantes avec un scénario minimal.
14. **Preuves puis synthèse** : confronter les résultats au dossier `application/preuves/` et aux bilans historiques. Signaler les écarts entre annoncé, implémenté et effectivement testé.

Après chaque étape : fichiers examinés, constats, preuves, couverture et inconnues. Suivre les parcours UI → HTTP → adaptateur → RPC → ACL/RLS → stockage → réponse. Un bouton masqué ne prouve pas un refus serveur.

Rapport final : P0 critique, P1 majeur, P2 significatif, P3 mineur. Pour chaque constat : identifiant, statut confirmé/suspecté/amélioration, fichier et lignes, acteur/droits, reproduction, attendu/observé, impact, preuve, correction et test de non-régression. Terminer par les blocages, ordre des corrections, tests manquants, parties non analysées, conditions de clôture S09 et conditions de production S16. Ne pas conclure à une sécurité globale sur la seule revue statique ou les anciennes preuves locales.

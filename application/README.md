**État courant — 31 octobre 2026 : consolidation S08 A–F terminée en recette locale fictive, lot E finalisé ; clôture locale proposée.** [Bilan final](preuves/S08-F-final/CLOTURE.md) · [Réserves et décisions S16](preuves/S08-F-final/RESERVES.md). Les décisions de production sont reportées à S16 sur instruction utilisateur, avant tout usage réel. Les sections ci-dessous sont historiques et ne décrivent pas toutes l’état actuel.

**S06 — validation à deux acteurs et publication interne testées en local, 30 octobre 2026.** [Bilan courant](preuves/S06-validation-diffusion/BILAN.html). Diffusion limitée aux lecteurs déjà habilités, sans envoi externe ; S06 reste ouvert.

**S06 — exports PDF serveur raccordés et testés en local, 29 octobre 2026.** [Bilan courant](preuves/S06-exports/BILAN.html). Contrôle de téléchargement et de version ; S06 reste ouvert.

**S06 — logo global par défaut raccordé et testé en local, 29 octobre 2026.** [Bilan courant](preuves/S06-logo-global/BILAN.html). Les documents existants restent inchangés ; S06 reste ouvert.

**S06 — suite du 29 octobre 2026 : logos par document et extensions raccordés en local.** [Bilan courant](preuves/S06-logos-extensions/BILAN.html). Réserve : logo global par défaut, exports et autres critères S06.

**État courant au 29 octobre 2026 : S05 clôturé en local sur acceptation utilisateur ; S06 Documents démarré.** Voir [le bilan S06](preuves/S06-documents/BILAN.html) et [l’acceptation S05](preuves/S05-acceptation/ACCEPTATION.md). Les états ci-dessous sont historiques.

S03 — gabarit PDF Agenda et notifications destinataires raccordés et testés en local. Bilan courant : `preuves/S03-fidelite-notifications/BILAN.html`. Restent les autres réserves S03 et les personnalisations PDF hors gabarit natif.

S03 — export PDF contrôlé et publication interne avec seconde validation testés en local. Bilan courant : `preuves/S03-pdf-diffusion/BILAN.html`. Réserve : fidélité graphique complète du PDF et notifications destinataires à terminer. S03 reste ouvert.

S03 — convocations locales et ordre du jour persistant testés. Bilan courant : `preuves/S03-convocations-odj/BILAN.html`. S03 reste ouvert ; diffusion/PDF, sélection fine et historique durable restent à raccorder.

S03 — administration des audiences Agenda validée en local. Bilan courant : `preuves/S03-audiences/BILAN.html`. Le sprint reste ouvert.

S03 — extraction Agenda et raccordement réel à l’accueil validés en local. Bilan courant : `preuves/S03-extraction-agenda/BILAN.html`. Le sprint reste ouvert.

S03 — rappels automatiques locaux et export ICS contrôlé validés le 27 octobre 2026. Bilan courant : `preuves/S03-rappels-ics/BILAN.html`. Le sprint reste ouvert.

S03 Agenda — premier lot local testé le 27 octobre 2026. Lecture/création/modification Supabase et contrôles des audiences opérationnels ; sprint encore ouvert. Bilan : `preuves/S03-agenda/BILAN.html`.

# uniion — socle final, S01 clôturé en local
**S02 : trois réserves corrigées et clôture locale proposée.** Voir le [bilan des corrections finales](preuves/S02-corrections-finales/BILAN.html) pour les retests, le périmètre validé et les travaux des prochains sprints.

**État actuel :** voir [le bilan de clôture locale S01](preuves/S01-worker-source/BILAN.html) et [le guide de déploiement](deploiement/GUIDE-DEPLOIEMENT.html). Les sections plus bas décrivent aussi les lots précédents ; le dernier bilan fait foi pour les réserves levées ou encore ouvertes.

Dossier autonome, séparé de la copie et de S00. Python 3.11+ ; dépendance cryptography, version fixée dans pyproject.toml. Ce premier lot est une fondation serveur en lecture seule, pas encore l’application finale ni un serveur de production.

## Exécution locale

Depuis `application/` :

```sh
UNIION_ENV=development-local UNIION_SUPABASE_URL=http://127.0.0.1:54321 python3 -B -m uniion.app
```

Écoute exclusivement sur `127.0.0.1:5060`. `GET /health` ne retourne aucune donnée métier. La seule route métier est `GET /api/organizations/{uuid}/resources/{uuid}`, avec un cookie de session serveur valide. Les jetons Bearer fournis directement à cette API sont refusés. Aucun jeton dans une URL, un journal ou un stockage navigateur. Les cookies et le renouvellement sont gérés côté serveur. Le frontal reste à porter en S02 ; aucun écran de prototype n’a été remplacé.

## Structure et frontières

- `uniion/core/` : contrats, principal organisation/utilisateur et registre versionné.
- `uniion/modules/resources/` : module de transition pour lire une ressource autorisée, sans dépendance Supabase.
- `uniion/adapters/` : transport Supabase et port d’accès aux ressources. Vérification de l’utilisateur et de l’appartenance, puis RLS avec son jeton. Aucun privilège global ni service_role.
- `uniion/app.py` : assemblage des modules et routage local. Aucune extension distante ou exécution arbitraire de code.
- `supabase/baseline/` : copie exacte des 14 migrations de recette et empreintes. **Non appliquées par ce lot** ; aucun reset automatique ni changement du schéma existant.
- `tests/` : tests unitaires et intégration locale explicite, en lecture seule sur les comptes fictifs existants (création/fermeture des sessions Auth uniquement).

Le manifeste décrit les commandes, sans accorder de droit. La base conserve la décision d’accès aux ressources et modules. Les exceptions de partage restent dans les RPC déjà validées ; ce module initial ne les expose pas et refuse les lectures transversales directes. Aucun raccourci super-admin ne donne accès aux contenus.

## Vérification

```sh
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B scripts/check_boundaries.py
python3 -B tests/local_integration.py
```

La dernière commande utilise les identifiants fictifs existants dans la copie, sans les recopier ici et sans les imprimer. Ne pas l’utiliser avec des comptes réels. La configuration actuelle refuse explicitement un lancement recette/production ; ces environnements doivent être créés séparément.

Le workflow `.github/workflows/quality.yml` est un modèle pour ce dossier comme racine du futur dépôt. Il n’est pas actif : aucun dépôt distant n’a été créé. Il ne remplace pas les tests RLS et intégrations dans un environnement de CI isolé, à préparer.

## Limites et suite S01

1. Sessions serveur et MFA TOTP locaux implémentés : voir le bilan S01-sessions-mfa. Restent invitations/récupération, gestion d’appartenance et stockage partagé des sessions pour la production. Aucun formulaire de prototype ni fournisseur email de production ajouté ici.
2. Ajouter des identités de recette multi-organisations, invitées, révoquées et plateforme, et tester tous les accès directs associés. Les révocations dans ce premier lot sont testées par simulation contrôlée ; les tests réels de ce lot ne modifient aucun droit.
3. Créer les environnements distincts, les secrets et la chaîne de livraison ; sélectionner le dépôt distant et les projets Supabase dédiés.
4. Préparer la migration du modèle de transition : dossiers/docs sont actuellement portés par le module SQL `socle`, contrairement à leurs propriétaires finaux dans S00. Ne pas déployer cette baseline comme schéma final sans migration explicite et répétition.
5. Porter les opérations d’écriture, fichiers et partage dans leurs services/modules dédiés, en réutilisant leurs preuves et en retestant chaque frontière.
6. S02 : frontal compilé, composants visuels extraits sans changement de design, activation des modules et comparaisons visuelles.

La sauvegarde externe, la garde des clés et la supervision indépendante restent nécessaires avant production. Aucun déploiement OVH, souscription, suppression de données ou migration de données métier réalisé ici.

## Sessions et MFA — lot du 26 octobre 2026

Routes de cette origine locale :

- `GET /auth/session` : amorçage du cookie opaque et CSRF ; statut d’authentification et MFA, jamais les jetons Supabase.
- `POST /auth/login`, `/auth/logout` : mot de passe, rotation du cookie/CSRF, révocation du renouvellement distant (y compris après expiration du JWT).
- `POST /auth/mfa/enroll` : TOTP, matériel d’enrôlement retourné uniquement pour la configuration de l’authentificateur.
- `POST /auth/mfa/challenge`, `/auth/mfa/verify` : défi lié à la session, code de six chiffres, élévation AAL2 et rotation du cookie/CSRF.
- `POST /auth/mfa/remove` : retrait d’un facteur en session vérifiée ; le dernier facteur vérifié est protégé. La récupération assistée reste à développer.

Les POST exigent Origin `http://127.0.0.1:5060`, JSON et `X-Uniion-CSRF`. Le cookie est HttpOnly/SameSite=Strict, non Secure sur ce HTTP de boucle locale uniquement. La production reste désactivée ; HTTPS/Secure indispensables pour l’ouvrir.

Sessions locales en mémoire : maximum 8 h, inactivité de requêtes 30 min, sessions anonymes 10 min, quotas et limites de tentatives. Renouvellement sérialisé. Un redémarrage ferme les sessions applicatives ; ce stockage n’est pas encore adapté à plusieurs instances. Une panne Auth pendant une révocation ferme l’accès local mais ne garantit pas la révocation distante ; une file durable de reprises est à prévoir en production.

Migration `supabase/migrations/202610260015_sessions_mfa.sql` appliquée localement : contrôle de session active et d’assurance dans les fonctions d’appartenance utilisées par RLS et les RPC métier. Les interfaces Auth restent accessibles pour accomplir le défi MFA. Le contrôle ne prétend pas protéger les tables d’autres applications partageant cette pile, ni les opérations privilégiées de service.

Politique actuelle : les comptes sans MFA restent utilisables ; après activation réussie dans ce socle, le MFA devient requis pour l’accès métier. L’exigence reste en base après retrait d’un facteur. L’obligation automatique par rôle privilégié et la récupération sûre restent à finaliser avant clôture S01. Aucun droit métier n’est accordé par le MFA.

### Recette dédiée

`tests/sessions_mfa_integration.py` : MFA réellement vérifié par Supabase, secrets TOTP exclusivement en mémoire. Les deux comptes fictifs dédiés sont inscrits via l’API publique Auth et confirmés uniquement depuis leurs emails Mailpit locaux ; aucun secret admin extrait. Les facteurs créés par ce test sont retirés en fin de recette via la session du compte concerné. Aucune donnée métier ni sauvegarde supprimée. Le compte de test principal conserve l’exigence MFA et doit ré-enrôler un facteur pour une nouvelle recette.

`tests/sessions_http.py` : cookies et accès par HTTP réel sur 5060. `tests/test_sessions.py` : expiration, concurrence du renouvellement, quotas, CSRF et origine sans attendre réellement 8 heures.

**Historique du premier lot — réserve alors identifiée :** le mécanisme de sauvegarde de recette refuse les comptes avec facteurs MFA plutôt que de produire une sauvegarde incomplète. Les facteurs de test sont retirés et le moniteur reste sain, mais un MFA permanent ne doit pas être activé sur des comptes à conserver avant d’intégrer la sauvegarde/restauration Auth/MFA et ses clés. Les anciennes suites SQL qui simulent seulement `sub` doivent être adaptées à de vraies sessions et claims ; ne pas désactiver le nouveau contrôle pour les faire passer.

Documentation primaire : https://supabase.com/docs/guides/auth/auth-mfa et https://supabase.com/docs/guides/auth/auth-mfa/totp


## Finalisation locale — 26 octobre 2026

Voir `preuves/S01-finalisation/BILAN.html` : 271 contrôles passent, 834 références inchangées. S01 reste ouvert selon la liste précise du bilan.

Routes supplémentaires : `POST /auth/recovery/request`, `/auth/recovery/verify` et `/auth/password`. Les jetons de récupération sont reçus en JSON, jamais en URL du BFF ; après vérification la fenêtre de modification est de 10 minutes. Modifier un mot de passe exige le MFA si requis, puis ferme les sessions Auth globales. Le parcours visuel et le routage du lien email restent à brancher en S02. La récupération assistée après perte de tous les facteurs et le contrôle des réenrôlements par accès Auth direct ne sont pas validés.

`operations/backup_restore.py`, `restore_services.py`, `security_cut.py` et `mfa_restore_drill.py` sont autonomes dans ce dossier. La restauration réelle préserve les facteurs TOTP vérifiés et exigences MFA, les données et fichiers. Les révocations postérieures sont réconciliées et les sessions créées pendant la vérification sont clôturées. Les cibles restent isolées ; aucun service de la source n’est remplacé. Ce moteur n’est PAS encore raccordé au planificateur existant : la réserve d’activation permanente du MFA reste applicable.

Tests supplémentaires : `tests/recovery_integration.py` (change uniquement le mot de passe d’un compte fictif et actualise son fichier privé), `tests/backup_factor_integration.py` (facteurs fictifs temporaires), `operations/mfa_restore_drill.py` (archive chiffrée, cible isolée, aucun nettoyage des sauvegardes). Ces opérations nécessitent le runtime Python avec cryptography et Docker local ; elles ne sont pas des tests unitaires sans effets. Ne pas les lancer en parallèle sur le même compte MFA.


## Invitations, confiance MFA et planification — 26 octobre 2026

Migrations locales supplémentaires appliquées dans l’ordre : 016 (facteurs approuvés), 017 (invitations), 018 (demandes MFA), 019 (révocation des opérateurs). Aucune migration de baseline n’a été réécrite. Les nouvelles tables privées ne sont accessibles que par les fonctions explicitement accordées aux utilisateurs Auth.

Routes : `/identity/invitations/create`, `/identity/invitations/accept`, `/identity/invitations/revoke`, `/identity/memberships/revoke` ; `/auth/mfa/recovery/enroll`, `/auth/mfa/recovery/request`, `/auth/mfa/recovery/approve`. Toutes passent par les cookies serveur, Origin et CSRF. Les RPC contrôlent également les droits et le MFA en accès direct. L’invitation ne donne aucun droit métier et le membre révoqué ne peut pas être réadmis silencieusement.

Le registre privé `platform_operators` désigne exclusivement les super administrateurs autorisés à valider une récupération ; il ne donne aucun accès métier. Aucun utilisateur ne peut s’y inscrire via l’API. L’opérateur fictif de recette est désactivé après test. La vérification humaine d’identité est indispensable : la référence enregistrée n’est pas une preuve automatique de cette vérification.

Limite confirmée : un appareil perdu dont le facteur reste enregistré bloque la création du remplacement en AAL1. Le circuit d’approbation livré ne contourne pas ce refus ; un adaptateur Auth privilégié et une recette complète restent nécessaires. Aucun secret interne Auth n’est extrait. La confiance d’un facteur approuvé est limitée à 30 minutes jusqu’à sa première validation réussie ; les anciens facteurs et sessions perdent leur autorisation.

Le planificateur macOS `org.uniion.local-backups` pointe maintenant vers `application/operations/scheduled_backups.py`. Configuration : `operations/backup-schedule.json`. Commandes : `tick`, `tick --force`, `monitor`, `monitor --ack`. Le forçage garde le verrou, les vérifications d’espace et l’interdiction de purge. Un exemplaire de l’ancienne configuration launchd est conservé pour retour arrière ; les anciennes archives ne sont pas déplacées. Le suivi du chat conserve son état PAUSED.

`tests/fixture_mfa_setup.py` est strictement réservé aux deux comptes fictifs locaux : il remet le compte MFA dédié dans l’état de premier enrôlement entre scénarios, uniquement en l’absence de facteur vérifié. Il n’est jamais importé par le serveur. `identity_integration.py` crée une organisation fictive par exécution. `assisted_mfa_integration.py` active temporairement puis désactive l’opérateur fictif, et distingue explicitement le cas encore bloqué.


## Sessions durables locales — état actuel

Le lancement `python -B -m uniion.app` utilise désormais `DurableSessionStore` : état chiffré AES-GCM dans `.local-sessions/state.sqlite3`, clé privée dans `.local-auth/session-encryption.key`. Ces fichiers ne sont pas destinés aux sauvegardes métier. Ne jamais régénérer la clé pour tenter de lire une base existante : une clé perdue ou un état altéré doit déclencher une intervention, pas un retour silencieux à des sessions vides.

SQLite sérialise les transactions entre processus du même hôte. Sessions, CSRF, limites de tentatives et file de révocation sont persistants. Les tests unitaires peuvent continuer à injecter le stockage mémoire ; `create_app(..., session_store=...)` permet les tests durables isolés. La dépendance `cryptography==50.0.2` est déclarée dans pyproject.toml.

La maintenance tourne toutes les 30 secondes dans le serveur local, avec reprises espacées jusqu’à 5 minutes, au plus quatre révocations par passage. Si la file atteint le seuil de protection, la création de sessions est refusée. Une panne Auth peut retarder la révocation distante mais ne maintient pas l’accès local. La supervision de cette file et le stockage multi-hôtes restent à qualifier pour la production.

Recettes : `tests/test_durable_sessions.py` (13 tests, dont processus séparés, état altéré, clé incorrecte et panne), `tests/durable_http.py` (prend temporairement le port 5060 et redémarre ses propres processus ; arrêter préalablement le serveur de recette identifié), `tests/durable_integration.py` (Auth réel avec échec de logout injecté dans le transport de test uniquement). Voir le dernier bilan : 175 contrôles exécutés dans ce lot, sans addition des anciennes suites non rejouées.


## Administration et appareil perdu — dernier lot S01

Migrations 020 à 024 appliquées localement. Les sept anciennes commandes privilégiées exigent AAL2 + facteur approuvé + leurs droits métier. Les lectures ordinaires de partages ne sont pas soumises à cette nouvelle exigence d’administration. Le prototype HTML est inchangé, mais ses appels admin AAL1 sont désormais refusés ; le frontal devra présenter le défi MFA.

Nouvelles routes serveur : `/auth/mfa/lost/request`, `/auth/mfa/lost/approve`, `/auth/mfa/lost/cancel`. Le traitement privilégié est séparé dans `operations/auth_recovery_worker.py`, avec snapshot des facteurs, approbation distincte, bail, vérification avant chaque suppression, refus des rejeux et permission de réenrôlement à usage unique. La clé est fournie exclusivement par fichier privé ; aucune extraction de clé source. Modèle sans secret : `operations/auth-admin.example.json`.

`operations/lost_factor_drill.py` crée une restauration isolée, génère sa propre clé temporaire et teste réellement la perte d’appareil avec facteur encore enregistré, l’API administrative officielle, le réenrôlement et le cloisonnement. Il inclut aussi une identité fictive extérieure à UNIION pour vérifier son refus. Les facteurs de la source ne sont pas modifiés par cette recette.

Le worker source n’est pas configuré : aucun credential admin dédié n’a été fourni. L’activation opérationnelle (configuration, super administrateurs, supervision du worker) reste à réaliser. Ne pas interpréter la réussite isolée comme un déploiement ou une activation source. Les clés de service Supabase disposent de privilèges larges ; elles doivent rester séparées du processus HTTP.

Dernier bilan : 407 contrôles exécutés pour ce lot, 834 références conformes. Reste notamment la qualification des sessions en situation de crash, l’infrastructure et le raccordement des écrans S02. La restauration annule tous les jobs de récupération non terminés avant une éventuelle réadmission.


## Résilience des sessions — dernier lot

Les opérations Auth sensibles sont marquées et sauvegardées avant l’appel distant. Un crash avant l’enregistrement d’un renouvellement ferme la session locale ; un renouvellement déjà enregistré reste disponible. La déconnexion enregistre la fermeture locale et la file de révocation avant de contacter Auth. Un verrou POSIX reste détenu pendant les validations SQLite intermédiaires, pour sérialiser les processus compatibles. Ne pas mélanger cette implémentation et une ancienne version du magasin sur le même état.

Les expirations en lot n’appellent pas Auth dans la boucle de la requête utilisateur. La maintenance reprend au plus UNE révocation par passage de 30 secondes, avec backoff jusqu’à 5 minutes. C’est une limite volontaire pour ce socle local ; la capacité de traitement doit être dimensionnée avant production. Une révocation globale ambiguë reste en attente, bloque les accès locaux concernés et nécessite éventuellement une vérification opérateur. Elle n’est jamais effacée au motif que le seul jeton initiateur est refusé.

État opérationnel : `.local-sessions/health.json`, uniquement des compteurs et une date, sans secret. Lecture indépendante : `python -B operations/session_health.py`. Seuil de maintenance trop ancienne : 120 secondes ; révocations retardées : 300 secondes. Les notifications et le collecteur externe ne sont pas encore raccordés. Le workflow CI préparé installe maintenant la dépendance cryptographique déclarée ; il n’est pas activé sur un dépôt distant.

Recette : `tests/test_session_crashes.py` (sorties brutales de processus enfants simulant Auth), `tests/crash_integration.py` (deux sorties brutales lors de renouvellements réels Supabase sur compte fictif), `tests/durable_mfa.py` et les régressions HTTP/droits. Bilan : 185 contrôles ciblés, preuves datées dans `preuves/S01-resilience/`. Les scénarios de crash local sont qualifiés ; cela ne constitue pas une garantie de panne électrique, de multi-hôtes ou de charge de production.

## S02 — compilation locale

Voir [le bilan de compilation](preuves/S02-compilation/BILAN.html). Frontal de démonstration compilé sur le port 5063 ; ne pas le confondre avec les services réels S01. Build : depuis frontend, `npm ci` puis `npm run build`.


## S02 — états et services séparés (26 octobre 2026)

Dernier bilan : [états et services](preuves/S02-etats-services/BILAN.html). Quatre magasins propriétaires et services pour navigation, dossiers, contacts et thème ; projection en lecture pour le rendu et répartiteur temporaire pour les actions héritées. Le frontal reste fictif, en mémoire, sans raccordement S01. Ce découpage ne constitue pas une barrière de sécurité serveur.

Compilation : lancer `node build.mjs` depuis `frontend/`. Tests : `node state/module-stores.test.mjs` et `node host/module-contract.test.mjs`. Serveur depuis application : `UNIION_NATIVE=1 UNIION_FRONTEND_PORT=5065 python -B -m uniion.frontend`.

23 contrôles d’états/services, 6 contrats, 12 comparaisons de rendu et parcours de création aux trois formats validés. S02 reste ouvert pour les actions héritées, les autres écrans et le raccordement réel aux droits et sessions.


## S02 — actions migrées (26 octobre 2026)

[Bilan du lot](preuves/S02-actions-services/BILAN.html). Treize méthodes migrées, dont six retirées du contrôleur commun. Sources : modules/{cases,contacts,theme}/actions.js, contacts/mutations.js et messaging/contact-links.js. Les discussions appartiennent au magasin messaging ; les contacts utilisent un port explicite pour maintenir leurs liens. Tests supplémentaires : `node state/actions.test.mjs` depuis frontend. Le frontal reste fictif ; S02 reste ouvert.


## S02 — messagerie et actions transversales

[Bilan du lot](preuves/S02-messagerie/BILAN.html). Sources : frontend/modules/messaging/actions.js et frontend/modules/cases/creation.js. 20 méthodes migrées, dont 19 sorties du contrôleur commun. Tests : `node state/messaging.test.mjs` depuis frontend. Les vues de messagerie et l’orchestration IA restent dans la coque commune ; raccordement réel S01 encore à faire. 55 contrôles automatisés et 15 comparaisons de rendu validés.


## S02 — vues et préparateurs de messagerie

[Bilan du lot](preuves/S02-vues-messagerie/BILAN.html). Vues sources : frontend/modules/messaging.html, messaging-group.html, messaging-forward.html ; compilées dans generated/. Le préparateur frontend/modules/messaging/presenters.js remplace quatre méthodes et deux blocs de calcul de l’hôte. Modales sans route indépendante. Test : `node state/presenters.test.mjs` depuis frontend. 61 contrôles automatisés et 15 comparaisons conformes ; S02 demeure ouvert.


## S02 — menus et passages aux dossiers

[Bilan](preuves/S02-menus/BILAN.html). Sources : frontend/modules/messaging/menu.js, modules/cases/picker.js et modules/case-picker.html. Le menu utilise une interface explicite vers l’état Dossiers. Deux méthodes retirées du contrôleur commun. Test : `node state/menus.test.mjs` depuis frontend. 54 contrôles et trois comparaisons de modale validés.


## S02 — campagnes et orchestration IA

[Bilan](preuves/S02-campagnes-ia/BILAN.html). Sources : frontend/modules/contacts/campaigns.js et frontend/modules/ai/orchestration.js. Sept méthodes extraites du contrôleur commun. Test : `node state/campaigns-ai.test.mjs` depuis frontend. 49 contrôles réussis ; campagnes et échec IA vérifiés aux trois formats. Transport IA réel et envois externes non raccordés.


## S02 — vue et préparateur de campagne

[Bilan](preuves/S02-vues-campagnes/BILAN.html). Sources : frontend/modules/campaign.html et modules/contacts/campaign-presenter.js. Route adhmsg conservée. Test : `node state/campaign-presenter.test.mjs` depuis frontend. 40 contrôles automatisés réussis ; parcours depuis les listes testé aux trois formats sans ouverture préalable en desktop. Le reste du module adhérents demeure à extraire.


## S02 — vues adhérents et filtrage

[Bilan](preuves/S02-adherents/BILAN.html). Vues : frontend/modules/members.html et member-detail.html. Filtrage : modules/contacts/member-filter.js (six fonctions extraites). Test : `node state/member-filter.test.mjs` depuis frontend. 40 contrôles et neuf comparaisons conformes. Le préparateur général et les actions de gestion restent à extraire.


## S02 — préparateur et gestion adhérents

[Bilan](preuves/S02-gestion-adherents/BILAN.html). Source : frontend/modules/contacts/member-management.js ; 17 méthodes retirées du contrôleur commun. Test : `node state/member-management.test.mjs` depuis frontend. 48 contrôles ; édition, cotisation fictive et import partiel testés aux trois formats. L’import administratif et les ports documentaires restent à découpler.


## S02 — import administratif et fichiers

[Bilan](preuves/S02-fichiers-admin/BILAN.html). Services modules/admin/import.js et services/csv-files.js. Sélection CSV et téléchargement réels testés aux trois formats. Import administratif testé au niveau service ; parcours complet UI restant.


### S02 — Parcours administratif (26 octobre 2026)
Recette locale import élus, doublons, annulation, tableau et modale aux formats 390/820/1440. Bilan : `preuves/S02-parcours-admin/BILAN.html`. Corrections de ciblage des doublons, retour contextuel et compteurs. Administration de production et clôture S02 non acquises.


### S02 — Extraction administrative
Trois vues et préparateur/actions administratifs extraits, HTML inchangé. Recette locale mobile/tablette/desktop : `preuves/S02-admin-modules/BILAN.html`. Invitations partagées et raccordement S01 restent à faire.


### S02 — Invitation indépendante
Vue, état, définition et soumission simulée extraits dans le module administratif. Recette aux trois formats : `preuves/S02-invitation/BILAN.html`. Aucun envoi réel ; raccordement S01 restant.


### S02 — Transport invitations S01
Entrée prévue `/s02?organization=UUID` sur 5060, après rechargement S01 ; session S01 MFA préalable requise. Adaptateur frontal réel disponible, 34 tests Supabase validés. Livraison des liens et connexion visible S02 non terminées. Voir `preuves/S02-invitations-s01/BILAN.html`.


### S02 - Connexion/MFA et Mailpit local (2026-10-27)
Port navigateur 5068 via UNIION_HTTP_PORT. Connexion/MFA, envoi local et acceptation testes, sans droits metier automatiques. Voir `preuves/S02-connexion-mail/BILAN.html`. Annuaire, profil et suivi restent fictifs.


### S02 - Profil et annuaire reels (2026-10-27)
Migration 202610270030_identity_views.sql appliquee localement. Profil propre et annuaire administratif controles par session, appartenance, MFA et autorite. Voir `preuves/S02-profil-annuaire/BILAN.html`. Lecture raccordee ; edition et commandes de gestion restent a finaliser.


### S03 — Archives PDF/ICS, 28 octobre 2026

Migration 071 : archives binaires privées enregistrées et vérifiées avant les envois locaux ; historique sans régénération des nouveaux PDF/ICS. Les anciens envois sans archive ne sont pas présentés comme des originaux. Sauvegarde adaptée aux objets archivés. Recette : `preuves/S03-archives/BILAN.html`. S03 reste ouvert, notamment restauration globale et supervision des envois incertains.


### S04 — Premier lot adhérents (28 octobre 2026)

Registre privé Supabase, import CSV atomique, consultation/filtrage et édition avec contrôle de version ; droits financiers séparés. Migrations 072–073. 33 contrôles intégration, 139 tests Python et 31 tests frontaux réussis ; recette UI aux trois formats. Voir [le bilan](preuves/S04-adherents/BILAN.html) pour les preuves et limites. S04 reste ouvert (cotisations structurées, exports, listes/campagnes, administration des droits, volumes/reprise et recette complète). S03 conserve ses réserves ; prototype et S00 inchangés.


### S04 — Dates et cotisations structurées (28 octobre 2026)

Migration 074 appliquée en local : date exacte et termes monétaires calculés/persistants, source conservée, validation serveur et client, permissions financières actives/non expirées. Aucun encaissement ni échéancier. 71 contrôles intégration, 33 tests frontaux, 139 tests Python ; parcours aux trois formats et rechargement vérifiés. [Bilan et réserves](preuves/S04-cotisations-structurees/BILAN.html). S04 et S03 restent ouverts.


### S04 — Registre des échéances et règlements (28 octobre 2026)

Migrations 075–076 locales. Création explicite par API, déclaration intégrale via le bouton existant pour une échéance unique, historique privé et reprise idempotente. 52 contrôles intégration, 35 tests frontaux, 139 tests Python ; déclaration mobile et consultation aux trois formats. [Bilan et limites](preuves/S04-reglements/BILAN.html). Création UI, échéanciers, corrections, partiels et reçus restent à réaliser. S04 ouvert.


### S04 — Création des échéances dans la fiche (28 octobre 2026)

Formulaire intégré, montant et dates explicites, annulation, erreurs en place et UUID stable lors des réessais. Trois créations UI aux formats mobile/tablette/desktop, puis relecture après reconnexion. 52 contrôles intégration, 39 tests frontaux, 139 tests Python. [Bilan](preuves/S04-creation-echeances/BILAN.html). S04 ouvert ; sélection multi-échéances, partiels, corrections et reçus restent à faire.


### S04 — Sélection et règlements partiels (28 octobre 2026)

Migration 077 : écritures de règlement distinctes, reprise des règlements intégraux, solde calculé, verrou transactionnel et UUID de reprise. Sélection explicite et déclaration partielle/intégrale dans la fiche ; rappel lisible du solde aux petits formats. 50 contrôles intégration, 43 tests frontaux, 139 tests Python ; trois règlements UI et rechargement vérifiés. [Bilan](preuves/S04-reglements-partiels/BILAN.html). S04 ouvert : corrections auditées, reçus, synthèses, exports et recette globale notamment restent à réaliser.


## S04 — Corrections auditées des règlements (28 octobre 2026)

Migration 078 : corrections append-only, motif/auteur/révision, annulation par montant zéro sans suppression et recalcul du solde. Recette : 69 contrôles intégration, 46 tests frontaux, 139 tests Python ; UI autorisée et sans droit financier aux trois formats. Prototype/S00 : 834 empreintes inchangées. Bilan : [preuves/S04-corrections-reglements/BILAN.html](preuves/S04-corrections-reglements/BILAN.html). S04 reste ouvert ; date effective, justificatifs, reçus/exports et recette/restauration sur pile neuve restent notamment à réaliser.


## S04 — Dates effectives et justificatifs (28 octobre 2026)

Migrations 079–080 : date effective distincte de la déclaration et correction auditée ; fichiers privés immuables par règlement, antivirus, contrôle financier et téléchargement distinct. Recette locale : 95 contrôles intégration, 51 tests frontaux, 139 tests Python ; autorisations/refus sur trois viewports. 834 références inchangées. [Bilan et limites](preuves/S04-dates-justificatifs/BILAN.html). S04 ouvert : reçus/exports, échéanciers, reprise des analyses interrompues et recette/restauration sur pile neuve restent à réaliser.


## S04 — Aperçu et reprise des analyses (28 octobre 2026)

Migration 081 : aperçu PDF/images rendu côté serveur et TXT/Word/Excel en texte inerte ; reprise manuelle des analyses en attente avec intégrité, antivirus et droits. 128 contrôles intégration, 53 tests frontaux et 143 tests Python ; reprises et pagination réellement testées aux trois formats, avec compte sans droit financier. [Bilan et limites](preuves/S04-apercu-reprise/BILAN.html). 834 références intactes. S04 reste ouvert : reçus/exports, échéanciers, recette globale/restauration notamment.

## S04 — Reçus et exports contrôlés (28 octobre 2026)

Migration 082 : reçu non fiscal figé par révision et CSV par adhérent ; lecture financière et autorisation distincte de téléchargement, contrôle avant livraison, audit et protection des cellules CSV. 118 contrôles intégration, 55 tests frontaux, 145 tests Python ; six téléchargements UI aux trois formats et refus vérifiés. 834 références inchangées. [Bilan et limites](preuves/S04-recus-exports/BILAN.html). S04 reste ouvert : synthèses, échéanciers, autres parcours métier et recette/restauration globale. Le PDF est régénéré depuis un instantané durable, sans archivage binaire dans ce lot ; attestation fiscale non raccordée.

## S04 — Synthèses financières réelles (28 octobre 2026)

Migration 083 et préparateur contacts : recouvrement des échéances exigibles, déclarations trimestrielles datées, solde exigible, retards et modes réels ; corrections/annulations intégrées sans double comptage, données absentes sans droit financier. 54 contrôles intégration, 62 tests frontaux, 145 tests Python ; recette aux trois formats, 834 références inchangées. [Bilan et définitions](preuves/S04-syntheses/BILAN.html). S04 ouvert : échéanciers, relances/campagnes, volumes et recette/restauration globale notamment.

## S04 — Échéanciers automatiques (28 octobre 2026)

Migration 084 : plans privés sur nouvelles adhésions/imports valides, dates ancrées et fin de mois, génération des occurrences dues, anti-doublon, contrôle des droits courants et pause conservant l’historique. pg_cron local testé puis remis à fréquence horaire (script operations/install_dues_cron.sql). 58 contrôles intégration, 64 tests frontaux, 145 tests Python ; 834 références intactes. [Bilan et réserves](preuves/S04-echeanciers/BILAN.html). S04 ouvert : reprise/revalidation des plans, fin d’adhésion, relances, volumes, alertes et restauration notamment.

## S04 — Reprise des échéanciers et tarifs (28 octobre 2026)

Migration 085 : proposition et confirmation versionnées, reprise sans rattrapage, nouveau tarif uniquement pour les échéances non créées, audit avant/après et réessai idempotent. 83 contrôles intégration, 67 tests frontaux, 145 tests Python ; autorisations/refus aux trois formats, modification du tarif et confirmation UI. 834 références intactes. [Bilan](preuves/S04-reprise-tarifs/BILAN.html). Restent notamment cadence/ancre, conflits, fin d’adhésion, relances et recette globale/restauration.

## S04 — Cadences et conflits (28 octobre 2026)

Migration 086 : ancre de cadence distincte de l’adhésion, couverture explicite des anciennes échéances manuelles, chevauchements bloquants, confirmation versionnée et auditée sans modification financière historique. 65 contrôles intégration, 70 tests frontaux, 145 tests Python ; recette des états autorisés/refusés aux trois formats et confirmation réelle desktop. 834 références intactes. [Bilan et limites](preuves/S04-cadence-conflits/BILAN.html). S04 reste ouvert : corrections de couverture déjà confirmée, fin d’adhésion, anciennes fiches, relances et recette/restauration globale notamment.

## S04 — Corrections auditées des couvertures (28 octobre 2026)

Migration 087 : correction explicite des fins de couverture manuelles confirmées, motif obligatoire, version, rejeu idempotent et audit avant/après. Montants et règlements inchangés ; chevauchements refusés, sans reprise automatique. 71 contrôles intégration, 73 tests frontaux, 145 tests Python ; trois corrections et refus de chevauchement réellement testés aux trois formats, droits insuffisants vérifiés. 834 références intactes. [Bilan et limites](preuves/S04-corrections-couvertures/BILAN.html). Restent notamment fin d’adhésion, anciennes fiches, relances et recette globale/restauration incluant la nouvelle table ; chaîne complète sur pile neuve non rejouée dans ce lot.

## S04 — Fin d’adhésion et arrêt des échéanciers (28 octobre 2026)

Migration 088 : date effective et motif, version, audit et rejeu ; arrêt des nouvelles échéances dès la fin, sans effacer l’historique ni le reste dû. Garde en base, worker et commandes de reprise protégés. Les anciennes dettes restent réglables. 69 contrôles intégration, 76 tests frontaux, 145 tests Python ; trois fins confirmées dans l’interface et refus aux trois formats, 834 références intactes. [Bilan et réserves](preuves/S04-fin-adhesion/BILAN.html). S04 ouvert : réadhésion/correction de fin, anciennes fiches, relances, volumes/alertes, recette globale et restauration des nouvelles tables. Aucune révocation implicite des comptes plateforme depuis le registre adhérents.

## S04 — Réadhésion et correction de fin (29 octobre 2026)

Migration 089 : cycles conservés, correction de fin auditée sans redémarrage, choix explicite entre plan en pause et reprise avec tarif/cadence/première échéance confirmés. Contrôles de version, de droits, de périodes et rejeu ; ancienne dette conservée. 89 contrôles dans la suite principale, 39 dans la suite ciblée du jour (socle commun), 78 tests frontaux et 145 tests Python. Six corrections et six réadhésions aux trois formats ; refus et chevauchement vérifiés. 834 références intactes. [Bilan et limites](preuves/S04-readhesion/BILAN.html). Restent anciennes fiches sans plan, relances, volumes/alertes et recette globale/restauration ; production et chaîne complète sur pile neuve non validées par ce lot.


## S04 — Clôture technique locale proposée (29 octobre 2026)

Migrations 090–093 : listes durables et critères financiers cloisonnés, contrat des destinataires, export minimal autorisé, activation explicite des anciennes fiches et couvertures sans plan. Libellés des sélecteurs React corrigés ; composants et parcours conservés. Sauvegarde des justificatifs et ordre de restauration des colonnes calculées corrigés. 80 contrôles de clôture, 48 ciblés sur les listes financières (socle commun), 16 suites de non-régression S04, 79 tests frontaux et 145 tests unitaires Python. 92 contrôles sur pile neuve ; restauration de 65 tables/174 fichiers, 241 vérifications et 16 contrôles Auth/MFA/droits après reprise. Parcours autorisés/refusés aux trois formats. 834 références intactes. [Bilan de clôture](preuves/S04-cloture/BILAN.html) et [contrats](documentation/CONTRATS-S04.md).

Le périmètre roadmap S04 est proposé à clôture en local ; ceci ne clôture pas toute l’application. Les envois de campagnes/relances (S07/S10), documents métier/fiscaux (S06), approbation de suppression et préparation de production restent identifiés. Prochaine étape : S05, dossiers et coffre de pièces.


## S05 — premier lot Dossiers (29 octobre 2026)

Création, consultation, édition, notes et états sur Supabase local, habilitations par dossier et versions. Voir `documentation/CONTRATS-S05.md` et `preuves/S05-dossiers/BILAN.html`. S05 reste ouvert : affectations, coffre/versionnement, classement intermodules et restauration à terminer.


### S05 — affectations (29 octobre 2026)

Affectation à un membre déjà habilité, permission distincte, retrait atomique de l’accès direct de l’ancien référent et historique durable. Recette locale : `preuves/S05-affectations/BILAN.html`. S05 reste ouvert pour le coffre, les opérations intermodules et la reprise.

### S05 — coffre de pièces, 29 octobre 2026

Dépôt réel, quarantaine antivirus, aperçu et téléchargement contrôlés raccordés aux dossiers sur Supabase local. Voir [le bilan du lot](preuves/S05-coffre/BILAN.html) et [le contrat S05](documentation/CONTRATS-S05.md). Migrations 098–099. S05 reste ouvert : versions, corbeille/restauration, classement, accueil, extraction et recette de reprise restent à terminer.

### S05 — versions du coffre, 29 octobre 2026

Migration 100 : versions immuables et restauration non destructive, contrôle de concurrence, antivirus et historique. [Bilan et réserves](preuves/S05-versions/BILAN.html). S05 reste ouvert ; la restauration d’une version ne constitue pas la recette de restauration d’une sauvegarde ni le circuit de corbeille D07.

### S05 — corbeille, 29 octobre 2026

Migrations 101–102 : demande métier, validation super admin sans contenu, blocage des pièces et de leurs versions, restauration avec droits actuels. Aucune destruction automatique. [Bilan et preuves](preuves/S05-corbeille/BILAN.html). La suppression définitive et la recette de sauvegarde/restauration complète restent ouvertes.


### S05 — classement serveur, 29 octobre 2026

Migration 103 : références de convocations et fichiers archivés, droits cumulés source/dossier à chaque lecture, version et anti-doublon. 26 contrôles intégration, 93 tests frontaux, 145 Python. Recette aux trois formats ; 834 références inchangées. [Bilan et réserves](preuves/S05-classement/BILAN.html). S05 ouvert, notamment incident temporaire de relecture à isoler, fichiers libres à recetter, accueil/extraction et restauration globale.


## S05 — Recette finale du classement, 29 octobre 2026

Fichiers libres classés et droits sources validés ; HTTP 429 reproduit et signalé explicitement sans requête en cascade. 21 contrôles ciblés, six suites S05, 94 tests frontaux et 145 Python. 92 contrôles pile neuve ; restauration 70 tables/199 objets et 271 vérifications, puis 12 contrôles Auth/MFA/droits. UI aux trois formats ; 834 références intactes. Voir [le bilan](preuves/S05-finalisation/BILAN.html). Le lot de classement est validé dans son périmètre serveur testé ; S05 reste ouvert pour les réserves explicitement conservées dans ce bilan.


## S05 — Classement et corbeille source, 29 octobre 2026

Réserve levée : une pièce source mise en corbeille rend sa référence inaccessible ; restauration sans rétablir les droits révoqués. 39 contrôles intégration, 95 tests frontaux ; refus de classement et téléchargement autorisé aux trois formats. HTTP 429 distingué dans le sélecteur ; 834 références inchangées. Preuves : `preuves/S05-classement-corbeille/BILAN.html`. S05 reste ouvert pour les autres réserves du bilan.

## S05 — Finition et clôture locale proposée, 29 octobre 2026

Accueil Dossiers réel, préparateur extrait, pagination, reprise antivirus et retrait réversible de références/dossiers avec validation super admin. Migrations 104–107 ; RLS et restauration sans recréer les droits révoqués. 97 tests frontaux, 145 Python, six suites S05 ; sauvegarde finale restaurée avec 301 contrôles puis 12 contrôles Auth/MFA/droits. Recette mobile/tablette/desktop détaillée dans [le bilan final](preuves/S05-cloture/BILAN.html). Clôture technique locale proposée pour le périmètre de contenus serveur validé ; acceptation produit et production distinctes.

### S06 — finalisation locale, 30 octobre 2026

[Bilan courant](preuves/S06-finalisation/BILAN.html) : corrections motivées, archives publiées, notifications, corbeille approuvée et restauration, file de rendu durable. 146 tests Python, 112 tests frontaux, 32 contrôles du cycle, 10 de reprise du worker, 312 de restauration et 15 d'accès après reprise réussis. Prototype et S00 : 834 empreintes inchangées. **S06 reste ouvert** : arbitrage des pages complémentaires pour les gabarits PDF incomplets et traitement explicite d'une déconnexion avec brouillon non sauvegardé. Les contrats du module sont dans [S06-CONTRATS](docs/S06-CONTRATS.md).

### S06 — pages complémentaires validées, 30 octobre 2026

[Bilan](preuves/S06-pages-complementaires/BILAN.html) : première page graphique conservée, blocs non repris reportés dans des compléments avec la charte, aperçu et export communs. 23/36 compositions du témoin exportées, les 13 débordements de première page restent refusés. 146 tests Python, 117 frontaux et 32 contrôles d’accès réussis ; téléchargements identiques aux trois viewports. Prototype/S00 intacts. La confirmation de déconnexion demeure un arbitrage distinct.


### S06 — clôture technique locale, 30 octobre 2026

[Bilan courant](preuves/S06-cloture-finale/BILAN.html) : les deux réserves précédentes sont levées. 36/36 compositions PDF, compléments et exports identiques aux trois viewports ; confirmation de déconnexion avec sauvegarde, annulation ou abandon explicite. 146 tests Python, 122 frontaux, 32 contrôles d’accès réussis ; 834 références protégées inchangées. S06 est clôturable en local, sous validation visuelle finale ; suite prévue S07. La production et les fournisseurs optionnels restent hors de cette clôture.

### S07 — Lot A, 30 octobre 2026

Conversations privées et messages durables, réponse, pagination et envoi idempotent raccordés à Supabase local. Refus par conversation, organisation, MFA, module et permissions ; aucune lecture métier automatique du super admin. 64 contrôles intégration, 150 tests Python et 132 tests frontaux ; recette aux trois viewports, 834 références intactes. [Bilan du lot A](preuves/S07-A/BILAN.md) et [contrat](docs/S07-CONTRATS.md). S07 reste ouvert ; suite : lot B.

### S07 — Lot B, 30 octobre 2026

Groupes, membres et modération persistants ; départ et réinvitation par nouvelles périodes, ouvertures historiques ciblées, révocables et auditées. 54 + 26 + 13 contrôles intégration B et 47 de non-régression A ; 152 tests Python, 144 frontaux ; UI aux trois viewports, 834 références intactes. [Bilan du lot B](preuves/S07-B/BILAN.md) et [contrats A/B](docs/S07-CONTRATS.md). S07 reste ouvert ; prochaine étape : C — pièces et classement.

### S07 — Lot C, 30 octobre 2026

Pièces de messages sur le coffre privé : dépôt, quarantaine, antivirus, reprise, aperçu et téléchargement contrôlé. Classement de messages/pièces par références cumulant les droits source et dossier ; corbeille source D07. 93 contrôles C et 154 de non-régression ; 155 tests Python, 152 frontaux ; recette UI aux trois formats, 834 références intactes. [Bilan du lot C](preuves/S07-C/BILAN.md). S07 reste ouvert ; suite : lot D — transfert et recherche.


### S07 — Lot D, 30 octobre 2026

Recherche paginée dans tous les messages autorisés, accès au résultat ancien, transfert par référence atomique et idempotent, citations filtrées selon les droits actuels. 115 contrôles D et 174 de régression A/B/C ; 157 tests Python, 162 frontaux ; modale aux trois formats, 834 références intactes. [Bilan du lot D](preuves/S07-D/BILAN.md). S07 reste ouvert ; suite : E — temps réel, lectures et notifications.


### S07 — Lot E, 30 octobre 2026

Temps réel local SSE, lectures persistantes par période, compteurs et notifications in-app filtrés ; retrait sur fil ouvert et reprise vérifiés. 65 contrôles E, 202 de régression B/C/D ; 163 tests Python, 172 frontaux ; UI aux trois formats, 834 références intactes. [Bilan du lot E](preuves/S07-E/BILAN.md). S07 reste ouvert ; suite F — installation neuve, restauration, charge et clôture.

### S07 — Lot F, 30 octobre 2026

Clôture technique locale proposée après installation neuve, restauration chiffrée isolée, Auth/MFA et droits restaurés, recette transversale et charge bornée. Les dépassements de délai observés ont conduit aux migrations 136–140 optimisant notifications, non-lus, révisions et recherche sans élargir l’accès. 430 contrôles S07, 111 sur pile neuve, 371 de restauration et 25 d’accès restaurés ; tests Python 163 et frontaux 172. [Bilan global S07 et lot F](preuves/S07-F/BILAN.md). Aucune qualification de production ni validation visuelle utilisateur implicite.

### S07 — clôturé le 30 octobre 2026

Clôture des lots A–F acceptée par l’utilisateur (« ok cloture »), avec acceptation de la livraison et de sa présentation visuelle sur les éléments présentés. Les réserves locales et de production restent applicables. [Décision de clôture](preuves/S07-F/CLOTURE.md) · [Bilan et preuves](preuves/S07-F/BILAN.md).

### S08 — lancé le 30 octobre 2026

IA commune et assistant : [plan et critères](planification/S08-demarrage/PLAN.md). Première brique d'orchestration serveur et tests de refus/annulation ajoutés ; lot A partiel, sans raccordement HTTP/Supabase/frontal ni fournisseur réel. Les accès IA historiques restent à migrer. [Bilan de démarrage](preuves/S08-demarrage/BILAN.md).

### S08 — lot A, 30 octobre 2026

Passerelle IA serveur, politique D09 persistante (approbation globale/activation organisation), Auth/MFA et permissions, connecteur ChatGPT/Codex local limité aux questions fictives autorisées. Configuration IA raccordée, appels directs et clés navigateur retirés, annulation et réponses tardives contrôlées. 72 contrôles d'intégration, réponse Codex réelle, 191 tests Python et 182 frontaux ; UI aux trois formats. [Bilan A](preuves/S08-A/BILAN.md) · [Contrats](docs/S08-CONTRATS.md). Activation fictive désactivée après recette. S08 ouvert ; suite B, contexte autorisé. Génération métier, quotas durables et production non qualifiés.

### S08 — lot B

Contexte IA autorisé Dossiers/Documents/Messages livré pour la recette locale fictive. Sources revalidées, masquage partiel, citations littérales vérifiées et retrait des résultats devenus indisponibles. Voir [bilan et limites](preuves/S08-B/BILAN.md) et [contrats](docs/S08-CONTRATS.md). Aucun envoi métier réel autorisé ; suites C–F encore ouvertes.

### S08 — lot C

Le lancement `python -m uniion.app` conserve les exécutions IA dans `.local-ai/runs.sqlite3` (schéma local versionné). Quota de recette : 100 demandes réservées/engagées par organisation et jour UTC, deux appels actifs par instance ; aucune relance automatique. Jetons et coût inconnus. Ne pas lancer plusieurs hôtes avec des copies indépendantes du registre en supposant leurs quotas partagés. Aucune purge automatique. Voir [bilan C](preuves/S08-C/BILAN.md) et [contrats](docs/S08-CONTRATS.md).

### S08 — lot D

Assistant, historique chiffré et mémoire de références sourcées raccordés pour les seules recettes fictives. Schéma local v2 ; clé privée `.local-ai/runs.history.key` indispensable à la relecture. Sources et droits revérifiés à chaque lecture/réutilisation ; archivage sans suppression. Les anciennes données IA du navigateur restent inutilisées. Voir [bilan D](preuves/S08-D/BILAN.md) et [contrats](docs/S08-CONTRATS.md).

### S08 E — actions unii, recette fictive

Le panneau unii des Dossiers, Documents et Messages utilise `/identity/ai/actions` : une référence certifiée, une proposition extractive persistée dans l’historique privé, et aucune application automatique. L’Assistant reprend une proposition par identifiant avec revalidation de ses sources. Les générateurs métier non raccordés refusent sans réponse de secours simulée. Les 37 actions du catalogue et le circuit de dérivés diffusables restent ouverts ; cette tranche ne clôt pas E métier ni S08. Bilan et preuves : `preuves/S08-E/BILAN.md`.

Recette locale : `python -B tests/s08_actions_integration.py --codex` utilise les comptes et fixtures S08 existants, une base d’exécution temporaire et les droits réels Supabase. Le drapeau `--codex` effectue un appel réel au connecteur local autorisé ; aucun appel de production. Tests dédiés : `tests/test_ai_actions.py`, `frontend/state/ai-actions.test.mjs`.

### S08 F — recette globale, 31 octobre 2026

Recette fictive validée ; **S08 métier reste ouvert, aucune admission production**. 262 tests Python, 214 tests frontaux, 111 contrôles HTTP/politique, 48 contrôles de pile neuve et 389 contrôles de restauration. Voir `preuves/S08-F/BILAN.md` pour les limites, les mesures et les fonctions E non livrées.

Les commandes `operations/s08_replay.py <suite>`, `operations/s08_fresh.py` et `operations/s08_restore.py` produisent les preuves F. `s08_restore.py` restaure uniquement dans une nouvelle cible isolée, avec sauvegarde chiffrée distincte du registre IA et de sa clé ; il ne modifie ni le calendrier de sauvegardes ni l’admission de production. Les copies et conteneurs arrêtés sont conservés sans purge. Les instantanés SQL et SQLite sont séparés : revalidation des sources et rapprochement des révocations obligatoires avant admission.

### S08 — complément du lot E, 31 octobre 2026

Catalogue serveur de 37 tâches de brouillon, correction privée chiffrée, relecture versionnée et application explicite dans le même Dossier/Document. 271 tests Python, 221 frontaux, 130 contrôles HTTP/MFA ; Codex réel sur données fictives ; installation neuve et recette visuelle. Les autres modules utilisent encore un document de contexte : leurs adaptateurs natifs, certaines applications, la conversation libre et la qualification métier complète restent ouverts. **E complet non clôturé.** État détaillé : [bilan courant](preuves/S08-E-final/BILAN.md). Les preuves et le package de F restent historiques et inchangés.


## Finalisation du lot E — 31 octobre 2026

État courant : sources métier natives, 37 actions et 7 générateurs spécialisés, conversation privée, dossiers dérivés, rôles serveur et publication locale versionnée à deux acteurs. Recette ChatGPT/Codex avec données fictives uniquement. 275 tests Python, 229 frontaux, 140 contrôles d’intégration, 34 contrôles complémentaires ; installation neuve et restauration vérifiées. Le [bilan complet](preuves/S08-E-complet/BILAN.md) précise les parcours testés et les limites (message unique, absence de collecte de votes et de push externe). Lot E local techniquement finalisé ; S08 et les décisions de production D07/D09 restent ouverts. Les bilans antérieurs sont historiques et conservés.

# S07 — Lot B : membres et historique

30 octobre 2026 — lot techniquement validé en local ; S07 reste ouvert.

## Périmètre et réalisation

Demande : membres et historique. Application locale sur le port 5068, Supabase local, comptes fictifs avec MFA. Les documents du package servent de spécifications ; aucune consigne documentaire n’élargit l’autorisation de déploiement.

Les groupes sont persistants : création idempotente, nom, description, ajout/retrait de membres et attribution/retrait du rôle d’administrateur. Le départ ferme l’accès sans supprimer les messages. Le dernier administrateur actif disposant de la lecture ne peut pas quitter seul.

Chaque arrivée crée une période de participation à partir de la prochaine séquence. Une réinvitation ne restitue ni ancien rôle ni ouverture historique. Pour une discussion privée après retour dans l’organisation, « nouvelle discussion » avec le même interlocuteur renouvelle explicitement la période ; lister ou lire ne la réactive pas.

L’habilitation history permet d’ouvrir des messages explicitement sélectionnés à un participant actuel. Le donneur doit lui-même les lire. Ces ouvertures sont auditées, liées à la période du destinataire et révocables. Leur retrait ne masque pas les messages normalement accessibles depuis son arrivée.

## Sécurité et architecture

Migrations 122–125 appliquées. Tables privées sous RLS, aucun accès direct des clients ; RPC sous JWT utilisateur, jamais service_role dans le BFF. Versions et verrou de conversation sérialisent les changements concurrents. L’envoi revérifie la participation après verrouillage.

Création de groupe, modération et habilitation historique sont distinctes. Ni l’administration d’organisation ni le super admin ne donnent une lecture métier implicite. Suspension, changement d’organisation, révocation de read et périodes fermées sont contrôlés côté serveur. Les citations sont filtrées selon les droits ; une citation mémorisée absente de la page autorisée rechargée n’est pas réaffichée.

Le service messaging délègue les commandes de membres au fichier frontend/modules/messaging/members.js. Les formulaires existants sont raccordés, conservent la saisie lors d’un refus et affichent l’erreur dans la fenêtre. Une réponse tardive ne modifie pas un nouveau contexte d’identité. Les modifications saisies pendant une requête ne sont pas effacées.

## Tests exécutés

| Exécution | Résultat | Preuve |
| --- | --- | --- |
| Python : unittest discover -s tests -p 'test_*.py' | 152 tests réussis | python-tests.log |
| Frontend : node --test state/*.test.mjs | 144 tests réussis | frontend-tests.log |
| tests/s07_members.py | 54 contrôles réussis | integration.json |
| tests/s07_b_edges.py | 26 contrôles réussis | access-edges.json |
| tests/s07_direct_return.py | 13 contrôles réussis après migration 125 | direct-return.json |
| tests/s07_a_regression.py | 47 contrôles réussis, relancés après migration 125 | regression-A/integration.json |
| frontend/build.mjs | Compilation réussie | build.log |
| scripts/check_boundaries.py | Frontières conformes | boundaries.log |
| Empreintes des références protégées | 834 inchangées | integrite-apres.json |

Les contrôles couvrent notamment : refus de création sans permission, administrateur d’organisation extérieur au groupe, autre organisation, accès direct aux tables/fonction interne, auto-escalade, version périmée, concurrent retrait/envoi, destinataire suspendu ou sans read, dernier administrateur, bornes de séquence, citations cachées, ouverture/révocation et réinvitation sans retour des anciens droits. Les nombres d’intégration incluent les contrôles de connexion et MFA ; ce ne sont pas des nombres de parcours UI.

Pour reproduire, lancer les scripts Python depuis application/ avec le runtime du projet et Supabase local démarré ; lancer les commandes Node depuis application/frontend/. Les suites d’intégration nécessitent les fixtures fictives ignorées de .local-auth et modifient exclusivement ces données locales. Les preuves du lot A sont conservées ; la non-régression B utilise son propre dossier et sa propre organisation.

## Interface et fidélité

Recette par contrôles visibles sur navigateur : 390×844, 768×1024, 1440×1000. Création/ajout/ouverture historique sur desktop, révocation/retrait sur tablette, réinvitation sur mobile. Le membre destinataire a constaté l’ouverture puis, après réinvitation, uniquement le nouveau message. Le refus de création conserve le formulaire avec erreur visible aux trois formats.

La relecture SQL confirme deux périodes pour le destinataire, une ouverture révoquée, deux messages et une nouvelle borne égale à 2 (ui-persistence.json). Les captures finales de lecture et les mesures n’indiquent pas de débordement horizontal. Détail : ui.json.

Le formulaire existant a été comparé à preuves/S02-messagerie/group-390.png ; structure, typographie et composants conservés. Les commandes historiques utilisent le menu, la sélection et le sélecteur existants. Les captures de sélection et de révocation précèdent une précision finale du libellé et du placeholder ; les captures finales de lecture suivent la dernière compilation. Validation sur viewports de navigateur, pas sur appareils physiques ; acceptation visuelle produit laissée à l’utilisateur.

## Réserves et suite

- C : pièces et classement ; D : transferts et recherche exhaustive ; E : temps réel, notifications et lecture ; F : installation neuve, restauration, charge et clôture. Ces validations ne sont pas déduites de recettes antérieures.
- Les droits sont revérifiés à chaque requête ; le retrait spontané d’un contenu déjà affiché attend E.
- Pas de suppression physique dans B. Un groupe sans modérateur accessible après révocation externe ne bénéficie d’aucune récupération implicite ; un circuit de récupération reste à définir.
- Limites explicites : 100 membres par groupe, 100 messages par ouverture ; brouillons en mémoire, aucune file durable hors ligne annoncée.
- La notification Agenda indisponible observée avec les comptes sans droits Agenda reste indépendante de B ; les réserves S03 ne sont pas clôturées par ce travail.

Lot B livré et vérifié localement. Prochaine étape : lot C — pièces et classement. Aucun déploiement ni envoi externe.

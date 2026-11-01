# S07 — Lot E : temps réel, lectures et notifications

30 octobre 2026. Demande couverte : « Go lot E — temps réel, lectures et notifications. » Livraison et recette locales ; aucun déploiement, email ou push externe. Le package S07 reste une référence de spécification, pas une autorisation indépendante.

## Réalisé

Un flux SSE authentifié alimente les discussions, le fil ouvert, les compteurs et les notifications. Une mutation réussie sur le serveur local réveille les abonnements ; chacun récupère sa propre projection autorisée. Aucun canal métier global, aucun JWT dans le navigateur. Serveur WSGI concurrent pour ne pas bloquer les commandes pendant un abonnement.

Les lectures sont persistées par période de participation. Le curseur est monotone ; un rejeu ancien ne recrée pas de non-lus. Le frontal acquitte jusqu’au dernier message affiché lorsque le fil est visible, avec focus et défilement en bas. Un onglet masqué ou une consultation des anciens messages ne marque pas le dernier message comme lu. Le bouton existant Tout marquer comme lu est raccordé au serveur.

La cloche et la page Notifications affichent les messages non lus encore autorisés, sous forme de références sans copie du texte. Un clic ouvre le message exact. Les anciennes alertes statiques de démonstration sont retirées du mode connecté ; les adaptateurs Agenda et Documents restent distincts. La coche simple conserve son sens « enregistré » : ce lot n’ajoute pas de double coche ni de liste nominative de lecteurs.

Migrations 133–135 appliquées. Contrat : ../../docs/S07-CONTRATS.md. Table privée message_reads sous RLS ; commandes read, read_all, notices, live ; endpoint /identity/messaging/events. Sources principales : adapters/message_stream.py, http_sessions.py, app.py, modules/messaging/live.js, service.js et auth-s01.js.

## Accès, reprise et limites du transport

Avant abonnement et à chaque projection : session, MFA, organisation, module commercial/activation, permission read, participation actuelle et droits historiques. Les transferts conservent tous leurs contrôles source. Un retrait purge le fil, les compteurs et les références transitoires ; les aperçus Messages, citations et recherches sont invalidés. Les réponses tardives d’une ancienne identité ne repeuplent pas l’écran.

Le curseur opaque représente la projection autorisée, sans compteur global permettant de suivre une conversation cachée. La reconnexion transmet Last-Event-ID et reçoit un nouvel instantané autorisé ; le frontal déduplique les curseurs. L’ordre des messages reste la séquence serveur. Les messages sont durables même si plusieurs changements ont lieu pendant une coupure ; la reprise ne promet pas de rejouer chaque événement intermédiaire. Une page récente contient 50 messages et garde la pagination vers les anciens.

Les mutations de ce BFF déclenchent une poussée immédiate. Les modifications réalisées directement en base ou dans un autre processus sont réconciliées au battement de dix secondes. Une activité non autorisée ne produit pas de trame de données supplémentaire. Session expirée : canal fermé. Un flux n’entretient pas l’activité de la session. Limites locales : trois flux par session, 64 par processus, renouvellement après deux minutes. Le frontal purge aussi après une erreur ou 25 secondes sans battement, selon l’ordonnancement du navigateur. Les délais réels comprennent la latence et les requêtes en cours ; les trames déjà en vol ne sont pas récupérables.

Il s’agit d’un transport local avec poussée et réconciliation, pas d’un simple polling navigateur ni d’un bus distribué qualifié pour la production. Le calcul des empreintes parcourt les messages autorisés ; sa charge à grande volumétrie reste à mesurer au lot F. Un changement de projection peut invalider les anciennes pages et fermer les formulaires de référence pour éviter leur conservation après révocation ; les brouillons d’un accès retiré sont purgés.

## Tests exécutés

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| Intégration E, Auth/MFA et flux WSGI réellement ouverts | 43 contrôles réussis | integration.json |
| Références protégées, Tout lire, activité cachée et refus complémentaires | 22 contrôles réussis | edges.json |
| Régression B — membres/historique | 54 contrôles réussis | regression-B/integration.json |
| Régression C — pièces/classement | 73 contrôles réussis | regression-C/integration.json |
| Régression D — transfert/recherche | 75 contrôles réussis | regression-D/integration.json |
| Tests Python | 163 réussis | python-tests.log |
| Tests frontaux | 172 réussis | frontend-tests.log |
| Compilation/frontières | réussies | build.log, boundaries.log |
| Références protégées | 834 inchangées | integrite-apres.json |

Les 267 contrôles d’intégration ne sont pas 267 parcours UI. Les tests de flux couvrent l’envoi pendant abonnement, la reconnexion avec curseur, le retrait sur connexion ouverte, la disparition du contenu, l’expiration, le plafonnement des abonnements, la libération des connexions et le maintien de l’expiration d’inactivité. Les tests client couvrent l’onglet masqué, le focus, le défilement, la déduplication et les réponses tardives. Les contrôles métier vérifient aussi MFA insuffisant, origine étrangère, appel anonyme, source historique masquée, module désactivé, commercial révoqué et suspension.

Commandes exécutées depuis application avec les runtimes locaux :

```sh
python3 -B tests/s07_live.py
python3 -B tests/s07_live_edges.py
python3 -B tests/s07_e_regressions.py s07_members
python3 -B tests/s07_e_regressions.py s07_files
python3 -B tests/s07_e_regressions.py s07_discovery
python3 -B -m unittest discover -s tests -p 'test_*.py'
python3 -B scripts/check_boundaries.py
# depuis frontend/
node --test state/*.test.mjs
node build.mjs
```

Une première exécution de la régression D a rencontré un chemin d’image fictive incorrect dans le lanceur E ; chemin corrigé, puis 75 contrôles réussis. Un second défaut du lanceur concernait la lecture imbriquée du script C : le remplacement du chemin ne correspondait plus à sa source, et la première sortie D de 75 contrôles a remplacé S07-C/integration.json. Cette sortie est conservée et identifiée par S07-C/INCIDENT-PREUVE-S07-E.md et regression-D/integration-premiere-execution.json. Le fichier détaillé original C n’a pas été récupéré à l’identique ; aucune preuve historique n’est reconstituée. Le bilan, les cas limites et les captures C restent inchangés. Les régressions C sous D et sous E conservent chacune leurs 73 contrôles. Lanceur corrigé ; la nouvelle exécution D utilise son dossier E dédié.

## Recette UI et fidélité

Alex dans le navigateur ; Camille comme second acteur fictif utilisant le BFF HTTP local. Arrivée d’un message pendant la consultation de la liste : compteur Non lues 1 et notification réels, sans rechargement. Clic sur la notification : ouverture du message. Tout marquer comme lu depuis le mobile : retrait de la notification. Envoi pendant que le fil est ouvert : nouveau message affiché sans action du destinataire. Retrait du participant depuis le second acteur : fil et compteurs disparaissent spontanément. Réinvitation : discussion vide, aucun ancien historique restauré. Reprise de session après redémarrage local observée.

Captures notifications-1440.png, notifications-768.png, notifications-390.png, fil-direct-1440.png et revocation-1440.png. Notification inspectée à 1440×1000, 768×1024 et 390×844 : bouton accessible, texte lisible et absence de débordement horizontal observé. Comparaison avec preuves/S03-fidelite-notifications/notifications-desktop.png : même page et mêmes cartes ; données réelles à la place des exemples. Aucun appareil physique testé. Les refus MFA rencontrés pendant le chevauchement des recettes ont été résolus avec une session et une fixture courantes, sans affaiblir les contrôles.

## Suite et réserves

Lot E raccordé et vérifié localement. S07 reste ouvert : lot F pour installation neuve, restauration couvrant les tables S07, concurrence/charge représentatives et clôture sur preuves. La validation de production, le bus distribué éventuel, les notifications externes, le hors ligne durable et les réserves historiques S03 ne sont pas déduits de cette recette. Aucun arbitrage S00 modifié.

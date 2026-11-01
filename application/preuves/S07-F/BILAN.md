# UNIION — bilan global S07 et lot F

30 octobre 2026. Données fictives, services locaux. **Lot F réalisé ; clôture technique locale de S07 proposée.** La validation visuelle utilisateur et l’admission en production restent distinctes. Aucun déploiement effectué.

## Résultat et parcours

Les lots A–E assurent désormais conversations et messages durables, groupes et périodes d’appartenance, historique explicitement ouvert, pièces privées contrôlées, classement Dossiers par référence, réponses/transferts protégés, recherche exhaustive, lectures, notifications in-app et SSE local. Aucun transfert ne donne implicitement accès à sa source. Les contrôles restent serveur/base, y compris pour les identifiants devinés et les appels directs.

F rejoue ces parcours, installe la pile depuis une base vide, restaure une sauvegarde incluant S07 et teste les accès après restauration. La charge a révélé des défauts réels de performance, corrigés avant clôture : les notifications reconstruisaient le nombre de non-lus par candidat et la recherche répétait les projections et contrôles sources. Migrations **136–140** : calculs bornés ou matérialisés, empreinte rapide pour les messages simples, contrôle explicite des actions NULL. Les formats d’API et les règles d’accès sont conservés ; pièces, citations et transferts gardent les projections et contrôles dynamiques complets.

Dans le navigateur : recherche de pièce dans tout l’historique, ouverture au message ancien, aperçu inerte autorisé sans téléchargement, envoi fictif mobile, puis relecture après nouvelle connexion MFA. L’envoi a été contrôlé en base avant toute reprise : une seule ligne ; aucun renvoi automatique.

## Vérifications et preuves

| Vérification | Résultat | Preuve F |
| --- | --- | --- |
| Régressions A/B/C/D/E et cas limites | 417 contrôles réussis | regressions-final139/, regressions-consolidees.json |
| Compteurs optimisés, quarantaine/révision et actions NULL | 13 contrôles réussis | regressions-final139/s07_volume_edges/S07-E/volume-edges.json |
| Installation neuve, Auth/MFA, fichiers et S07 | 111 contrôles réussis | fresh/S01-ephemeral/integration.json |
| Sauvegarde/restauration finale, schéma, fonctions, ACL/RLS et données/objets | 371 contrôles réussis | restore-final140/restore-b044bd49.json |
| Nouvelles connexions MFA et droits après restauration | 25 contrôles réussis | restore-final140/restore-access.json |
| Tests Python / frontaux | 163 / 172 réussis | python-tests.log, frontend-tests.log |
| Compilation et frontières des modules | réussies | build.log, boundaries.log |
| Références protégées / anciennes preuves | 834 / 2 007 inchangées | integrite-apres.json |
| Secrets de fixtures connus et motifs JWT | aucun signalement dans les artefacts contrôlés | integrite-apres.json |

Les 430 contrôles S07 consolidés sont des contrôles d’intégration, pas 430 parcours UI. Ils couvrent notamment MFA insuffisant, troisième acteur, autre organisation, droits/module/commercial retirés, suspension, périodes et réinvitation, référence sans droit source, fichier infecté ou en quarantaine, reprise après interruption de dépôt/scan, révocation pendant récupération, idempotence et versions concurrentes. Les flux ouverts couvrent reprise, arrivée d’un message, révocation et expiration ; la suite client couvre les réponses tardives et les conditions d’acquittement.

Les dix suites ont été rejouées après 139. Le complément de 13 contrôles inclut la validation finale 140. Les tests Python/frontaux et la compilation n’ont pas été répétés après les seules modifications SQL : aucun code Python ou frontal de production n’a changé en F. Le contrôle d’équivalence confronte le nouveau compteur à la formule initiale fondée sur la visibilité de chaque message, pour l’auteur et le lecteur à historique restreint. La mise en quarantaine doit changer l’empreinte, puis sa restauration restituer l’empreinte initiale.

Les essais échoués, causes et reprises sont détaillés dans [INCIDENTS-RECETTE.md](INCIDENTS-RECETTE.md). La synthèse consolidée prévaut sur les journaux des premières tentatives. Aucune ancienne preuve n’a été remplacée pendant F. L’incident sur S07-C/integration.json survenu pendant E reste documenté dans [l’incident historique](../S07-C/INCIDENT-PREUVE-S07-E.md), sans reconstitution de l’original.

## Installation neuve et charge

Cible Docker `uniion-ci-e3983a36`, sans port hôte exposé, données et identités fictives créées sur place ; aucun import de sauvegarde ni de données source. Auth, PostgREST et Storage réels ; fichiers via les adaptateurs actuels et ClamAV réel. **134 fichiers SQL** de baseline/migrations jusqu’à 139 sont appliqués depuis zéro ; **140 est ensuite appliquée sur cette même cible**, avec preuve séparée fresh/migration140.json : 135 fichiers SQL au total, les numéros de migrations ne sont pas leur nombre.

La recette vérifie Auth/MFA, cloisonnement, coffre, partage explicite/révocation, quarantaine antivirus et récupération, puis création S07, rejouabilité concurrente, réponse, lectures et live, pièce de message, aperçu et octets identiques, recherche et transfert de pièce, retrait du membre et disparition de sa référence.

Charge : 1 200 nouveaux messages, huit appels simultanés sous JWT utilisateur, après deux messages initiaux. Toutes les séquences 3–1202 sont présentes une fois ; page récente de 50, dernière séquence correcte et 1 200 non-lus pour le lecteur. Quatre appels simultanés partageant la même clé produisent un seul message. Lecture globale idempotente, puis contrôles de pièce et de référence. Preuve : fresh/volume.json.

- Écritures : 51,49 secondes au total ; latence p95 d’un appel 0,50 seconde, pont Docker inclus.
- Dix projections live : 0,82 à 1,80 seconde ; budget local de 2 secondes respecté sans autres recettes lourdes simultanées.
- Recherche sur le jeu isolé de diagnostic : environ 0,66 seconde après correction, preuve volume-diagnostic-recherche.json.
- Avec les autres recettes lourdes concurrentes, certaines lectures ont atteint 2,34 secondes : mesure conservée dans volume-sous-recettes-concurrentes.json.

Ce sont des mesures RPC locales, avec huit appels et non huit utilisateurs indépendants. Elles ne qualifient pas le débit HTTP/SSE du BFF, les grands ensembles de longues chaînes de transferts, une forte concurrence multi-organisation, un bus distribué ou une infrastructure de production. Les performances restent dépendantes de l’hôte et du volume ; aucune garantie de délai générale n’est déduite.

## Sauvegarde, restauration et accès

Snapshot final chiffré `20261030T183528Z` : 89 tables, 15 290 lignes, 19 comptes projet, 14 facteurs TOTP confirmés, 280 objets privés représentant 1 377 277 octets. Clés séparées dans le stockage local privé ; aucun secret dans les preuves. Les sessions Auth ne sont pas restaurées. Sauvegarde et volumes conservés, aucune purge automatique.

Restauration sur `uniion-restore-b044bd49`, réseau sans interface externe ni port exposé ; services Auth/REST/Storage dédiés avec secrets propres à la cible. Intégrité des lignes, fonctions, ACL/RLS, métadonnées et octets vérifiée avant accès. Les tables messages, conversations, participations, ouvertures historiques, pièces, lots/transferts et lectures sont incluses automatiquement dans le catalogue restauré.

Les contrôles après restauration vérifient trois connexions réelles, refus AAL1, MFA restauré, historique ouvert ou masqué, transfert dépendant de la source, réinvitation sans ancien historique/non-lus, fichier téléchargé identique, aperçu sans droit download, autre organisation refusée, table des lectures privée, puis retrait des droits et refus live/aperçu. Les mutations de révocation de cette recette restent dans la cible isolée.

Tous les conteneurs de recette créés pour F sont arrêtés après les vérifications ; leurs données/volumes restent disponibles. Les piles préexistantes principale et `unii-recette` sont préservées. Une restauration de production nécessiterait une admission séparée, la réconciliation des révocations postérieures au snapshot et la décision explicite sur les files d’envoi ; F ne remet aucun worker de livraison en service et n’envoie aucun message externe.

## Fidélité visuelle

Comparaison avec preuves/S02-messagerie/thread-1440.png : structure liste/fil, cartes, fond pointillé, barre de saisie, navigation et palette conservés. Les données de démonstration sont remplacées par les données fictives persistées ; notice d’accès serveur et commandes des lots précédents conservées. Aucun changement de maquette en F.

Captures inspectées : fil-1440.png, fil-768.png, fil-390.png, apercu-1440.png et envoi-reconnexion-390.png. Viewports configurés 1440×1000, 768×1024 et 390×844 ; largeur utile réduite par la barre de défilement du navigateur. Sur tablette/mobile, largeur de contenu égale à la largeur utile (760/382 px), sans débordement horizontal observé. Pièce, texte et saisie lisibles. Aucun appareil physique testé.

Des interruptions de synchronisation et une ancienne session devenue invalide ont été observées pendant les recettes simultanées ; pas de contenu conservé après invalidation. La recette finale a été reprise avec une connexion MFA fraîche. L’envoi mobile est visible après reconnexion. Cette vérification ne vaut pas validation visuelle finale par l’utilisateur.

## Fichiers et reproduction

Production : supabase/migrations/202610300136_message_notice_volume.sql à 202610300140_message_action_validation.sql. Aucun changement frontal/Python de production. Documentation : docs/S07-CONTRATS.md, planification/S07-demarrage/02-ETAT-COURANT.md et README.md.

Recette : operations/s07_fresh.py, s07_restore.py, s07_restore_access.py, s07_profile.py, s07_proof_scope.py, s07_integrity.py ; tests/s07_f_regressions.py, s07_f_suite.py, s07_volume_edges.py. Le lanceur redirige les sorties/fixtures et bloque toute écriture directe dans une ancienne preuve ; le contrôle SHA final vérifie indépendamment leur conservation.

Commandes depuis application, avec les runtimes locaux et Docker disponibles :

```sh
python3 -B tests/s07_f_suite.py
python3 -B tests/s07_f_regressions.py s07_volume_edges --final
python3 -B operations/s07_fresh.py
python3 -B operations/s07_restore.py --final
python3 -B operations/s07_restore_access.py --final
python3 -B operations/s07_integrity.py
python3 -B -m unittest discover -s tests -p 'test_*.py'
python3 -B scripts/check_boundaries.py
# depuis frontend/
node --test state/*.test.mjs
node build.mjs
```

Une nouvelle exécution crée de nouvelles identités/organisations/cibles fictives et doit conserver ses preuves séparément si celles de F doivent rester figées. Les répertoires privés .local-auth, .local-backups et .local-sessions ne sont pas des livrables publics.

## Réserves et conclusion

S07 A–F est techniquement clôturable en local. Restent hors périmètre et non implicitement validés : production et résilience distribuée, bus multi-instance, email/push de Messages, hors ligne durable S13, publication élargissant l’audience D12/D13, classement IA/création automatique de dossiers, signature et réserves antérieures S03. Les coches indiquent l’enregistrement serveur, pas une preuve de lecture humaine.

Les mesures sous charge concurrente et l’incident historique de preuve restent explicitement conservés. Aucun arbitrage S00 n’a été modifié. La suite est la validation visuelle utilisateur puis le prochain périmètre autorisé, sans déploiement automatique.

## Clôture acceptée — 30 octobre 2026

À la suite de la décision utilisateur « ok cloture », **S07 est clôturé dans le périmètre local A–F**. La livraison et sa présentation visuelle sont acceptées sur les éléments présentés. Cet addendum actualise les mentions de clôture proposée ci-dessus ; les preuves et réserves restent inchangées. Voir [la décision de clôture](CLOTURE.md). Aucun déploiement effectué.

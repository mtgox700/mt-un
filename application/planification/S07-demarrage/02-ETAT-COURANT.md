# État courant — point de reprise compact

Date : 30 octobre 2026. À actualiser après chaque lot S07.

## Position

- S00 : décisions et référence protégées.
- S01 : clôture locale, identité/MFA/sessions et contrôles d’accès.
- S02 : réserves locales levées, hôte modulaire et interface commune.
- S03 : Agenda fonctionnel, mais dernier bilan d’archives conservant des réserves. Ne pas le déclarer clôturé par déduction.
- S04 : clôture technique locale proposée, registre adhérents/cotisations.
- S05 : clôture locale du périmètre de classement de contenus serveur ; coffre, antivirus, droits sources, corbeille et restauration.
- S06 : dernières réserves techniques levées, clôturable localement sous validation visuelle finale. Documents, PDF, archives, validation/diffusion interne, corbeille et protection du brouillon.
- S07 : lots A à E livrés et vérifiés localement le 30 octobre 2026 ; prochaine action : lot F. Voir ../../preuves/S07-E/BILAN.md et ../../docs/S07-CONTRATS.md.

## Acquis vérifiés pour la reprise

Les fichiers frontend/modules/messaging/{module,actions,presenters,menu,contact-links,convocation-history}.js et les vues existent. Les routes déclarées sont messagerie et thread. L’adaptateur convocation-history projette un historique serveur protégé dans Messages ; les conversations privées et groupes sont désormais raccordés à Supabase par les lots A/B. Il interdit certaines actions sur les convocations en lecture seule. Ne pas retirer ces protections pour unifier l’affichage.

Dernière recette S06 : 146 tests Python, 122 frontaux, 32 contrôles du cycle documentaire, 36 compositions PDF ; 834 références inchangées. Ce sont des résultats historiques, pas des tests exécutés par ce package. Restauration S06 antérieure : 312 contrôles puis 15 Auth/MFA/droits ; reprise du worker : 10 contrôles. Ces chiffres ne prouvent pas les futurs contrats S07.

## Réserves à suivre sans les masquer

Dernier bilan S03-archives : ouverture de l’historique antérieur à l’arrivée, pagination, supervision/reprise des envois incertains, suppression approuvée, recette neuve/restauration des archives. Des restaurations ont eu lieu ensuite ; vérifier leur couverture avant de lever la réserve précise. Le temps réel S07 ne résout pas à lui seul les envois email incertains S03.

Le lot B couvre l’ouverture explicite de messages historiques des conversations ordinaires ; les contrôles des convocations sont conservés. Identifier les responsabilités restantes de l’Agenda, sans clôturer artificiellement S03.

Production, fournisseurs externes, appareils physiques, sécurité indépendante et charge de production restent ultérieurs. IA commune S08, signature optionnelle S12, hors ligne durable S13.

## Après chaque lot

Renseigner : lot / date / état livré / preuve / commandes de test et résultats / réserves / décisions nouvelles / prochaine action. Garder cette fiche compacte, avec liens vers les détails. Les anciens bilans ne deviennent pas faux parce qu’ils décrivaient un état antérieur.

## Lot A — 30 octobre 2026

Conversations privées à deux participants, messages et réponses persistants, pagination, idempotence et refus serveur raccordés. Migrations 120/121 appliquées. 47 + 17 contrôles intégration, 150 tests Python, 132 tests frontaux, compilation/frontières réussies, 834 références inchangées. Parcours UI 390×844, 768×1024 et 1440×1000. Preuves : ../../preuves/S07-A/BILAN.md.

Groupes/habilitation historique (B), pièces/classement (C), transfert/recherche exhaustive (D), temps réel/notifications (E), pile neuve/restauration/clôture (F) restent ouverts. Aucun arbitrage S00 modifié. S07 non clôturé.

## Lot B — 30 octobre 2026

Groupes, membres, rôles de modération, départ/réinvitation et ouvertures historiques par période raccordés. Migrations 122–125 appliquées. 54 contrôles membres/historique, 26 cas limites, 13 contrôles de retour en discussion privée et 47 contrôles de non-régression A réussis ; 152 tests Python, 144 frontaux, compilation/frontières réussies. Parcours UI aux trois formats ; 834 références inchangées. Preuves et commandes : ../../preuves/S07-B/BILAN.md.

Prochaine action : C — pièces et classement. D — transfert/recherche exhaustive, E — temps réel/notifications et F — pile neuve/restauration/clôture restent ouverts. Pas de suppression physique ni de récupération implicite d’un groupe sans modérateur accessible. Aucun arbitrage S00 modifié ; S07 non clôturé.

## Lot C — 30 octobre 2026

Pièces Messages sur le coffre privé, quarantaine/antivirus/reprise, aperçu inerte et téléchargement distinct ; classement manuel de messages et pièces par références dynamiques dans Dossiers. Corbeille source avec validation D07 et restauration sans restitution des droits. Migrations 126–130. Recette : 73 contrôles principaux, 20 cas limites, 47 A, 54 B, 27 coffre et 26 classement Agenda ; 155 tests Python, 152 frontaux ; compilation/frontières réussies et 834 références intactes. UI : dépôt, aperçu, classement, téléchargement identique ; refus de téléchargement aux trois formats. Voir ../../preuves/S07-C/BILAN.md.

Prochaine action : D — transfert et recherche. E — temps réel/notifications ; F — pile neuve/restauration/charge/clôture. Le classement manuel est raccordé ; qualification IA/création automatique de dossier et signature restent indisponibles. S07 reste ouvert.


## Lot D — 30 octobre 2026

Recherche serveur paginée dans tout l’historique autorisé, navigation vers le message exact, transfert atomique/idempotent par références conservant tous les droits source et destination, réponses avec citations dynamiques. Migrations 131–132. 115 contrôles D et 174 de régression A/B/C ; 157 tests Python, 162 frontaux ; compilation/frontières réussies ; 834 références intactes. UI : transfert et relecture, réponse puis citation masquée pour le participant sans historique ; modale aux trois formats. Preuves : ../../preuves/S07-D/BILAN.md.

Prochaine action : E — temps réel/lectures/notifications. F — pile neuve/restauration/charge/clôture. Aucun élargissement implicite d’audience : une publication distincte D12/D13 reste hors périmètre. S07 reste ouvert.


## Lot E — 30 octobre 2026

Flux SSE local authentifié avec reprise par projection autorisée, invalidation après retrait, curseurs de lecture par période, non-lus et notifications in-app réelles. Migrations 133–135 ; exemples statiques retirés des notifications en mode connecté. 65 contrôles E, 202 de régression B/C/D ; 163 tests Python, 172 frontaux ; compilation/frontières réussies, 834 références intactes. UI : arrivée sans rechargement, lecture, notification, retrait sur fil ouvert et réinvitation sans historique ; trois viewports. Preuves : ../../preuves/S07-E/BILAN.md.

Transport : poussée sur mutation de ce BFF, réconciliation dix secondes pour changements externes, aucune qualification distribuée/charge de production. Prochaine action F : pile neuve, restauration S07, charge et clôture. S07 reste ouvert.

## Lot F — 30 octobre 2026

Recette transversale finale et corrections des coûts répétés de notifications, révisions, non-lus et recherche : migrations 136–140. 430 contrôles S07 consolidés ; installation neuve 111 contrôles ; restauration finale 371 contrôles d’intégrité puis 25 contrôles Auth/MFA/accès. Tests Python 163 et frontaux 172, compilation/frontières réussies. Charge bornée : 1 200 écritures à concurrence huit, séquences complètes ; dix live entre 0,82 et 1,80 seconde hors autres recettes lourdes. La mesure concurrente à 2,34 secondes est conservée, pas masquée.

Recherche → message ancien → aperçu, envoi mobile puis relecture après reconnexion vérifiés dans le navigateur ; captures aux trois formats. 834 références protégées et 2 007 anciennes preuves inchangées. Aucun secret de fixture connu détecté dans les nouveaux artefacts textuels contrôlés. Les échecs et corrections de recette sont consignés.

S07 est techniquement clôturable dans le périmètre local A–F. La validation visuelle finale par l’utilisateur et la recette de production restent distinctes. Aucun déploiement effectué, aucune nouvelle décision S00, aucun envoi externe implicite. Voir ../../preuves/S07-F/BILAN.md pour les limites et les preuves. Les réserves antérieures, dont l’incident documentaire C pendant E et les réserves S03, restent visibles.

## Clôture S07 — 30 octobre 2026

**S07 clôturé, lots A–F, périmètre local.** Acceptation utilisateur : « ok cloture », après bilan et capture finale. Livraison et présentation visuelle acceptées sur les éléments présentés ; réserves du bilan maintenues. Décision : ../../preuves/S07-F/CLOTURE.md. Aucun déploiement ni démarrage automatique du sprint suivant.

# S05 — Dossiers, premier lot local

Date : 29 octobre 2026. Skill appliqué : uniion-developpement.

## Contrat livré

POST `/identity/cases` reçoit exactement `organization_id`, `action`, `payload`. Actions : list, get, create, edit, status, note. Les UUID, contenus, versions, champs acceptés et droits sont contrôlés côté serveur et dans `public.uniion_cases`. Aucune clé privilégiée au navigateur.

Le module utilise `public.uniion_resources` et les habilitations `uniion_resource_grants` existantes. Les métadonnées métier et l’historique appartiennent aux tables privées `cases` et `case_history`. Les relations composées empêchent les associations inter-organisations. Le module Dossiers est inscrit au catalogue ; aucun droit commercial n’est donné aux organisations existantes par cette migration.

La lecture exige session MFA valide, appartenance active, module autorisé et activé, accès commercial valide, permission métier read et habilitation au dossier non expirée/révoquée. Aucun accès automatique pour un administrateur global ou d’organisation. L’écriture exige en plus write et can_write sur la ressource. La création exige create et attribue au créateur une habilitation à sa nouvelle ressource ; elle ne lui confère aucune permission de module supplémentaire. Cette habilitation de créateur n’a pas d’expiration propre, mais les contrôles de session, appartenance, module et révocation restent applicables à chaque opération.

Les mutations verrouillent la ressource et vérifient la version attendue. Les événements d’historique portent acteur et date serveur ; aucune modification ni suppression de l’historique n’est exposée. L’édition synchronise le titre et le contenu textuel de la ressource pour les mécanismes de partage existants. L’ensemble de l’historique n’est pas ajouté implicitement aux partages.

## Frontal

`modules/cases/supabase.js` possède les commandes et brouillons transitoires. Les vues et styles existants sont conservés. Les textes de stockage et les compteurs fictifs sont remplacés par des informations exactes. Les anciens élus fictifs ne sont plus proposés pour une affectation réelle. Un message explicite remplace la réponse initiale simulée de l’assistant.

Les données dossiers, pièces et conversations de dossier ne sont ni restaurées ni persistées par le stockage navigateur lorsque le pont S01 est actif. Le changement d’identité vide l’état ; une réponse tardive ne peut le repeupler. Un identifiant inconnu ne sélectionne jamais un autre dossier par défaut. Un refus d’écriture recharge les droits et les données accessibles ; aucune confirmation de succès fictif.

## Limites et suite du sprint

Ce lot ne clôture pas S05. Restent : affectations et réaffectations dans l’interface, retrait des accès associés ; coffre de fichiers (dépôt, antivirus, aperçu, téléchargement, versions, corbeille et restauration sous circuit D07) ; opérations publiques de classement de message et ajout de document ; extraction des préparateurs encore présents dans le contrôleur commun ; raccordement de l’accueil ; recette pile neuve et sauvegarde/restauration des nouvelles tables et fichiers ; recette globale des critères S05.

Les boutons dépendants du coffre, de l’IA, du courrier, des affectations et de la suppression ne prétendent pas réaliser ces opérations. Le classement hérité via Messages ne crée plus de faux dossier en mémoire sur la pile authentifiée. L’IA nécessite son raccordement autorisé D09 ; aucune activation externe dans ce lot.

## Preuves

`preuves/S05-dossiers/` : intégration réelle Supabase (33 contrôles), tests frontaux (82), tests Python (145), captures et résultats UI en viewports 390×844, 768×1024 et 1440×1000. Ces dimensions sont une émulation de navigateur, pas des tests sur appareils physiques. Les nouvelles tables n’ont pas encore fait l’objet d’une restauration S05 : réserve à lever avant clôture.

## Lot affectations — 29 octobre 2026

Commande `assign` : `{id, version, user}`. Permission séparée `dossiers_assign`, délégable par le circuit existant des habilitations dans les limites du délégant. Aucune attribution automatique de cette permission par la migration. Le libellé est disponible dans la console des droits.

L’acteur doit pouvoir modifier le dossier. Le destinataire doit déjà disposer d’un accès direct actif en lecture et écriture dans la même organisation. Le changement de référent n’accorde ni droit de module, ni habilitation nouvelle, ni téléchargement. Auto-affectation refusée. Les candidats proposés sont filtrés côté serveur, sans exposition de l’annuaire complet.

La transaction verrouille ressource et habilitations, recontrôle la version et les accès, change le référent, révoque l’habilitation directe de l’ancien référent et écrit l’historique et l’audit. Si l’acteur est l’ancien référent, la réponse ne contient pas le dossier : le frontal recharge les accès et revient à la liste. Les liens de partage/support distincts restent soumis à leurs propres règles ; aucune garantie de révocation universelle de copies déjà téléchargées n’est revendiquée.

Le panneau « Assigner à un élu » garde ses boutons et styles. Les noms proviennent des profils de l’organisation ; le texte indique que les destinataires sont déjà habilités et que l’ancien accès direct est retiré. Aucun statut de formation SSCT n’est inventé.

La recette de fichiers révoqués et les restaurations restent à réaliser avec le coffre de pièces. S05 demeure ouvert.

## Lot coffre — 29 octobre 2026

Migrations 098 et 099 : consultation contrôlée des métadonnées et compteur réel au chargement du dossier. `/identity/cases` accepte `files`, `file_upload`, `file_preview`, `file_download`, `file_rescan`. Le dossier parent et l’appartenance de la pièce sont vérifiés avant l’action puis avant la réponse contenant des octets. Le pipeline existant de stockage privé, antivirus ClamAV et contrôle de format est réutilisé ; aucun accès direct Storage utilisateur. L’écriture du dossier est requise pour déposer/reprendre une analyse ; la lecture permet l’aperçu et le droit distinct de téléchargement reste nécessaire pour récupérer l’original.

Le frontal `modules/cases/files.js` remplace les données locales du coffre par le serveur. Les octets sont transitoires, jamais ajoutés à localStorage/IndexedDB. Une réponse tardive après déconnexion est ignorée. Après réaffectation, l’ancien référent perd la liste, l’aperçu et le téléchargement. Les fichiers déjà téléchargés ne sont pas révocables à distance.

Formats repris du pipeline : PDF, PNG, JPEG, TXT, DOCX, XLSX, maximum 5 Mo. Recette de ce lot : PNG sain, PDF invalide et témoin antivirus EICAR. L’aperçu affiche la première page ; un aperçu non pris en charge est refusé explicitement. Les boutons de versions, classement, suppression et signature restent non raccordés et n’affichent pas un succès fictif. La reprise d’analyse est disponible côté serveur mais son action dédiée dans cette interface reste à raccorder.

Preuves `preuves/S05-coffre/` : 27 contrôles d’intégration réelle, 87 tests frontaux, 145 tests Python. UI : dépôt sain sur desktop ; aperçu, téléchargement identique à l’original et refus de téléchargement/dépôt du lecteur aux trois dimensions 390×844, 768×1024, 1440×1000. Compteur après reconnexion vérifié. Les 834 références protégées sont identiques. Aucun style modifié ; les textes de stockage et de formats ont été corrigés pour décrire le service réel. Les notifications de refus sont temporaires et fermables ; elles peuvent recouvrir momentanément le contenu selon le comportement existant.

S05 reste ouvert : versions, corbeille/restauration sous D07, classement intermodules, accueil et extraction restante, reprise d’analyse UI, recette des autres formats et pagination d’aperçu, puis pile neuve et restauration cohérente des dossiers/fichiers/droits. L’historique du dossier n’intègre pas encore l’ensemble des opérations sur pièces ; le pipeline possède ses propres métadonnées et traces. Ne pas annoncer la clôture du coffre complet ni de S05.

## Lot versions — 29 octobre 2026

Migration 100 : table privée `case_file_versions`, RLS et aucun accès direct utilisateur. Les fichiers restent immuables dans Storage. Les pièces existantes deviennent implicitement v1 ; leur historique est matérialisé à la première opération de versionnement. La liste regroupe les versions sous une pièce logique, dont le compteur reste stable. La version courante est la dernière version saine ; un dépôt infecté ou en erreur ne remplace pas une version saine.

Commandes `/identity/cases` : `file_version` avec `{case,attachment,expected,filename,content}` ; `file_restore` avec `{case,attachment,expected,version}`. `attachment` désigne la racine logique pour ces deux commandes. `expected` porte la dernière révision connue, y compris les versions en quarantaine. Verrouillage du dossier et de la racine, contrôle du droit d’écriture, de l’organisation, du dossier et de la révision avant mutation. Une restauration ajoute une révision pointant vers les octets immuables déjà analysés, sans effacer les suivantes. Les versions non saines ne sont pas restaurables. Historique du dossier et événement de sécurité conservent acteur, date et révision.

Les boutons existants « Déposer une nouvelle version » et « Restaurer » sont raccordés sans changement de style ou d’enchaînement. Le lecteur ne peut effectuer aucune de ces opérations ; il conserve seulement ses droits de lecture et son éventuel droit distinct de téléchargement. Les aperçus et téléchargements utilisent l’identifiant physique de la version courante, contrôlé à nouveau côté serveur. Aucune modification des instantanés de partage existants : pas d’accès implicite aux nouvelles pièces.

Preuves : `preuves/S05-versions/`. 21 contrôles d’intégration, 89 tests frontaux, 145 tests Python, compilation et frontières OK. Création de versions et restauration testées dans l’interface à 390×844, 768×1024, 1440×1000 avec comparaison exacte des octets restaurés, puis refus du lecteur aux trois tailles. La confirmation initiale du dépôt desktop n’a pas été obtenue lors de la série rapide ; une nouvelle lecture a confirmé sa persistance, sans réémission. Les messages d’erreur restent génériques ; l’amélioration du signalement des limites temporaires et de la reprise d’analyse reste une réserve UX fonctionnelle, sans refonte dans ce lot.

Réserves : corbeille et restauration après suppression sous circuit D07 (distinctes de la restauration de version livrée ici), classement intermodules, reprise d’analyse depuis le coffre, pagination/recette des autres formats, accueil et extraction restante ; restauration isolée des nouvelles tables et des fichiers, puis recette globale S05. La table de versions n’a pas encore été validée par une restauration complète. S05 demeure ouvert.

## Lot corbeille — 29 octobre 2026

Migrations 101–102 : demandes privées `case_file_trash` avec états pending/approved/rejected/restored, révision figée et motif catégoriel. La commande `file_trash` expose request/list/restore pour le métier, admin_list/approve/reject pour le super admin. La validation globale vérifie MFA, rôle existant et révision, puis recontrôle le droit d’écriture du demandeur. La mise en corbeille concerne la pièce logique et toutes ses versions, sans effacement des octets. Les passerelles attachment_get (y compris partage) et support_file_get refusent les pièces mises en corbeille. Les anciennes fonctions renommées ne sont pas exécutables par les utilisateurs.

La restauration exige les droits actuels d’écriture du dossier et n’altère aucune habilitation. Les accès et partages toujours actifs retrouvent leur fonctionnement normal ; les révocations demeurent. Historique du dossier pour la demande/restauration, événements de sécurité pour toutes les décisions. Aucun nom de fichier ni contenu dans l’inventaire global d’approbation. Aucune purge au terme de la cible de 30 jours : la suppression définitive nécessite un circuit distinct restant à développer.

L’utilisateur a validé explicitement les ajouts fonctionnels : demande via le bouton existant, accès Corbeille dans le coffre, validation globale avec composants existants et action Restaurer. Les pages utilisent les cartes, boutons, modales et navigation de la console de droits. Le lien de validation est visible pour le super admin dans Organisations ; la page reste protégée côté serveur en accès direct.

Preuves `preuves/S05-corbeille/` : 30 contrôles d’intégration, 89 tests frontaux, 145 tests Python ; cycles UI aux trois tailles, refus métier/global et octets restaurés identiques. Une ambiguïté SQL a été corrigée par 102. Les essais n’ont accordé aucun rôle global : le super admin fictif préexistant a été utilisé après refus automatique d’une attribution envisagée. Nouvelle restauration des sauvegardes et recette complète partages/support actifs restant à réaliser. S05 reste ouvert.


## Lot classement — 29 octobre 2026

Le menu existant « Envoyer dans un dossier » classe une convocation durable dans l’historique du dossier. Les fichiers de cette convocation proposent le même sélecteur ; les archives PDF/ICS apparaissent ensuite dans le coffre, avec aperçu PDF et téléchargement contrôlé. Les références persistent après changement de session. Aucun texte fourni par le navigateur n’est copié dans le dossier.

Migration 103 : table privée case_links, RLS, aucun accès direct utilisateur. Classement par identifiant source, verrouillage/version du dossier, unicité et rejeu idempotent. Audit sans contenu métier. Écriture du dossier obligatoire ; lecture de la source obligatoire. Consultation, compteurs, aperçu et téléchargement recontrôlent la source et la cible. Une référence ne crée aucun nouveau droit. Retirer l’audience source masque le texte et les fichiers ; retirer le dossier bloque aussi les octets. Les contrôles sont répétés avant livraison.

## Tests exécutés

- 26 contrôles d’intégration réussis : MFA, diffusion locale, classement message/PDF/ICS, doublons, version périmée, anonyme, autre organisation, lecteur sans écriture, source inconnue, révocation source et cible, aperçu et téléchargement.
- 93 tests frontaux et 145 tests Python réussis. Compilation et frontières des modules OK.
- UI réelle à 390×844, 820×1180 et 1440×1000 : classement initial message/PDF mobile et ICS desktop ; rejeu ICS tablette ; refus du lecteur aux trois tailles. Message et deux fichiers relus après reconnexion.
- PDF téléchargé avec signature PDF valide ; ICS téléchargé avec BEGIN:VCALENDAR. Aperçu PDF observé aux trois formats. L’aperçu affiche la première page.
- Les captures ont révélé un PDF recadré sur mobile et un refus masqué par la modale : correction de l’ajustement de l’image et erreur en ligne dans la modale, avec les styles existants. Aucun débordement horizontal de page constaté aux dimensions testées.
- 834 références protégées vérifiées : aucune modification du prototype ni de S00.

## Limites et réserves

Une répétition d’aperçu sous le compte lecteur a échoué et vidé temporairement la liste. Une nouvelle session auteur a retrouvé les références et permis aperçu/téléchargement. La cause n’est pas isolée : ne pas présenter ce résultat comme un refus de permission validé. Le signalement des erreurs temporaires reste à préciser.

Le raccordement des références couvre les fichiers retournés par l’historique serveur ; les essais de ce lot ont porté sur les archives PDF/ICS. La recette spécifique des fichiers libres classés et de leur mise en corbeille reste à compléter. Les conversations de démonstration et l’éditeur Documents local ne sont pas intégrés, conformément au périmètre choisi.

Les références ne se versionnent ni ne se suppriment depuis le coffre : ces actions restent explicitement bloquées. Un circuit de retrait de référence reste à définir/raccorder. Création de dossier assistée depuis un message, signature, courrier et IA restent non raccordés. Aucun fournisseur externe activé.

S05 reste ouvert : accueil et extraction restante, reprise d’analyse UI, pagination/recette étendue des fichiers, clôture des réserves de classement, recette globale sur pile neuve et restauration cohérente des nouvelles tables avec fichiers et droits. Aucune restauration complète de case_links n’a été effectuée dans ce lot. Pas de déploiement.


## S05 — Recette finale du classement, 29 octobre 2026

Fichiers libres classés et droits sources validés ; HTTP 429 reproduit et signalé explicitement sans requête en cascade. 21 contrôles ciblés, six suites S05, 94 tests frontaux et 145 Python. 92 contrôles pile neuve ; restauration 70 tables/199 objets et 271 vérifications, puis 12 contrôles Auth/MFA/droits. UI aux trois formats ; 834 références intactes. Voir `preuves/S05-finalisation/BILAN.html`. Le lot de classement est validé dans son périmètre serveur testé ; S05 reste ouvert pour les réserves explicitement conservées dans ce bilan.


## S05 — Classement et corbeille source, 29 octobre 2026

Réserve levée : une pièce source mise en corbeille rend sa référence inaccessible ; restauration sans rétablir les droits révoqués. 39 contrôles intégration, 95 tests frontaux ; refus de classement et téléchargement autorisé aux trois formats. HTTP 429 distingué dans le sélecteur ; 834 références inchangées. Preuves : `preuves/S05-classement-corbeille/BILAN.html`. S05 reste ouvert pour les autres réserves du bilan.

## Finition approuvée — 29 octobre 2026

Ajouts explicitement approuvés avec les composants existants : pagination de l’aperçu, reprise d’analyse interrompue, retrait de référence et suppression réversible du dossier via validation super admin.

Les migrations 104–107 ajoutent `case_disposals` et l’état `case_links.withdrawn`. La commande `uniion_case_disposal` sépare demande métier (version attendue, motif), approbation/rejet global (inventaire technique sans contenu), liste et restauration avec les droits actuels. Une demande en attente ne coupe pas l’accès. L’approbation conserve les octets et historiques ; le dossier devient inaccessible via les RPC et les politiques RLS des ressources/versions. Restaurer ne recrée aucun droit. Les fichiers d’un dossier retiré restent bloqués par les contrôles de pièces, y compris les chemins qui réutilisent ces contrôles. Aucun effacement physique ni purge automatique.

La migration 106 rattache explicitement les politiques RLS à la nouvelle fonction : un renommage seul conserve les références PostgreSQL à l’ancien OID. La migration 107 corrige l’alias de la liste de corbeille.

`link_preview` accepte une page entière entre 1 et 200 ; les droits de référence et source sont recontrôlés après le rendu. La reprise antivirus exige le droit d’écriture ; une réponse tardive après déconnexion ne recharge pas les pièces privées. Aucune donnée de fichier n’est inscrite dans le stockage navigateur.

Le préparateur du tableau Dossiers et les cartes Dossiers de l’accueil sont extraits dans `frontend/modules/cases/presenter.js`. L’accueil connecté recharge les seuls dossiers accessibles et présente un état vide si le module est refusé.

# S06 — Documents : lancement local

29 octobre 2026. S05 est clôturé sur acceptation explicite de l’utilisateur, dans son périmètre serveur validé. S06 est en cours ; ce premier lot ne clôture pas le sprint.

## Réalisé

Les vues Documents et Éditeur sont extraites en modules. Les brouillons sont créés depuis les modèles de base, listés, ouverts et enregistrés dans Supabase avec leur titre, format, blocs de base et charte. Les sauvegardes sont sérialisées et versionnées ; une version périmée est refusée. Une sauvegarde échouée conserve la saisie et bloque la navigation interne. Déconnexion : les contenus Documents sont retirés de l’état client ; une réponse tardive ne les réinjecte pas. Aucun contenu métier n’est ajouté au stockage navigateur par ce service.

Les migrations 108 et 109 sont appliquées à la pile locale. Documents entre au catalogue commercial : les organisations ont désormais besoin d’un accès commercial explicite, sans attribution implicite. Les seuls accès ajoutés par les recettes concernent des organisations fictives.

## Droits

Session/MFA, appartenance, activation du module, accès commercial, permission métier et habilitation à la ressource sont contrôlés côté serveur. La création exige créer et écrire. La lecture seule ne donne pas accès à l’écriture. Le cloisonnement organisationnel, les versions obsolètes, la révocation, l’accès direct aux ressources et le module désactivé sont testés. Le service ne confère aucun accès métier global au super admin.

## Tests

- 21 contrôles d’intégration Documents réussis, dont accès autorisés/refusés, révocation et isolation.
- 24 contrôles de non-régression Agenda réussis ; les fixtures disposent désormais explicitement de l’accès commercial Documents.
- 101 tests frontaux réussis, dont sauvegardes concurrentes, erreur et déconnexion pendant une lecture.
- 145 tests Python réussis. Contrôle des frontières réussi.
- Interface testée à 390 × 844, 768 × 1024 et 1440 × 1000 : édition autorisée et relecture, lecture seule et refus d’écriture. Création depuis Courrier et refus de création vérifiés sur desktop. Aperçu mobile/tablette vérifié. Ce sont des viewports émulés, pas des appareils physiques.
- 834 empreintes protégées identiques : prototype et S00 intacts.

## Fidélité et correction

Aucune refonte des écrans. La compilation omettait theme/reference.css : son contenu existant est maintenant inclus. Les commandes mobiles retrouvent leurs styles et leur masquage desktop. Les écrans conservent leurs composants et enchaînements. Les compteurs et messages décrivent désormais la persistance réelle. Les actions encore non raccordées refusent explicitement l’opération au lieu de simuler un succès.

## Reste de S06

1. Logos personnalisés, images et blocs/styles d’extensions, puis tous les modèles ; le premier lot accepte les blocs de base uniquement.
2. Exports serveur Documents, fidélité des gabarits, pagination longue, formats et archivage des versions réellement exportées.
3. Validation/diffusion par version et droits séparés, contrat du module de signature optionnel ; aucun envoi externe dans ce lot.
4. Suppression/corbeille des brouillons avec circuit super admin et raccordement du classement aux dossiers.
5. Résolution explicite des conflits d’édition, protection de la saisie lors d’une fermeture/recharge du navigateur et hors ligne selon D08 ; la sauvegarde en ligne ne remplace pas ce chantier.
6. Achever l’extraction des préparateurs/actions hérités et la recette globale S06, puis restauration sur pile neuve avec les nouvelles migrations avant clôture.

Les exports, signatures, diffusion, IA Documents et logos non raccordés restent bloqués explicitement. L’ancien contenu de démonstration des modèles doit être relu et remplacé avant usage réel. Le déploiement OVH/Supabase managé reste hors périmètre, conformément à la demande de poursuite locale.

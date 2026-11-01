# S06 — Exports serveur des documents

29 octobre 2026 — export PDF de brouillon raccordé et testé en local. S06 reste ouvert.

## Réalisé

Le bouton existant « Imprimer / PDF » télécharge désormais un PDF généré sur le serveur à partir de la version enregistrée dans Supabase. Les modifications en attente sont sauvegardées avant l’export ; un échec de sauvegarde bloque l’export pour éviter une version ancienne. Aucun changement de vues, de styles ni de navigation. Aucun envoi externe.

Le moteur PDF existant est réutilisé pour la charte, le logo et les extensions. Les métadonnées identifient le document, sa version et son statut de brouillon. Un dépassement de page produit une erreur explicite au lieu d’un document tronqué. Les clics répétés ne lancent pas deux exports simultanés ; une réponse tardive après déconnexion ne déclenche pas de téléchargement.

## Droits et traçabilité

Migration 112 appliquée à Supabase local. Session/MFA, appartenance, module commercialement accessible, lecture de la ressource et permission distincte de téléchargement sont contrôlés en base. L’organisation et la version doivent correspondre. Les contrôles sont rejoués après le rendu avant de renvoyer les octets : révocation et modification concurrente refusent l’export.

L’événement document.export.authorized consigne l’autorisation pour une ressource/version, sans contenu métier. Il ne prouve pas que le fichier a été remis sur le disque du destinataire. Aucun PDF n’est archivé durablement par ce lot ; aucun nettoyage ou suppression ajouté.

## Tests exécutés

- 21 contrôles d’intégration réussis : MFA, création, anonyme, rédacteur et lecteur sans téléchargement, autre organisation, export autorisé, deux pages, dernière page, métadonnées, version périmée, révocation pendant rendu, modification concurrente, logo et extension, module désactivé.
- 107 tests frontaux et 145 tests Python réussis. Compilation et frontières des modules vérifiées.
- Interface desktop 1440 × 1000, tablette 768 × 1024, mobile 390 × 844 : téléchargement réel du PDF de version 3, puis refus avec le compte lecteur sans téléchargement. Trois PDF téléchargés conservés et vérifiés : deux pages et texte de première/dernière page présents.
- Quatre pages rendues et inspectées : Classique et style institutionnel avec logo fictif personnalisé et bloc chiffre clé. Aucun texte coupé dans ces exemples. Captures des trois formats inspectées ; notification mobile visible puis disparition automatique constatée. Recette de viewports, pas d’appareils physiques.
- 834 empreintes protégées identiques : prototype et S00 intacts.

## Fidélité et limites

Le bouton et les composants existants sont conservés. La vérification graphique couvre les exemples A4 ci-joints ; elle ne vaut pas validation exhaustive de toutes les combinaisons de modèles, formats, polices, styles et extensions. Cette matrice reste à compléter avant la clôture globale. Les exports Word/Excel ne sont pas implémentés par ce lot PDF.

## Reste de S06

Circuits de validation et de diffusion par version, corbeille, contrat de signature optionnelle, gestion des conflits et protection des saisies à la fermeture, recette graphique globale et restauration incluant les nouvelles tables/images. L’archivage d’un export effectivement diffusé devra être raccordé au circuit de diffusion. Aucun déploiement en production.

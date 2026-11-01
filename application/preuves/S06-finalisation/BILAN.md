# S06 — Finalisation locale, réserves de clôture

30 octobre 2026. Skill uniion appliqué. Prototype et S00 intacts : 834 empreintes identiques.

## Réalisé

- Demande de corrections motivée par un relecteur habilité distinct des contributeurs. Une nouvelle version est nécessaire avant une nouvelle validation.
- Historique des versions publiées, PDF archivés immuables et téléchargement soumis aux droits actuels. Les archives restent identiques après restauration d’un document.
- Notifications internes durables aux lecteurs habilités lors de la publication ; accès recontrôlé à l’ouverture. Aucun e-mail externe.
- Corbeille Documents : demande motivée, approbation super admin, retrait réversible, restauration sous droits actuels. Aucune suppression physique. Les corbeilles Dossiers et Documents sont filtrées par module.
- Rendu PDF différé, file durable par organisation/document/version/demandeur, concurrence limitée et reprise explicite des travaux interrompus après expiration du bail. Les jetons ne sont pas persistés dans la file.
- Reprise de session vers Documents depuis la corbeille ; retour mobile réutilisant le lien existant. Avertissement de fermeture pendant une sauvegarde ou avec des modifications non enregistrées.
- Contrats des extensions et de la future signature optionnelle documentés dans `docs/S06-CONTRATS.md`. Aucun prestataire de signature activé.

## Vérifications exécutées

| Vérification | Résultat |
| --- | --- |
| Tests Python | 146 réussis |
| Tests frontaux | 112 réussis |
| Compilation et frontières de modules | Réussies |
| Intégration réelle du cycle Documents | 32 contrôles réussis |
| Arrêt puis reprise du worker PDF dans un nouveau processus | 10 contrôles réussis |
| Sauvegarde/restauration isolée finale | 312 contrôles réussis, sauvegarde 20261030T050939Z |
| MFA et accès après cette restauration | 15 contrôles réussis |
| Références protégées | 834/834 inchangées |

La dernière recette de connexion après restauration a d’abord échoué pendant une indisponibilité transitoire des services locaux. Le diagnostic a ensuite confirmé HTTP 200 et la même pile restaurée a passé les 15 contrôles. Incident rétabli, pas de réserve active sur cette connexion.

## Interface

Recette par navigateur aux viewports 390 × 844, 768 × 1024 et 1440 × 1000, sans prétendre à des tests sur appareils physiques :

- ouverture et téléchargement réel d’une version publiée par le responsable ;
- refus du téléchargement au lecteur dépourvu du droit distinct ;
- demande de corrections autorisée par le relecteur, avec trois motifs effectivement enregistrés ;
- demande de corrections refusée au contributeur ;
- demande de mise en corbeille refusée au lecteur ;
- retour mobile de la corbeille et reprise de la session vers Documents vérifiés ;
- cycle autorisé de corbeille : demande sur desktop, approbation globale sur mobile, restauration sur tablette, sans destruction.

L’ouverture d’une archive depuis une notification a été vérifiée sur mobile. Les captures sont disponibles dans ce dossier. Les refus serveur et la révocation sont également couverts par l’intégration réelle ; ils ne sont pas déduits des seuls boutons.

## PDF : réserve bloquante

La matrice de 12 styles × 3 formats utilise un contenu commun complet. Sur ces 36 cas : **15 rendent le texte attendu, 13 sont bloqués pour débordement et 8 pour omission de texte**. Cela ne signifie pas que les styles bloqués ne fonctionnent avec aucun contenu : leurs gabarits ne conviennent pas au contenu commun dans les combinaisons testées.

Un contrôle supplémentaire refuse maintenant un PDF qui omet une ligne de texte simple (titres, paragraphes, listes, citations et badges). Ce contrôle ne prouve pas à lui seul la présence de chaque image, tableau ou bloc d’extension : une recette graphique reste nécessaire.

Le mode Classique restitue les 12 blocs d’extension sur 12 pages, en A4, A5 et paysage : 36 pages vérifiées. Trois compositions paysage représentatives sont exportées, et leurs trois variantes excessives sont refusées. Les pages 1 et 12 du Classique ainsi qu’un paysage ont été inspectés visuellement.

**Arbitrage en attente :** conserver la première page graphique et reporter les blocs non rendus sur des pages complémentaires dans la même charte (recommandation), ou maintenir le refus avec proposition de passer explicitement au mode Classique. Aucun ajout automatique de pages ni changement silencieux du style n’a été effectué.

## Reste avant clôture

1. Valider puis réaliser le traitement des contenus qui ne tiennent pas dans les gabarits graphiques ; comparer aperçu et export pour toutes les combinaisons retenues, y compris images et blocs complexes.
2. Examiner le cas d’une déconnexion volontaire avec un brouillon non sauvegardé : la navigation et la fermeture sont protégées, mais la déconnexion nettoie actuellement l’état privé. Ne pas confondre cette protection avec le hors-ligne chiffré D08, non livré par ce lot.

## Conclusion

La reprise du worker a été testée après arrêt du processus ayant pris le travail, puis relance dans un processus neuf. L’expiration est accélérée uniquement sur l’horodatage du travail fictif ; le bail de cinq minutes du produit reste inchangé. Le résultat PDF est récupéré et un ancien bail ne peut pas l’écraser.

Les ajouts fonctionnels approuvés sont implémentés et les contrôles décrits ci-dessus sont réussis. **S06 reste ouvert** : les réserves de fidélité et de conservation des brouillons ne sont pas masquées par les succès techniques. Pas de déploiement en production. La signature électronique externe relève du module optionnel déjà décidé.

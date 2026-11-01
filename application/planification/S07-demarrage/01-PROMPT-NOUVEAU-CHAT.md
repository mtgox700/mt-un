# Mission : lancer S07 sur uniion

Travaille dans :
`/Users/mt/.codex/.chatgpt-projects/g-p-6aaba98c248081918b85b5c6a9dceffd`

Lis le package `application/planification/S07-demarrage/`, en commençant par `02-ETAT-COURANT.md`, puis applique le skill `/Users/mt/.codex/skills/uniion-developpement/SKILL.md` et les AGENTS.md applicables.

Commence S07 — Messagerie et collaboration — par le lot A défini dans `03-LOTS.md` : conversations privées, messages persistants et raccordement au parcours existant. Réalise une tranche complète interface/service/base/droits/tests. Poursuis les étapes techniques autorisées jusqu’au résultat vérifiable ; ne t’arrête pas à un plan ou à un bouton non raccordé. Les lots suivants constituent le backlog, pas une déclaration de réalisation.

Contraintes impératives :
- Développement et recette en local, avec des comptes et contenus fictifs. Aucun déploiement OVH ni branchement externe.
- Modifications dans application/ uniquement ; prototype, anciennes copies, S00 et sources/ intacts.
- Conserver design, UX, navigation et composants. Demander un arbitrage uniquement si une nouvelle décision produit ou un ajout visible non autorisé est indispensable ; continuer les travaux indépendants.
- Cloisonnement fort entre organisations ET entre conversations d’une même organisation. Aucune lecture métier automatique pour le super admin.
- Respecter D11 : accès depuis l’arrivée, ouverture de l’historique sur autorisation spécifique, retrait au départ ; réinvitation sans restitution implicite de l’historique.
- Respecter les permissions commerciales et métier, MFA et protections serveur existantes. Aucun secret privilégié dans le navigateur ou les preuves.
- Ne pas transmettre de messages réels à des tiers. Pas de purge, suppression irréversible ou restauration sur la pile source.
- Ne pas transformer les messages fictifs du prototype en données métier ni conserver une simulation comme réponse de secours à une erreur serveur.

Avant de coder, confirmer les sources et dépendances réelles, les réserves S03 pertinentes et la matrice d’acceptation du lot. Ne pas réimplémenter les primitives disponibles. Les propositions de schéma et d’API du package sont à ajuster au dépôt, sans modifier les décisions validées.

Tester les accès autorisés/refusés directement côté serveur, la persistance après reconnexion, les doublons et les parcours touchés sur mobile 390×844, tablette 768×1024 et desktop 1440×1000. Utiliser les outils navigateur autorisés. Distinguer émulation de viewport et appareils physiques.

Pour économiser les tokens : recherches ciblées, sorties bornées, aucun dump de secrets/logs/contenus ; tests ciblés pendant le développement puis non-régression pertinente. Pas de relecture de tout l’historique. Pas de délégation automatique. Ne pas refaire un test déjà réussi sans modification ou doute précis.

Produire les preuves dans un nouveau dossier `application/preuves/S07-<lot>/`, mettre à jour l’état courant, puis donner un bilan court : livré, tests, réserves, prochaine étape. Ne déclarer S07 clôturé que lorsque tous les critères de clôture sont vérifiés. Ne pas confondre fin du lot A et fin de S07.

# S05 — Classement, corbeille de la source et restauration

29 octobre 2026 · Local · Skill uniion appliqué.

## Réserve levée

Une pièce déposée dans un dossier source est jointe à une convocation validée, puis classée par référence dans un autre dossier. Sa demande de mise en corbeille ne coupe pas prématurément l’accès. L’approbation par le super admin fictif préexistant bloque ensuite liste, aperçu et téléchargement de la référence. La restauration par un acteur habilité conserve la révocation du lecteur. Les octets d’origine sont identiques pour les acteurs encore autorisés ; aucun droit n’est créé implicitement.

Le cycle utilise les commandes réelles, Supabase local, antivirus et messagerie locale de recette. Les comptes sont fictifs. Aucun nouveau rôle global accordé, aucune suppression physique.

## Correction

Le sélecteur de classement distingue désormais HTTP 429 (« Limite temporaire atteinte… ») d’un refus de droits ou d’une version périmée. Aucun changement de structure, style ou navigation ; aucun assouplissement du quota. Un test frontal vérifie que cette limite n’est pas présentée comme un manque de permission.

## Tests

39 contrôles d’intégration réussis, incluant le socle du classement de fichier libre, droits source, quarantaine, mise en corbeille, refus de validation/restauration du lecteur et restauration avec révocation conservée. Ce nombre inclut des prérequis communs, pas 39 parcours distincts.

95 tests frontaux réussis ; compilation et frontières OK. Les tests Python et la restauration complète du lot précédent n’ont pas été rejoués : aucun code serveur ni schéma n’a changé dans ce lot. La nouvelle recette d’intégration utilise les règles serveur existantes.

UI à 390×844, 768×1024 et 1440×1000 : refus du classement d’une référence par le lecteur, puis téléchargement autorisé du PNG restauré. Les téléchargements mobile et tablette ont réussi avant l’attente du troisième téléchargement ; desktop relancé avec succès après réouverture du coffre. La séquence rapide a vidé le coffre transitoire lors du refus temporaire ; aucune donnée serveur perdue. La capture seule ne constitue pas la preuve des octets : leur signature PNG a été contrôlée après téléchargement, et la comparaison intégrale est effectuée dans la recette serveur.

Les cycles de corbeille/approbation/restauration de ce lot sont des tests d’intégration, pas des clics UI aux trois formats. Les clics UI portent sur le classement refusé et la consultation après restauration.

834 références protégées vérifiées, aucune modification. Prototype, S00, design et UX conservés. Captures sans débordement horizontal de page constaté aux trois tailles ; pas de conclusion sur tous les écrans de l’application.

## Reste de S05

La réserve « source classée ensuite mise en corbeille » est levée. Le périmètre de classement des contenus serveur reste validé ; conversations locales et brouillons Documents locaux exclus suivant le choix utilisateur.

S05 n’est pas clôturé intégralement : finition accueil/préparateurs, reprise d’analyse UI, pagination d’aperçu et circuits de retrait de référence/suppression de dossier restent identifiés. Aucun report silencieux ni déploiement.

# S08 — lot C : exécutions persistantes et quotas

30 octobre 2026. **Lot C livré pour l'instance locale et la recette fictive autorisée. S08 reste ouvert.** Skill uniion-développement appliqué. Aucun déploiement ni transfert de données métier réelles.

## Résultat observable

Configuration IA affiche un quota réel de demandes de recette et le dernier état d'exécution. Le test Codex réel produit `UNIION_S08_OK`, passe de « En cours » à « Réussie », comptabilise une demande et laisse 99 demandes disponibles. Après arrêt/redémarrage du serveur et connexion dans une nouvelle session, ces valeurs sont relues et identiques. Les réponses ne sont pas conservées dans le registre.

Le lancement local injecte `.local-ai/runs.sqlite3`. Migration SQLite explicite version 1, répertoire 0700 et fichier 0600 ; synchronisation complète. Tables privées du serveur, sans endpoint d'écriture de statut ou de consommation et sans clé Supabase privilégiée. Pas de modification des migrations Supabase historiques. Politique et sources métier restent sous contrôle du JWT utilisateur.

## Règles implémentées

- Réservation atomique : 100 demandes par organisation et jour UTC, deux exécutions actives pour le connecteur de l'instance. Limites techniques de recette, pas un budget financier.
- Clé d'idempotence durable organisation/acteur/requête. Doublon refusé sans nouvel appel, y compris avec corps différent, autre session ou après redémarrage. L'identifiant n'est jamais réutilisé.
- États attente, en cours, réussi, échoué, annulé et incertain. Bail expiré après engagement → incertain ; aucun renvoi automatique ni remboursement d'un appel potentiellement engagé.
- Annulation avant engagement : réservation libérée. Après engagement : unité conservée ; emplacement concurrent maintenu jusqu'à arrêt du worker ou expiration. Une réponse tardive ne remplace pas un état terminal.
- Journal des transitions sans questions, réponses ou secrets. L'API de suivi ne retourne que les états de l'acteur courant et les compteurs agrégés de son organisation autorisée.
- Jetons et coût inconnus (`null`), jamais présentés comme zéro ni extrapolés. Pas d'historique de contenu ou de mémoire ajouté.

Détails et limites : [S08-CONTRATS](../../docs/S08-CONTRATS.md), section lot C.

## Tests

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| Intégration HTTP et vraie politique Supabase | 31 contrôles réussis | integration.json |
| Codex réel, question fictive fixe | HTTP 200, réponse exacte, état réussi et unité conservée | codex-live.json |
| Suite Python finale | 233 tests réussis | python-tests-final.log |
| Registre durable | 18 tests réussis, inclus dans la suite Python | ledger-tests-final.log |
| Suite frontale | 191 tests réussis | frontend-tests-final.log |
| Compilation et frontières | Réussies | build.log, boundaries-final.log |
| Redémarrage du serveur réel | Schéma 1, une réussite, une unité, trois transitions | restart-local.json |
| Intégrité références et anciennes preuves | SHA-256 comparés, aucun changement | integrite-apres.json |

Les 18 tests de registre comprennent six processus concurrents pour une seule place, conservation après réouverture, refus d'un doublon après reconstruction de la passerelle, isolation acteur/organisation, propriétaire de transition forgé, annulation précoce et engagée, changement de jour, expiration, erreur fournisseur, copie SQLite cohérente et restauration isolée. Deux tests terminent réellement un processus avec `os._exit` avant/après engagement ; l'expiration est ensuite accélérée par l'horloge de test. Ce n'est pas une simulation de panne électrique de l'hôte.

L'intégration vérifie aussi MFA/session, origine/CSRF, anonyme, organisation étrangère, identité/consommation forgées, absence de contenu dans le registre, quota partagé entre acteurs, plafond atteint avant appel fournisseur, délai ambigu persistant et absence de relance. Une base isolée à trois unités teste le quota sans épuiser celle de l'interface.

## Fidélité et interface

La structure de Configuration IA, sa carte Consommation et ses styles hérités de S00/A/B sont conservés. Les valeurs auparavant non mesurées sont remplacées par le nombre réel de demandes et la disponibilité ; jetons/coûts restent inconnus. Une commande « Actualiser le suivi » et un libellé de dernier état sont ajoutés dans la carte de connexion existante. Aucun nouveau parcours d'Assistant dans ce lot.

Contrôles aux viewports 1440×1000, 768×1024, 390×844. Largeurs utiles tablette/mobile 760/382 px, égales au contenu : aucun débordement horizontal observé. Les compteurs mobiles sont accessibles par défilement et restent lisibles au-dessus de la navigation fixe. Pas d'appareil physique testé.

Captures : suivi-1440.png (succès réel), suivi-apres-redemarrage-768.png (nouvelle session, mêmes compteurs), suivi-390-haut.png et suivi-390-compteurs.png. Un onglet de recette a disparu pendant le changement de viewport ; la vérification a repris dans un nouvel onglet avec connexion/MFA, ce qui a aussi confirmé la relecture du suivi sans état React antérieur.

## Portée et réserves

Le registre est durable sur une instance locale, y compris plusieurs processus partageant le fichier. Il n'est pas un service distribué multi-hôte. Les fabriques utilisées par les tests sans injection explicite restent en mémoire ; le point d'entrée de l'application injecte toujours le fichier persistant.

Les compteurs sont des demandes réservées ou engagées, pas des jetons ni des euros. Le plafond n'est pas une garantie de dépense fournisseur. Une invocation échouant avant un envoi effectif peut être comptée par prudence si le connecteur a été appelé. L'annulation ne garantit pas l'arrêt de l'inférence distante.

Réconciliation des baux à la prochaine transaction, sans worker de relance. Aucun effacement automatique. Métadonnées personnelles conservées en fichier serveur privé ; sauvegarde globale, chiffrement des sauvegardes, rapprochement après restauration périmée et objectifs D07 restent à qualifier en F. Le test de copie/restauration du seul registre ne clôt pas ce chantier.

Un identifiant réussi dont la réponse a été perdue n'est pas régénéré ; il ne permet pas encore de relire le texte, qui relève du lot D. Les restrictions B restent appliquées à chaque génération. Aucun accès métier n'est conféré par un état du registre.

**Suite : lot D — Assistant, historique et mémoire.** Lots E et F et arbitrages de production D07/D09 restent ouverts.

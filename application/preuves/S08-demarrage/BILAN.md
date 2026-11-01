# S08 — démarrage et première brique locale

30 octobre 2026. **Sprint ouvert ; lot A partiel.**

La roadmap, la clôture S07 et les décisions D09/D12 ont été relues. Le [plan S08](../../planification/S08-demarrage/PLAN.md) décrit les lots, l'état existant et la matrice d'acceptation.

## Réalisé

Ajout de uniion/core/ai.py : contrat d'accès injecté, récupération par identifiants, contrôle avant récupération/envoi/restitution, bornes du contexte, annulation, détection des sources modifiées, erreurs fournisseur expurgées et dépendances D12 attachées au résultat. Aucun fournisseur par défaut, cache, mémoire ni réseau dans cette brique.

Douze tests unitaires avec fournisseur et autorisations fictifs : résultat/dépendances, autre organisation, fournisseur refusé, source inconnue, révocation, modification, annulation avant/pendant appel, erreur fournisseur, réponse vide, limite de contexte et doublons.

## Limites explicites

Ce service n'est pas raccordé à HTTP, Supabase ou au frontal. Le contrat authorize doit encore être implémenté avec de vrais contrôles serveur : les tests fictifs ne prouvent ni RLS, ni MFA, ni la politique D09 en production. Pas de quota durable, anonymisation serveur, citations validées, historique, adaptateur de fournisseur, ni restauration S08 à ce stade. L'annulation empêche la restitution mais n'interrompt pas un fournisseur en cours. La course entre validation et envoi ne constitue pas une révocation instantanée d'un transfert déjà commencé.

Les chemins IA historiques restent présents ; aucune qualification de leur confidentialité n'est annoncée. Aucun écran modifié, aucune recette visuelle S08 ni déploiement. Aucun fichier sources/ ou référence prototype modifié.

## Exécution

Une première commande lancée à la racine avec le Python système a échoué avant découverte des tests (répertoire tests absent). La recette a été reprise depuis application/ avec le runtime Python du projet. Les résultats observés sont conservés dans python-tests.log et boundaries.log.

Prochaine étape : terminer A par les adaptateurs d'autorisation et l'API locale, puis migrer le premier parcours Assistant. Le choix fournisseur et ses conditions D09 restent ouverts pour toute connexion réelle.

Résultat observé : **175 tests Python réussis**, dont les 12 nouveaux tests S08 ; contrôle des frontières des modules et des 14 migrations de référence réussi. Aucun test d'intégration ou frontal S08 exécuté, car le raccordement applicatif reste à faire.

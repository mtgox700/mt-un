# S07 — Lot A : conversations privées et messages durables

30 octobre 2026. Lot A livré et vérifié en local. **S07 reste ouvert.** Aucun déploiement ni fournisseur externe.

## Périmètre et réalisation

Le parcours existant Messages → Contacts & groupes → participant crée ou retrouve une conversation privée à deux membres. La liste et le fil proviennent de Supabase. Un message envoyé est relu après rechargement et reconnexion. Réponse liée, informations, copie, pagination et états vide/chargement/refus sont raccordés. Aucune conversation de démonstration ne sert de secours à une erreur serveur.

Migrations 120 et 121 appliquées sans reset. La seconde corrige le nom réel du champ de fonction des profils et borne également le texte côté RPC. Trois tables privées, une RPC contrôlée, adaptateur Python et service frontal du module. Le premier essai d’intégration a révélé le champ incorrect ; le résultat final ci-dessous correspond au rejeu corrigé.

Les actions non raccordées (groupes, pièces, transfert, classement, suppression, IA) annoncent leur indisponibilité. La pièce fictive héritée a été neutralisée. L’historique des convocations conserve son adaptateur, ses refus et sa lecture seule.

## Sécurité et accès

MFA, organisation active, membre non suspendu/révoqué, module autorisé/activé/payé, permission métier et participation sont cumulés. Aucun accès implicite du super administrateur. Les tables privées n’accordent aucun privilège direct aux clients. Les appels métier et les tests de refus utilisent les JWT utilisateurs ; SQL administrateur sert uniquement aux migrations et à la préparation des fixtures locales.

Les périodes et bornes de séquence empêchent de restituer l’historique après réinvitation. Les commandes de gestion de ces périodes relèvent du lot B ; les transitions de recette ont été préparées en SQL, sans prétendre avoir testé leur interface.

La réponse à un message invisible est refusée. Les clés d’envoi identiques ne créent qu’un message, y compris en concurrence. Le contenu modifié sous la même clé est refusé. Les données privées sont retirées de l’écran lors d’un refus ; les réponses tardives après déconnexion sont ignorées.

## Matrice et tests exécutés

| Critère du lot A | Résultat observé | Preuve |
| --- | --- | --- |
| Création et relecture par deux acteurs | Conversation unique, message et réponse persistants après reconnexion MFA | integration.json |
| Hors conversation / autre organisation | Liste filtrée, lecture et envoi refusés, y compris RPC directe | integration.json |
| Super admin non participant | Refus sur le fil des deux autres acteurs ; rôle actif confirmé séparément | integration.json, admin-fixture.json |
| MFA, module, paiement et permissions | Refus aal1, module désactivé, droit expiré, write/read retirés | integration.json, access-edges.json |
| Départ / suspension / réinvitation | Retrait effectif ; nouvelle période sans ancien historique ; réinvitation d’organisation sans reprise implicite | integration.json, access-edges.json |
| Rejeu et concurrence | 4 requêtes concurrentes : un message ; changement de texte refusé | integration.json |
| Pagination du fil | 50 messages, page suivante sans doublon malgré un nouvel envoi | integration.json |
| Entrées directes hostiles | Champs usurpés, null, curseurs invalides, réponse inexistante et longueur excessive refusés | access-edges.json |
| État frontal | Double clic, reprise incertaine, saisies entre fils, déconnexion et navigation tardive | messaging-tests.log |
| Interface | Création desktop, réponse, envoi sur les trois dimensions, relecture après reload, pagination tablette | ui.json et captures |
| Refus avec session ouverte | Envoi refusé après désactivation ; fil/liste vidés ; message lisible aux trois formats | captures *-refus.png |
| Références protégées | 834 fichiers inchangés | integrite.json |

Résultats : **47 contrôles d’intégration principaux + 17 contrôles complémentaires**, **150 tests Python**, **132 tests frontaux dont 10 ciblés S07**. Compilation et frontières des modules réussies. Les nombres ne désignent pas des parcours UI. Le contrôle séparé du rôle administrateur n’est pas ajouté à ces comptes.

Commandes depuis application/ : python3 -B tests/s07_messaging.py ; python3 -B tests/s07_access_edges.py ; python3 -B -m unittest discover -s tests -p 'test_*.py' ; python3 -B scripts/check_boundaries.py. Depuis frontend/ : node build.mjs ; node --test state/*.test.mjs host/*.test.mjs. Exécutables du runtime Codex utilisés, chemins détaillés dans le package de reprise.

Les tests d’intégration ont utilisé une horloge avancée dans leur seule instance WSGI pour séparer les fenêtres de quota ; aucune protection de l’application servie sur 5068 n’a été réduite. Les essais UI passent par les contrôles visibles avec le quota normal. Les comptes, noms, paiements et contenus sont fictifs ; les paramètres d’accès temporairement changés pour la recette ont été rétablis.

## Fidélité

Comparaison visuelle avec preuves/S02-messagerie/thread-390.png : structure, navigation, bulles, composition et styles conservés. Viewports émulés : 390×844, 768×1024, 1440×1000. Largeurs de document observées : 382, 760, 1440 pixels, sans débordement horizontal.

Adaptations fonctionnelles visibles : participants et dates réels, notice de stockage serveur, champ « Votre message », une coche d’enregistrement au lieu d’un accusé de lecture fictif, boutons de pagination dans les styles existants, messages d’indisponibilité. Aucun chiffrement de bout en bout n’est revendiqué.

## Réserves et suite

- Lot B : groupes, gestion des membres et ouverture habilitée de l’historique. Le modèle est prêt, ces commandes ne sont pas livrées.
- Lots C/D : pièces et classement protégés, transferts et recherche exhaustive. La recherche actuelle porte sur les éléments chargés.
- Lot E : temps réel, notifications et curseurs de lecture. Une révocation est contrôlée à la prochaine requête ; aucun abonnement temps réel n’est présenté comme réalisé.
- Lot F : installation neuve, restauration isolée incluant S07, charge et clôture globale. Non exécutées dans A.
- Les brouillons et clés de reprise sont uniquement en mémoire. Après fermeture/rechargement suivant un résultat incertain, relire le fil avant un nouvel envoi ; hors ligne durable S13.
- L’alerte existante d’historique Agenda inaccessible peut apparaître lorsqu’un compte n’a pas le module Agenda ; elle ne bloque pas les conversations privées. Réserves historiques S03 conservées.
- Appareils physiques, production et qualification indépendante restent hors recette.

**Conclusion : lot A validé techniquement en local ; acceptation produit distincte. Prochaine étape : lot B.**

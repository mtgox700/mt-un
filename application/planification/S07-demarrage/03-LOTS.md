# S07 — lots proposés et dépendances

Découpage technique proposé. Les comportements déjà validés restent obligatoires ; les choix nouveaux ne sont pas présumés approuvés.

## A — Conversation privée et message durable

Objectif : un utilisateur habilité ouvre ou crée une conversation via le parcours existant, écrit un message réel, et retrouve ce message après rechargement/reconnexion. Un utilisateur hors conversation ne voit ni liste, ni texte, ni métadonnées.

Livrer ensemble : schéma/versionnement, contrôles de base et serveur, API, service frontal propriétaire, choix de participants autorisés, liste et fil réels, états vide/erreur/chargement, idempotence d’envoi, pagination stable. Conserver réponse et information du message si présentes ; toute action non encore raccordée doit être explicitement indisponible, sans faux succès. Ne pas créer de faux messages pour remplir l’écran.

Critères de sortie : deux acteurs fictifs autorisés, troisième hors groupe, autre organisation, MFA insuffisant, module/droits retirés ; persistance et double clic/rejeu testés ; aucune lecture via identifiant deviné. Recette aux trois formats. Ne pas attendre les pièces ou le temps réel pour prouver la sécurité des lectures.

## B — Membres, historique et révocation

Dépend A. Raccorder les groupes et membres aux permissions séparées. Gérer les périodes d’appartenance, l’accès depuis l’arrivée et l’ouverture explicitement habilitée de l’historique. Réinvitation : nouvelle période sans restitution automatique. Tester les bornes temporelles, les comptes suspendus et les réponses tardives après changement d’identité.

L’administration d’organisation ne donne pas accès automatiquement aux conversations. Une demande de suppression suit D07 ; pas de suppression physique directe depuis un bouton hérité.

## C — Pièces et classement dans Dossiers

Dépend A/B. Réutiliser le pipeline privé existant : dépôt, quarantaine, antivirus, reprise, aperçu inerte et téléchargement distinct. Messages → Dossiers : référence durable, contrôles cumulés source/destination, recontrôle à chaque consultation/téléchargement, pas de copie qui contourne une révocation. Tester pièce infectée, scan interrompu, autre organisation, révocation et corbeille source.

## D — Réponse, transfert et recherche

Dépend A/B/C. Réponse liée à un message lisible, extraits et recherche filtrés. Transfert : lecture source + écriture destination sont nécessaires mais pas toujours suffisantes pour autoriser une nouvelle diffusion. Par défaut, une référence reste soumise aux droits sources ; toute copie élargissant l’audience relève de D12/D13 et nécessite le circuit validé. Faire arbitrer une ambiguïté produit avant d’accorder cet élargissement. Notifications et compteurs ne doivent pas révéler de conversations cachées.

## E — Temps réel, notifications et reprise

Dépend A/B, complété avec C/D. Choisir et documenter le transport après inspection des outils disponibles ; aucun canal global contenant du métier. Authentifier les abonnements, filtrer événements et métadonnées, recontrôler les droits lors de la récupération. Un signal minimal suivi d’une lecture autorisée peut limiter l’exposition, sans remplacer les contrôles d’abonnement.

Reconnexion avec curseur, ordre serveur stable et déduplication. Tester la révocation sur une connexion déjà ouverte : aucun nouvel événement métier après révocation, état sensible invalidé. L’expiration de session ferme le canal. Le polling seul n’est pas présenté comme une implémentation temps réel achevée. Notifications in-app d’abord ; aucun email/push externe implicite.

## F — Clôture du sprint

Rejouer les parcours transversaux et les suites de sécurité concernées ; comparer les écrans ; tester une installation neuve et une restauration isolée couvrant les tables/objets S07, puis droits/MFA après restauration. Tester concurrence, interruptions et volume représentatif borné. Vérifier intégrité des références et absence de secrets dans les artefacts. Mettre à jour contrats, état courant et bilan global.

Pas de clôture si : fuite de contenu/métadonnées, droits contournables, message perdu/doublonné silencieusement, révocation temps réel inefficace, stockage fictif encore utilisé comme vérité, migration/restauration non vérifiée, parcours essentiel cassé. Documenter les dépendances reportées sans les faire disparaître.

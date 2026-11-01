# S08 — lot A : passerelle IA et politique D09

30 octobre 2026. **Lot A réalisé et recetté en local dans le périmètre fictif autorisé. S08 reste ouvert.**

## Périmètre et résultat

Demande : « go lot A avec le skill uniion ». Autorisation complémentaire explicite : connecteur ChatGPT/Codex local, uniquement avec des données fictives pour cette recette. Aucun contenu métier envoyé ; deux questions serveur prédéfinies, pas de texte libre. Aucun déploiement.

Réglages → Configuration IA est raccordé au BFF et à Supabase. Approbation fournisseur par super admin, activation par administration d'organisation, contrôle des permissions utilisateur et test de connexion réel. L'état est persisté et relu après nouvelle connexion/redémarrage. Le bouton visible a reçu `UNIION_S08_OK` depuis Codex. Annulation, activation, révocation et refus après révocation ont été actionnés dans l'interface.

## Sécurité et implémentation

Migrations 141–142 appliquées à Supabase local : tables privées/RLS, RPC avec JWT utilisateur, MFA, rôles séparés, versions, invalidation des activations après nouvelle approbation et audit sans contenu. Le super admin ne reçoit aucun droit de génération par son seul rôle.

La passerelle revalide avant et après l'appel, libère le verrou des sessions pendant l'inférence et rejette les résultats après annulation, déconnexion ou changement de politique. Annulation précoce couverte, budget d'annulation indépendant, demandes bornées et anti-rejeu transitoire. Les erreurs du fournisseur restent génériques côté client, sans faux succès ni relance automatique.

Le connecteur utilise un environnement temporaire privé, sans configuration/MCP/plugins/historique hérités et sans outils autorisés. L'authentification du compte est utilisée côté serveur, jamais transmise au navigateur. Appels directs et stockage de clé supprimés du code frontal actif et de sa source de génération. Les fonctions métier non migrées retournent une indisponibilité pour la génération ; elles ne passent pas par un fournisseur de secours.

Voir les [contrats et limites précises](../../docs/S08-CONTRATS.md).

## Tests observés

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| Auth/MFA, politique, API et concurrence | 54 contrôles réussis | integration.json |
| Requêtes forgées, droits et erreurs supplémentaires | 18 contrôles réussis | policy-edges.json |
| Appel Codex réel, question fictive fixe | HTTP 200, réponse exacte | codex-live.json |
| Suite Python finale | 191 tests réussis | python-tests-final.log |
| Suite frontale finale | 182 tests réussis | frontend-tests-final.log |
| Compilation et frontières | Réussies | build.log, boundaries-final.log |
| Références protégées / anciennes preuves | 834 / 2 107 inchangées | integrite-apres.json |

Les 72 contrôles d'intégration ne sont pas 72 parcours UI. Les tests couvrent notamment AAL1/anonyme, origine/CSRF/Bearer, autre organisation, absence de read/write, module désactivé/non autorisé/expiré, abonnement expiré, suspension/révocation, organisation inactive, droits de gestion séparés, versions périmées, accès direct aux tables et RPC, champs de fournisseur/URL forgés, doublon, annulation concurrente, révocation et déconnexion pendant l'appel, erreur fournisseur expurgée. Les tests HTTP utilisent aussi le stockage de session chiffré durable et ses rechargements.

Les 191 tests Python incluent 28 tests IA ; les tests frontaux incluent neuf nouveaux tests de passerelle. Le dernier correctif frontal empêche une confirmation de configuration tardive de réapparaître après déconnexion ; il est couvert par test. Aucune modification de mise en page dans ce correctif.

## Fidélité et recette UI

Référence comparée : planification/S00/consolidation/captures/apikey-desktop.jpg et apikey-mobile.jpg, avec le registre S00. Cartes, palette, typographie, navigation et organisation de l'écran conservées. Adaptations nécessaires : retrait de la saisie de clé, fournisseur de recette unique, actions de politique réelles et remplacement des garanties/consommations simulées par leur état exact. Ce n'est pas une identité textuelle avec le prototype.

Viewports 1440×1000, 768×1024 et 390×844. Largeur document observée 760/382 px pour tablette/mobile, correspondant à la largeur utile hors barre de défilement ; aucun débordement horizontal observé. Commandes d'activation/révocation atteignables sur mobile après défilement. Aucun appareil physique testé.

Captures utiles : connexion-finale-1440.png, annulation-1440.png, configuration-768.png, configuration-finale-390.png, activation-revoquee-390.png, refus-390.png. L'activation de recette a été désactivée depuis l'interface à la fin ; le serveur reste disponible sur 5068. La capture de succès montre l'état pendant la recette, pas une activation permanente.

## Incidents et corrections

- Le premier jeu réutilisait un acteur historique déjà super admin : il ne pouvait pas prouver le refus d'un admin local. Recette reprise avec trois acteurs entièrement nouveaux et fictifs. Ce n'était pas une faille de contrôle du rôle.
- Première exécution frontale : assignation au global crypto en lecture seule avec Node 24 ; fixture de test corrigée. Quelques commandes de création/lecture ont utilisé un mauvais préfixe de répertoire et ont échoué avant modification ; exécutées ensuite au bon emplacement.
- Le contrôle de session par identité d'objet a été remplacé par session/CSRF/acteur, nécessaire au rechargement du store durable. Test unitaire dédié et appel réel depuis le navigateur réussis.
- Course d'annulation avant enregistrement corrigée ; confirmation de configuration tardive après déconnexion corrigée.
- Le navigateur refuse le port 5060 ; l'instance uniion identifiée sur 5068 a été rechargée en préservant ses sessions. Une tentative d'annulation a rencontré une réponse déjà terminée ; l'essai suivant a annulé pendant l'exécution et montré l'état attendu.
- La première capture mobile était prise pendant le changement de viewport ; configuration-finale-390.png est la capture stabilisée à retenir.

## Réserves et suite

Le lot A porte sur la passerelle et sa recette fictive. Le choix du fournisseur de production, les conditions de traitement/localisation/conservation et l'articulation D07 restent ouverts. La copie temporaire d'authentification Codex est un mécanisme de recette locale, pas une gestion multi-utilisateur de comptes fournisseurs en production.

Restent à réaliser dans S08 : contexte autorisé et anonymisation serveur B ; exécutions/quotas/coûts/idempotence durables C ; Assistant/historique/mémoire D ; actions unii et modules E ; qualification globale F. Le contrat de sources initial core/ai.py ne constitue pas encore un raccordement des ressources métier.

Migrations appliquées et contrôles locaux exécutés ; aucune nouvelle installation complète ni restauration S08 exécutée dans A, à qualifier en F. L'anti-rejeu et l'annulation sont locaux au processus, pas distribués. Les coûts ne sont pas mesurés. L'annulation ne garantit pas l'arrêt d'un traitement déjà reçu par le fournisseur.

Conclusion : A livré dans le périmètre autorisé ; prochaine étape **B — contexte autorisé**, sans autorisation implicite d'envoyer des données réelles.

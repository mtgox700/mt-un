# S08 F — recette globale et décision de clôture

31 octobre 2026 — Europe/Paris. Skill uniion-développement appliqué.

**Lot F validé pour le périmètre local fictif raccordé. S08 n’est pas clôturé sur son périmètre métier complet et n’est pas admis en production.** Les 37 actions métier, la conversation libre, les adaptateurs des autres modules et les dérivés applicables/diffusables signalés en E restent ouverts. Aucune autorisation supplémentaire de transfert, aucun déploiement, aucune purge.

## Résultats observés

| Vérification | Résultat | Preuve actuelle |
| --- | --- | --- |
| Suite Python | 262 tests réussis | python-tests.log |
| Suite frontale | 214 tests réussis | frontend-tests-final.log |
| Politique D09, erreurs sans détail privé | 18 contrôles | s08_policy_edges/S08-A/policy-edges.json |
| Exécutions, quotas, idempotence et états | 29 contrôles | s08_runs_integration/S08-C/integration.json |
| Historique, mémoire, révocation et isolement | 33 contrôles | s08_assistant_integration/S08-D/integration.json |
| Actions, références strictes, acteur/organisation, Codex réel | 31 contrôles | s08_actions_integration/S08-E/integration.json |
| Pile vierge Auth/Storage/PostgREST, MFA, migrations et refus IA | 48 contrôles | fresh/S01-ephemeral/integration.json |
| Restauration base/fichiers, catalogues, RLS, octets et lignes | 374 contrôles | restore/restore-*.json |
| Restauration IA, MFA, relecture et révocation | 15 contrôles | restore/acceptance.json |
| Compilation et frontières | Réussies | build.log, boundaries.log |
| Intégrité | 834 références protégées et 2206 anciennes preuves inchangées | integrite-apres.json |

Les 111 contrôles d’intégration sont rejoués dans F, sans réécrire les preuves A–E. Les registres des scénarios sont temporaires. Les révocations des fixtures sur la pile de travail sont restaurées par les scénarios ; la révocation de restauration se fait seulement dans la copie isolée.

Un appel réel au connecteur Codex, limité à une source fictive certifiée, retourne une réponse persistée avec citation vérifiée. Les autres scénarios utilisent des fournisseurs de test déterministes pour les refus, délais, annulations et erreurs ; ils ne constituent pas autant d’appels réels au modèle.

## Installation neuve

139 fichiers SQL sont appliqués dans l’ordre depuis une base vide ; leur numérotation va jusqu’à 144. Le manifeste contient chaque chemin et empreinte. Auth, Storage et PostgREST sont de vrais services locaux isolés, sans port publié. Les utilisateurs sont fictifs, le second facteur est réellement vérifié.

Le fournisseur IA est initialement non approuvé, aucune organisation n’est activée, le registre de certification est vide et un membre ne peut pas approuver le fournisseur. Le registre SQLite neuf atteint le schéma 2 et ne contient pas d’historique. Aucun secret, compte ou sauvegarde de la pile de travail n’est importé dans cette installation neuve.

Deux erreurs du harnais de recette ont été corrigées : confusion entre le dernier numéro et le nombre de fichiers SQL, puis collision entre une variable de destination de preuve et le rapport local du harnais historique. Les journaux des deux essais sont conservés. Aucun de ces échecs n’a nécessité de modifier une migration métier.

## Restauration réellement exécutée

Nouvelle sauvegarde chiffrée de Supabase et des fichiers privés, puis restauration dans une cible isolée. Schéma, fonctions, RLS, droits, lignes et fichiers comparés aux empreintes de sauvegarde. Les anciennes sessions Auth ne sont pas réactivées.

Un instantané cohérent SQLite est pris avec l’API de sauvegarde SQLite en lecture seule de la source. Le registre et sa clé d’historique sont placés dans une enveloppe AES-GCM ; la clé d’enveloppe est enregistrée séparément sous permissions privées. Le registre restauré est vérifié (`integrity_check`, schéma 2). Les réponses sont déchiffrées puis relues via les droits, versions et certifications de la base Supabase restaurée, avec une nouvelle connexion et un vrai second facteur.

Vérifications : refus AAL1, isolation acteur/organisation, préférence mémoire conservée, interdiction de rejouer une requête déjà exécutée, révocation d’appartenance bloquant la relecture, clé d’historique manquante provoquant un refus sans remplacement silencieux. Les contrôles d’intégrité et les refus ne se substituent pas à une admission en service.

Mesure de cette exécution locale : 24,787 s pour la restauration base/fichiers, 54,443 s pour le scénario complet incluant la sauvegarde et les contrôles IA. Ce ne sont pas des RPO/RTO de production.

**Limites de restauration :** les instantanés SQL et SQLite sont séparés, sans transaction distribuée ; les dépendances doivent être revalidées et les révocations postérieures à la sauvegarde rapprochées avant toute admission. Ce scénario n’ajoute pas automatiquement l’historique IA au calendrier de sauvegardes existant. Les clés et copies locales sont conservées, sans purge. Les conteneurs de recette sont arrêtés, pas supprimés. La politique de conservation et l’exploitation production restent à terminer selon D07.

## Confidentialité, injections et qualité

Les tests couvrent les références forgées, les champs supplémentaires, les outils/commandes injectés dans les résultats, les citations inventées, les modifications/révocations pendant l’appel, le refus du texte libre et l’absence de repli implicite. Les contenus IA et documents importés restent des données. Le modèle n’a aucun outil métier ; l’application ne traite pas ses réponses comme des commandes.

La qualité qualifiée est **extractive** : citations et extraits exacts d’un contexte autorisé, masquage partiel et absence de faits ajoutés dans la réponse acceptée. Cela ne valide ni raisonnement juridique, ni exhaustivité, ni anonymisation complète. Les limites de taille sont des refus explicites, pas des troncatures cachées. Coûts et jetons restent inconnus, les compteurs d’exécution ne sont pas présentés comme une facture.

L’écran déjà ouvert est recontrôlé périodiquement, pas par révocation poussée instantanée. L’historique est chiffré sur le serveur local ; les métadonnées d’exécution et l’administrateur de l’hôte restent hors de cette protection. Aucun secret connu de fixture ni JWT détecté dans les preuves textuelles ; cette recherche n’est pas un audit exhaustif.

## Recette visuelle

Nouvelle connexion du lecteur fictif et relecture d’une réponse persistée du lot E dans l’Assistant. Contrôle aux formats 1440×1000, 768×1024 et 390×844 ; captures et observations dans ce dossier. Les preuves E du panneau unii, de son annulation, des trois modules et du brouillon de message conservé sont maintenues. F conserve la structure des écrans. Une correction ciblée retire la réponse sélectionnée lorsqu’une saisie libre est refusée, afin que le message « Votre texte n’a pas été envoyé » soit visible. Un test vérifie ce refus après ouverture d’un historique, sans appel serveur supplémentaire ; la suite frontale passe de 213 à 214 tests.

## Décision et reste à faire

- Autoriser la poursuite des recettes locales sur les fixtures certifiées, avec le connecteur autorisé.
- Ne pas annoncer les 37 actions métier comme livrées, ni appliquer/diffuser un dérivé en contournant D12/D13.
- Compléter E métier, les sources des autres modules et leurs recettes avant clôture fonctionnelle S08.
- Arbitrer fournisseur, modèle, localisation, conservation et finalités de production selon D09/D07 ; aucune activation réelle n’est déduite de F.
- Intégrer la sauvegarde coordonnée SQL/fichiers/registre IA/clés dans l’exploitation, tester restauration et révocations, puis mesurer RPO/RTO. Qualifier le multi-hôte ou choisir explicitement l’exploitation mono-instance.

Le package de transmission est nommé « RECETTE » pour rendre cette réserve visible. Il contient la documentation et les preuves sélectionnées, sans comptes, clés, bases privées, sauvegardes ou sources synchronisées.

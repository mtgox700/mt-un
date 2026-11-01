# S08 — réserves et décisions différées

31 octobre 2026. L’utilisateur a demandé de laisser les décisions de production au dernier sprint. Destination : **S16, avant tout usage réel**. Ce report ne modifie pas les décisions S00 et ne vaut pas acceptation implicite d’un fournisseur ou d’un hébergeur.

## Décisions à acter en S16

| Sujet | Travail / décision requis | Impact jusque-là |
| --- | --- | --- |
| D09 — fournisseur IA | Fournisseur/modèle cible, localisation et sous-traitants, traitement/conservation, conditions contractuelles et budget | Connecteur ChatGPT/Codex de recette, données fictives uniquement |
| Protection des données | Vérification du masquage, minimisation, périmètres de données autorisés et validation du cadre de traitement | Masquage partiel ; aucune garantie d’anonymisation exhaustive |
| D07/D08 — conservation et sauvegardes | Durées, purge validée, sauvegardes coordonnées DB/fichiers/IA/clés, objectifs de reprise et exercice cible | Restauration isolée locale prouvée ; exploitation de production non certifiée |
| Infrastructure et livraison | Cible, domaine, HTTPS, secrets, supervision, alertes, procédure de livraison/repli et responsabilités | Aucun site externe, push ou déploiement activé |
| Exploitation IA | Coûts/jetons, quotas, capacité, concurrence, résilience et observabilité | Coûts/jetons inconnus ; registre local mono-instance |
| Recette cible et feu vert | Droits, restauration et parcours rejoués sur la configuration choisie ; acceptation du pilote | La recette locale ne remplace pas celle de production |

S15 peut préparer et documenter ces choix ; aucune activation ne doit les anticiper. Une utilisation de données réelles avant S16 imposerait de traiter ces prérequis avant cette utilisation.

## Limites du périmètre S08 livré

- Une action Messages porte sur le message sélectionné, pas sur tout l’historique de conversation. Les listes croisent au plus huit sources autorisées. Le contexte Accueil/Paramètres est limité et exclut les dossiers classifiés ; il n’est pas un index exhaustif de l’organisation.
- Les contrôles serveur restent nécessaires à chaque action ; les listes UI se revalident toutes les dix secondes. Les réponses anciennes peuvent devenir indisponibles après modification ou révocation de leur source.
- Générations et copies diffusées localement sont des brouillons ou publications explicitement relus ; aucune réponse n’est une validation juridique. Les propositions de notification ne sont pas des envois.
- Le connecteur et la liste d’organisations de recette sont explicitement limités aux fixtures fictives. Aucune donnée réelle n’a été autorisée pour cette recette.
- Les sorties déjà produites ne sont pas réécrites rétroactivement : une ancienne preuve montrant un défaut est conservée avec sa correction ultérieure.

## Fonctions prévues dans les sprints suivants

Ces éléments relèvent de la feuille de route, pas de nouvelles décisions de production.

| Destination | Travail restant | Frontière S08 |
| --- | --- | --- |
| S09 | Audio, transcription, consentement et chaîne complète de PV | S08 prépare le projet depuis les notes/marqueurs disponibles ; aucun contenu audio analysé |
| S10 | Collecte réelle des votes, campagnes et statistiques | S08 produit les options/analyses depuis les seules données disponibles ; pas de résultats inventés |
| S11 | Sites et connecteurs externes, parcours complets de publication | S08 conserve les brouillons natifs et copies locales D12/D13 ; l’aperçu garde des liens/gabarits de démonstration et aucun domaine n’est publié |
| S12 | Parcours complets de formation, attestations, reporting et signature | S08 génère et conserve cours, exercices et brouillons ; pas une certification de ces modules entiers |
| S13–S15 | Hors ligne, administration, intégration complète et recette cible | Les contrôles S08 ne certifient pas les modules à venir |

## Acceptation

Les correctifs de document, PV, aperçu Intranet et concurrence sont livrés et testés dans F final. Aucune réserve technique bloquante du périmètre local S08 n’est connue à l’issue des contrôles décrits. La clôture produit reste proposée à l’utilisateur, sans lui attribuer une acceptation qu’il n’a pas donnée. Les décisions S16 restent ouvertes avec leur impact explicite.

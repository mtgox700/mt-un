# Package de lancement S07 — uniion

Établi le 30 octobre 2026. Dossier de transmission, pas preuve d’implémentation de S07.

## Utilisation

Ouvrir un nouveau chat dans le projet Cockpit, avec accès à ce workspace. Coller le contenu de `01-PROMPT-NOUVEAU-CHAT.md`. Le nouveau chat doit commencer par le lot A et aller jusqu’à sa recette, sans attendre une nouvelle instruction pour les étapes techniques ordinaires. Ce package ne crée pas de chat et ne lance pas S07.

## Lecture économique

1. Lire le prompt et `02-ETAT-COURANT.md`.
2. Lire le skill uniion, les instructions applicables, puis seulement le lot concerné de `03-LOTS.md`.
3. Utiliser `04-CONTRATS-ET-SECURITE.md`, `05-RECETTE.md` et `06-REPERES-TECHNIQUES.md` comme références ciblées.
4. En fin de lot, actualiser l’état courant et les preuves ; ne pas réécrire les bilans historiques.

Les décisions utilisateur et S00 priment sur les propositions de ce package. Aucun calendrier ni taux d’avancement n’est déduit du nombre de sprints. Les lots sont ordonnés par dépendances, sans estimation de durée inventée.

## Résultat attendu

Une messagerie réelle et persistante sur Supabase local, fidèle aux écrans existants, avec contrôle d’accès par conversation, pièces protégées, synchronisation temps réel, notifications et classement dans Dossiers. Les transferts ne doivent pas élargir implicitement la diffusion d’un contenu source.

Le ZIP est une commodité de transport documentaire. Il ne contient ni code applicatif, ni clés, ni comptes, ni données métier. Pour exécuter le travail, le nouveau chat doit accéder au dépôt local.

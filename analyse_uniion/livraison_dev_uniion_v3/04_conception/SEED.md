# Jeu de données de départ et fixtures de test

Version 1 — 5 septembre 2026. Le prototype embarque un jeu de démonstration en mémoire ; ce document
le spécifie pour qu'il soit reconstruit côté serveur, et distingue les trois jeux de données à livrer.

## 1. Trois jeux distincts

| Jeu | Usage | Contrainte |
|---|---|---|
| `seed-demo` | Démonstration commerciale, formation, recette fonctionnelle | Organisation fictive, adresses en `@example.org`, aucun destinataire réel joignable |
| `fixtures-test` | Tests automatisés | Déterministe : identifiants et dates figés, aucun aléa, aucune dépendance à la date du jour |
| `seed-vide` | Première connexion réelle d'une organisation | Rubriques de site et gabarits de documents seulement, aucune personne |

Le jeu de démonstration ne doit **jamais** être chargé en production sur une organisation réelle, et
aucune adresse e-mail réelle ne doit y figurer : la démonstration envoie des messages.

## 2. Organisation de démonstration

- **Section syndicale Métallurgie — Valenciennes**, sigle SECTION MÉTA VAL, type
  `section`, IDCC métallurgie, local syndical 12 rue de la Fonderie, 59300 Valenciennes.
- Trois établissements : Valenciennes, Douai, Cambrai. 84 adhérents souscrits.
- Compte principal : **Sophie Marchand**, déléguée syndicale, secrétaire de section, rôles
  `militant` + `communication` + `admin`.
- Comptes secondaires : **Jean-Paul Deniau** (`militant`, `communication`),
  **Karim Belkacem** (`militant`, `communication`), **une trésorière** (`tresorier`) —
  nécessaire pour démontrer le cloisonnement de l'article 9 et la validation par un pair.

## 3. Volumes attendus

| Entité | Démonstration | Fixtures de test | Justification |
|---|---|---|---|
| Adhérents | 84 | 3 + 1 lot de 2 500 | Le lot valide la pagination et l'import asynchrone |
| Dossiers | 8 (répartis sur les trois colonnes, dont 1 clos) | 4 | Kanban crédible sans surcharge |
| Pièces jointes | 3 (dont 1 de 40 Mo) | 2 (dont 1 de 81 Mo, rejetée) | Valide les limites |
| Pages de site | 5 intranet + 3 publiques | 2 par site | Couvre les cinq statuts de publication |
| Événements d'agenda | 12 sur le mois, dont 1 série récurrente et 1 privé | 5 | Valide récurrence et visibilité |
| Documents | 6 (un par gabarit, dont 1 signé) | 3 | Couvre les statuts |
| Réunions | 3 (dont 1 avec transcription) | 2 | — |
| Sondages | 3 (brouillon, diffusé, clos) | 3 | Couvre la validation par un pair |
| Listes de diffusion | 4 (3 dynamiques, 1 fixe) | 2 | Valide le recalcul |
| Fils de messagerie | 3 | 2 | — |
| Journal d'audit | 40 entrées réparties sur 3 mois | 10 | Rend les écrans d'audit lisibles |
| Reporting | Agrégats sur 24 mois | 12 mois | Permet les trois périodes de l'écran |

## 4. Règles de génération

1. **Dates relatives à l'installation** pour la démonstration (« il y a 3 jours », « dans 8 jours »)
   afin que l'agenda et les échéances restent crédibles dans le temps ; **dates absolues figées**
   pour les fixtures de test.
2. **Couverture des statuts** : chaque entité à statut doit avoir au moins une occurrence par statut,
   y compris les statuts d'échec (page retournée par le webmaster, campagne en échec, cotisation en
   retard, dossier clos sans suite).
3. **Cas limites inclus** : un titre de dossier de 180 caractères, un nom composé long, un adhérent
   sans e-mail, un événement de 12 h, une pièce jointe volumineuse, un CSV en latin-1 avec
   point-virgule (fichier d'exemple à livrer avec le jeu).
4. **Aucune donnée d'article 9 vraisemblable** : les mentions de santé au travail dans les dossiers
   de démonstration doivent rester manifestement fictives.
5. **Reproductibilité** : le chargement du jeu est idempotent (identifiants stables) et
   réinitialisable en une commande — équivalent serveur du bouton « Réinitialiser la démonstration »
   présent dans le prototype.
6. **Réconciliation** : une évolution du jeu livré doit être visible sans effacer les saisies de
   l'utilisateur. Le prototype le fait par fusion sur identifiant ; côté serveur, versionner le jeu
   (`seed_version`) et n'insérer que les entrées absentes.

## 5. Fichiers à livrer avec le code

- `seed/demo.json` — organisation, comptes, entités listées au §3.
- `seed/vide.json` — rubriques de site et gabarits de documents seulement.
- `seed/import-exemple.csv` — 2 500 lignes dont 37 invalides, motifs variés, encodage latin-1.
- `fixtures/*.json` — un fichier par module, déterministe.
- `seed/README.md` — commandes de chargement, de réinitialisation et de vérification.

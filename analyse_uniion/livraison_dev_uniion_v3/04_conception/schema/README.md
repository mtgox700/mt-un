# Schéma de référence

Version 1 — 5 septembre 2026.

- `uniion.sql` — schéma PostgreSQL 15+, **source de vérité**. Types énumérés, contraintes
  métier (relecteur ≠ auteur, validateur ≠ auteur, taille de pièce jointe, cohérence des dates),
  suppression logique, concurrence optimiste, journal d'audit en ajout seul avec empreinte chaînée,
  et politiques de sécurité par ligne pour le cloisonnement entre organisations, le périmètre des
  dossiers et la visibilité de l'agenda.
- `uniion.d.ts` — types partagés client / serveur, miroir du SQL. Les données d'article 9 sont
  typées séparément des agrégats (`Adherent` contre `AdherentAgrege`) afin qu'une réponse
  destinée à un rôle non habilité ne puisse pas, par construction, transporter de personnes.

## Ce que le schéma impose au code

1. Toute session applicative doit poser `uniion.organisation_id` et `uniion.personne_id` :
   sans eux, les politiques de sécurité par ligne ne renvoient aucune ligne. Le cloisonnement ne
   dépend donc jamais d'une condition oubliée dans une requête.
2. Les politiques livrées couvrent adhérents, dossiers (organisation et périmètre) et agenda
   (visibilité). **À répliquer sur toutes les tables portant `organisation_id`** avant la mise en
   production : le fichier montre le motif, il ne le déroule pas sur les 30 tables.
3. Les durées de conservation de `MODELE_DONNEES.md` s'implémentent en tâches planifiées qui
   écrivent dans `execution_retention` : une purge sans trace d'exécution est considérée comme non
   exécutée.
4. Le chiffrement applicatif des colonnes `bytea` (notes de dossier, détail de dossier, messages)
   relève du code, pas de la base : la clé ne doit jamais être accessible au moteur.

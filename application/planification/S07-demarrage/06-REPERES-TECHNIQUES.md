# Repères techniques — lectures ciblées

Chemins relatifs à la racine Cockpit ; vérifier l’état avant exécution.

## Sources autorisées / protégées

Travail : application/. Lecture seule : sources/, planification/S00/, prototype-local/ et prototype-evolution/. Empreintes : prototype-evolution/organisation-droits-partage/empreintes-reference.json. Ne pas modifier un fichier généré à la place de son générateur. Ne pas réinitialiser le workspace ; des changements existants peuvent être non versionnés.

## Entrées à inspecter

- frontend/modules/messaging/module.js : routes et contrat du module.
- frontend/modules/messaging/{actions,presenters,menu,contact-links,convocation-history}.js : actions/vues et raccordement Agenda.
- frontend/modules/messaging.html, messaging-group.html, messaging-forward.html : sources des vues existantes ; vérifier leur génération.
- frontend/modules/messaging-group/module.js et messaging-forward/module.js.
- frontend/services/auth-s01.js : session et changement d’identité.
- frontend/modules/cases/ : API de classement et services Dossiers.
- documentation/CONTRATS-S05.md : lire aussi les ajouts finaux, pas seulement les limites du premier lot.
- docs/S06-CONTRATS.md : publications, travaux durables et extensions.
- supabase/migrations/202610280069_convocation_history.sql, 202610280071_convocation_archives.sql, 202610290105_case_disposal_messages.sql : références existantes, pas modèles à copier aveuglément.
- uniion/adapters/convocation_archive.py ; rechercher les routes actuelles avec rg.
- tests/test_convocation_archive.py et test_convocation_attachments.py : régressions Agenda/pièces.

## Bilans de référence

preuves/S01-worker-source/BILAN.html ; S02-corrections-finales/BILAN.html ; S03-archives/BILAN.html ; S04-cloture/BILAN.html ; S05-cloture/BILAN.md ; S06-cloture-finale/BILAN.md.

Roadmap : planification/roadmap-sprints.json, section S07. Ses statuts initiaux ne sont pas le registre d’exécution actuel. Décisions : planification/S00/decisions.json et détails concernés.

## Commandes existantes

Depuis application/ :
```sh
/Users/mt/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -B -m unittest discover -s tests -p 'test_*.py'
/Users/mt/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -B scripts/check_boundaries.py
```
Depuis application/frontend/ :
```sh
/Users/mt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node build.mjs
/Users/mt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --test state/*.test.mjs host/*.test.mjs
```
Ces commandes ne remplacent pas les intégrations S07 à écrire. Ne pas exécuter toutes les recettes historiques à chaque petite modification.

Dernière pile utilisée : application HTTP 127.0.0.1:5068, entrée /s02?organization=<UUID fictif>&screen=messagerie ; Supabase local 127.0.0.1:54321, conteneur DB supabase_db_unii. Ce sont des repères historiques, vérifier disponibilité/configuration sans afficher les secrets. Ne pas démarrer une seconde instance sur un port occupé ni arrêter les services existants sans nécessité. Le chemin et les identifiants ne confèrent aucun accès.

Utiliser les outils navigateur autorisés pour l’UI. Les scripts backend sont pour les tests API/base ; ne pas leur faire piloter le navigateur en contournant les outils prévus.

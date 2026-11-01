# Vérification du package GitHub

1er novembre 2026. Contrôles exécutés sur la copie isolée destinée au dépôt, sans les états `.local-*` ni dépendances copiées de la machine de développement.

- Installation frontend depuis le lockfile avec le cache npm local : réussie.
- Compilation frontend : réussie.
- Tests Python 3.12 : 287 réussis.
- Tests frontend avec Node 24.22.1 local : 274 réussis.
- Contrôle des frontières et 14 migrations de référence : réussi.
- CI proposée : Python 3.12 / Node 22, installation des dépendances, compilation avant tests Python, tests frontend. Le workflow n’a pas été exécuté sur GitHub ; validation distante à effectuer après import.

La première exécution des tests sur la copie sans compilation a révélé que le test de la page servie exige le frontend construit. L’ordre du README et de la CI a été corrigé puis les tests Python rejoués avec succès. Les tests frontend initiaux sans dépendances ont été rejoués après `npm ci`.

Les produits du build, dépendances installées et logs de contrôle restent hors archive. Les sources, exemples de configuration et licences tierces sont conservés. Contrôle des secrets connus et motifs de clés/JWT effectué ; pas de garantie exhaustive de détection. Aucun secret, compte local ou sauvegarde n’est volontairement inclus.

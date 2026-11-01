# uniion

Dépôt préparé pour revue de code sur GitHub — snapshot du 1er novembre 2026.

**État : S09 A à E réalisés en recette locale fictive ; lot F et qualification de production S16 ouverts.** Aucun déploiement de production effectué.

## Lire d’abord

- [Ordre de revue](docs/REVUE-DE-CODE.md)
- [Bilan courant S09 E](application/preuves/S09-E/BILAN.md)
- [Reste à faire](application/preuves/S09-E/RESTE-A-FAIRE.md)
- [Handover S09](application/planification/S09-demarrage/HANDOVER-S09.md)
- [Périmètre et exclusions](docs/PERIMETRE-DU-DEPOT.md)

Le README historique dans `application/` décrit plusieurs états successifs ; ne pas le prendre pour une description uniforme de l’état courant. Les décisions validées sont dans `planification/S00/`. `sources/` et les prototypes sont des références, à préserver.

## Installation pour les contrôles de revue

Python 3.12 et Node 22 sont utilisés dans la configuration CI proposée. Depuis la racine :

```sh
python3 -m venv .venv
. .venv/bin/activate
python -c 'import tomllib,pathlib; p=tomllib.loads(pathlib.Path("application/pyproject.toml").read_text()); print("\n".join(p["project"]["dependencies"]))' > /tmp/uniion-review-requirements.txt
python -m pip install -r /tmp/uniion-review-requirements.txt
npm ci --prefix application/frontend
npm run build --prefix application/frontend
cd application
python -B -m unittest discover -s tests -p 'test_*.py'
python -B scripts/check_boundaries.py
node --test frontend/state/*.test.mjs frontend/host/*.test.mjs
```

Ces contrôles ne requièrent pas de secrets de production. La CI ne lance ni intégration Supabase, ni suppression, ni restauration, ni déploiement. Certains tests liés à des binaires optionnels peuvent être ignorés si ces outils sont absents ; lire les résultats.

L’exécution de l’application nécessite les services documentés, leurs migrations et des comptes fictifs propres à l’environnement. Les fichiers `.local-*` de la machine d’origine ne sont pas fournis. Lire les scripts d’intégration avant de les lancer : certains modifient des droits ou exécutent des opérations destructives sur leurs fixtures.

## Importer sur GitHub

Extraire le ZIP et placer **son contenu**, dont `.github/` et `.gitignore`, à la racine d’un dépôt vide. Publier les fichiers décompressés, pas le ZIP comme unique fichier. Aucun dépôt distant n’a été créé ni alimenté par cette préparation.

Pour une revue par pull request, conserver une branche cible minimale et pousser les sources sur une branche de revue, puis ouvrir la PR. Ne pas fabriquer de commits attribués à des tiers. Choisir le nom, la visibilité et les permissions du dépôt lors de sa création.

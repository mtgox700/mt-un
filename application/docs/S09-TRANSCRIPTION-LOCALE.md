# S09-C — exploitation de la transcription locale fictive

Le moteur est faster-whisper 1.2.1, modèle multilingual base, CPU int8, deux threads. Le modèle est identifié par révision et SHA-256 dans `preuves/S09-C/model-manifest.json`. PyAV est fixé à 16.0.1 : sa version 19 est incompatible avec l’appel de décodage employé par cette version de faster-whisper.

## Installation explicite

Depuis `application/`, avec Python 3.12 :

```sh
python3.12 -m venv .venv-transcription
.venv-transcription/bin/pip install -r operations/requirements-transcription.lock
.venv-transcription/bin/python operations/install_transcription_model.py
```

Seule cette préparation télécharge des bibliothèques et le modèle public. Le worker n’installe rien et le moteur utilise un répertoire local, `local_files_only=True`, les modes hors ligne et la vérification des empreintes. Aucun audio n’est transmis à un fournisseur.

## Services et identité de recette

Appliquer les migrations 171 puis 172 à la pile locale existante. Auth, PostgreSQL, Storage et ClamAV de B restent nécessaires. La recette `tests/s09_transcription_integration.py` crée, si nécessaire, une identité fictive dédiée, confirme uniquement son adresse locale et l’inscrit dans `uniion_private.transcription_workers`. Ses identifiants restent dans `.local-auth/transcription-worker.json`, fichier local ignoré par Git de mode 0600. Elle n’est membre d’aucune organisation et ne reçoit aucun rôle scanner ou service_role.

Après provisionnement de recette :

```sh
python3.12 -B operations/transcription_worker.py
```

`--once` traite au plus une tâche. Le processus doit fonctionner pour consommer la file ; aucun service système ni démarrage automatique n’est installé. Après arrêt, relancer la même commande : les tâches en attente sont prises et un bail interrompu est récupérable après six minutes. Les parties déjà persistées ne sont pas recalculées. Le moteur dispose de quatre minutes maximum par partie et de 200 ko de sortie. Une erreur requiert une relance explicite de l’utilisateur. L’annulation invalide immédiatement le bail ; le calcul CPU déjà engagé peut finir jusqu’à sa limite, mais sa réponse tardive ne peut plus être enregistrée.

Redémarrer le serveur applicatif avec la procédure locale habituelle pour charger les nouvelles commandes Python ; reconstruire le frontend avec `node build.mjs` depuis `frontend/`. La recette UI dédiée est `operations/s09_c_ui_server.py` (port 5070 par défaut). Le serveur utilisateur historique n’est pas arrêté par cette recette.

## Données et droits

Une tâche capture la liste ordonnée des sources de la prise choisie, leur empreinte, la version du consentement et de la réunion, leur durée et leur décalage absolu. Ajouter ensuite une partie crée un autre ensemble de sources, sans réécrire le premier résultat. L’idempotence est définie par organisation, réunion, demandeur et ensemble ordonné de sources.

Démarrer, annuler ou reprendre exige les droits d’écriture métier et audio ; consulter exige les droits audio actuels sur chaque source. Les résultats sont réservés au demandeur, sans export ou diffusion implicite. Le worker revérifie les droits du demandeur, le module, l’accès commercial, les versions et le consentement. Storage n’autorise que les sources non terminées d’un bail courant attribué à ce worker. Le retrait, l’annulation et l’expiration empêchent une réponse tardive de réussir.

La progression compte les segments audio serveur terminés ; ce n’est pas une estimation seconde par seconde. Les horodatages affichés ajoutent le décalage du segment à la position reconnue. Une entrée silencieuse peut donner une transcription vide ; aucune phrase de substitution n’est inventée. Les erreurs de reconnaissance doivent être relues. Le lot D traitera corrections, révision et raccordement au PV.

Conservation : aucune suppression introduite. Les trois tables privées nouvelles, leurs références et le modèle doivent rejoindre l’inventaire/restauration du lot E. La qualification matériel, longue durée, langues et précision restent à la recette globale F. Ce choix de recette n’est pas une validation de fournisseur ou de configuration de production S16.

Sources techniques : [faster-whisper](https://github.com/SYSTRAN/faster-whisper), [modèle public Systran](https://huggingface.co/Systran/faster-whisper-base).

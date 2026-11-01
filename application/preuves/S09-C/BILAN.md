# S09 — lot C, transcription locale réelle

31 octobre 2026. Lot C réalisé et vérifié dans le périmètre local fictif. S09 reste ouvert.

## Réalisé

- Moteur faster-whisper installé dans un environnement isolé, modèle base multilingue téléchargé explicitement et identifié par révision/empreintes. Inférence locale CPU, sans téléchargement automatique ni fournisseur de secours.
- Tâches PostgreSQL persistantes avec source, réunion, consentement/version, empreinte, séquence et chronologie ; progression par segment, erreurs, annulation, relance et idempotence.
- Worker distinct du scanner, sans appartenance métier et sans clé service_role. Bail de six minutes, reprise après interruption, résultat enregistré par segment et refus des réponses tardives.
- Transcription horodatée dans le panneau existant, commandes de lancement/annulation/reprise et relecture. Le raccordement au PV reste au lot D.
- Audits des commandes, tables privées non accessibles au client, contrôle Storage limité aux sources non terminées d’une tâche attribuée au worker. Vérifications du consentement, des habilitations, du module, du commercial et des versions lors du traitement ; lecture du texte soumise aux droits actuels sur toutes les sources.

## Vérifications observées

- 57 contrôles d’intégration S09-C réussis avec Auth/MFA, PostgreSQL, Storage, ClamAV et moteur réel locaux. La recette couvre parole française synthétique, idempotence, refus autre organisation/lecteur non habilité, compte ordinaire refusé comme worker, Storage hors tâche refusé, annulation, résultat tardif, entrée malformée, erreur/reprise, perte de bail/reprise avec checkpoint, deux parties et décalage absolu, révocation de droit, désactivation du module et retrait du consentement pendant une tâche.
- 56 contrôles A2 de non-régression audio réussis, preuves séparées.
- 287 tests Python et 256 tests frontend réussis ; build React et frontières des modules réussis.
- Parcours UI réellement actionné : lancement → annulation → relance → résultat réel. Captures desktop 1440 × 1000, tablette 768 × 1024, mobile 390 × 844 inspectées, sans débordement horizontal sur tablette/mobile. Composants et charte existants conservés.
- 2 808 fichiers d’anciennes preuves/références vérifiés contre le relevé de début C ; contrôle complémentaire des 3 856 références du relevé B final. Aucune modification constatée.

Les fichiers `integration.json`, `result-real.json`, `result-sequence.json`, les journaux de tests, `RECETTE-UI.md` et les captures constituent les preuves. Les sorties d’erreur initiales ont été diagnostiquées : Python système trop ancien pour les tests, PyAV 19 incompatible, voix macOS silencieuse dans le sandbox. Les exécutions finales utilisent Python 3.12, PyAV 16.0.1 et une véritable phrase synthétique produite localement.

## Limites explicites

Le texte est à relire : « vendredi » est reconnu, mais la proposition sur lundi comporte une erreur visible. Aucun score de précision, reconnaissance des locuteurs, traitement matériel de plusieurs heures ou qualification de production n’est revendiqué. Les tests longs et adverses de la chaîne complète restent à F.

La progression est par partie audio, pas seconde par seconde. Une annulation interdit immédiatement la persistance ; le calcul de la partie en cours peut continuer jusqu’au délai maximal de quatre minutes. Les résultats sont consultables par le demandeur habilité ; aucune diffusion ni export implicite.

Le quota existant a été rencontré en UI. Les commandes ont été optimisées pour exploiter leur réponse directement. Le bandeau de temporisation reste visible dans les captures ; l’amorçage de recette hérite temporairement des timestamps d’une horloge de test accélérée. La politique serveur de quota n’a pas été diminuée.

Le worker doit être lancé comme processus local distinct ; aucun démarrage système automatique n’est installé. Le serveur utilisateur historique n’a pas été redémarré. Voir `../../docs/S09-TRANSCRIPTION-LOCALE.md` pour le démarrage/rechargement local. La sauvegarde/restauration des nouvelles tables est à E ; aucun déploiement engagé.

## Suite

Lot D : transcription et marqueurs vers PV, corrections, relecture, validation par version et diffusion restreinte. Détails dans `RESTE-A-FAIRE.md`.

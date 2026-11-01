# S09 E — conservation et restauration locales

## Règle appliquée

D07 : la première relecture habilitée d’une version de PV, réalisée par un second acteur dans le circuit D, fixe la validation des audios de son ensemble de sources. Le délai est de 30 jours. Une nouvelle relecture ne repousse pas silencieusement l’échéance. Un audio sans validation reste conservé. Le lot ne crée pas une validation implicite à la fin d’une transcription automatique.

Le collecteur crée des demandes idempotentes par organisation/réunion. L’échéance et son dépassement sont visibles dans la carte existante de conservation. La commande de collecte est explicite dans la recette locale ; aucun ordonnanceur supplémentaire ni purge automatique n’est installé. Le traitement régulier de cette file relève de l’exploitation : appeler `collect`, puis examiner les demandes, sans jamais automatiser `approve`.

## Inventaire et approbation

Migrations 180–182. Tables privées avec RLS : validations, lots, items et tombstones (registre empêchant la réintroduction). Le lot contient les identifiants, empreintes, tailles, chemins Storage, nombres de blocs de transfert et d’originaux. Il indique aussi les transcriptions, PV et publications conservés. Il ne contient ni titre métier, ni nom de fichier, ni participants, ni texte de transcription.

Le super admin MFA consulte ces métadonnées sans droit métier supplémentaire. Il peut :

- conserver le lot jusqu’à une date future, avec motif ;
- approuver son inventaire exact, avec motif ;
- actualiser un inventaire devenu périmé, ce qui annule toute ancienne approbation.

Le lot actif ne couvre **que les octets audio serveur** : WAV Storage, blocs de transfert et blocs des originaux importés. Les consentements, séquences, marqueurs, transcriptions, provenance privée, versions de PV, copies diffusées/révoquées et journaux restent recensés et conservés sous leurs restrictions. Leur suppression n’est pas autorisée par l’approbation d’un lot audio. D07 ne fixe pas ici une destruction automatique des PV ou transcriptions. Le statut ne prétend pas que tous les audios d’une réunion sont supprimés si d’autres subsistent.

## Commandes d’exploitation locale

Depuis `application/`, avec le Python du projet. Le fichier de session doit contenir un jeton MFA courant, être privé (0600), ne pas être placé dans les preuves et ne pas être passé en argument sous forme de jeton. Aucun rôle ne peut s’attribuer lui-même la qualité de super admin par ces commandes.

```sh
python3 -B operations/audio_retention_admin.py collect --organization UUID --token-file /chemin/prive/session
python3 -B operations/audio_retention_admin.py list --organization UUID --token-file /chemin/prive/session
```

Exporter une ligne de `rows` dans un fichier d’inventaire local ; vérifier les identifiants et impacts. Puis choisir explicitement :

```sh
python3 -B operations/audio_retention_admin.py hold --organization UUID --token-file /chemin/prive/session --batch-file /chemin/inventaire.json --reason 'Motif de conservation' --until '2027-01-31T00:00:00Z'
python3 -B operations/audio_retention_admin.py approve --organization UUID --token-file /chemin/prive/session --batch-file /chemin/inventaire.json --reason 'Motif de suppression de ce lot audio'
```

L’exécution est une action distincte et explicite :

```sh
python3 -B operations/audio_retention.py UUID_DU_LOT
```

Elle utilise le compte scanner local existant, jamais une clé `service_role`. Ce compte ne peut pas approuver. Avant toute suppression, la base recontrôle le lot approuvé, son inventaire, l’approbateur actif et verrouille les audios. Elle inscrit les tombstones, bloque les accès et annule les tâches non terminées. Le Storage API efface les objets précis sous RLS ; la finalisation refuse tant qu’un objet existe encore. Les blocs audio et originaux sont ensuite effacés, puis le lot est déclaré terminé et audité. Une interruption laisse un lot `executing`, reprenable avec la même commande. Un approbateur révoqué bloque la poursuite.

Un ancien identifiant de requête ou les mêmes octets dans la même réunion ne peuvent pas recréer un audio supprimé. Les copies de PV approuvées restent indépendantes et révocables ; les dérivés privés deviennent illisibles quand leur source audio est supprimée.

## Copies locales et appareils indisponibles

Le coffre chiffré ne nettoie qu’un brouillon marqué entièrement sauvegardé dont **tous** les segments correspondent aux reçus serveur de cet utilisateur, dans cette organisation et cette réunion. Nettoyage sous verrou multi-onglets, transaction IndexedDB sur le manifeste et les parties. Une sauvegarde partielle, un reçu absent, une erreur réseau ou une autre identité empêchent le nettoyage. Aucun travail non synchronisé n’est effacé à échéance.

Les appareils hors ligne ne sont pas déclarés nettoyés à distance. Le nettoyage se produit lors de la prochaine ouverture du coffre connecté ; le serveur empêche la réinjection des octets supprimés. La durée locale et le verrouillage D08 restent applicables. Les fichiers déjà téléchargés hors du coffre de l’application ne peuvent pas être rappelés : ne pas promettre leur destruction.

## Sauvegardes et reprise

`backup_restore.py` couvre maintenant les WAV S09 en Storage, tous les blocs/originaux en base, les jobs, consentements, provenance, versions et publications, ainsi que les identités de traitement et super admins. Export MVCC cohérent ; archives base/fichiers chiffrées séparément et empreintes contrôlées. Les archives existantes restent conservées, avec cible de 30 jours ; une suppression serveur ne les détruit pas. Toute suppression d’archive exige son propre inventaire et accord, hors approbation d’un lot audio. Aucune purge d’ancienne sauvegarde n’a été exécutée dans E.

`audio_retention_restore.py` exporte un journal courant des suppressions et restrictions, séparé du snapshot ancien. La recette le chiffre avec une clé indépendante et vérifie son intégrité avant usage. La réconciliation :

1. refuse une cible autre qu’un conteneur `uniion-restore-*`, base `restored`, sans réseau ;
2. réapplique tombstones, blocages et suppressions approuvées aux fichiers et blocs restaurés ;
3. réapplique les retraits de consentement, révocations de copies et restrictions de droits ; elle retire conservativement les droits modifiés au lieu de les élargir ;
4. ne restaure pas de session active et n’admet pas le service en production ;
5. autorise uniquement la recette de reconnexion Auth/MFA dans le réseau isolé, puis arrête les conteneurs de recette.

Le mécanisme Storage de maintenance `storage.allow_delete_query` est employé **seulement dans cette cible isolée**, après suppression des fichiers physiques correspondant exactement aux tombstones. Le service courant utilise exclusivement le Storage API. Une erreur conserve la cible hors service ; rejouer la réconciliation, ne jamais l’ignorer.

Avant une vraie admission, figer les écritures ou établir une barrière de reprise, disposer du journal le plus récent, réconcilier également les autres modules et sauvegardes indépendantes, puis qualifier la cible. Les copies locales de l’assistant S08 restent soumises à sa revalidation des sources ; E n’efface pas son historique SQLite ni ne lui ouvre les sources supprimées. Ce test de reprise S09 n’est pas une admission de production générale.

## Preuves

`preuves/S09-E/` contient la recette d’intégration, les résultats SQL/fichiers de restauration, la recette UI et le bilan. Les mesures locales donnent l’âge réel du snapshot à la capture du journal et la durée jusqu’aux accès vérifiés. Elles ne garantissent pas un RPO d’une heure ou RTO de huit heures en production : cible et exploitation restent à qualifier en S16.

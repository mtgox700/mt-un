# S09 — lot B : raccordement audio navigateur

31 octobre 2026. **Lot partiellement livré ; S09 reste ouvert.** Données entièrement fictives, services locaux, aucun fournisseur externe ni déploiement. Méthode : skill uniion-developpement. Le lot A reste acquis.

## Réalisé

- Parcours existants Réunions/enregistrement/import/fiche raccordés au serveur, suppression des succès audio simulés. Réunions natives uniquement après authentification.
- Préparation de réunion, habilitations audio distinctes attribuées par un autre acteur autorisé, renouvellement/retrait de consentement, lecture contrôlée des prises et marqueurs serveur.
- Import conservé dans un brouillon AES-GCM IndexedDB, séparé par utilisateur et organisation. Original conservé ; conversion navigateur vers WAV PCM mono 16 kHz lorsqu’un décodeur est disponible. WAV PCM contrôlé côté serveur.
- Transfert de blocs de 256 Kio, état durable serveur, reprise des blocs manquants, identité de requête stable, contrôle SHA-256, analyse ClamAV et stockage privé avant confirmation. Migration 168 appliquée localement.
- Capture MediaRecorder réelle, pause/reprise, marqueurs, arrêt sur limite de 150 secondes ; aucun repli simulé. Une capture sans octets est signalée comme un échec.
- Conservation du dernier segment avant mise de côté, récupération explicite des brouillons, arrêt des lectures et invalidation des réponses tardives à la déconnexion/navigation. Brouillons non synchronisés jamais purgés automatiquement.

## Tests et preuves

| Exécution | Résultat | Portée |
| --- | --- | --- |
| Intégration réelle | 41 contrôles réussis | Auth/MFA, droits, consentement, 3 blocs, interruption/reprise, répétition/altération, autre acteur/organisation, Storage privé et ClamAV |
| Python | 287 tests réussis | Non-régression serveur |
| Frontend | 247 tests réussis | Dont 10 tests audio ; MediaRecorder remplacé par un double dans les tests unitaires, pas une preuve de capture navigateur |
| Build et frontières | Réussis | Sources générées par build.mjs |
| Intégrité | 3 836 fichiers inchangés | Sources, références/prototypes, S00 et preuves antérieures photographiées |

Voir integration.json, python-tests.log, frontend-tests.log, build.log, boundaries.log et integrite-apres.json.

## Recette navigateur et fidélité

Premier parcours réel sur instance isolée 5069 : import WAV fictif, conservation après erreur de quota, rechargement/reprise, sauvegarde serveur et action d’écoute sur la fiche autorisée observés. Les refus de quota ne sont pas comptés comme refus de permission. La deuxième tentative d’import sur 5070 après reconstruction n’a pas atteint de confirmation observable ; elle n’ajoute aucune preuve de réussite.

Capture sur 5070 avec un signal WebAudio synthétique injecté uniquement par le lanceur de recette : pause/reprise/arrêt utilisés, mais zéro octet MediaRecorder. Le diagnostic indépendant de l’application sur 5071 constate également « context running tracks 1 mime octets 0 stopped ». La capture réelle reste **non validée dans cet environnement**. Sources et capture du diagnostic conservées. Aucun microphone physique ni donnée réelle utilisé.

Les composants, couleurs, typographies et structure existants sont réutilisés, sans refonte. Les textes simulés sont remplacés par des états exacts ; contrôles de réunion/droits/reprise ajoutés dans les composants existants. La capture actuelle observée est de 663 × 804 px, sans débordement horizontal mesuré. Les demandes 360/390/768/1024/1440 px et faible hauteur ont toutes retourné 663 × 804 : les noms des captures `reunions-WxH.jpg` désignent les dimensions **demandées**, non obtenues. `ui/viewports.json` contient les dimensions réellement mesurées. La matrice responsive, le clavier et les appareils restent à qualifier ; aucune validation visuelle exhaustive n’est annoncée.

## Réserves techniques

- Limites actuelles : prise de 150 secondes, WAV serveur 5 Mio, import source 20 Mio. Ce profil de recette ne couvre pas une réunion longue. Conversion des autres codecs dépendante du navigateur, non qualifiée par une matrice réelle.
- Original MediaRecorder/import conservé chiffré localement ; seule la représentation WAV validée est stockée côté serveur. Pour un original non-WAV, ce n’est pas une sauvegarde serveur bit à bit de la source.
- La clé AES-GCM non extractible reste dans IndexedDB, même origine. Cela ne protège pas contre un script malveillant exécuté sur cette origine ou un appareil compromis. Reprise exige une session MFA en ligne ; aucun accès hors ligne autonome garanti. Politique D08 d’expiration configurable/24 h à raccorder.
- Droits revérifiés au serveur ; une lecture déjà chargée en mémoire est stoppée lors des changements de contexte et de la prochaine vérification (15 secondes), sans révocation instantanée des octets déjà reçus.
- Blocs de transfert conservés en base après assemblage, en plus du fichier Storage. Les inventaires de suppression/restauration du lot E devront couvrir les deux, et les originaux/brouillons locaux. Aucune suppression automatique.

## Suite

Voir RESTE-A-FAIRE.md. B n’est pas clôturé : qualification de capture et extension aux séances longues restent nécessaires. C–F restent ouverts. L’application existante sur 5068 n’a pas été arrêtée par la recette ; son processus doit être relancé pour charger les changements Python s’il utilisait une ancienne version.

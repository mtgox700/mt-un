# S09 — lot E, conservation et restauration

31 octobre 2026. Lot E réalisé dans le périmètre local fictif, sans refonte ni déploiement. S09 reste ouvert ; prochaine étape F.

## Réalisé

- Validation issue de la relecture distincte d’une version du PV et échéance audio à 30 jours. Les nouvelles relectures ne repoussent pas cette première date.
- Collecteur de demandes idempotentes, inventaire précis, conservation prolongée motivée, approbation MFA du super admin sur l’inventaire exact. Aucun accès métier accordé à ce rôle.
- Exécution distincte via le scanner local, sous RLS : blocage et tombstones, suppression réelle des objets Storage et des blocs audio/originaux, confirmation, audit, reprise et idempotence. Les octets approuvés ont réellement été effacés dans une nouvelle organisation fictive de cette recette.
- Anciennes requêtes, anciens octets et rescan ne peuvent pas ressusciter l’audio. Les transcriptions/PV privés restent restreints ; une copie de PV déjà approuvée garde ses droits propres et sa révocation.
- Reçus serveur par acteur pour nettoyer uniquement les copies locales entièrement sauvegardées. Aucun brouillon non synchronisé ou partiellement sauvegardé n’est supprimé. Appareils hors ligne explicitement non confirmés.
- Carte de conservation existante raccordée, y compris après effacement. Les états en attente, prolongé, approuvé, en cours et terminé sont distincts. Un nouveau fichier hors lot empêche une affirmation de suppression de toute la réunion.
- Sauvegarde étendue aux WAV S09 et aux comptes techniques/administratifs nécessaires. Restauration isolée depuis un snapshot antérieur à la suppression, avec journal courant chiffré des suppressions et restrictions, avant reconnexion aux services isolés.

## Preuves observées

| Contrôle | Résultat |
| --- | --- |
| Intégration chaîne C/D/E et contrôles E | **99 contrôles réussis** |
| Snapshot restauré, schéma/droits/lignes/fichiers | **470 contrôles réussis** |
| Reconnexion et réconciliation E | **16 contrôles réussis** |
| Tests Python | **287 réussis** |
| Tests frontend, état et contrat hôte | **274 réussis** |
| Compilation et frontières | Réussies |
| Références et anciennes preuves | **3 684 fichiers inchangés** |

L’intégration vérifie : refus avant échéance/approbation, rôle MFA, absence de lecture métier implicite, mauvais acteur/organisation/inventaire refusés, conservation prolongée, approbateur désactivé, reprise interrompue, refus de finalisation avant retrait Storage, absence physique du fichier, disparition des blocs et originaux préalablement présents, maintien puis révocation de copie publiée, reçus locaux propres à l’acteur et blocage de réinjection. La transcription utilisée est celle du moteur réel de C.

Les blocs d’original importé sont écrits par les RPC normales puis scannés. La fixture utilise un upload WAV direct et ajoute des blocs fictifs équivalents à ceux du transfert navigateur pour rendre leur contrôle d’effacement non vide ; ne pas confondre cette préparation avec un nouveau test de capture matérielle.

La dernière sauvegarde couvre 117 tables, 351 objets et 17 149 591 octets de fichiers. Archives chiffrées conservées hors du dossier public de preuves. Reprise base/fichiers : **31,893 s** ; chaîne jusqu’aux accès Auth/MFA vérifiés : **37,958 s**. Âge du snapshot lors de la capture du journal : **39,162 s**. Ces mesures concernent cette recette locale, pas une garantie RPO/RTO de production. Le snapshot de restauration inclut les migrations jusqu’à 181 ; la précision d’affichage 182 a été vérifiée sur la base courante et en UI.

Une première réconciliation a rencontré la protection de suppression directe Storage. Le traitement isolé a été corrigé, puis rejoué avec succès : suppression des fichiers physiques exacts et mécanisme de maintenance limité au conteneur isolé. Le service courant utilise toujours le Storage API. Les nouveaux résultats remplacent cette tentative, sans modifier de preuve historique.

## Interface et fidélité

Carte, couleurs, typographies, navigation et boutons existants conservés. Texte de conservation rendu exact ; carte maintenue après suppression, commandes d’écoute masquées lorsque le fichier n’est plus disponible. Desktop 1440 × 1000, tablette 768 × 1024 et mobile 390 × 844 inspectés. Débordement horizontal contrôlé aussi à 360 × 640 et 1024 × 768. Captures et `responsive.json` dans ce dossier. La recette UI vérifie la consultation du statut ; l’approbation et l’exécution ont été testées par HTTP/RPC et console, pas par des clics dans un nouvel écran administrateur.

## Limites et exploitation

- **Périmètre d’effacement : octets audio actifs seulement.** Transcriptions, consentements, marqueurs, provenance, PV et versions publiées/révoquées sont recensés, conservés et protégés. Une approbation audio n’autorise pas leur suppression ni celle des sauvegardes.
- Les archives restent chiffrées et conservées avec cible de 30 jours. Aucune ancienne archive supprimée. Un lot distinct et une approbation propres sont nécessaires avant suppression d’archives ; leur exploitation cible reste à S16. Le journal courant est obligatoire avant admission d’une ancienne restauration.
- Collecte, conservation prolongée, approbation et exécution disponibles dans la **console locale documentée**. Aucun nouvel ordonnanceur, écran administrateur ou déploiement automatique installé. La file doit être examinée régulièrement ; sans accord, conserver et signaler le dépassement.
- Nettoyage IndexedDB couvert par les règles et tests frontend ; pas de preuve de rappel à distance d’un appareil réellement hors ligne ni d’un fichier téléchargé hors application.
- La restauration conserve sa quarantaine. Elle vérifie la chaîne S09, pas une admission de production globale, ni l’effacement de l’historique SQLite de l’assistant S08. Celui-ci doit continuer à revalider ses sources.

Les conteneurs de restauration ont été arrêtés, leurs archives/volumes conservés. Le serveur UI temporaire 5073 et l’onglet de recette sont fermés ; le serveur utilisateur 5068 n’a pas été redémarré. Charger le nouveau serveur, appliquer les migrations 180–182 et compiler selon la procédure locale habituelle avant utilisation sur cette instance.

Contrat et commandes : `../../docs/S09-CONSERVATION-RESTAURATION.md`. Suite : `RESTE-A-FAIRE.md`.

# S09 — reste à faire après le lot A

31 octobre 2026. Le lot A couvre désormais les contrats et la persistance serveur : réunions, attestation, audio privé, habilitations, états de contrôle et marqueurs. Les travaux ci-dessous restent ouverts ; ils ne sont pas remplacés par les tests du lot A.

| Lot | Travail restant | Résultat attendu |
| --- | --- | --- |
| B — capture/import/lecture | Raccorder le consentement visible, les habilitations, la capture, l’import, les marqueurs et la lecture aux API serveur, sans changer le design ; gérer les formats réels MediaRecorder et imports, interruptions, transfert segmenté/reprise, quotas, états exacts et copies locales protégées | Parcours navigateur réel ; aucun faux enregistrement ni faux succès ; travail non synchronisé préservé |
| C — transcription | Identifier et qualifier un moteur réel de recette compatible avec les seules données fictives ; jobs persistants liés à organisation/réunion/prise, progression, annulation, idempotence, reprise après panne et recontrôle des droits/consentement | Transcription réelle durable, aucun substitut simulé présenté comme résultat |
| D — PV | Générer depuis transcription et notes autorisées, référencer leurs versions (dont marqueurs), corriger, relire, approuver et diffuser une version distincte avec les contrats S06/S08 | Chaîne audio → transcription → PV ; restrictions des sources et validation à deux acteurs respectées |
| E — conservation/restauration | Déclencher la demande D07 à échéance, conservation autorisée, validation super admin sur lot identifié, exécution et audit ; sauvegarder/restaurer tables et fichiers, réappliquer retraits et suppressions avant reprise | Pas de purge automatique ; restauration réellement prouvée pour les nouvelles données S09 |
| F — recette complète | Rejouer toute la chaîne, refus inter/intraorganisation, pannes et réponses tardives, formats et appareils disponibles ; UI 360/390/768/1024/1440 px, clavier et faible hauteur ; bilan et archive | Preuves de bout en bout et proposition de clôture S09, distincte de l’acceptation produit |

## Limites à traiter explicitement

- A accepte actuellement des WAV PCM de 5 Mio maximum, 20 prises par réunion ; le rejeu d’un dépôt complet est disponible, pas l’upload segmenté d’une longue séance.
- Les écrans actuels restent sur leurs parcours précédents tant que B n’est pas raccordé. Les tests du lot A sont des contrôles serveur, pas des clics navigateur ni des essais micro physiques.
- Le consentement est une attestation opérateur liée aux participants déclarés ; aucune signature individuelle n’est prétendue. Retrait/renouvellement ne réactive pas les anciennes prises. Le parcours visible de B doit rendre ces états compréhensibles et conserver les originaux en attente.
- Les anciens audios A2 sans durée doivent repasser par le même dépôt vérifié avant utilisation des marqueurs. Aucun recalcul à partir d’une durée fournie par le client.
- ClamAV et la validation de conteneur ne constituent pas une garantie de détection universelle. La limite EICAR encapsulé constatée en A2 reste documentée dans son bilan.
- Les objectifs RPO/RTO et la restauration des données S09 ne sont pas certifiés par une simple relecture après redémarrage.
- Production, fournisseurs cibles et usage de données réelles restent reportés à S16. Les travaux locaux fictifs B–F peuvent avancer sans rouvrir ces arbitrages prématurément.

Prochaine étape : **lot B**, en commençant par le parcours import fictif → consentement/habilitation → sauvegarde serveur → relecture, puis capture et reprise.

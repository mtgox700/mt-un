# A2 — acceptation serveur

Données fictives, sans modification frontend. Réutiliser Storage privé, identité de scanner restreinte et ClamAV local. Premiers fichiers : WAV PCM synthétiques, 5 Mio maximum. Les conteneurs MediaRecorder et transferts segmentés seront raccordés dans B ; aucun codec non vérifié admis.

Vérifier : upload réel et hash après nouvelle lecture/redémarrage ; idempotence et collision ; refus sans droits audio malgré lecture de réunion ; écoute distincte du téléchargement ; gestion des habilitations sans auto-attribution ; consentement/version liés à la prise et retrait immédiat aux prochaines requêtes ; contrôle réel format/antivirus et quarantaine ; refus autre organisation, ACL/module/appartenance révoqués, accès Storage direct et falsification du verdict scanner ; aucune purge.

L’attestation et les participants de la version de réunion sont figés avec la prise. Il s’agit d’une déclaration opérateur, pas de preuves individuelles. Tout renouvellement d’attestation ou changement de réunion impose une nouvelle prise pour cette première version ; aucune réactivation silencieuse d’un ancien audio.

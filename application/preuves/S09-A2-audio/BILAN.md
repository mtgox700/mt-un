# S09 — A2 : stockage audio serveur, droits et consentement

31 octobre 2026. **A2 serveur livré pour le profil WAV PCM local ; S09 reste ouvert.** Skill uniion-developpement appliqué. Données fictives exclusivement, aucun changement du design ni fournisseur externe.

## Réalisé

Migrations 165–166 installées dans PostgreSQL local. Coffre Storage privé réutilisé pour des objets audio immuables ; validation structurelle WAV, empreinte SHA-256, analyse ClamAV réelle et reçu après revalidation. Les métadonnées persistantes distinguent attente, fichier contrôlé et blocage. Reprise idempotente d’un dépôt interrompu par rejeu du même UUID/contenu, sans écrasement.

Habilitations audio par réunion distinctes des droits métier génériques : lecture, écriture et téléchargement. Attribution versionnée et auditée par un gestionnaire habilité, sans auto-attribution. Lire une réunion ou gérer ses droits ne donne pas accès à son audio.

Chaque prise est liée aux versions de réunion et consentement, avec acteur/date de l’attestation et copie des participants déclarés. Retrait ou décalage de version bloque la restitution ; renouveler une attestation ne réactive pas implicitement les anciennes prises. Aucun fichier supprimé.

## Vérifications exécutées

- **56 contrôles d’intégration** : Auth/MFA, Storage réel, ClamAV, relecture exacte, hash au téléchargement, rejeu idempotent, collision de demande, redémarrage application/session, snapshots de consentement ; refus sans droit audio, téléchargement distinct, auto-attribution, anciennes versions, autre organisation, accès Storage direct et faux verdict scanner ; révocation audio, module désactivé, membre suspendu, ACL réunion retirée ; quarantaine, reprise après indisponibilité et retrait pendant le scan. Résultat : `integration.json`.
- **285 tests Python réussis**, dont sept nouveaux tests de validation audio et de frontière serveur : `python-tests.log`.
- Frontières des modules et migrations de référence : OK, `boundaries.log`.
- **6 437 fichiers protégés, preuves historiques et fichiers frontend inchangés** : `integrite-apres.json`.

Le témoin principal est un WAV de silence généré en mémoire, sans voix réelle. ClamAV a réellement analysé les WAV autorisés. La détection du témoin antivirus inoffensif EICAR brut a été testée séparément ; le refus d’un audio sur verdict infecté utilise une injection explicite de ce verdict. L’EICAR encapsulé dans du PCM n’a pas été détecté par ce moteur : aucune détection universelle des contenus incorporés n’est prétendue. L’indisponibilité scanner et le retrait pendant analyse sont également des injections contrôlées ; le stockage et les vérifications d’accès restent réels.

Le premier dépôt a révélé l’absence du MIME WAV dans la liste du coffre ; migration 166 corrective, puis recette complète rejouée. Les fixtures des tentatives restent locales ; aucune ancienne preuve réécrite ni nettoyage destructif.

## Limites et fidélité

Aucun frontend modifié. Cette livraison ne prétend pas que les commandes actuelles de capture/import/lecture du navigateur utilisent déjà ce contrat : raccordement prévu en B, avec recette UI dédiée. Aucun test micro ou appareil physique effectué dans A2.

Profil accepté : WAV PCM, 5 Mio maximum, 20 prises par réunion ; autres conteneurs et transfert segmenté à B. Le consentement est une attestation opérateur, pas une preuve individuelle de chaque participant. L’écoute livre nécessairement des octets au navigateur ; le droit distinct de téléchargement n’est pas un mécanisme anticopie.

La reprise après redémarrage est testée ; une restauration depuis sauvegarde des nouvelles tables et objets ne l’est pas encore et reste à E. Aucun effacement automatique, transcription, génération depuis audio ou usage réel. Les choix de production restent à S16.

## Suite

B : raccorder les parcours existants sans changer leur design, traiter les formats réels de MediaRecorder, interruptions, transferts reprenables et consentement visible. C : jobs et moteur réel de transcription. D–F : PV, conservation/restauration et recette complète.

Contrat détaillé : `../../docs/S09-CONTRATS.md`. Code : `uniion/adapters/meeting_audio.py`, migrations 165–166, tests `test_meeting_audio.py` et `s09_audio_integration.py`.

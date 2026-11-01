# S09 — plan d’exécution local

31 octobre 2026. Sprint ouvert, données fictives exclusivement ; production et fournisseurs cibles à S16. Checkout courant sans dépôt Git à la racine. Références protégées photographiées dans `preuves/S09-demarrage/integrite-avant.json`.

## Premier lot A1

Persister l’attestation de consentement de l’opérateur sur une réunion native existante : lecture autorisée, déclaration versionnée, retrait et journal. Conserver séparément la version de réunion attestée ; une modification de réunion rend l’attestation à renouveler. Ne pas présenter cette déclaration comme une preuve individuelle de chaque participant. Aucun droit audio ni autorisation de transfert n’en découle.

Acceptation : session/MFA et module actifs ; ACL de réunion ; écriture réservée à un rédacteur habilité ; refus autre organisation, lecteur seul, révocation, version périmée et champs injectés ; relecture réelle via une nouvelle requête ; table privée inaccessible directement ; audit sans contenu.

## Suite du lot A et du sprint

- A2 : objets audio, droits distincts `audio.read`, consentement lié à chaque prise, marqueurs versionnés et stockage privé avec contrôle de fichiers. Une lecture du PV ou une invitation agenda n’autorise pas l’écoute.
- B : capture/import/lecture serveur, reprise d’envoi, erreurs réelles, chiffrement et distinction des copies locales. Supprimer les simulations du parcours migré.
- C : jobs durables et moteur réel de transcription de recette ; aucun fournisseur externe implicitement autorisé.
- D : transcription → projet de PV → corrections → validation de version → diffusion via les contrats S06/S08, restrictions D12.
- E : échéance à 30 jours après validation, demande de suppression, validation super admin sur inventaire précis ; restauration avec réapplication des retraits. Aucune purge automatique.
- F : chaîne complète, erreurs et reprise, tests adverses, formats et appareils disponibles ; UI 360/390/768/1024/1440 px, clavier et faible hauteur ; bilan et transmission.

A1 est une tranche serveur préparatoire ; sa réussite ne clôt ni A ni S09. Aucune modification UI n’est prévue dans A1. Capacité et calendrier restent à recalibrer après la recette capture et le choix technique local de transcription.

## Avancement A2 — 31 octobre 2026

Stockage serveur privé, droits audio distincts, prises liées aux versions de consentement/réunion et contrôles de quarantaine livrés pour WAV PCM ≤ 5 Mio. 56 contrôles d’intégration et 285 tests Python réussis ; voir `../../preuves/S09-A2-audio/BILAN.md`. Capture/import/lecture UI, formats MediaRecorder, marqueurs liés aux fichiers et transferts segmentés restent à B. Aucun changement de design. La restauration des nouvelles données reste à E.

## Clôture technique A — 31 octobre 2026

Le reliquat des marqueurs liés aux prises est désormais livré côté serveur (migration 167), avec durée attestée, versions conservées et contrôles de concurrence. Il n’est plus reporté à B ; seul son raccordement UI y reste. A1/A2/marqueurs : 150 contrôles d’intégration actuels et 287 tests Python réussis. Lot A terminé dans son périmètre de contrats/persistance fictifs. B–F restent ouverts ; voir `../../preuves/S09-A-final/RESTE-A-FAIRE.md`.

## Avancement B — 31 octobre 2026

Parcours audio navigateur raccordés, brouillons chiffrés, transfert reprenable par blocs et lecture serveur ; migration 168. 41 contrôles d’intégration, 287 tests Python et 247 tests frontend réussis. **B partiel** : MediaRecorder produit zéro octet dans le navigateur disponible, y compris dans un diagnostic indépendant ; profil limité à 150 secondes/5 Mio, originaux non-WAV encore locaux, D08 et matrice appareils/responsive à compléter. Voir `../../preuves/S09-B/BILAN.md` et `../../preuves/S09-B/RESTE-A-FAIRE.md`. Aucun report de ces exigences hors de B ni clôture implicite. C–F restent ouverts.

## Finalisation locale B — 31 octobre 2026

Capture PCM indépendante de MediaRecorder, segments reprenables et chronologie serveur, originaux importés privés/contrôlés, droits et consentements, durée locale configurable et verrou inter-onglets livrés (migrations 169–170). WAV/AIFF PCM16 et matrice responsive du navigateur disponible vérifiés. 101 contrôles B, 56 contrôles de non-régression A2, 287 tests Python et 257 tests frontend réussis. **B finalisé techniquement en recette locale fictive** ; aucune promesse d’endurance sur micro physique : les suspensions du moteur audio du navigateur sont documentées et gérées explicitement. Les huit heures sont vérifiées par traitement accéléré de trames, pas par huit heures d’UI réelle.

Référence actuelle : `../../preuves/S09-B-final/BILAN.md` ; suite : `../../preuves/S09-B-final/RESTE-A-FAIRE.md`. Prochain lot C : moteur de transcription local et jobs durables. S09 reste ouvert jusqu’à C–F.


## 31 octobre 2026 — lot C local réalisé

Transcription réelle faster-whisper/base hors ligne, tâches durables et checkpoints par segment, worker dédié à accès Storage limité, annulation/reprise/idempotence et texte horodaté dans le panneau existant. Migrations 171–172. 57 contrôles C et 56 contrôles audio A2, 287 tests Python, 256 tests frontend ; build/frontières réussis. Recette UI desktop/tablette/mobile réalisée.

Référence : `../../preuves/S09-C/BILAN.md` ; reste : `../../preuves/S09-C/RESTE-A-FAIRE.md` ; démarrage moteur : `../../docs/S09-TRANSCRIPTION-LOCALE.md`. Aucun fournisseur de production, suppression ni changement de charte. La transcription peut comporter des erreurs et doit être relue ; PV encore fondé sur les notes. Prochain lot **D**, puis E/F et préparation S16. S09 reste ouvert.


## 31 octobre 2026 — lot D local réalisé

PV distinct alimenté par transcription et marqueurs, provenance et restrictions cumulatives, corrections versionnées, relecture par second acteur et publication S08 d’une copie limitée au titre/texte. Révocation disponible après retrait du consentement ; aucun partage direct du brouillon. Migrations 173–179.

86 contrôles de chaîne D et 57 de non-régression C, 287 tests Python, 266 tests frontend ; build et frontières réussis. Parcours UI à deux comptes, retrait et révocation, desktop/tablette/mobile vérifiés. L’assemblage n’est pas une synthèse IA simulée ; le contexte de l’assistant existant reste soumis à S08.

Bilan : `../../preuves/S09-D/BILAN.md` ; contrat : `../../docs/S09-PV-DERIVES.md` ; reste : `../../preuves/S09-D/RESTE-A-FAIRE.md`. Prochain lot **E**, puis F et préparation S16. S09 reste ouvert.


## 31 octobre 2026 — lot E local réalisé

Conservation audio à 30 jours après relecture du PV, demande/inventaire, prolongation motivée, approbation super admin MFA et exécution distincte reprenable. Effacement réel WAV/blocs/originaux sur données fictives, tombstones contre réinjection ; copies de PV distinctes conservées/révocables. Reçus pour nettoyage des seules copies locales entièrement sauvegardées. Migrations 180–182. Console d’exploitation documentée, carte existante raccordée, aucun nouveau design ni ordonnanceur.

99 contrôles de chaîne C/D/E, 470 contrôles de snapshot restauré et 16 contrôles complémentaires de réconciliation/reconnexion ; 287 tests Python et 274 frontend, build/frontières réussis. Reprise locale vérifiée en 37,958 s ; âge du snapshot 39,162 s, sans garantie de production. Anciennes sauvegardes conservées ; journal courant obligatoire avant admission d’une restauration.

Bilan : `../../preuves/S09-E/BILAN.md` ; contrat/commandes : `../../docs/S09-CONSERVATION-RESTAURATION.md` ; reste : `../../preuves/S09-E/RESTE-A-FAIRE.md`. Prochain lot **F**, puis qualification S16. Appareils physiques, endurance et acceptation produit restent à F ; aucune clôture globale S09 ni production annoncée.

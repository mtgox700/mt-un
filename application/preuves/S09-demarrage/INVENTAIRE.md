# État observé au démarrage S09

31 octobre 2026 ; inspection des sources, sans capturer de voix.

| Fonction | Classe | Constat |
| --- | --- | --- |
| Réunions natives | Réelle serveur | `business_records` : création, lecture, sauvegarde et ACL PostgreSQL |
| Projet de PV S08 | Réel depuis notes/marqueurs | Génération persistée et publication à deux acteurs ; audio non analysé |
| Consentement capture | Local seulement | Cases `rec.c1/c2` dans le contrôleur ; aucun registre durable dédié |
| Capture micro | Locale seulement | MediaRecorder, chunks en mémoire puis IndexedDB ; aucun upload |
| Micro indisponible/refusé | Simulé explicitement | `startSimulated` anime compteur et niveau ; sauvegarde simulée refusée |
| Import | Local seulement | Contrôle extension/MIME déclaré ; pas de validation réelle du conteneur serveur |
| Lecture | Locale seulement | Blob IndexedDB et URL temporaire ; journal local non probant |
| Marqueurs | Mixte | Pendant capture : état local ; notes de réunion native : sauvegarde générique S08 |
| Transcription | Absente | Libellé « non connectée » ; aucun job audio serveur |
| Conservation audio | Non exécutée | Compteur local 30, références de démonstration ; pas de demande D07 liée à un fichier serveur |

Points à corriger lors du raccordement B : ne pas transformer le refus micro en enregistrement apparent ; ne pas afficher import terminé avant sauvegarde serveur ; préserver les données locales non synchronisées. Les anciennes mentions de destruction et de durée du prototype ne constituent pas une politique exécutée.

Dépendances lues : clôture/réserves/contrats S08, bilan E et recette UI F ; clôture technique S06 ; D07/D08/D09/D12/D13 et matrice audio.read S00. La recette des exports S06 n’a pas été rejouée pour ce lot sans export.

# S09 — finalisation du lot B

31 octobre 2026. **Lot B finalisé techniquement pour la recette locale, données fictives exclusivement. S09 reste ouvert (C–F).** Ce bilan complète celui de S09-B sans le réécrire. Aucune validation de production ni acceptation produit implicite.

## Réalisé et réserves levées

| Réserve précédente | Réalisation et preuve |
| --- | --- |
| MediaRecorder ne produit aucun octet | Capture mono PCM 16 kHz via AudioWorklet à partir du vrai MediaStream. Recette avec oscillateur fictif 440 Hz ; enregistrement serveur de 151,034 s, deux segments, écoute après rechargement. Empreintes, amplitudes et fréquences vérifiées sur les WAV relus de Storage (`capture-server.json`). Aucune simulation de succès. |
| Prises limitées à 150 s | Capture bornée à huit heures, blocs locaux d’une seconde et segments serveur de deux minutes. Tampon du processeur constant. Découpage des blocs partiels sans perte ni duplication, chronologie attestée en base et marqueurs relatifs au bon segment. Test accéléré de huit heures de trames et test de franchissement de frontière après bloc partiel ; ce ne sont pas huit heures sur appareil réel. |
| Originaux non-WAV seulement locaux | Original importé transmis par blocs, conservé à l’identique en base privée, hash vérifié et ClamAV obligatoire avant libération du WAV dérivé. Téléchargement distinct, contrôlé, en binaire non inline. Quarantaine et verdict infecté bloquent aussi l’écoute du dérivé, y compris via RPC directe. |
| Formats non qualifiés | WAV PCM strict et AIFF PCM16 mono/stéréo décodés localement sans codec système ; WAV/AIFF réels vérifiés dans le navigateur (`ui/formats.json`). Les autres formats dépendent du navigateur et sont refusés explicitement s’ils ne sont pas décodables. |
| Reprise locale, durée et concurrence | Brouillons et blocs AES-GCM par utilisateur/organisation. Bloc et manifeste de reprise écrits atomiquement dans IndexedDB. Accès de 24 h par défaut, réglable de 1 à 168 h par l’autorité `organization_edit`, renouvelé après session MFA en ligne. Verrou Web Locks entre onglets, reprise des brouillons mis de côté. Aucun effacement automatique. |
| Quota et interruptions | Quota HTTP conservé, attente/reprise explicite ; les lectures Réunions ne vident plus la fiche immédiatement sur 429. Erreur de stockage : arrêt de capture, derniers blocs conservés en mémoire pour réessai, aucune confirmation serveur prématurée. Un arrêt du flux audio est signalé et les blocs déjà reçus sont conservés. |
| Responsive non mesuré | Dimensions effectivement obtenues : 360×800, 390×844, 768×1024, 1024×768, 1440×1000, plus 768×400. Aucun débordement horizontal mesuré sur fiche et consentement. Espace/Tab vérifiés sur les confirmations ; action accessible à faible hauteur. |

## Contrats et accès

Migrations 169 et 170 appliquées à Supabase local. Les séquences sont immuables, ordonnées et rattachées au même acteur, à la même organisation/réunion et aux mêmes versions de consentement. Les offsets sont calculés à partir des durées serveur, jamais acceptés du client. Plafonds : 240 segments par capture, 480 fichiers audio par réunion, 5 Mio par WAV, 20 Mio par original importé.

Les droits audio ne découlent ni de la lecture du PV ni de l’administration générale. Les contrôles de A restent actifs. Capture et fiche sont revérifiées périodiquement (30 s), chaque lecture/transfert est autorisé par le serveur ; pause/reprise revalide le consentement. Une copie déjà reçue ne peut pas être reprise à distance instantanément.

La clé locale non extractible réside dans IndexedDB : ce chiffrement ne protège pas contre un script malveillant exécuté dans la même origine ou un appareil compromis. La reprise nécessite une session MFA en ligne. Les écritures d’une capture en cours restent possibles pour préserver les octets ; l’expiration verrouille les lectures et demande un renouvellement. Si le stockage refuse une écriture, ne pas fermer l’onglet avant réessai : les derniers octets sont alors uniquement en mémoire et ce risque est affiché.

## Vérifications

- Intégration B finale : 101 contrôles réels Auth/MFA, PostgreSQL, Storage et ClamAV réussis (`integration.json`). Deux acteurs réauthentifiés après redémarrage du service de test.
- Non-régression A2 : 56 contrôles réussis, nouvelle sortie isolée (`A2-regression/integration.json`).
- Python : 287 tests réussis (`python-tests.log`).
- Frontend : 257 tests réussis (`frontend-tests.log`) ; tests du processeur, frontière de segment, marqueurs, chiffrement, expiration, reprise après quota de stockage, identité tardive et reprise de transfert.
- Build et contrôle de frontières réussis. 3 856 fichiers de références et anciennes preuves inchangés (`integrite-apres.json`).
- Parcours navigateur et captures : `RECETTE-UI.md`, `ui/`. Les doubles de capture des tests unitaires sont séparés de la preuve navigateur/Storage.

## Fidélité et portée

Aucune refonte ni changement du thème : structure, typographies, couleurs, composants et navigation existants conservés. Ajouts fonctionnels dans les composants existants : durée locale, sélection des segments, téléchargement autorisé ; libellés réels d’erreur/progression/écoute. Les textes ne prétendent pas qu’une transcription ou un PV issu de l’audio existent déjà.

Recette uniquement sur navigateur disponible et signaux fictifs. Le navigateur peut suspendre son moteur audio ; l’application le signale et conserve ce qu’elle a reçu. Capture en premier plan, espace disque disponible et navigateur compatible AudioWorklet/Web Locks requis. Les appareils physiques, la veille système prolongée et les codecs supplémentaires restent à la qualification globale F, explicitement listée dans RESTE-A-FAIRE.md.

Les originaux importés sont stockés en base privée ; les WAV validés sont dans Storage, et les blocs de transfert restent en base. Le lot E doit inventorier toutes ces copies. Aucun fichier de référence, ancienne preuve ou original non synchronisé n’a été purgé.

Les serveurs de recette isolés (5070/5071) ont été arrêtés après vérification ; le processus utilisateur existant sur 5068 n’a pas été remplacé. Pour utiliser les nouveaux contrats sur un autre serveur déjà lancé, relancer ce processus avec le code courant et les migrations 169–170. Aucun fournisseur externe ni déploiement.

## Suite

Lot C : transcription locale et jobs durables. Puis D : PV/version/validation/diffusion ; E : conservation/restauration ; F : recette complète et clôture. Voir RESTE-A-FAIRE.md.

La reprise d’un brouillon après rechargement a également été observée sur la dernière écriture atomique. Le diagnostic indépendant conserve la preuve de l’horloge audio figée ; voir la recette UI.

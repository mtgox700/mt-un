# S09 — contrats locaux

31 octobre 2026. A1 réalisé : attestation de l’opérateur, sans capture ni transfert. Le registre ne constitue pas la preuve du consentement individuel des participants et n’accorde aucun accès audio.

`POST /identity/business`, session opaque, origine/CSRF et MFA du socle existant :

- `{organization_id, module:"reunions", action:"consent_get", payload:{id}}` : état de l’attestation ; `version:0`, `accepted:false`, `current:false` si absente.
- `consent_set` avec `{id, version, meetingVersion, accepted}` : déclaration ou retrait. Versions entières exactes requises. `accepted` est un booléen strict. Champs supplémentaires refusés. Aucun acteur ou horodatage imposable par le client.

RPC `uniion_meeting_consent` appelée avec le JWT utilisateur ; contrôles également applicables en appel direct. Organisation, module actif, droit commercial et ACL de réunion native revérifiés. Lecture réservée aux lecteurs de la réunion, écriture aux rédacteurs. Aucun passe-droit super admin. Verrou de réunion commun avec sa sauvegarde pour sérialiser les modifications ; version d’attestation propre contre les écritures concurrentes.

Réponse : `id`, `version`, `meetingVersion` courante, `attestedMeetingVersion`, `accepted`, `current`, `updatedAt`. `current` exige une déclaration positive sur la version courante de réunion. Une modification ultérieure invalide cette correspondance sans effacer l’attestation historique. Retrait explicite conservé comme version suivante. Un doublon avec ancienne version échoue ; le client peut relire l’état, pas rejouer aveuglément.

Migration 164 : table privée `meeting_consents`, clé composée organisation/réunion, FK composée vers la ressource, RLS active, aucun accès direct public/anon/authenticated. Journal `meeting.consent` : acteur serveur, identifiant, versions et booléen ; aucun texte métier. Les anciennes transitions restent dans le journal existant. Aucune suppression ni purge automatique ajoutée.

## Frontières encore ouvertes

Aucun raccordement UI A1 ; les cases actuelles de capture restent locales. A2 doit lier chaque prise audio et ses participants à une déclaration appropriée et imposer le droit audio distinct. Ne pas traiter `current` comme autorisation suffisante de capture, d’écoute ou d’envoi fournisseur. Stockage audio, analyse de format/antivirus, upload reprenable, jobs, transcription, marqueurs liés au fichier et conservation D07 restent à réaliser. La migration 164 n’ajoute aucun statut de fichier sauvegardé ou de transcription réussie.

Les exports/relectures/publications futurs réutiliseront les contrats S06/S08 après revalidation des sources. D07 : échéance → demande → validation super admin d’un lot identifié → exécution auditée ; la durée ne donne pas autorisation de destruction. Fournisseurs et exploitation de production restent à S16.

## A2 — stockage audio serveur et droits propres (31 octobre 2026)

Cette section complète A1. Migrations 165–166 : tables privées `meeting_audio` et `meeting_audio_grants`, RLS, accès direct retiré ; ajout ciblé de `audio/wav` au coffre `uniion-private`. Aucun octet dans la table de réunion ou dans la réponse de ses lectures génériques. Les objets Storage sont immuables et leurs chemins sont attribués en base. Aucune URL publique ou signée émise. L'identité restreinte de scanner existante transporte les octets ; aucune clé service_role ajoutée.

Le contrat `/identity/business`, `module:"reunions"`, accepte désormais :

| Action | Payload | Effet |
| --- | --- | --- |
| `audio_grant` | `id,user,version,read,write,download` | Habilitation audio par réunion, versionnée et auditée. Exige autorité `rights` et écriture sur la réunion ; auto-attribution interdite. Version initiale 0. Aucun droit implicite administrateur. |
| `audio_list` | `id` | Métadonnées et état des prises ; requiert lecture réunion + droit audio read + consentement courant. |
| `audio_upload` | `id,request_id,consentVersion,filename,content` | `content` en base64 ; préparation durable, stockage immuable, ClamAV réel, revalidation puis reçu id/status/hash/taille. Requiert écriture réunion + audio read/write. |
| `audio_listen` | `id,audio` | Restitution base64 des octets vérifiés, avec MIME/nom/id ; droit audio read. |
| `audio_download` | `id,audio` | Même contrôle, plus droit audio download distinct. |

Ces API sont serveur : aucun nouveau bouton ni raccordement du contrôleur de capture n’est livré dans A2. Le navigateur recevant un son pour l’écouter possède nécessairement ses octets ; le droit de téléchargement contrôle l’action dédiée, pas une protection DRM contre leur copie par un lecteur autorisé.

### Validation et persistance

Profil initial volontairement borné : WAV RIFF PCM, mono/stéréo, 8/16/24/32 bits, fréquences 8/16/22,05/24/44,1/48 kHz, 5 Mio maximum. Validation de taille RIFF, chunks fmt/data uniques, alignement, fréquence et débit cohérents ; autres chunks, codecs, métadonnées et conteneurs refusés. Le MIME client n’est jamais une preuve de format. WebM/Ogg/MP3 et les longues captures segmentées restent au lot B.

La clé organisation + acteur + UUID de demande est durable. Rejouer le même fichier et le même consentement retrouve le même objet ; changer son nom, hash, taille, réunion ou version de consentement avec la même clé est refusé. En cas d’échec après écriture Storage, le rejeu compare les octets existants puis reprend l’analyse. Le reçu `clean` n’est retourné qu’après sauvegarde, hash/taille vérifiés, analyse et nouvelle vérification des droits/consentement. Au plus 20 prises par réunion pour cette première version locale.

États : `pending`, `clean`, `blocked`. Une indisponibilité du scanner laisse le fichier pending ; aucun succès ni restitution. Un verdict bloquant est durable et ne peut pas être promu par un rejeu utilisateur. Seule l’identité scanner peut enregistrer un verdict. Les utilisateurs ne peuvent ni lire ni remplacer directement les objets Storage. La liste MIME du coffre ne donne aucun droit d’upload.

### Consentement et accès

Chaque prise fige version de réunion, version/acteur/date de l’attestation et participants déclarés dans cette version. Il s’agit toujours d’une attestation opérateur, pas de signatures individuelles. L’habilitation audio ne vaut pas consentement et le consentement ne donne pas de droit audio.

À chaque opération : session/MFA, module et accès commercial, appartenance, ACL de réunion, habilitation audio, attestation positive et version de réunion courante. La restitution d’une prise exige en plus l’égalité exacte avec sa version de consentement. Retirer puis renouveler le consentement ne réactive pas les anciennes prises ; leur réautorisation éventuelle nécessitera un circuit explicite ultérieur. Modifier la réunion invalide l’attestation A1.

Après transfert/scan, les contrôles sont rejoués avant réponse. Le retrait pendant un scan empêche d’annoncer un audio utilisable ; les octets conservés ne sont pas supprimés. Une révocation ne retire pas les octets déjà reçus par un lecteur. Préparations, habilitations, verdicts et restitutions sont audités sans contenu sonore.

### Portée et suite

A2 valide le stockage et les contrats serveur sur données synthétiques ; capture/import/lecture UI restent à B, transcription à C. Le chiffrement du cache navigateur, les uploads segmentés et le circuit de consentement visible n’ont pas été raccordés. Aucune donnée locale historique importée automatiquement. Aucune suppression ni purge : D07 reste demande puis validation explicite ; restauration coordonnée des nouvelles tables et objets à qualifier dans E. Production et choix de fournisseurs à S16.

## A final — marqueurs audio et clôture du socle serveur

31 octobre 2026. Cette section fixe l’état courant après A1/A2 : réunion native, attestation, prises serveur, habilitations audio, états de quarantaine et marqueurs versionnés disponibles. Les sections antérieures décrivent leurs étapes de livraison. Le branchement des écrans reste à B.

Migration 167 : `meeting_audio.duration_ms` attestée par le traitement serveur et `meeting_audio_markers`, table privée RLS sans accès direct. Le serveur calcule la durée depuis les frames/fréquence du WAV validé, après vérification des octets durables. Valeur arrondie vers le bas à la milliseconde. Aucun champ de durée accepté depuis le navigateur. Seule l’identité scanner peut l’attester ; une durée déjà attestée ne peut être remplacée par une autre.

Une prise A2 ancienne sans durée reste lisible selon ses droits, mais les opérations de marqueurs sont refusées jusqu’au rejeu vérifié du même dépôt. Ce rejeu réutilise l’objet, contrôle ses octets et renseigne la durée ; aucun téléchargement ou transfert externe ajouté.

Actions `/identity/business`, `module:"reunions"` :

- `audio_markers_get` : `{id,audio}` → `{audio,version,durationMs,markers}` ; version 0 et liste vide en l’absence d’écriture.
- `audio_markers_save` : `{id,audio,version,markers}` ; remplace la liste courante par une nouvelle révision conservée, avec version attendue obligatoire.

Chaque marqueur est `{id,timeMs,kind,note}` : UUID unique dans la liste, temps entier entre 0 et la durée serveur, type de référence `vote`, `decision`, `engagement`, `desaccord`, `verifier`, `diverse` ou `point`, note textuelle de 1 000 caractères maximum (vide admis). Au plus 100 marqueurs. Champs supplémentaires, doublons UUID, temps négatifs/fractionnaires/hors durée et versions périmées refusés en base, y compris via RPC directe.

La lecture exige les mêmes conditions que l’écoute : appartenance/module/ACL, habilitation audio read, fichier clean, attestation et version de réunion courantes. La sauvegarde exige également l’écriture réunion et audio. Aucun droit de téléchargement requis pour les notes. Le verrou de réunion sérialise les révisions avec les changements de consentement : deux écritures sur une même version ne peuvent pas s’écraser silencieusement.

Les anciennes révisions sont conservées, y compris après une liste vide : aucun effacement physique. Une modification de marqueurs ne modifie pas la version de réunion ni son attestation. La future dérivation D doit référencer cette version de marqueurs propre pour invalider ses résultats lorsqu’elle change. Aucune copie automatique vers les notes génériques de réunion, le PV ou l’IA ; les restrictions audio restent effectives. L’audit contient audio/version et acteur, sans notes.

**Lot A techniquement clôturable dans ce périmètre serveur fictif.** UI, formats de capture et transferts segmentés à B ; jobs/transcription à C ; PV/relecture à D ; conservation et restauration à E ; recette complète à F. Aucune transcription ou capture navigateur migrée n’est annoncée par cette clôture.

## Lot B — contrats navigateur (migration 168)

`audio_setup` lit les capacités et versions courantes ; `audio_manage` applique un preset explicite à un membre par courriel, sans auto-attribution. Le serveur conserve les contrôles d’autorité/ACL/module/MFA et les droits audio distincts.

`audio_begin` prépare une prise idempotente ; `audio_part` transmet un bloc de 262144 octets (dernier bloc ajusté), `audio_progress` relit les indices reçus, `audio_complete` réassemble et repasse le validateur WAV/SHA/ClamAV/Storage du lot A. Seul l’auteur de la prise peut utiliser le transfert, avec droit d’écriture audio et consentement courant. Un bloc répété identique est accepté ; un remplacement différent est refusé. Limite 5 Mio/prise inchangée. La table privée `meeting_audio_chunks` n’est pas directement accessible au client et n’est pas purgée automatiquement.

Brouillons AES-GCM par utilisateur/organisation sur l’appareil ; originales sources conservées localement même après sauvegarde du WAV. Session MFA en ligne requise pour la reprise. Ce mécanisme ne vaut pas réalisation complète de D08 ni sauvegarde serveur bit à bit d’un original non-WAV. Capture 150 secondes maximum, sans simulation ; aucun octet => aucun succès annoncé. Voir le bilan S09-B pour les limites observées et le reste à faire.

## Finalisation locale B — migrations 169 et 170

La capture primaire utilise `AudioWorklet` et un `MediaStream` autorisé, sans encodeur MediaRecorder ni repli simulé. Mono PCM16 à 16 kHz ; blocs locaux d’une seconde, écriture atomique bloc/manifeste chiffrés, segments WAV de 120 secondes maximum. Un bloc chevauchant une frontière est réparti sans supprimer ni doubler d’échantillons. Plafond d’une capture : 8 heures/240 segments ; plafond serveur d’une réunion : 480 fichiers. Le quota de l’appareil peut interrompre plus tôt : arrêt explicite, réessai des blocs encore en mémoire et aucun succès anticipé.

`audio_sequence` lie `{audio, recording, position}`. La position zéro exige `recording = request_id` de la première prise ; les suivantes exigent le précédent, le même acteur et les mêmes organisation/réunion/consentement/version. L’offset est calculé en base avec la durée attestée. `audio_list` expose la séquence, l’offset, la durée et les capacités de téléchargement ; l’écoute enchaîne les segments de la même capture avec nouvelle autorisation serveur à chaque segment.

`audio_source_begin/part/progress/complete/download` préservent l’original importé (20 Mio maximum) en blocs privés. Le navigateur transmet cet original avant de terminer le premier WAV dérivé. SHA et ClamAV contrôlés ; original en attente ou bloqué => dérivé non consultable, même via appel RPC direct. Original téléchargé en `application/octet-stream`, jamais exécuté ni servi inline. Les prises PCM capturées sont elles-mêmes les originaux serveur. Les fichiers importés WAV PCM et AIFF PCM16 ont des décodeurs locaux ; les autres formats nécessitent un décodeur navigateur et sont refusés explicitement s’il manque.

`audio_policy` lit la durée locale, 24 h par défaut ; `audio_policy_set` la règle entre 1 et 168 h avec l’autorité `organization_edit` et audit. La reprise renouvelle cette durée après session MFA en ligne. Verrou Web Locks par utilisateur/organisation. Expiration/verrouillage ne suppriment rien. Clé AES-GCM non extractible conservée dans IndexedDB ; pas de garantie face à une compromission de l’origine ou du poste.

Les contrôles périodiques de capture/fiche ont un intervalle de 30 s, sans supprimer les contrôles de chaque commande serveur. Une interruption du flux arrête la capture et conserve les données reçues ; sa raison est conservée dans le brouillon. Sur 429, attente et reprise, sans modification du quota serveur. Aucun délai ne constitue une autorisation implicite.

Bilan et portée observée : `../preuves/S09-B-final/BILAN.md`. Transcription/PV issus de l’audio restent à C/D ; inventaires de toutes les copies et restauration restent à E ; endurance matérielle et clôture complète restent à F.


## C — transcription locale (migrations 171–172)

Commandes métier `transcription_start/status/cancel/retry` avec `{id,audio}`. Ensemble ordonné des sources d’une prise capturé dans un job idempotent par demandeur. Résultat privé par partie avec modèle/révision, segments relatifs et offset global ; état durable et compteur de progression. Compte worker distinct, stockage limité par bail courant, reprise après six minutes et limite moteur de quatre minutes par partie. Droits/consentement/version revérifiés, réponses tardives rejetées. Aucune écriture dans le champ métier consommé par le générateur de PV. Contrat détaillé et exploitation : `S09-TRANSCRIPTION-LOCALE.md` ; preuves : `../preuves/S09-C/BILAN.md`.


## D — PV dérivés (migrations 173–179)

`pv_prepare/status` prennent `{id,audio}` ; `pv_publications` prend `{id}` et fournit aux personnes autorisées un inventaire minimal de révocation. Le PV est une ressource réunion distincte, identifiée `meetingPV` dans la projection privée, avec provenance en `meeting_minutes`. Corrections limitées au titre/texte via le contrat métier de sauvegarde versionnée ; source et provenance conservées. Publication S08 à deux acteurs avec projection `{title,minutes}` et audience distincte. Le retrait source masque le brouillon mais laisse la copie approuvée révocable. Le frontend sépare fiche source et copie de consultation. Contrat détaillé : `S09-PV-DERIVES.md` ; preuves : `../preuves/S09-D/BILAN.md`.


## E — conservation et restauration

Contrat détaillé : [S09-CONSERVATION-RESTAURATION.md](S09-CONSERVATION-RESTAURATION.md). RPC `uniion_audio_retention` : statut, collecte, liste, prolongation, actualisation et approbation d’un inventaire. `uniion_audio_retention_execute` : début/finalisation réservés au scanner après approbation. `uniion_audio_local_receipts` : reçus propres à l’acteur pour nettoyage des seules copies locales entièrement sauvegardées. Tables privées, contrôle des droits côté base, tombstones, audit et suppression Storage réelle.

Les octets audio sont le seul périmètre supprimé par ce lot ; transcriptions, PV et copies approuvées ainsi que sauvegardes ont un sort distinct explicitement inventorié. Restauration en quarantaine avec réapplication des suppressions/révocations avant admission. Voir `../preuves/S09-E/BILAN.md` pour la preuve locale et ses limites.

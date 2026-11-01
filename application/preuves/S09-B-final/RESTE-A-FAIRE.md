# S09 — reste à faire après finalisation locale de B

Le lot A est terminé. Le lot B est finalisé pour la recette locale fictive : capture PCM, import WAV/AIFF 16 bits, segments reprenables, originaux serveur, droits/consentement, chiffrement local et écrans existants. La clôture de S09 et la préparation à la production restent distinctes.

## C — transcription réelle

- Installer/configurer un moteur local de recette, sans fournisseur externe implicite.
- Jobs durables liés à la réunion, aux segments et à leurs versions de consentement ; progression, erreurs, annulation contrôlée, reprise et idempotence.
- Transcription horodatée sur la chronologie complète, droits hérités des sources et refus après retrait.

## D — transcription vers procès-verbal

- Raccorder transcription et marqueurs au projet de PV. Aujourd’hui le générateur utilise les notes uniquement.
- Corrections, relecture, validation par version et diffusion via S06/S08.
- Restrictions D12/D13 : une copie diffusée du PV n’autorise pas l’accès à l’audio ou aux sources.

## E — conservation, suppression et restauration

- Échéance à 30 jours après validation, inventaire précis et demande de suppression ; validation super admin préalable, aucune purge automatique.
- Couvrir WAV Storage, blocs de transfert, originaux et blocs conservés en base, séquences, consentements, transcriptions, dérivés, brouillons et sauvegardes.
- Restaurations mesurées avec réapplication des retraits/révocations ; traitement explicite des copies locales et des appareils indisponibles.

## F — recette globale et clôture S09

- Chaîne complète capture/import → transcription → PV → validation → diffusion → conservation/restauration, tests adverses et erreurs transverses.
- Endurance réelle d’une séance de plusieurs heures sur appareils physiques et navigateurs cibles, micro physique, verrouillage/veille, perte de périphérique, quotas réels de stockage. Les huit heures de B sont vérifiées par traitement accéléré de trames en test, pas par huit heures d’enregistrement matériel.
- Matrice de codecs complémentaires (MP3/AAC/Opus/WebM selon les décodeurs disponibles). Les profils qualifiés ici sont PCM navigateur, WAV PCM et AIFF PCM16 ; un autre codec ne doit pas être annoncé supporté sans recette.
- Comparaison visuelle complète et acceptation produit, bilan et transmission du sprint.

## S16 — production

Hébergement, fournisseurs, secrets, supervision, sauvegardes cibles, quotas d’exploitation et validation de la configuration déployée. Aucun déploiement ni fournisseur externe n’a été engagé dans B.

**Prochaine étape de développement : lot C, moteur local de transcription et jobs durables.**

# Recette navigateur S09-B finale

Environnement : navigateur intégré disponible, Supabase/Auth/MFA/Storage/ClamAV locaux. Compte et organisation fictifs. Le lanceur `operations/s09_b_final_ui_server.py` remplace seulement l’entrée microphone de recette par un oscillateur WebAudio 440 Hz ; la capture PCM, IndexedDB, le transport et les contrôles serveur sont réels. Aucun microphone physique ni fournisseur externe utilisé.

## Scénarios observés

1. Sélection d’une réunion native, confirmations de consentement, capture PCM. Pause, marqueur Décision, reprise puis marqueur Vote ; arrêt après 151,034 secondes de signal reçu. Deux fichiers `clean`, offsets 0 et 119720 ms, chacun avec une révision de marqueurs. Relecture indépendante de Storage : SHA exacts, RMS ≈ 0,00706 et fréquence ≈ 440 Hz (`capture-server.json`).
2. Sauvegarde segmentée, quota HTTP rencontré puis reprise. Rechargement de la page, fiche serveur, sélection des deux segments, marqueurs 00:30 et 02:31. Écoute effective confirmée par l’action « Arrêter l’écoute », puis arrêt volontaire. Durée totale 02:31 après rechargement.
3. Import d’un WAV synthétique de 3244 octets : fichier dérivé `clean`, durée 100 ms, original `clean` de 3244 octets confirmé en base (`import-server.txt`). Quota pendant actualisation ; récupération automatique de la fiche après correction de la reprise des lectures.
4. Deuxième onglet : entrée refusée par le verrou de brouillon, message « Un autre onglet utilise les brouillons audio ». La capture n’a pas été simulée. Une tentative suivante a aussi rencontré un quota, distingué du refus de verrou (`ui/second-onglet.txt`).
5. Contrôle formats avec le même module de conversion : WAV PCM et AIFF PCM16, fichiers réels de silence synthétique, chacun converti en WAV de 3244 octets/100 ms (`ui/formats.json`). Le décodage AIFF du système étant indisponible, le module possède maintenant un décodeur PCM16 borné ; l’original reste inchangé.
6. Interruption du moteur audio observée lors de tentatives ultérieures : arrêt explicite « Flux audio interrompu », petits segments reçus conservés, brouillons mis de côté sans suppression. Une séance stable initiale ne garantit pas le fonctionnement en veille ou sur tout appareil. L’endurance matérielle reste à F.

## Dimensions et clavier

Fiche : 360×800, 390×844, 768×1024, 1024×768, 1440×1000 et 768×400 effectivement mesurés. Consentement : les cinq largeurs effectivement mesurées. `scrollWidth <= innerWidth` dans les observations. JSON et captures dans `ui/` ; certaines vues sont volontairement défilées vers les actions.

À 768×400 : Espace coche la première confirmation, Tab donne le focus à la seconde, Espace la coche, Tab atteint le bouton d’enregistrement. Son rectangle vertical observé est compris entre 198,8 et 246,3 px, donc accessible dans ce viewport. Les captures ne sont pas des tests sur appareils physiques.

## Distinction des preuves

- La capture 151 s, la relecture Storage et l’import ci-dessus sont réels.
- Les huit heures de trames, quotas de stockage, réponses tardives et franchissements précis de frontières sont des tests automatisés, avec doubles lorsque nécessaire ; ne pas les présenter comme huit heures d’enregistrement UI.
- Le découpage final à exactement 120 s par segment corrige le léger découpage anticipé observé avec une pause dans la première recette (119720 ms). Le test de bloc partiel vérifie qu’aucun échantillon n’est perdu ni doublé.
- Micro physique, branchement/débranchement matériel, veille système et codecs complémentaires : non qualifiés ici, explicitement suivis dans F.

Diagnostic indépendant : après 33.252 secondes réelles, l’horloge de la source AudioContext vaut 0.005333 seconde (état déclaré running), avec 0 échantillons émis. Voir `ui/diagnostic-horloge.json` et le diagnostic conservé. Le blocage du signal se reproduit sans Auth, IndexedDB, transfert ni interface uniion.

Sur la version finale avec écriture atomique, un brouillon interrompu a été retrouvé après rechargement avec nouvelle confirmation de consentement obligatoire (`ui/reprise-brouillon-atomique.txt`). Aucun original fictif n’a été supprimé.

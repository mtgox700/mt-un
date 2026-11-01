# États non nominaux à concevoir et à développer

Version 1 — 5 septembre 2026. Le prototype montre le cas nominal. Ce document liste, écran par écran,
les états qui manquent et le comportement attendu. **Aucun écran n'est considéré comme terminé sans
ses états vide, chargement, échec et permission refusée.**

## 1. Règles transverses

| État | Règle |
|---|---|
| **Chargement** | Squelettes reprenant la forme du contenu attendu (jamais un tourniquet plein écran). Au-delà de 400 ms seulement, pour éviter le clignotement. |
| **Vide** | Une phrase qui dit ce qui manque, une action pour le créer. Jamais une illustration sans issue. |
| **Échec réseau** | Message explicite, bouton « Réessayer », conservation de la saisie. Jamais de perte de formulaire. |
| **Échec partiel** | Ce qui a réussi reste affiché ; ce qui a échoué est marqué et relançable individuellement. |
| **Permission refusée** | Message sans révéler l'existence de la ressource (voir `AUTORISATIONS.md` §4). |
| **Hors ligne** | Bandeau persistant, actions d'écriture désactivées ou mises en file avec mention explicite. |
| **Action longue** | Au-delà de 2 s : progression réelle si mesurable, sinon état d'attente nommé (« Transcription en cours — environ 3 min »). |
| **Après suppression** | Confirmation avec « Annuler » pendant 10 s (la suppression est différée, pas rejouée). |

## 2. Par écran

### Tableau de bord
- Première connexion : aucun dossier, aucun événement — proposer les trois premières actions
  (créer un dossier, importer le fichier adhérents, compléter son mandat).
- Chargement : squelettes de cartes de statistiques.
- Échec d'un bloc : le bloc affiche son propre échec, le reste du tableau reste utilisable.

### Dossiers (kanban)
- Vide : colonne « À traiter » avec appel à créer.
- 200 dossiers dans une colonne : virtualisation ou pagination par colonne (à trancher — cible de
  performance en `RECETTE.md` §3).
- Titre de 180 caractères : troncature à deux lignes, titre complet en infobulle et sur la fiche.
- Déplacement refusé (dossier clos, droit manquant) : la carte revient à sa position avec un message.
- Conflit : le dossier a changé pendant l'édition → écran de comparaison, pas d'écrasement.

### Assistant IA (les cinq surfaces)
- **Quota atteint** : indication du plafond, de la date de réinitialisation, et du recours (demander un
  relèvement à un administrateur).
- **Modèle indisponible** (`503`) : message franc, relance manuelle, aucune réponse de repli
  simulée — jamais de contenu inventé pour combler.
- **Masquage incomplet** : l'envoi est bloqué ; l'écran indique les **types** d'identifiants détectés,
  jamais les valeurs, et propose la correction.
- **Méta-question refusée** : réponse immédiate expliquant le refus, sans consommer de quota.
- Réponse tronquée par la limite de jetons : marquer la troncature, proposer « Continuer ».
- Aucune citation trouvée : le dire, ne pas présenter une réponse non sourcée comme sourcée.

### Adhérents
- Vide : import CSV en action principale, saisie manuelle en secondaire.
- 2 000 adhérents : pagination serveur (25 par page), recherche serveur, tri serveur.
- Import : rapport de lignes avec valides / rejetées / averties, motif par ligne, export du rapport,
  possibilité d'importer les seules lignes valides ; fichier > 5 Mo ou > 5 000 lignes → traitement
  asynchrone avec notification.
- Doublon détecté (même e-mail) : choix explicite entre fusion, création et abandon.
- Accès sans le rôle trésorier : écran expliquant la restriction article 9, avec le nom du trésorier
  à contacter.

### Agenda
- Vide : semaine en cours affichée, appel à créer un premier événement.
- 60 événements sur un même jour : compteur « +12 autres » et bascule vers la vue liste du jour.
- Événement passé : lecture seule, duplication proposée.
- Conflit d'horaire sur un même participant : avertissement non bloquant.
- Rappel dont l'envoi a échoué : marqué dans l'événement, relançable.

### Documents et signature
- Vide : bibliothèque de gabarits en écran d'accueil.
- Prestataire de signature indisponible : le document reste « Relu », aucune signature partielle.
- Export PDF en échec : conserver le document, proposer l'impression navigateur en repli.

### Réunions
- Micro refusé par le navigateur : expliquer comment l'autoriser, proposer l'import d'un fichier audio.
- Enregistrement interrompu (onglet fermé, batterie) : reprise proposée, fragment conservé.
- Transcription en échec : audio conservé, relance possible, compte rendu non généré.

### Sites (intranet et public)
- Aucune page : les gabarits en écran d'accueil (déjà le cas).
- HTML saisi non conforme après assainissement serveur : indiquer les balises retirées.
- Publication retournée par le webmaster : motif visible, page rouverte en édition (déjà le cas).
- Logo trop lourd ou format inconnu : refus avec la contrainte exacte (déjà le cas côté client, à
  refaire côté serveur).

### Messagerie
- Clé de l'appareil absente (nouvelle connexion) : les messages antérieurs restent illisibles — le dire
  clairement, ne pas laisser croire à une perte de données.
- Destinataire sans clé publique : envoi impossible, expliquer.

### Reporting
- Période sans données : axes affichés, message « aucune donnée sur la période », pas de graphique vide
  trompeur.
- Agrégat portant sur moins de 5 personnes : **ne pas afficher** (réidentification).

### Réglages
- Facturation indisponible : afficher les sièges connus en dernière date, marquer l'information comme
  potentiellement périmée.
- Retrait de son propre rôle d'administrateur : refusé s'il ne reste aucun autre administrateur.

## 3. Cas limites de contenu à tester systématiquement

Titre de 180 caractères · nom composé de 60 caractères · adresse e-mail de 254 caractères ·
0, 1, 5, 25, 26, 2 000 lignes · pièce jointe de 0 octet, 79 Mo, 81 Mo · texte en majuscules accentuées ·
caractères RTL et emoji dans un champ libre · CSV en latin-1 avec point-virgule · CSV avec BOM ·
deux onglets ouverts modifiant le même dossier · session expirée pendant une saisie longue ·
horloge client décalée de 2 h · zoom navigateur à 200 % · largeur de fenêtre 320 px.

## 4. Compléments version 3 — 1er octobre 2026

### Messages
- **Vide** : écran d'accueil à droite (bureau) avec les trois actions ; liste filtrée vide : message propre à chaque filtre (déjà conçu).
- **Chargement** : squelettes de lignes (avatar + deux lignes) ; dans le fil, chargement de l'historique au défilement vers le haut.
- **Envoi** : bulle en état « en cours » (horloge) puis ✓ envoyé, ✓✓ lu ; échec : bulle rouge « Non envoyé — Réessayer ».
- **Hors ligne** : composer actif, messages mis en file, bandeau « Les messages partiront à la reconnexion ».
- **Diffusion refusée** (`409 consentement`) : feuille listant les destinataires exclus et le motif.
- **Retiré d'un groupe** : fil en lecture seule, composer remplacé par « Vous ne faites plus partie de ce groupe ».
- **Contact supprimé** : nom remplacé par « Contact supprimé », discussions directes conservées en lecture.
- **Long** : nom de groupe de 120 caractères, message de 5 000 caractères, groupe de 200 membres (liste virtualisée).

### Formations
- **Génération en cours** : écran d'attente (conçu). Au-delà de 30 s : « Toujours en préparation… » et bouton Annuler.
- **IA indisponible** : parcours type et bandeau d'avertissement (conçu). Quota atteint : message avec heure de réinitialisation.
- **Réponse IA invalide** (pas de module, quiz incohérent) : régénération automatique une fois, puis parcours type.
- **Catalogue vide ou filtres sans résultat** : conçu.
- **Demande de session** : états envoyée, acceptée, refusée, planifiée (lien vers l'agenda) — à concevoir sur la fiche.

### Préférences d'interface
- Menu latéral réduit : conservé par appareil ; sous 940 px, sans objet (barre inférieure).

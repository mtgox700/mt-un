# Contrats à stabiliser avant implémentation

## Entités proposées — à adapter aux primitives existantes

Conversation : organisation, identifiant, type, titre, état, version, dates serveur. Participation : conversation, utilisateur, intervalle d’appartenance, statut, droits d’administration distincts. Autorisation d’historique : périmètre temporel explicite, bénéficiaire, approbateur habilité, audit. Message : organisation/conversation/auteur, ordre serveur, texte inerte, identifiant d’idempotence, éventuelle réponse source, version/état. Pièce : référence au stockage privé et au scan, message parent, intégrité. Lecture : curseur individuel. Notification : destinataire, référence et état ; pas de contenu inaccessible dupliqué. Audit : événements minimaux, sans copie inutile des messages.

Utiliser des relations composites cohérentes avec l’organisation ; ne jamais considérer l’organisation reçue du client comme une autorisation. Éviter un booléen de membre qui perd les périodes de départ/réarrivée. Ordre déterministe par séquence serveur ou couple date/identifiant, pas par horloge du navigateur.

## Services

Définir les commandes liste/lecture/création/envoi/réponse/membres/historique/pièces/transfert/lecture-notifications selon les conventions actuelles. Ne pas inventer de route définitive avant inspection. Pour chacune : entrées strictes, version attendue si nécessaire, permission, transaction, audit, réponse, erreurs, rejeu et événements.

Envoi : le même identifiant client rejoué ne crée qu’un message ; une réutilisation avec contenu différent est refusée. Réponse « envoyé » seulement après confirmation serveur. En cas de résultat incertain, réconcilier par identifiant, ne pas multiplier les écritures.

## Contrôles cumulés

Session/MFA → appartenance active à l’organisation → accès commercial et activation du module → permission métier → participation à la conversation et période visible → droit spécifique pour téléchargement/transfert/membres/historique → état/version.

RLS et commandes serveur doivent se compléter. Une clé service_role contourne RLS : ne jamais en faire la preuve d’un test de refus utilisateur. Aucun nouveau secret lu ou imprimé par défaut. Utiliser les configurations existantes uniquement selon les autorisations applicables ; ne pas recopier les autorisations de privilèges passées comme un blanc-seing.

## D02/D03/D07/D11/D12/D13

Aucun partage implicite section/fédération. Super admin : gestion globale, pas lecture des fils. Suppression soumise à validation préalable ; pas de purge automatique. Accès à l’historique depuis l’arrivée, ouverture spécifique et révocation au départ. Les références dérivées héritent des restrictions ; diffusion distincte seulement avec relecture et autorisation appropriées. Les circuits sensibles nécessitent le second acteur prévu.

## Frontal

Le module possède son état/services. Effacer les données à la déconnexion, au changement d’organisation et au retrait d’accès. Les résultats asynchrones d’un contexte expiré ne repeuplent pas le nouvel écran. Aucun cache métier persistant en localStorage/IndexedDB ajouté dans S07 ; le hors ligne sécurisé est un chantier distinct. Traiter XSS, noms de fichiers et liens comme des données non fiables.

## Arbitrages éventuels, à poser seulement s’ils deviennent nécessaires

- Contrôle précis des administrateurs de groupe, si non défini par l’existant.
- Sens du transfert vers une audience ne lisant pas la source : référence restreinte ou version distincte approuvée.
- Édition/suppression de messages et présentation de leur historique si le prototype ne définit pas le circuit.
- Nouveaux contrôles visibles sans équivalent validé.

Ne pas rouvrir les décisions S00 ni redemander les préférences déjà explicites. Continuer les lots indépendants pendant un arbitrage.

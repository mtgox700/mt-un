# S09 — lot D, transcription vers PV

31 octobre 2026. Lot D réalisé et vérifié pour les données fictives locales. S09 reste ouvert, prochaine étape E.

## Réalisé

- Projet de PV séparé de la réunion, lié à une transcription terminée et à l’ensemble exact de ses segments. L’ajout d’un segment produit un autre ensemble de sources et un nouveau PV ; aucun ancien projet n’est réutilisé silencieusement.
- Assemblage serveur fidèle de l’ordre du jour, du texte horodaté et des marqueurs versionnés. Aucune décision inventée et aucune inférence simulée. Le bouton Assistant utilise le PV et ses sources dans le contrat S08 existant, sous ses règles d’accès et limites.
- Corrections dans la modale existante, concurrence par version, texte conservé en cas d’échec. Une correction du PV ne modifie pas la réunion et ne périme donc pas son consentement.
- Validation par un second acteur habilité, audience explicite et permission distincte de publication. La version diffusée contient seulement titre et texte relu ; pas de provenance privée, de transcription brute séparée ou de droit sur les audios. Consultation seule, sans téléchargement implicite.
- Retrait des sources pris en compte par les brouillons, leurs versions directes, le contexte IA et l’affichage. La copie approuvée conserve sa propre autorisation, avec révocation depuis l’interface même après retrait du consentement.
- Migrations 173–179, commandes et composant métier dédiés ; garde RLS et blocage du partage direct des brouillons dérivés.

## Preuves observées

- **86 contrôles d’intégration de la chaîne D**, préparation réelle C incluse : transcription/markers, idempotence, versions, sources privées, refus d’auto-validation, relecture/publication nouvelles, copies et droits distincts, retrait, révocation, RLS direct, contexte S08, correction longue sans troncature et nouvel ensemble de segments.
- **57 contrôles de non-régression C** réussis, dans un dossier de preuves séparé.
- **287 tests Python**, **266 tests frontend**, compilation React et frontières des modules réussis. Les tests frontend ajoutés couvrent notamment réponse tardive après déconnexion, saisie conservée après conflit, retrait en actualisation de fond et absence de cache persistant d’une copie révoquée, fermeture des fenêtres sans contamination des autres actions et effacement immédiat après retrait local du consentement.
- Parcours UI complet à deux comptes réellement actionné, y compris publication après relecture, consultation après retrait du consentement, révocation puis disparition de la copie.
- Desktop, tablette et mobile inspectés, sans débordement horizontal sur ces dimensions ; accès au dernier paragraphe mobile vérifié par défilement. Design existant conservé : cartes, boutons, modales, typographies, couleurs et navigation réutilisés.
- Références et anciennes preuves comparées aux empreintes du début de lot : résultat détaillé dans `integrity-after.json`, aucune modification constatée.

## Limites et suites

Le projet initial rassemble les sources, il n’est pas présenté comme une synthèse générative. Aucune nouvelle inférence via fournisseur externe n’a été exécutée pour D. Le raccordement du contexte S08 a été testé, avec refus après retrait. Les limites S08 de taille du contexte restent applicables ; ce lot ne les contourne pas.

Les projets complets sont bornés à 6 Mio et les dépassements refusés sans troncature. Une correction de plus de 100 000 caractères a été conservée intégralement lors de la recette. Cela ne remplace pas l’endurance d’une réunion réelle de plusieurs heures ni la qualification de précision de transcription, à F.

La diffusion livrée est interne à l’application, consultation seule ; pas de nouveau téléchargement, export PDF, signature ni envoi externe. Conservation/suppression approuvée/restauration des nouvelles données à E ; recette globale et acceptation produit à F ; production à S16. Aucun service de production ni démarrage système automatique n’est installé.

Pour charger les nouvelles commandes sur un serveur applicatif déjà ouvert, suivre son redémarrage local habituel après application des migrations et compilation frontend. Les recettes utilisent un serveur temporaire distinct. Contrat et fonctionnement : `../../docs/S09-PV-DERIVES.md`. Liste complète : `RESTE-A-FAIRE.md`.

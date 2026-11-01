# S09-D — parcours UI réellement exécuté

31 octobre 2026, serveur de recette temporaire 5072, deux comptes MFA fictifs, organisation isolée. La voix et sa transcription sont celles du moteur local réel ; aucune synthèse IA de remplacement.

1. Rédacteur : ouvrir la réunion avec audio serveur et marqueur, préparer le PV. Le projet reprend transcription et marqueur.
2. Ouvrir « Corriger le PV », remplacer le projet par un texte relu qui confirme vendredi et laisse la date incertaine du prochain rendez-vous à vérifier.
3. La première tentative rencontre le quota existant ; la saisie reste dans la modale. La reprise enregistre la version 2, observée dans la fiche.
4. Relecteur distinct : ouvrir le même PV v2, valider après relecture avec l’adresse du destinataire fictif. Confirmation « Action enregistrée ».
5. Acteur habilité : publier la v2 dans l’application. Confirmation réelle, pas un replay d’une version déjà publiée.
6. Destinataire : retirer le consentement audio depuis la fiche, revenir à la liste puis ouvrir la copie publiée. Seul le texte approuvé est visible ; audio non diffusé, absence des commandes d’enregistrement, d’écoute, d’assistance sur sources et de transcription.
7. Revenir à la réunion source, ouvrir « Gérer les versions diffusées du PV », révoquer la v2 après retrait du consentement. Confirmation « Version révoquée », puis disparition de la copie publiée dans la liste.

## Visuel

Captures inspectées : desktop 1440 × 1000, tablette 768 × 1024, mobile 390 × 844. Mesures réelles dans `responsive.json` : aucun débordement horizontal. La fin du texte mobile est accessible après défilement ; `mobile-bas-pv.jpg` la montre au-dessus de la navigation fixe. Cartes, styles, modales et navigation préexistants réutilisés. Les contrôles sur les sources sont conditionnels et absents de la copie publiée.

`desktop-pv.jpg` montre l’étape de correction/relecture ; `desktop-publie.jpg`, `tablette-publie.jpg` et `mobile-publie.jpg` montrent la copie consultée après retrait du consentement, avant révocation. `revocation-mobile.jpg` montre le résultat de la révocation. La publication de recette a finalement été révoquée.

Le quota serveur n’a pas été diminué. Le message de sauvegarde distingue maintenant ce cas d’un refus de version ou d’habilitation. L’amorçage de cette instance de recette efface uniquement ses timestamps de quota issus de l’horloge synthétique des fixtures, avant de commencer les actions navigateur avec l’horloge réelle.

Le serveur temporaire et l’onglet ont été fermés après recette. Aucun parcours sur appareil physique ni export PDF n’est revendiqué ici.

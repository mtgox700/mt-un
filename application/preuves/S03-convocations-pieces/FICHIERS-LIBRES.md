# S03 — Choix des pièces jointes libres

Décision utilisateur du 28 octobre 2026 : permettre les fichiers libres (PDF, images, documents), en plus de l’ordre du jour.

## État constaté

La convocation sait déjà joindre le PDF validé et le calendrier ICS. Le socle fichiers accepte actuellement PDF, PNG, JPEG et texte UTF-8, à concurrence de 5 Mo par fichier. Il dispose de stockage privé, empreintes, quarantaine, antivirus et téléchargements autorisés. Cette disponibilité ne signifie pas que le parcours convocation y est raccordé. Les formats bureautiques ne sont pas encore pris en charge par ce pipeline.

## Conditions du raccordement

- Sélection explicite des fichiers de la convocation, avec noms et état de contrôle visibles dans le panneau existant.
- Conservation privée en base et stockage serveur ; aucun fichier métier durable en stockage navigateur.
- Vérification du type réel, des tailles, du contenu et de l’intégrité ; antivirus indisponible ou contrôle incomplet : refus de diffusion.
- Association immuable des fichiers et de leurs empreintes à la version approuvée ; ajout ou remplacement après validation impose une nouvelle validation.
- Respect des restrictions des sources selon D12 ; la sélection d’un fichier existant ne confère pas de nouveaux droits à ses destinataires.
- Recontrôle de l’organisation, de l’audience, des droits de diffusion et téléchargement avant chaque livraison.
- Aucun effacement automatique des fichiers déposés ou en quarantaine.
- Recette avec fichiers valides, invalides, infectés et trop volumineux ; accès directs et inter-organisations refusés ; révocation et version périmée ; vérification des fichiers réellement reçus.
- Parcours mobile, tablette et desktop ; prototype et S00 intacts.

## Réserve de compatibilité

Étendre les formats bureautiques demande un validateur adapté. Ne pas autoriser simplement une nouvelle extension ni traiter une archive Office comme un fichier déjà contrôlé. Documenter les formats réellement pris en charge et leurs limites dans le prochain bilan.

Cette note enregistre le choix et les exigences. Elle ne constitue pas une preuve d’implémentation ni de recette des fichiers libres.

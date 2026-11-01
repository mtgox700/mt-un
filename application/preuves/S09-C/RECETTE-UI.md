# S09-C — recette interface locale

31 octobre 2026, navigateur intégré, compte MFA fictif et réunion créée pour cette recette.

Parcours réellement actionné : ouverture de la fiche, « Transcrire localement » → attente, « Annuler la transcription » → annulée, « Réessayer la transcription » → attente, exécution du worker réel puis « Actualiser la transcription » → terminée avec deux passages français horodatés. Le PV reste explicitement fondé sur les notes ; aucun raccordement prématuré au lot D.

Captures inspectées : desktop 1440 × 1000, mobile 390 × 844, tablette 768 × 1024. Aucun débordement horizontal mesuré sur mobile (382 px pour 390) ou tablette (760 px pour 768). Cartes, couleurs, typographies et navigation existantes conservées ; commandes et texte ajoutés dans le panneau préexistant.

Le quota existant de requêtes a été rencontré et sa temporisation visible. Les actions de transcription actualisent désormais leur réponse directement sans trois requêtes de relecture supplémentaires. Le bandeau de temporisation apparaît sur les captures ; il ne constitue pas un échec de transcription. La recette d’intégration utilise une horloge accélérée pour ses nombreuses commandes ; le serveur UI reprend ensuite l’horloge réelle, ce qui peut prolonger temporairement les timestamps de quota hérités de son amorçage.

Limites : pas de test matériel de longue durée, de reconnaissance multi-locuteurs ou de précision sur des réunions réelles. La phrase synthétique contient une erreur de reconnaissance dans sa dernière proposition, visible et conservée dans les preuves.

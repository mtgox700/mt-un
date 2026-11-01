# Lot B — matrice de réalisation
- Groupe créé via le formulaire existant ; création idempotente, nom/description/membres réels.
- Permission create distincte de write ; administrateur de groupe distinct de l’administrateur d’organisation ; habilitation history distincte.
- Ajout à la séquence suivante ; anciens messages et extraits cachés ; retrait immédiat côté serveur.
- Réinvitation : nouvelle période, anciens grants inactifs ; suspension/retrait/réinvitation d’organisation contrôlés.
- Ouverture de messages explicitement sélectionnés vers des participants actuels ; approbateur lecteur habilité ; audit ; révocation explicite.
- Modifications par version, pas de perte silencieuse ; dernier administrateur protégé ; aucune suppression physique.
- Réponses tardives après changement d’identité écartées ; UI aux trois viewports, tests RPC directs et non-régression A.

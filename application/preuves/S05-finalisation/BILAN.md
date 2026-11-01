# S05 — Recette finale du classement serveur

29 octobre 2026. Travail local, skill uniion appliqué. Prototype et S00 inchangés.

## Résultat

Le périmètre validé « contenus serveur d’abord » est vérifié : convocations durables et leurs archives PDF/ICS, plus fichier libre PNG, classés par référence dans un dossier. Pas de copie de contenu permettant de contourner les droits source. Classement réservé à l’écriture du dossier ; consultation et téléchargement soumis aux droits actuels source et cible. Aucun nouveau droit accordé par le classement.

Une nouvelle recette confirme le téléchargement exact du fichier libre, l’aperçu, le retrait des droits source, le refus d’une autre organisation et le blocage d’une pièce requalifiée en quarantaine. Cette requalification est une simulation de statut sur une pièce fictive ; ce n’est pas un nouveau test de détection d’EICAR. Les tests antivirus réels du coffre restent couverts par la suite S05-files rejouée.

## Incident temporaire et correction

La limite serveur existante est de 20 requêtes d’identité par utilisateur et par minute. Une série de 21 consultations reproduit HTTP 429 ; après expiration de la fenêtre, la consultation réussit. Cela explique un scénario compatible avec l’incident précédent, sans disposer d’une trace HTTP de cet incident permettant d’en certifier rétrospectivement la cause.

Le transport frontal conserve désormais le statut HTTP. Sur 429, le coffre n’enchaîne plus une seconde requête vouée à échouer ; il efface les métadonnées transitoires et demande explicitement d’attendre une minute puis de rouvrir le coffre. Aucun quota ni contrôle de sécurité affaibli. Test unitaire de l’absence de cascade ajouté.

## Vérifications exécutées

- Recette ciblée : 21 contrôles réussis.
- Six suites S05 rejouées : dossiers 33, affectations 23, coffre 27, versions 21, corbeille 30, classement 26. Socles communs : ne pas lire ces nombres comme des parcours distincts.
- 94 tests frontaux et 145 tests Python réussis. Compilation et frontières des modules OK.
- Interface réelle aux viewports 390×844, 768×1024 et 1440×1000 : classement message mobile, ICS tablette, rejeu du fichier libre desktop ; refus du classement par le lecteur aux trois formats. Aperçu et téléchargement PNG autorisés aux trois formats. Identité visuelle et enchaînement du sélecteur conservés ; aucune nouvelle vue créée. Pas de débordement horizontal constaté dans les modales testées.
- Installation depuis une base neuve isolée : 92 contrôles, toutes les migrations présentes rejouées.
- Sauvegarde chiffrée puis restauration isolée : 70 tables et 199 objets, 271 contrôles de schéma, données, fonctions, droits et octets. Aucun effacement automatique et aucune restauration dans la pile source.
- Sur cette restauration : 12 contrôles avec connexion Auth réelle et MFA, lecture du dossier et de la référence, refus d’écriture du lecteur, révocation bloquant la référence, table privée inaccessible. La révocation de recette affecte uniquement la cible isolée.
- 834 empreintes de référence identiques.

La sauvegarde précède les derniers clics UI et la non-régression ; elle établit la reprise des tables et références présentes au moment de la capture, pas celle des mutations ultérieures. Les cibles isolées sont conservées ; pas de nettoyage destructif.

## Statut de clôture et réserves

Le lot de classement des contenus serveur est validé sur le périmètre testé. La restauration des nouvelles tables n’est plus une réserve générale.

Je ne déclare pas S05 entièrement clôturé : les réserves fonctionnelles déjà inscrites restent visibles. L’accueil et les préparateurs hérités nécessitent encore leur finition ; reprise d’analyse depuis le coffre et pagination d’aperçu restent à raccorder ; retrait d’une référence et suppression de dossier restent bloqués plutôt que simulés, avec circuit D07 à définir/raccorder. La recette spécifique d’une source classée ensuite mise en corbeille reste à compléter (distincte de la quarantaine et de la corbeille ordinaire testées).

Les conversations locales et brouillons de l’éditeur Documents restent exclus conformément au choix utilisateur. Signature, courrier et IA dépendent des modules suivants et ne sont pas annoncés comme opérationnels. Le hors ligne sécurisé et le déploiement ne sont pas validés par cette recette.

# S08 — Lot E : raccordement métier complet pour la recette locale

31 octobre 2026. **Lot E techniquement finalisé dans le périmètre autorisé : connecteur ChatGPT/Codex local, organisations et données fictives.** Ce bilan remplace l’état partiel décrit dans S08-E et S08-E-final, sans modifier leurs preuves. Il ne clôt pas S08 et ne vaut ni déploiement ni acceptation produit par l’utilisateur.

## Réalisé

Les 37 actions du catalogue utilisent les sources de leur module, relues par les contrats serveur. Dossiers, Documents et Messages rejoignent les adaptateurs Agenda, Adhérents et les objets persistants Réunions, Communication, Mobile, Formations, Sondages, Intranet, Reporting et Raccourcis. Accueil et Paramètres disposent d’un contexte d’organisation limité aux dossiers, réunions et événements autorisés ; ce périmètre est indiqué au modèle. Les actions de liste peuvent croiser jusqu’à huit sources autorisées. Aucun ancien corpus navigateur n’est importé implicitement.

Les sept générateurs spécialisés sont raccordés : cours, retour d’exercice, document, page Intranet, projet de PV, contenu de communication et options de sondage. Les sorties sont structurées et validées avant leur utilisation. Le cours vérifie notamment les types, les réponses du quiz et la somme des durées. Une sortie invalide échoue explicitement, sans contenu de secours inventé. Les éditeurs métier sauvegardent leurs brouillons sur le serveur avant génération.

Le panneau unii conserve la correction, la relecture et l’application explicite. Outre les notes de Dossiers et paragraphes de Documents déjà livrés, les propositions peuvent mettre à jour le brouillon du plan de communication, le texte d’une page mobile et son brouillon de notification. L’application porte sur la source autorisée ; elle ne choisit jamais une destination à partir d’une instruction du modèle. Les reçus d’application restent atomiques et idempotents.

La conversation libre est disponible dans les organisations fictives explicitement inscrites pour cette recette. Elle conserve l’historique privé chiffré et les dépendances cumulées, avec limites de longueur, de sources et de tours. Un dossier privé peut être créé depuis une réponse persistée ou depuis le message sélectionné. Il reste lié aux droits de toutes ses sources ; il ne peut pas être rendu accessible à un autre acteur par un simple partage de dossier. Les dépendances détaillées du contexte d’organisation sont conservées.

Les actions disposent d’une configuration serveur versionnée : activation et restriction aux six rôles métier du référentiel. Le gestionnaire doit disposer de la permission prévue. L’attribution de rôle est distincte, auditée et refuse l’auto-attribution ; les droits du module et de chaque ressource restent nécessaires.

## Publication et accès

Les objets Réunions, Communication, Mobile et Intranet disposent d’une publication locale distincte et immuable par version. Le second relecteur ne peut être un contributeur de cette version ou de ses sources. Relecture, permission de diffusion et audience explicite sont contrôlées côté serveur. Le destinataire consulte la copie approuvée sans obtenir l’accès aux sources. Une ancienne version publiée reste révocable après modification du brouillon. L’interface distingue cette ancienne copie et évite de doubler la version courante.

Les contrôles IA sont renouvelés avant/après génération, lors de la consultation, de l’application et de la création du dossier. Une source modifiée ou retirée invalide l’ancienne réponse. Les politiques RLS des dossiers dérivés sont vérifiées aussi par accès direct aux tables. Les listes métier sont recontrôlées toutes les dix secondes ; elles sont retirées en cas de refus ou d’indisponibilité. Ce délai n’est pas présenté comme une révocation instantanée.

Les organisations ordinaires conservent la certification exacte des fixtures. Seuls les acteurs fictifs et organisations explicitement inscrits pour la recette interactive peuvent utiliser les nouveaux objets fictifs. Aucun fournisseur secondaire, donnée réelle, push externe ou envoi de message n’a été activé.

## Vérifications exécutées

| Vérification | Résultat observé | Preuve |
| --- | --- | --- |
| Python | 275 tests réussis | python-tests-final.log |
| Frontend | 229 tests réussis | frontend-tests-final.log |
| Compilation et frontières | Réussies | compilation finale et boundaries-final.log |
| HTTP, MFA, PostgreSQL, persistance et refus | 140 contrôles réussis | native-integration.json |
| Dossiers dérivés, listes natives, révocation et RLS directe | 34 contrôles réussis | native-followup.json |
| Codex réel | 37 actions + 7 générateurs : 44 sorties réussies et persistées après corrections | qualification-metier.json |
| Installation depuis zéro | 56 contrôles, 158 fichiers SQL | fresh/S01-ephemeral/integration.json, fresh-final.log |
| Restauration isolée | 382 contrôles SQL/fichiers et 22 contrôles IA | restore/, restore-final.log |
| Intégrité | 834 références et 2 264 anciennes preuves inchangées | integrite-apres.json |

Ces unités ne sont pas interchangeables : 44 générations ne signifient pas 44 parcours navigateur. L’intégration utilise un fournisseur déterministe pour les refus et invariants ; la qualification métier utilise réellement Codex. Les sorties originales et les corrections sont conservées. La première génération du cours a échoué sur des types de champs ambigus ; le contrat du prompt a été précisé, puis le cours a été régénéré avec succès. Les dates de l’historique des dossiers, le contexte Accueil, les actions de liste et la distinction destinataire/auteur ont également été corrigés et rejoués.

## Interface et fidélité

Parcours réellement actionnés dans le navigateur : conversation libre puis dossier privé ; cours de 15 minutes, exercice et retour Codex ; atelier de communication puis brouillon persistant ; refus d’auto-validation ; relecture par un second acteur, publication, persistance après redémarrage et révocation ; création du modèle mobile Contacts des élus ; déconnexion sans écran vide.

Les deux rendus vides défectueux (Intranet puis Réunions) ont été corrigés et couverts par un test du rendu complet. Le modèle mobile conserve ses blocs Contact en base. Les libellés du mobile indiquent désormais une audience envisagée, une notification en brouillon et l’absence de statistiques collectées, sans promettre un envoi externe.

La structure, les composants et les styles du référentiel sont conservés. Les captures bureau 1440×1000, tablette 768×1024 et mobile 390×844 vérifient les parcours modifiés. Les captures stables Communication et le retour de formation mobile montrent le repli responsive et l’accès par défilement. La capture formation-tablette prise pendant un redimensionnement est conservée, mais n’est pas utilisée comme preuve du rendu stabilisé. Aucune refonte graphique n’a été introduite. La validation visuelle produit reste celle de l’utilisateur.

## Limites précises du résultat

- La Messagerie utilise un message sélectionné, ou le dernier message visible lorsqu’il n’y a pas de sélection ; ce n’est pas une synthèse exhaustive du fil. Une sélection multiple est refusée explicitement.
- Les contextes et listes sont bornés, et n’attestent pas l’exhaustivité de l’activité. Les dossiers comportant des sources classées sont exclus des agrégats et refusés pour une application qui perdrait leurs restrictions.
- L’analyse de sondage utilise sa question et ses options. Cette recette n’implémente pas un système de collecte des votes ni la restitution statistique D06. En l’absence de résultats accessibles, l’IA indique qu’elle ne peut pas calculer de participation ou de tendance. Le Reporting ne fabrique pas d’indicateurs absents.
- Les applications Communication et Mobile restent des brouillons, suivis si nécessaire du circuit de publication locale. Aucun réseau social, fournisseur push, signature externe ou publication sur un site public n’est raccordé par ce lot.
- Les 44 exemples ont été relus pour vérifier la distinction faits/propositions, les inconnues, les citations et l’absence d’action prétendument exécutée. Ils ne garantissent pas la justesse de toutes les futures réponses ni une validation juridique. Le masquage est partiel, ce qui justifie le maintien des données fictives.
- Les autres fonctions des modules (enregistrement/transcription, votes, campagnes et exploitation) ne sont pas déclarées terminées par le raccordement IA du lot E.

Le contrôle automatique a refusé une tentative d’ajout d’un droit de lecture temporaire à un nouvel objet de recette, faute d’autorisation explicite pour le destinataire, la ressource et la durée. Le droit n’a pas été ajouté. La recette à deux acteurs a été menée sur un objet fictif déjà autorisé, sans élargissement de cet accès. Ce refus ne laisse pas de demande d’approbation en attente.

## Clôture et suite

Les quatre chantiers E ouverts dans le précédent bilan sont réalisés pour cette recette : sources natives, applications et copies diffusables D12/D13, conversation/générateurs/rôles, qualification métier et parcours d’interface décrits ci-dessus. Les preuves permettent de proposer l’acceptation du lot E local. **S08 reste ouvert pour sa consolidation globale et les réserves d’exploitation.** Les choix de fournisseur et l’articulation conservation/sauvegarde D09/D07 restent à acter avant des données réelles ou une mise en production ; ils ne sont pas présentés comme des travaux E laissés à l’utilisateur.

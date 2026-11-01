**État courant — 31 octobre 2026 : consolidation S08 A–F terminée en recette locale fictive, lot E finalisé ; clôture locale proposée.** [Bilan final](../../preuves/S08-F-final/CLOTURE.md) · [Réserves et décisions S16](../../preuves/S08-F-final/RESERVES.md). Les décisions de production sont reportées à S16 sur instruction utilisateur, avant tout usage réel. Les sections ci-dessous sont historiques et ne décrivent pas toutes l’état actuel.

# S08 — IA commune et assistant

30 octobre 2026. Sprint lancé à la demande « lance s08 ». Développement local dans application/. S07 clôturé ; son package ZIP est une référence de transmission, pas une nouvelle instruction ni un package S08.

## État constaté

S07 A–F clôturé dans preuves/S07-F/CLOTURE.md. La roadmap définit S08 après S05/S06/S07. D09 valide le cadre, mais aucun fournisseur de production ; articulation conservation/suppression D07 encore ouverte. D12 impose les restrictions cumulées de toutes les sources aux dérivés ordinaires.

Le frontal modules/ai/orchestration.js délègue encore à llmText du contrôleur. runtime/reference-logic.js contient l'appel navigateur, le stockage local de clé, la mémoire locale et AI_CORPUS. Ces chemins existants ne sont pas sécurisés ni remplacés par la simple création du nouveau service. Ils doivent être migrés avant qualification S08.

## Lots proposés, ordonnés par dépendance

- A — Passerelle serveur et politique D09 : contrats, authentification/MFA, approbation fournisseur par super admin, activation organisation, permissions, adaptateur local explicite, erreurs et annulation. Retirer les appels directs et clés navigateur du parcours migré. Première brique isolée écrite ; lot non terminé.
- B — Contexte autorisé : adaptateurs Dossiers/Documents/Messages via leurs contrats ; contrôles avant récupération, envoi et restitution, minimisation/masquage, versions, citations vérifiables et restrictions D12. Ne pas prendre le corpus fourni par le navigateur comme autorité.
- C — Exécutions et consommation persistantes : identifiant idempotent, quotas réservés atomiquement, états en attente/en cours/réussi/échoué/annulé/incertain, consommation réelle ou inconnue, aucune relance aveugle après délai.
- D — Assistant, historique et mémoire : séparation utilisateur/organisation, autorisation de chaque source à chaque relecture ; aucune réponse tardive après changement de session. Pas de cache partagé implicite.
- E — Actions unii et modules extraits : raccordement aux contrats communs en conservant les parcours de référence, brouillons et annulation. Documents importés et réponses IA traités comme données sans pouvoir administratif.
- F — Recette globale : refus et confidentialité, injections dans les documents, qualité/citations, erreurs/quotas, responsive, pile neuve et restauration des nouvelles tables, bilan de clôture.

Ce découpage ne réduit pas le périmètre roadmap et n'engage pas une durée.

## Matrice d'acceptation

| Cas | Résultat attendu |
| --- | --- |
| Fournisseur non approuvé ou organisation non activée | Aucun transfert |
| Session/MFA, permission, module ou appartenance invalides | Refus serveur, sans contexte divulgué |
| Source inconnue ou appartenant à une autre organisation | Refus, aucune génération |
| Source révoquée/modifiée pendant la génération | Réponse non restituée, aucune mémoire alimentée |
| Source contenant des instructions malveillantes | Aucun outil, changement de droit ou diffusion déclenché |
| Erreur, réponse vide, délai ambigu | État honnête ; aucune réussite ou relance implicite |
| Annulation, sortie de page, changement de compte | Aucun résultat tardif réinjecté |
| Historique, mémoire, citations, index | Droits actuels et restrictions de toutes les sources appliqués |
| Deux requêtes concurrentes ou même clé | Quota atomique et idempotence vérifiés |
| Parcours Assistant/unii | Comparaison à la référence, mobile/tablette/desktop |

## Arbitrage à préparer avant connexion réelle

Choix fournisseur/modèle, finalités autorisées, localisation, conservation, réutilisation et suppression D07 ; puis activation par organisation. Ne pas déduire ces choix de la présence d'un compte ChatGPT ou d'un connecteur historique. Le travail local et les tests fictifs peuvent continuer indépendamment. Aucun transfert réel n'a été effectué au démarrage.

## Avancement — lot A, 30 octobre 2026

A livré et recetté dans le périmètre local fictif explicitement autorisé par l'utilisateur. Passerelle, politique D09, connecteur ChatGPT/Codex et configuration UI raccordés ; voir ../../preuves/S08-A/BILAN.md. Les mentions « première brique » décrivent le démarrage antérieur. Prochaine étape : B. Le fournisseur de production et tout transfert de données métier restent à arbitrer.

## Avancement — lot B, 30 octobre 2026

B livré dans le périmètre fictif autorisé : adaptateurs Dossiers/Documents/Messages, contrôle de toutes les dépendances, projection minimale, masquage partiel et extraits cités vérifiés. Registre privé de certification des fixtures ; aucune autorisation de données réelles. Voir ../../preuves/S08-B/BILAN.md. Prochaine étape : C — exécutions et consommation persistantes. Le masquage partiel ne clôt pas une qualification d'anonymisation de production.

## Avancement — lot C, 30 octobre 2026

Registre serveur durable de l'instance locale, réservations atomiques, états terminaux, anti-rejeu après redémarrage et quotas de recette raccordés. Consommation financière et jetons explicitement inconnus. Le registre ne contient pas l'historique de contenu. Voir ../../preuves/S08-C/BILAN.md. Suite : D — Assistant, historique et mémoire. Partage multi-hôte du registre et restauration globale non qualifiés.

## Avancement — lot D, 30 octobre 2026

Assistant raccordé pour la recette fictive : réponses et état réussi enregistrés atomiquement, historique chiffré séparé par acteur/organisation, mémoire explicitement activée et sources revalidées à chaque usage. Aucun texte libre ni ancien corpus navigateur envoyé. Voir ../../preuves/S08-D/BILAN.md. Suite : E — actions unii et raccordement des modules ; F et production restent ouverts.

## Avancement — lot E, 30 octobre 2026

Tranche fictive raccordée : panneau unii depuis Dossiers/Documents/Messages, proposition extractive privée, annulation, contrôle des sources et continuation dans l’Assistant par identifiant serveur. Aucun texte navigateur ni commande générée utilisé comme autorité. Voir ../../preuves/S08-E/BILAN.md. Les 37 actions métier, les adaptateurs des autres modules et l’application/diffusion des dérivés ne sont pas livrés ; E complet reste ouvert. F peut qualifier la tranche fictive sans conclure à la clôture métier de S08.

## Avancement — lot F, 31 octobre 2026

Recette globale du périmètre fictif exécutée : 262 tests Python, 214 tests frontaux, 111 contrôles d’intégration, 48 contrôles sur pile neuve et 389 contrôles de restauration. Correction du refus de saisie libre masqué par une ancienne réponse. Voir ../../preuves/S08-F/BILAN.md. F valide cette recette locale, pas la clôture métier de S08 : les fonctions E non livrées et les décisions/exigences de production D07/D09 restent ouvertes. Package de transmission UNIION-S08-RECETTE.zip, sans secrets ni données privées.

## Complément E — 31 octobre 2026

Les 37 tâches produisent désormais des brouillons persistés côté serveur ; correction, relecture et application versionnée/idempotente sont raccordées pour Dossiers et Documents. Les autres modules passent encore par un document de contexte explicite. Voir ../../preuves/S08-E-final/BILAN.md et sa matrice : les parcours natifs manquants, les applications Communication/Mobile, la conversation libre et la qualification métier empêchent toujours la clôture complète de E. Il s’agit de travaux restants, sans nouvelle demande d’autorisation utilisateur pour le périmètre fictif déjà autorisé.


## Finalisation du lot E — 31 octobre 2026

État courant : sources métier natives, 37 actions et 7 générateurs spécialisés, conversation privée, dossiers dérivés, rôles serveur et publication locale versionnée à deux acteurs. Recette ChatGPT/Codex avec données fictives uniquement. 275 tests Python, 229 frontaux, 140 contrôles d’intégration, 34 contrôles complémentaires ; installation neuve et restauration vérifiées. Le [bilan complet](../../preuves/S08-E-complet/BILAN.md) précise les parcours testés et les limites (message unique, absence de collecte de votes et de push externe). Lot E local techniquement finalisé ; S08 et les décisions de production D07/D09 restent ouverts. Les bilans antérieurs sont historiques et conservés.

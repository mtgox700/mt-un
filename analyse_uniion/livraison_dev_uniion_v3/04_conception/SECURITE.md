# Exigences de sécurité, RGPD et robustesse

Le produit traite des données particulièrement sensibles : signalements de harcèlement, données de santé,
appartenance syndicale (donnée sensible au sens de l'article 9 du RGPD). Le niveau d'exigence est celui
d'une application de santé, pas celui d'un outil collaboratif ordinaire.

## Cloisonnement vis-à-vis de l'employeur

- Hébergement et administration **hors du système d'information de l'employeur**, sans compte
  administrateur employeur, sans SSO fourni par l'employeur (ou alors sans accès aux contenus).
- Aucune journalisation exploitable par l'employeur. Le prototype affiche cette promesse à l'utilisateur
  (« chiffré et invisible pour l'employeur », « journal d'accès conservé 5 ans ») : elle doit être
  techniquement tenue, sinon la retirer de l'interface.

## Authentification et accès

- MFA obligatoire (WebAuthn en premier choix, TOTP en repli), sessions courtes, révocation par appareil,
  détection des connexions inhabituelles (l'écran Sécurité les présente déjà).
- Contrôle d'accès par rôle **et** par appartenance à l'établissement, appliqué côté serveur sur chaque
  requête. Rôles présents dans le prototype : élu, référent SSCT, communication, administrateur.
- Journal d'audit append-only : qui a consulté quel dossier, quand, depuis quel appareil.

## Données personnelles

- Minimisation à la saisie (déjà signalée sur l'écran Nouveau dossier).
- Chiffrement au repos des pièces jointes et des messages, clés gérées hors base applicative.
- Durées de conservation par nature de donnée, purge automatique et purge à la fin de mandat
  (l'écran RGPD expose registre, export et purge : ces actions doivent être réelles et journalisées).
- Export et droit d'accès des personnes concernées.
- Sous-traitance IA : contrat, localisation UE, non-réutilisation pour entraînement, durée de rétention
  nulle côté fournisseur.

## Pipeline IA

1. Le client n'envoie **jamais** de contenu non masqué. Le masquage de référence est côté serveur.
2. Le niveau d'anonymisation retenu, le nombre d'entités masquées et l'empreinte de la requête sont
   journalisés ; le contenu ne l'est pas.
3. Refus d'envoi si des identifiants résiduels sont détectés.
4. Les pièces jointes ne sont jamais transmises au modèle au niveau RPS.
5. Aucune clé de modèle dans le client ; quotas et coûts contrôlés côté serveur (l'écran Configuration IA
   décrit fournisseur, clé et quotas : la clé doit rester serveur, l'écran ne fait que la référencer).
   **Le prototype appelle le modèle depuis la page** — c'est une commodité de démonstration, à remplacer
   par une passerelle serveur.
6. **Filtre de méta-questions** : les questions portant sur l'identité du modèle, le fournisseur, la clé
   d'API, l'hébergement, l'architecture ou la version sont bloquées **avant l'appel** et reçoivent une
   réponse locale. À reproduire côté serveur, avec les motifs versionnés et un test de non-régression.
7. **Double rideau** : le filtre applicatif est la défense principale, le prompt système la sauvegarde.
   Ne jamais compter sur le seul prompt : il est contournable.
8. **Prompts et corpus non exposés** : les quatre prompts système et le corpus injecté (convention,
   extraits du Code du travail, accords, dossiers) doivent être assemblés côté serveur et absents des
   charges utiles du client.
9. **Échec honnête** : en cas d'erreur du modèle, afficher l'erreur ; jamais de repli sur une réponse
   fabriquée localement, qui serait indiscernable d'un avis juridique fondé.

## Fichier des adhérents

L'appartenance syndicale est une donnée sensible au sens de l'article 9 du RGPD ; le fichier est la cible
la plus exposée de l'application.

- Chiffrement au repos, clés hors base applicative ; jamais d'export en clair, jamais de copie locale.
- Accès restreint par rôle : trésorier et administrateurs pour les cotisations, responsables de section
  pour leur seul périmètre. Contrôle **serveur** sur chaque requête, y compris sur les filtres.
- Chaque consultation, export, import et campagne est inscrit au journal d'audit append-only.
- Import CSV : validation serveur (colonnes, e-mails, doublons), import transactionnel, fichier source
  supprimé après traitement, rapport conservé sans données nominatives.
- Campagnes : pas de destinataires en copie visible, lien de désinscription, aucune adresse d'adhérent
  exposée à un autre adhérent.
- Inscription au registre des traitements, durée de conservation liée à l'adhésion, purge à la
  démission avec conservation comptable minimale des seules cotisations.

## Contenu publié (intranet)

- Assainissement du HTML avant publication (liste blanche), interdiction des scripts et des ressources
  tierces.
- Double validation conservée : relecture par un pair, puis envoi au webmaster, avec contrôle des données
  personnelles avant diffusion.

## Robustesse

- Idempotence des actions distantes (envoi, signature, publication) via clé de requête.
- États d'erreur et de reprise explicites sur chaque action ; aucune action silencieuse.
- File d'attente persistante pour les opérations hors ligne, résolution de conflits présentée à
  l'utilisateur.
- Sauvegardes chiffrées, restauration testée, plan de continuité.
- Tests : contrôle d'accès par rôle, masquage (jeu de textes piégés), synchronisation hors ligne,
  parcours kanban au clavier, exports.

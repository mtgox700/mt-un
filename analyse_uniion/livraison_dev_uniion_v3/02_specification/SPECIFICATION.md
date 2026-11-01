# uniion — Spécification fonctionnelle complète

**Référence maquette :** `uniion App v3.dc.html` · **Version du document :** 1.0 · **Date :** 19 octobre 2026
**Périmètre :** application web responsive (poste de travail + mobile) des représentants du personnel et des militants syndicaux, console super administrateur de la plateforme, assistant « unii », extensions.

---

## Sommaire

0. Conventions du document
1. Vision, périmètre, hors périmètre
2. Acteurs, rôles et habilitations
3. Types d'organisation et vocabulaire adaptatif
4. Offres (Élu 1.0 → 4.0) et matrice d'accès
5. Exigences transverses (sécurité, anonymisation, IA, unii, marque, extensions, persistance, accessibilité, responsive)
6. Navigation et gabarit d'écran
7. Écrans et user stories — par module
   - 7.1 Authentification
   - 7.2 Accueil
   - 7.3 Dossiers (Kanban, fiche, coffre, aperçu, assistant du dossier)
   - 7.4 Assistant IA (conversations, dossier guidé, contrôle d'anonymisation, mémoire, sécurité de l'IA)
   - 7.5 Sondages salariés
   - 7.6 Réunions et procès-verbaux
   - 7.7 Agenda
   - 7.8 Documents (bibliothèque, éditeur, générateur IA)
   - 7.9 Signature électronique
   - 7.10 Messages
   - 7.11 Contacts & groupes
   - 7.12 Adhérents / Représentants
   - 7.13 Intranet et site public
   - 7.14 Communication
   - 7.15 Application mobile (pages publiées)
   - 7.16 Formations
   - 7.17 Reporting
   - 7.18 Raccourcis
   - 7.19 Réglages
   - 7.20 Panneau unii et actions d'unii
   - 7.21 Extensions
   - 7.22 Recherche globale et notifications
   - 7.23 Console super administrateur
   - 7.24 Composants transverses (feuilles, modales, toasts, confirmations)
8. Modèle de données fonctionnel
9. Exigences non fonctionnelles
10. Matrice de traçabilité (récapitulatif des US)
11. Glossaire

---

## 0. Conventions du document

- **Identifiant d'US :** `US-<MODULE>-<nn>` (ex. `US-DOS-04`). Chaque US suit le format « En tant que … je veux … afin de … », suivi de ses **critères d'acceptation (CA)** vérifiables.
- **Priorité :** `M` (indispensable au lancement), `S` (souhaitable au lancement), `C` (peut suivre).
- **Offre minimale :** `[1.0]`, `[2.0]`, `[3.0]`, `[4.0]` — l'US n'est disponible qu'à partir de cette formule. Sans mention : toutes formules.
- **Rôle :** quand une US est réservée, le rôle est indiqué entre crochets, ex. `[Admin org]`.
- **Libellés** entre guillemets « » : libellés exacts de l'interface, à conserver.
- **Données de démonstration :** les exemples (Sophie Marchand, section Métallurgie — Valenciennes, NAO 2027, Atelier B…) sont ceux de la maquette ; ils illustrent les règles, ils ne les définissent pas.
- **Toast :** message bref en bas d'écran confirmant une action (« flash »). Toute action d'écriture produit un toast.

---

## 1. Vision, périmètre, hors périmètre

### 1.1 Vision
« L'outil des élus, pas celui de la direction. » uniion réunit dans un seul espace chiffré tout le travail d'un mandat : suivi des demandes des salariés (dossiers), réunions et PV, consultations anonymes, documents et signatures, messagerie, fichier des adhérents, communication (intranet, réseaux, appli mobile), formation, bilan de mandat — avec un assistant juridique IA sourcé sur la convention collective de l'organisation et une anonymisation obligatoire avant tout appel au modèle.

### 1.2 Promesses produit (affichées à la connexion)
1. Dossiers chiffrés de bout en bout, aucun accès employeur.
2. Assistant juridique sourcé sur la convention et le Code du travail.
3. Consultations des salariés anonymes.
4. Bilan de mandat exportable.
5. Hébergement en France / UE, RGPD, chiffrement AES‑256, anonymisation avant inférence IA.

### 1.3 Périmètre
- Application organisation (élus, militants, administrateurs d'organisation).
- Console plateforme (super administrateur uniion), sans accès aux contenus des organisations.
- Assistant contextuel **unii** présent dans chaque module.
- Système d'**extensions** (styles, blocs, thèmes) chargées sans modifier le cœur.

### 1.4 Hors périmètre de cette version
- Application mobile salariés « FO » elle-même (uniion produit les pages et notifications qui y sont publiées, voir 7.15).
- CMS de l'intranet / site public (uniion produit du HTML et le transmet au webmaster, voir 7.13).
- Paiement des cotisations en ligne (uniion enregistre les règlements, il ne les encaisse pas).
- Prestations humaines (pôle communication, consultant Élu 3.0) : uniion collecte la demande, la prestation se fait hors application.

---

## 2. Acteurs, rôles et habilitations

### 2.1 Acteurs

| Acteur | Description | Accès |
|---|---|---|
| Élu·e titulaire | Membre élu du CSE | Application organisation |
| Élu·e suppléant·e | Membre suppléant | Application organisation, droits restreints configurables |
| Secrétaire | Secrétaire du CSE ou de section | Toutes fonctions élu + PV, convocations, bilan |
| Trésorier·e | Trésorier | Toutes fonctions élu + cotisations, relances, budget |
| Délégué·e syndical·e (DS) | Mandat syndical | Toutes fonctions élu + négociation, courriers |
| Élu·e SSCT | Formé santé-sécurité | Mis en avant pour l'assignation des dossiers SSCT |
| Admin organisation | Un ou plusieurs élus administrateurs | + membres, marque, configuration IA, actions d'unii, extensions, back-office |
| Expert externe / Lecture seule | Avocat, expert-comptable (ex. Cabinet Berger) | Lecture seule sur les éléments partagés, suspendable |
| Commission (ex. « Commission ASC ») | Rôle fonctionnel de membre | Accès aux groupes et dossiers de sa commission |
| Super administrateur | Équipe uniion (admin@uniion.fr) | Console plateforme uniquement, aucun contenu d'organisation |
| Webmaster | Destinataire externe des pages intranet | Reçoit des demandes de publication, répond (hors application) |
| Salarié / adhérent | Bénéficiaire | Ne se connecte pas : vote aux sondages, reçoit messages, pages et notifications |

### 2.2 Rôles unii (utilisés pour filtrer les actions d'unii)
`secretaire` Secrétaire · `tresorier` Trésorier·e · `titulaire` Élu·e titulaire · `suppleant` Élu·e suppléant·e · `ds` Délégué·e syndical·e · `ssct` Élu·e SSCT. Un utilisateur peut cumuler plusieurs rôles (ex. « Déléguée syndicale · Secrétaire de section »).

### 2.3 Règles d'habilitation
- **H1** — Le super administrateur n'a aucun accès aux dossiers, messages, pièces, documents, adhérents des organisations. Ses actions sont tracées.
- **H2** — Les données d'une organisation sont strictement cloisonnées des autres organisations et de l'employeur.
- **H3** — La MFA est obligatoire pour les rôles administrateur.
- **H4** — Le statut d'un membre est : Actif · Invité (jamais connecté) · Suspendu. Un compte suspendu ne peut plus se connecter ; ses contenus sont conservés.
- **H5** — Les statistiques nominatives d'usage (« Élus les plus actifs ») ne sont visibles que des administrateurs de l'organisation.
- **H6** — La visibilité d'un événement d'agenda est : Élus seulement · Élus et adhérents · Tous les salariés (libellés adaptés au type d'organisation, cf. §3).

---

## 3. Types d'organisation et vocabulaire adaptatif

L'organisation choisit sa **nature** dans Réglages › Informations de l'organisation. Ce choix adapte le vocabulaire et certaines fonctions dans toute l'application.

| Clé | CSE | Section syndicale | Union départementale |
|---|---|---|---|
| Description | Instance élue de l'entreprise | Section d'entreprise ou d'établissement | Structure interprofessionnelle |
| Personnes | Élus | Militants | Militants |
| Module « membres » | « Représentants » / « Représentants du personnel » | « Adhérents » | « Adhérents » |
| Séance type | Réunion CSE / Réunion plénière | Réunion de section | Assemblée générale |
| Permanence | Permanence des élus | Permanence syndicale | Permanence syndicale |
| Onglet argent | « Budget » (pas de cotisations) | « Cotisations » | « Cotisations » |
| Fichier d'adhésion | Non : listes de convocation et d'information | Oui | Oui |
| Temps forts communication | PV plénière, billetterie ASC, chèques Noël, journée bien-être, NAO, bilan ASC, aides de rentrée, élections | CR réunion CSE, NAO, campagne d'adhésion, permanence, AG de section, « une question, une réponse », élections | idem section |
| Import | « Importer des représentants » | « Importer des adhérents » | idem |

**US-ORG-01 (M)** — En tant qu'admin organisation, je choisis la nature de mon organisation (CSE, Section syndicale, Union départementale) afin que l'application parle mon vocabulaire.
CA : (1) le choix est visible avec sa note explicative ; (2) après enregistrement, menus, titres, libellés de visibilité, temps forts et onglets s'adaptent sans rechargement ; (3) en CSE, l'onglet Cotisations est remplacé par l'absence de suivi de cotisations et la note « Le CSE ne tient pas de fichier d'adhésion… » apparaît dans Listes de diffusion.

---

## 4. Offres et matrice d'accès

### 4.1 Formules
| Formule | Prix HT / mois | Promesse | Contenu |
|---|---|---|---|
| Élu 1.0 | 99 € | L'essentiel pour structurer votre activité d'élu | Gestion des demandes (Kanban), agenda partagé, base documentaire, 5 dossiers inclus* |
| Élu 2.0 (Populaire) | 199 € | La puissance de l'IA pour augmenter votre expertise | Tout 1.0 + Assistant IA, génération de courriers, analyse juridique instantanée, **unii**, propositions de style de document |
| Élu 3.0 | 499 € | Un expert humain dédié | Tout 2.0 + consultant dédié, relecture stratégique, assistance négociation, conditions préférentielles pôle communication |
| Élu 4.0 | 999 € | La solution complète | Tout inclus, support prioritaire 24/7, formation sur site, API & intégrations, conditions préférentielles pôle communication |

\* Au-delà, 9 € HT par dossier supplémentaire. Prix HT, TVA 20 %. Résiliation à tout moment, effet en fin de période.
Migration des anciennes offres : Standard → Élu 2.0 ; Fédéral → Élu 4.0 ; Essai → Élu 1.0.

### 4.2 Règles de gating
- **G1** — unii (panneau, pastilles, actions, propositions de style) est disponible à partir d'Élu 2.0. En Élu 1.0, le panneau unii affiche « À partir d'Élu 2.0 — unii vous accompagne dans chaque module » avec le bouton « Voir les formules ».
- **G2** — Les parcours de formation recommandés sont alignés sur les niveaux Élu 1.0 (Découverte), 2.0 (Augmenté), 3.0 (Stratège), 4.0 (Orchestrateur).
- **G3** — Le dépassement du quota de dossiers inclus est facturé ; l'utilisateur est informé avant la création du dossier excédentaire.
- **G4** — Le quota IA est mutualisé à l'organisation (ex. « 84,20 € / 150 € de quota »).

---

## 5. Exigences transverses

### 5.1 Sécurité et confidentialité
- **SEC-01** Chiffrement au repos (AES‑256) et en transit ; messages chiffrés de bout en bout (« Ni l'employeur ni uniion ne peuvent les lire »).
- **SEC-02** Hébergement en France / UE ; aucun accès employeur.
- **SEC-03** Journal d'audit organisation : accès aux dossiers, générations de documents, dépôts de pièces, changements de rôle — date, action, auteur. Export CSV.
- **SEC-04** Journal d'audit plateforme : chaîne d'empreintes inaltérable, conservation 36 mois, export CSV signé.
- **SEC-05** Durées de conservation : dossiers clos 5 ans ; messages chiffrés 2 ans ; logs d'usage IA 12 mois ; votes de sondage anonymes et non liés ; audio de réunion détruit à l'approbation du PV ou à 30 jours (au premier des deux) ; exports disponibles 30 jours ; corbeille documents 30 jours.
- **SEC-06** Journal d'accès aux dossiers conservé 5 ans (audit RGPD).
- **SEC-07** Déconnexion : purge du cache local chiffré.
- **SEC-08** Gestion des appareils connectés : liste et déconnexion à distance.
- **SEC-09** Les clés API IA ne quittent jamais la passerelle serveur ; affichage et copie tracés ; jamais réaffichées en clair après enregistrement côté organisation.
- **SEC-10** Le HTML produit pour les sites ne contient ni script ni style en ligne.
- **SEC-11** Aucun numéro de carte stocké : paiement par prestataire européen conforme DSP2.

### 5.2 Anonymisation avant inférence (règle cardinale)
Tout texte envoyé à un modèle de langage passe par une **anonymisation locale**. Le modèle ne reçoit qu'un payload masqué ; les identités sont **recollées côté client** après réponse.

**Niveaux :**
| Niveau | Cas d'usage | Masquage | Pièces jointes | Envoi en clair |
|---|---|---|---|---|
| Standard | NAO, budget, articles | Léger (matricules) | Résumé de pièce autorisé | Possible après confirmation |
| RH sensible | Inaptitude, discipline, sanction, licenciement, reclassement, médical | Nominatif + matricules | Pièces bloquées, résumé masqué | Possible après confirmation |
| RPS | Harcèlement, souffrance au travail, moral, burn-out | Maximal (noms, service, établissement, élu rédacteur) | Pièces bloquées | **Interdit** |

**Règles :**
- **ANO-01** Détection automatique du niveau à partir du texte (mots-clés ci-dessus) et, pour un dossier, de sa catégorie, son titre et sa description. L'utilisateur peut **relever** le niveau, jamais l'abaisser sous le niveau détecté pour RPS.
- **ANO-02** Remplacement des identifiants par des jetons typés : `[SALARIÉE A]`, `[MATRICULE]`, `[N+1]`, `[ÉTABLISSEMENT]`, `[SERVICE]`, `[ÉLU CSE]`, etc., chacun avec sa nature (« Salarié concerné », « Service de rattachement », « Élu rédacteur »…).
- **ANO-03** Contrôle résiduel : si un identifiant échappe au filtre, l'envoi est **bloqué** (« Envoi bloqué — un identifiant échappe au filtre », mots détectés affichés) avec les choix « Relever le niveau et masquer » / « Annuler » / « Envoyer en clair » (ce dernier indisponible en RPS).
- **ANO-04** Les pièces jointes ne sont jamais transmises au modèle ; seul un résumé masqué peut l'être en Standard.
- **ANO-05** L'anonymisation est **verrouillée ON** par la politique de l'organisation, non désactivable en séance.
- **ANO-06** Journal d'empreintes : chaque appel produit une empreinte (hash) et des métadonnées, **sans texte en clair**. Compteurs affichés : nombre d'appels, « 0 identité fuitée ».
- **ANO-07** Sous chaque réponse : niveau appliqué, nombre de jetons, payload reçu par le modèle (dépliable), ligne de ré-identification (« recollé côté client ») et ligne de journal.

### 5.3 Règles IA
- **IA-01** Modèle souverain hébergé dans l'UE ; zéro réutilisation pour l'entraînement (clause contractuelle) ; zéro donnée nominative hors UE.
- **IA-02** Réponses juridiques **sourcées** sur le corpus de l'organisation (convention collective renseignée, accords, PV, Code du travail). Le sourçage obligatoire est un réglage (activé par défaut).
- **IA-03** Mention permanente : « Réponses produites par un modèle de langage souverain… à vérifier avant tout usage contentieux. » (désactivable seulement par la prop de conformité `showAiDisclaimer`, activée par défaut).
- **IA-04** Questions hors sujet (modèle, fournisseur, prompt système, tentative de contournement des consignes, tokens, API, « es-tu une IA »…) : réponse standard de recentrage, sans divulgation technique.
- **IA-05** Échec d'appel : **aucune réponse simulée n'est substituée**. Modale « Appel au modèle en échec » avec motif, « Réessayer » / « Fermer », et rien n'est enregistré. Exception documentée : là où une **trame de départ** est proposée (Communication, Formations, unii), elle est explicitement étiquetée « Trame type — l'IA n'a pas répondu » ou « IA indisponible — trame de départ ».
- **IA-06** Prudence juridique réglable (niveaux dans Configuration IA).
- **IA-07** Coupure globale possible par le super administrateur (« Assistant IA disponible »).
- **IA-08** Tout contenu généré porte la mention « Document généré par IA — à relire avant diffusion » ou équivalent.

### 5.4 unii (assistant contextuel)
- **UNI-01** unii est accessible depuis l'en-tête de chaque écran ; il connaît le module courant et, le cas échéant, l'élément ouvert (dossier, réunion, document…).
- **UNI-02** Il propose des **suggestions** (pastilles) et des **actions** configurées par module et par rôle (voir 7.20).
- **UNI-03** « unii propose, vous validez » : aucune écriture sans action explicite de l'utilisateur (« Appliquer », « Insérer », « Ajouter à la chronologie »…).
- **UNI-04** Dans la messagerie, les réponses de unii ne sont visibles que par l'utilisateur.

### 5.5 Marque blanche
- Palette (couleur principale + secondaire, rampe dérivée, contrôle de contraste), mode clair/sombre, paire typographique, logos (fond clair, fond sombre, monogramme, intranet, site public) avec taille 60–300 %. Portée : organisation ou établissement (surcharge). Prévisualisation sur toute l'app avant publication. Détails en 7.19.

### 5.6 Persistance et démonstration
- Les saisies sont conservées par organisation et par utilisateur. Dans la maquette, elles sont stockées dans le navigateur ; « Réinitialiser la démonstration » restaure le jeu d'exemple. En production : base serveur chiffrée.

### 5.7 Suppression
- **DEL-01** Toute suppression demande une **confirmation en deux temps** (le bouton passe à « Confirmer ? » / « Supprimer ? Oui · Non »).
- **DEL-02** Documents supprimés : récupérables 30 jours dans la corbeille.

### 5.8 Accessibilité
- WCAG 2.1 AA : contraste texte 4,5:1, focus visible (contour 2,5 px), navigation clavier complète (y compris Kanban : sélection d'une carte, ← → pour déplacer, Espace pour déposer), respect de `prefers-reduced-motion`, cibles tactiles ≥ 44 px, rôles ARIA sur dialogues.

### 5.9 Responsive
- Poste de travail : barre latérale gauche + contenu. Mobile : en-tête compact + barre de navigation inférieure (sous-ensemble des modules marqués « mobile »). Les grilles se réorganisent en une colonne. Impression : seuls les documents sont imprimés (`#docPrint`), un document par page.

### 5.10 Hors ligne
- La base documentaire (convention, Code du travail, accords, PV, règlement intérieur) est consultable hors ligne, chiffrée sur l'appareil, avec synchronisation intelligente (voir 7.19.12).

---

## 6. Navigation et gabarit d'écran

### 6.1 Modules de la barre latérale (ordre par défaut)
Accueil · Assistant · Dossiers · Messages · Agenda · Réunions · Documents · Formations · Communication · Application mobile · Adhérents/Représentants · Intranet · Reporting · Raccourcis · Réglages.
Bloc bas de barre : « Assistant IA — Une question de droit ? — Ouvrir le chat » ; carte utilisateur (initiales, nom, fonction).

### 6.2 En-tête
Logo de marque · champ de recherche globale · cloche de notifications (pastille si non lues) · bouton **unii** (pastille du nombre de suggestions) · avatar. Sur sous-écran : « ← Retour » (pile d'historique).

### 6.3 US navigation
**US-NAV-01 (M)** — En tant qu'utilisateur, je navigue entre les modules depuis la barre latérale (poste) ou la barre inférieure (mobile).
CA : l'élément actif est mis en évidence ; le titre et le contenu changent sans rechargement ; l'URL / l'état restaure l'écran au retour.

**US-NAV-02 (M)** — Je reviens à l'écran précédent avec « ← Retour ».
CA : retour sur l'écran exact d'origine (pile d'historique), y compris depuis la recherche.

**US-NAV-03 (S)** — En tant qu'utilisateur, je réordonne les modules du menu (Réglages › Ordre du menu de gauche).
CA : flèches monter/descendre par module avec son rang ; l'ordre s'applique aussitôt à la barre latérale et à la barre mobile ; indicateur des modules présents sur mobile ; « Réinitialiser » restaure l'ordre par défaut avec toast.

**US-NAV-04 (S)** — Un bandeau d'information plateforme publié par le super administrateur s'affiche en haut de l'application pour tous les utilisateurs.

---

## 7. Écrans et user stories

### 7.1 Authentification

**Écran « Connexion »** — Deux colonnes sur poste (panneau de marque à gauche : nom du produit, promesse, trois garanties ; formulaire à droite), une colonne sur mobile.

Éléments : titre « Connexion », sous-titre « Compte militant de la <organisation> », champs « Adresse professionnelle », « Mot de passe », bouton « Continuer », séparateur « ou », bouton « SSO fédération (SAML) », lien « Mot de passe oublié ? », lien « Accès super administrateur (admin@uniion.fr) ».

**Écran « Redirection SSO »** — « Authentification déléguée à l'annuaire de la fédération. Aucun mot de passe n'est stocké par uniion. » Fournisseur d'identité affiché (ex. idp.federation-metallurgie.fr), « Assertion SAML 2.0 signée · attributs mandat et établissement transmis. » Boutons « S'authentifier sur l'annuaire », « Revenir au mot de passe ».

**Écran « Vérification en deux étapes »** — Indication du canal (`authMfaHint`), saisie de code à 6 cases, message d'erreur, « Vérifier et ouvrir la session », « Renvoyer un code », « Utiliser une clé de sécurité », « Changer de compte ». Pour le compte plateforme : « Compte plateforme — la session ouvrira la console d'administration, sans accès aux contenus des organisations. »

**US-AUTH-01 (M)** — En tant qu'élu, je me connecte avec mon adresse professionnelle et mon mot de passe.
CA : champs obligatoires ; message d'erreur explicite en cas d'échec sans révéler si l'adresse existe ; après succès, passage à l'étape MFA.

**US-AUTH-02 (M)** — Je valide la connexion par un code à usage unique (MFA).
CA : 6 caractères, saisie case par case avec avance automatique et collage ; code faux → erreur et cases vidées ; « Renvoyer un code » ; succès → ouverture sur l'Accueil, toast « Session ouverte — appareil de confiance enregistré ».

**US-AUTH-03 (S)** — J'utilise une clé de sécurité (WebAuthn/FIDO2) comme second facteur.

**US-AUTH-04 (M)** — Je me connecte via le SSO de ma fédération (SAML 2.0 ; OIDC activable en réglages).
CA : écran de redirection explicite ; attributs mandat et établissement récupérés ; aucun mot de passe stocké.

**US-AUTH-05 (M)** — Je réinitialise mon mot de passe.
CA : feuille « Réinitialiser le mot de passe » ; choix du canal (Email professionnel / SMS — appareil de confiance, avec adresse ou numéro masqué) ; lien à usage unique valable 30 minutes ; confirmation « Lien envoyé » ; envoi consigné au journal d'audit ; bouton « Revenir à la connexion ».

**US-AUTH-06 (M)** — En tant que super administrateur, je me connecte (admin@uniion.fr + MFA) et j'arrive sur la Console d'administration.
CA : aucune route organisation accessible depuis cette session.

**US-AUTH-07 (M)** — Je change de compte depuis l'étape MFA.

**US-AUTH-08 (M)** — En tant qu'utilisateur, je me déconnecte (Réglages › Session).
CA : purge du cache local chiffré ; retour à l'écran de connexion.

**US-AUTH-09 (S)** — J'active le verrouillage biométrique à l'ouverture de l'app (Face ID / empreinte) sur mobile.

---

### 7.2 Accueil

**Contenu :**
1. Salutation « Bonjour, <prénom> » + ligne de synthèse « <organisation> · N dossiers ouverts, 1 échéance légale cette semaine ».
2. Carte **unii suggère** (Élu 2.0+) : suggestions contextuelles cliquables, compteur.
3. **Alerte urgente** (ex. « Urgent · il y a 10 min · Accident Atelier B · Enquête CSSCT déclenchée. Accusé de réception attendu sous 4 h. ») — ouvre le dossier.
4. **Sondage en cours** (ex. « Sondage NAO en cours · Priorités salariales 2027 · 75 % de participation ») — ouvre les résultats.
5. **Actions rapides** (`qa`) : raccourcis vers Nouveau dossier, Assistant, Nouveau sondage, Enregistrer une réunion, Générer un document…
6. **Mes dossiers** (liste courte, « Tout voir »).
7. **Agenda partagé — Prochaines échéances** (date, titre, méta).
8. **Bibliothèque** : accès aux documents de référence (ouvre l'Aperçu de document, cf. 7.8.5).

**US-ACC-01 (M)** — En tant qu'élu, je vois dès l'ouverture les urgences, mes dossiers et les prochaines échéances afin de prioriser ma journée.
CA : dossiers triés par urgence/échéance ; clic sur un élément → écran détaillé ; compteurs cohérents avec les modules.

**US-ACC-02 (M)** — Je suis alerté d'un événement urgent (accident du travail, droit d'alerte) avec son délai de réponse.
CA : carte rouge en tête ; accusé de réception ; escalade automatique si sans accusé sous 4 h (si activée).

**US-ACC-03 (S)** — Je vois la participation au sondage en cours et j'accède aux résultats.

**US-ACC-04 (S) [2.0]** — unii me propose ce qui mérite mon attention (échéance proche, brouillon à relire, messages non lus) ; actions « Faire le point de la semaine » et « Par quoi commencer ? ».

**US-ACC-05 (S)** — Je lance une action fréquente en un clic depuis les actions rapides.

---

### 7.3 Dossiers

#### 7.3.1 Écran « Gestion de projet — Suivi des demandes » (Kanban)
En-tête : « N dossiers · 2 échéances légales · mandat de déléguée syndicale » ; aide « Glissez une carte pour changer son état — ou sélectionnez-la et utilisez ← → » ; bouton « + Nouveau dossier ».
Colonnes : **À traiter** · **En cours** · **Terminé**, chacune avec compteur.
Carte : catégorie (tag coloré), titre, description courte, référent (initiales), échéance (ex. J−3), pastille unii (`uniiTip`). Carte sélectionnée : zone d'analyse IA (niveau d'anonymisation, réponse sourcée, suggestions, mention de confidentialité, bouton « Analyse complète »). Zone de dépôt vide : « Déposez un dossier ici ».
Catégories : Juridique, SSCT, Négociation, ASC, Formation (extensibles).

**US-DOS-01 (M) [1.0]** — En tant qu'élu, je visualise tous les dossiers de l'organisation par état.
CA : 3 colonnes avec compteurs ; dossiers clos en « Terminé » ; seuls les élus voient les dossiers.

**US-DOS-02 (M)** — Je change l'état d'un dossier par glisser-déposer.
CA : aperçu flottant de la carte pendant le glisser ; zone de dépôt surlignée ; toast de confirmation ; entrée datée ajoutée à l'historique.

**US-DOS-03 (M)** — Je change l'état au clavier.
CA : sélection de la carte (Entrée/Espace) → annonce « Carte saisie — ← → pour déplacer, Espace pour déposer » ; ← → change de colonne ; Espace dépose ; Échap annule.

**US-DOS-04 (S) [2.0]** — Je sélectionne une carte pour obtenir une analyse IA courte anonymisée, puis « Analyse complète » ouvre l'Assistant avec le contexte du dossier.

**US-DOS-05 (S) [2.0]** — unii priorise mes dossiers (« Prioriser mes dossiers »).

#### 7.3.2 Feuille « Nouveau dossier »
Bandeau « Visible uniquement des élus. Données minimisées (RGPD). » Champs : Intitulé, Catégorie (choix), Contexte. Bouton « Créer le dossier ».

**US-DOS-06 (M)** — Je crée un dossier avec intitulé, catégorie et contexte.
CA : intitulé obligatoire ; le dossier arrive en « À traiter » ; référent = créateur ; première entrée d'historique ; rappel de minimisation ; si quota de l'offre dépassé, information du coût (9 € HT) avant création.

**US-DOS-07 (S) [2.0]** — Je crée un dossier à partir d'une conversation de l'Assistant, d'un message ou d'un dossier guidé (voir 7.4, 7.10) : unii propose titre, catégorie, échéance et plan d'action.

#### 7.3.3 Fiche dossier
Contenu : tag, titre, description longue ; « Modifier le dossier » (Intitulé, Description, Échéance, « Terminer la modification ») ; suppression avec confirmation ; Échéance, Statut, Référent ; **Historique** (date, titre, corps) avec saisie « Ajouter » ; **Actions** : « Analyser sans identité → » (avec niveau d'anonymisation et note), « Générer un courrier à la direction », « Pièces jointes (N) », bouton d'avancement d'état (`advanceLabel`) ; **Assistant du dossier** (chat contextuel « Contexte chargé », « Mode assistant », suggestions, mention de confidentialité, « Analyse complète → ») ; **Assigner à un élu** (« Seuls les élus formés SSCT apparaissent en gras ») ; **Cloisonnement** (« Ce dossier est chiffré et invisible pour l'employeur. Journal d'accès conservé 5 ans »).

**US-DOS-08 (M)** — J'ouvre un dossier et je vois toutes ses informations, son historique et ses pièces.
CA : l'ouverture est consignée au journal d'accès.

**US-DOS-09 (M)** — Je modifie l'intitulé, la description et l'échéance.
CA : édition en place ; « Terminer la modification » enregistre ; toast.

**US-DOS-10 (M)** — J'ajoute une entrée datée à l'historique (note, appel, rendez-vous…).
CA : date du jour par défaut ; entrée en tête de liste ; vide refusé.

**US-DOS-11 (M)** — Je fais avancer le dossier à l'état suivant (À traiter → En cours → Terminé) depuis la fiche.

**US-DOS-12 (M)** — J'assigne le dossier à un élu référent.
CA : liste des élus avec initiales et rôle ; élus formés SSCT en gras ; un seul référent ; entrée d'historique.

**US-DOS-13 (M)** — Je supprime un dossier.
CA : confirmation en deux temps ; trace d'audit ; dossier retiré du Kanban.

**US-DOS-14 (M) [2.0]** — J'analyse le dossier sans identité : passage par le Contrôle d'anonymisation (7.4.3) avec le niveau détecté pour ce dossier.

**US-DOS-15 (M) [2.0]** — Je génère un courrier à la direction à partir du dossier.
CA : ouvre le Générateur de documents prérempli (type Courrier, points clés issus du dossier) ; prompt anonymisé ; signature recollée localement.

**US-DOS-16 (S) [2.0]** — Je discute avec l'assistant du dossier (contexte chargé : catégorie, chronologie, pièces résumées selon niveau).
CA : réponses sourcées ; bascule « Mode assistant » vers l'Assistant plein écran en conservant le contexte.

**US-DOS-17 (S) [2.0]** — unii propose la suite à donner, résume la chronologie, vérifie les délais légaux, rédige un courrier (rôles titulaire, DS, secrétaire) ; je peux appliquer la proposition à l'historique.

#### 7.3.4 Coffre du dossier — Pièces jointes
Contenu : résumé (`piecesSummary`), zone « Déposer un document » (PDF, image, audio · 25 Mo max · chiffré à l'envoi) avec barre de progression (nom, %, statut) ; liste des pièces (extension, nom, méta, version) ; état vide « Aucune pièce pour l'instant. Les documents déposés ici sont chiffrés et invisibles pour l'employeur. » ; détail d'une pièce : « Ouvrir l'aperçu », **Versions** (libellé, méta, action), « Déposer une nouvelle version », « Joindre à un courrier », « Supprimer la pièce » ; **Traçabilité** : « Chaque dépôt, ouverture et suppression est horodaté… durée de conservation du dossier (5 ans) ».

**US-PCE-01 (M)** — Je dépose une pièce dans le coffre d'un dossier.
CA : formats PDF, image, audio ; refus > 25 Mo avec message ; chiffrement avant envoi ; progression visible ; nouvelle pièce en v1 ; trace d'audit.

**US-PCE-02 (M)** — Je dépose une nouvelle version d'une pièce.
CA : numéro de version incrémenté ; anciennes versions listées et consultables.

**US-PCE-03 (M)** — J'ouvre l'aperçu chiffré d'une pièce.
CA : modale « Aperçu chiffré » ; « Consultation tracée dans le journal d'audit du dossier — déchiffrement local, aucun envoi au serveur » ; actions « Faire signer », « Fermer ».

**US-PCE-04 (S)** — Je joins une pièce à un courrier généré.

**US-PCE-05 (M)** — Je supprime une pièce (confirmation, trace).

**US-PCE-06 (M)** — Les pièces ne sont jamais envoyées au modèle IA (ANO-04).

---

### 7.4 Assistant IA [2.0]

#### 7.4.1 Écran « Assistant IA — Votre expert juridique de poche »
Sous-titre « Sourcé sur la <Convention> et le Code du travail ». Modes d'affichage : intégré ou **plein écran** (`asst.fullLabel`). Bandeau d'origine quand ouvert depuis un module (« ← Retour à <module> », titre de conversation). Indicateur mémoire (`memShort`). Lien vers dossier associé.
Barre d'actions : « Nouvelle conversation », « Nouveau dossier guidé ». **Historique** : compteur, filtres par origine (`fl`), liste (titre, origine, quand, nombre de messages), suppression, état vide « Aucune conversation pour ce filtre. »
Zone de conversation : en-tête « uniion Assistant · Aucune identité transmise » ; sélecteur **Niveau d'anonymisation** (Standard / RH sensible / RPS) ; messages utilisateur ; réponses avec bloc « Reçu par le modèle » (niveau · nb de jetons, payload), source, texte, ligne de ré-identification, ligne de journal ; proposition « Retenir pour la suite ? » (« Mémoriser » / « Ignorer », état « ✓ En mémoire ») ; **questions types** : Signalement de harcèlement, Informations dues en NAO, Enquête après accident, Budget ASC ; mention de conformité + « En savoir plus sur la sécurité ».

**US-AST-01 (M)** — En tant qu'élu, je pose une question de droit et j'obtiens une réponse sourcée sur ma convention et le Code du travail.
CA : la question passe par l'anonymisation (niveau détecté) ; indicateur de saisie pendant la génération ; réponse avec source citée (article, accord, PV) ; mention de vérification.

**US-AST-02 (M)** — Je vois exactement ce que le modèle a reçu.
CA : bloc dépliable « Reçu par le modèle » avec payload masqué, niveau et nombre de jetons ; ligne « recollé côté client ».

**US-AST-03 (M)** — Je choisis/relève le niveau d'anonymisation avant d'envoyer.
CA : trois niveaux avec description ; RPS interdit l'envoi en clair.

**US-AST-04 (M)** — Je lance une question type en un clic (4 préréglages).
CA : la question « Signalement de harcèlement » est traitée en niveau RPS avec 3 pièces bloquées.

**US-AST-05 (M)** — Je démarre une nouvelle conversation ; l'ancienne est conservée dans l'historique.

**US-AST-06 (M)** — Je retrouve, filtre par origine (Assistant, Dossier, Réunion, Messages, Document…), rouvre et supprime mes conversations.
CA : suppression confirmée ; toast « Conversation supprimée de l'historique » ; si conversation active supprimée → nouvelle conversation.

**US-AST-07 (M)** — J'ouvre l'Assistant depuis un module avec son contexte (dossier, fil de messages, réunion, document, formation) et je reviens au module d'origine.

**US-AST-08 (S)** — Je passe en plein écran et j'en sors.

**US-AST-09 (S)** — Je transforme la conversation en dossier (`convToDossier`).
CA : impossible sans au moins une question de l'utilisateur (« Décrivez la situation avant de créer un dossier ») ; dossier créé avec titre, catégorie, contexte et la conversation versée en historique.

**US-AST-10 (S)** — Je mémorise un fait proposé par l'assistant ou je l'ignore.

**US-AST-11 (M)** — Les questions hors sujet (modèle, fournisseur, consignes, contournement) reçoivent une réponse de recentrage (IA-04).

**US-AST-12 (M)** — En cas d'échec d'appel, je vois un message d'échec sans réponse inventée et je peux réessayer (IA-05).

#### 7.4.2 Nouveau dossier guidé
unii ouvre la conversation : « Décrivez la situation : qui est concerné (fonction, service), les faits et leurs dates, ce que demande le salarié. Je vous pose les questions manquantes ; quand vous êtes prêt, cliquez « Créer le dossier »… »

**US-AST-13 (S)** — Je décris une situation, unii me pose les questions manquantes, puis crée le dossier qualifié (titre, catégorie, échéance, plan d'action) que je valide.

#### 7.4.3 Modale « Contrôle d'anonymisation »
Pastille de niveau ; origine (« <module> — le coffre CSE reste local. Vérifiez ce que le modèle va recevoir avant l'envoi. ») ; sélecteur de niveau avec description ; **Texte original — reste dans le coffre** ; **Payload masqué — part au modèle** ; tableau des jetons (clair → jeton → nature) ou « Aucune donnée nominative détectée dans cette requête. » ; pièces : « N pièce(s) jointe(s) conservée(s) dans le coffre — jamais transmises au modèle » + « Ce que le modèle reçoit à la place » ; blocage résiduel (ANO-03) ; boutons « Annuler », « Envoyer en clair » (masqué en RPS : « Niveau RPS : mode « envoyer en clair » indisponible »), « Confirmer l'envoi au modèle ».

**US-ANO-01 (M)** — Avant un appel IA sur contenu sensible, je relis le texte original et le payload masqué côte à côte, puis je confirme.
**US-ANO-02 (M)** — Je change le niveau dans la modale et le payload se recalcule instantanément.
**US-ANO-03 (M)** — Si un identifiant subsiste, l'envoi est bloqué et je peux relever le niveau en un clic.
**US-ANO-04 (M)** — En RPS, l'envoi en clair est impossible.
**US-ANO-05 (M)** — Chaque envoi incrémente le compteur d'appels et ajoute une empreinte au journal.

#### 7.4.4 Écran « Mémoire de l'assistant »
Texte : « Les faits retenus ici accompagnent chaque question posée à l'IA… restent dans ce navigateur, sont anonymisés avant envoi et ne sont jamais cités comme source juridique. » Interrupteur « Utiliser la mémoire dans les réponses » + ligne d'état ; « Ajouter un élément » (catégorie + texte, « Ajouter à la mémoire ») ; éléments groupés par catégorie avec compteur, méta (origine, date), « Modifier » / « Oublier » / « Enregistrer » / « Annuler » ; état vide ; « Tout oublier » (confirmation).

**US-MEM-01 (S)** — J'active/désactive l'usage de la mémoire.
**US-MEM-02 (S)** — J'ajoute manuellement un fait (catégorie au choix).
CA : doublon refusé (fait déjà présent).
**US-MEM-03 (S)** — Je modifie ou oublie un fait.
**US-MEM-04 (S)** — J'efface toute la mémoire (confirmation).
**US-MEM-05 (M)** — La mémoire est anonymisée avant envoi et jamais citée comme source.

#### 7.4.5 Écran « Sécurité, anonymisation et conformité » (documentation)
Sections : ce que l'application met en œuvre, ce qui est garanti par contrat, ce qui reste de la responsabilité de l'élu (cartes titre + note + items) ; **Documentation de référence** : Registre des traitements, Analyse d'impact (AIPD), Contrat de sous-traitance du modèle, Politique de conservation et de purge, Procédure d'exercice des droits (« réception, qualification, réponse sous un mois »), Journal d'audit — spécification (« événements tracés, format, durée de trois ans ») ; « Écrire au délégué à la protection des données ».

**US-AST-14 (M)** — Depuis tout lien « En savoir plus sur la sécurité », j'accède à la documentation de sécurité de l'IA.
**US-AST-15 (S)** — Je demande une pièce de référence ou j'écris au DPO.
CA : toast « Demande adressée au délégué à la protection des données de la fédération ».

---

### 7.5 Sondages salariés (« Démocratie sociale »)

#### 7.5.1 Écran « Sondages salariés »
En-tête « Votes anonymes · N salariés inscrits », bouton « + Lancer un sondage ». Liste : statut (En cours / Clos / Brouillon), titre, méta (réponses / inscrits, anonymat, clôture), barre de participation, suppression. **Résultats** du sondage sélectionné : titre, méta, barres par réponse (libellé, %), **encadré d'analyse** (titre + insight), « Générer le tract → », « Relancer les non-répondants », encart « Anonymat garanti — Aucun lien technique n'est conservé entre l'identité du votant et son choix. »

**US-SDG-01 (M)** — Je consulte la liste des sondages et leur participation.
**US-SDG-02 (M)** — Je consulte les résultats en pourcentage et une lecture synthétique.
**US-SDG-03 (S) [2.0]** — Je génère un tract à partir des résultats (ouvre le Générateur avec les chiffres en points clés).
**US-SDG-04 (S)** — Je relance les non-répondants (notification push).
CA : la relance ne révèle pas qui a voté ; toast avec le nombre de relancés.
**US-SDG-05 (M)** — Je supprime un sondage (confirmation).
**US-SDG-06 (S) [2.0]** — unii analyse les résultats et rédige des questions neutres.

#### 7.5.2 Écran « Nouveau sondage » (assistant en 3 étapes)
Étapes : **1. Question & réponses** · **2. Cible & clôture** · **3. Relecture & diffusion**. Bandeau « Vote anonyme, une seule réponse par salarié. Aucune donnée nominative n'est conservée. »
- Étape 1 : « Question posée aux salariés » ; « Type de réponse » (Choix unique / Choix multiples / Oui / Non) ; « Réponses proposées » (numérotées, « + Ajouter une réponse ») ; « Propositions de l'assistant ».
- Étape 2 : « Cible » (Tous les salariés · Site de … · Ouvriers et employés · Adhérents du syndicat · Élus et représentants — avec effectif) ; canal (Notification mobile · Email + QR code atelier · Les deux) ; « Clôture du vote » (48 heures · 7 jours · 14 jours) + aide ; « Vote strictement anonyme — Imposé par la configuration de l'organisation » (Verrouillé) ; « Relance automatique — Rappel push aux non-répondants à 48 h de la clôture ».
- Étape 3 : **Aperçu côté salarié** (« Tel qu'il apparaîtra dans l'app et sur l'affichage QR code ») ; **Contrôles de conformité** (Question claire et non orientée · Anonymat garanti · Base légale : intérêt légitime — chaque contrôle ✓/✗ avec détail) ; **Modération** : relecteurs (initiales, nom, état), « Envoyer en relecture », « Relancer les relecteurs » ; « Diffuser à N salariés ».
- Pied : « ← Étape précédente », bouton suivant, « Enregistrer le brouillon ».

**US-SDG-07 (M)** — Je rédige une question et ses réponses, et je choisis le type de réponse.
CA : au moins 2 réponses pour choix unique/multiple ; Oui/Non génère les deux réponses ; réponses vides ignorées.
**US-SDG-08 (S) [2.0]** — L'assistant me propose des réponses et des reformulations neutres ; je les ajoute en un clic.
**US-SDG-09 (M)** — Je choisis la cible, le canal et la durée de vote.
CA : effectif cible affiché et repris dans le bouton de diffusion ; date de clôture calculée affichée.
**US-SDG-10 (M)** — Le vote est obligatoirement anonyme ; l'option est verrouillée.
**US-SDG-11 (S)** — J'active la relance automatique à 48 h de la clôture.
**US-SDG-12 (M)** — Je prévisualise le sondage tel que le salarié le verra.
**US-SDG-13 (M)** — Les contrôles de conformité sont calculés ; une question orientée est signalée.
**US-SDG-14 (S)** — J'envoie le sondage en relecture à d'autres élus et je les relance.
**US-SDG-15 (M)** — Je diffuse le sondage.
CA : statut « En cours » ; apparaît en tête de liste et sur l'Accueil ; toast ; QR code disponible pour affichage atelier.
**US-SDG-16 (M)** — J'enregistre un brouillon et je le reprends plus tard.
**US-SDG-17 (M)** — Chaque salarié ne vote qu'une fois ; aucun lien identité ↔ choix n'est stocké.

---

### 7.6 Réunions (« Séances & procès-verbaux »)

#### 7.6.1 Écran « Réunions »
Synthèse (`reunionsSummary`). Deux cartes d'action : **Enregistrer une réunion** (« Dictaphone avec marqueurs de séance. Consentement des participants demandé avant le premier octet. ») et **Importer un enregistrement** (« Fichier du dictaphone, de la visio ou de la salle. Chiffré sur l'appareil, même règle de destruction. » → « Choisir un fichier audio », nom/taille, étapes de traitement : Fichier lu sur l'appareil · Chiffrement local AES‑256 · Transcription en file d'attente, « Créer la réunion » / « Annuler »). Liste **Toutes les réunions** : type, date · durée, titre, état audio, état PV.
Types : CSE ordinaire · CSSCT · Réunion NAO · Préparatoire élus.

**US-REU-01 (M)** — Je consulte toutes les réunions avec l'état de leur audio et de leur PV.
**US-REU-02 (M)** — J'importe un enregistrement audio existant pour créer une réunion.
CA : lecture et chiffrement sur l'appareil ; étapes visibles ; même règle de destruction que l'enregistrement direct.

#### 7.6.2 Écran « Avant d'enregistrer » (consentement)
« L'enregistrement d'une séance suppose l'accord des personnes présentes. Deux confirmations sont requises avant que le micro ne s'ouvre. » Type de réunion ; deux cases : « Les personnes présentes ont été informées de l'enregistrement… » et « La séance ne s'… » (n'est pas couverte par une confidentialité empêchant l'enregistrement) ; encart « Ce qui est fait de l'enregistrement » ; bouton d'enregistrement actif seulement après les deux coches ; note sur la demande d'accès au micro.

**US-REU-03 (M)** — Je ne peux pas démarrer l'enregistrement sans les deux confirmations de consentement.
**US-REU-04 (M)** — Le navigateur me demande l'accès au micro ; en cas de refus ou d'absence de réponse, je peux « Continuer en simulé » (démo) ou « Annuler ».

#### 7.6.3 Écran « Enregistrement »
État (`recStateLabel`), type, chronomètre, « Pause » / « Reprendre » / « Arrêter » ; après arrêt : « Enregistrer la séance » / « Supprimer ». **Marqueurs de séance** : « Un tap pendant la réunion : le marqueur devient un point d'ancrage du PV, horodaté à la seconde. » Boutons : Vote · Décision · Engagement direction · Désaccord · À vérifier · Question diverse · Changement de point. Liste « Marqueurs posés » (heure, libellé), état vide.

**US-REU-05 (M)** — J'enregistre une séance, je la mets en pause, la reprends et l'arrête.
CA : chronomètre exact ; micro libéré à l'arrêt.
**US-REU-06 (M)** — Je pose des marqueurs typés horodatés à la seconde pendant l'enregistrement.
**US-REU-07 (M)** — J'enregistre la séance (création de la réunion) ou je supprime l'enregistrement.

#### 7.6.4 Fiche réunion
Type, titre, date · durée ; tuiles Procès-verbal (état), Marqueurs (nombre), Enregistrement (état court) ; **Ordre du jour** numéroté ; bouton PV (`pvCta` : Générer le projet de PV / Ouvrir le PV) ; « Passer en mode assistant » ; « Écouter l'enregistrement » ; **Rétention de l'audio** (badge + texte : « Audio conservé — destruction dans N jours » ; « Destruction certifiée dès l'approbation du PV, ou à échéance des 30 jours — au premier des deux ») ; si détruit : **Destruction certifiée** (« Enregistrement et transcription supprimés le …, à l'approbation du PV. Voici ce qui subsiste comme preuve. » : Certificat de destruction horodaté · Empreinte SHA‑256 de l'audio · Écriture au registre RGPD · Notification aux participants ; « Télécharger le certificat de destruction ») ; **Marqueurs** (heure, note, libellé) ; **Transcription & extraction** (état, éléments extraits ; « Transcription et extraction passent par l'anonymisation avant inférence ») ; **Journal d'accès à l'enregistrement** (qui, quoi, quand).

**US-REU-08 (M)** — Je consulte une réunion, son ordre du jour et ses marqueurs.
**US-REU-09 (M) [2.0]** — Je génère le projet de PV à partir de la transcription anonymisée et des marqueurs ; il s'ouvre dans l'éditeur de documents (modèle Compte rendu de séance).
**US-REU-10 (M)** — L'audio est détruit automatiquement à l'approbation du PV ou à 30 jours ; un certificat de destruction téléchargeable subsiste.
**US-REU-11 (M)** — Chaque écoute de l'enregistrement est tracée dans le journal d'accès.
**US-REU-12 (S) [2.0]** — unii prépare les questions à poser, extrait décisions et actions, rédige un résumé pour les salariés, rédige le projet de PV (secrétaire).
**US-REU-13 (S)** — J'écoute l'enregistrement en me positionnant sur un marqueur.

---

### 7.7 Agenda (« Planification partagée »)

Écran : intro + nombre d'événements ; navigation mois (‹ mois ›, « Aujourd'hui ») ; vues Mois / Liste ; « Nouvel événement » ; filtres par nature (Réunion CSE · Négociation · Permanence · Formation · Assemblée · Échéance, couleur propre) + « Tout afficher » ; grille du mois (jours de la semaine, numéro, pastilles colorées, « +N ») ; vue liste (titre, quand · heures, lieu, nature) ; panneau du jour sélectionné (« + Ajouter », événements, état vide « Aucun événement ce jour-là… ») ; **Prochaines échéances** + note de rappel.
Formulaire : Intitulé, Nature, Date, Début, Fin, Lieu, Visibilité (Élus seulement · Élus et adhérents · Tous les salariés, avec note), Note interne, « Rappel 48 h avant ».
Détail : nature, titre, Quand, Où, Organisation, infos (`i`), notes, visibilité ; actions « Modifier », « Convoquer », « Ordre du jour », « Exporter .ics », « Retirer », « Fermer ».

**US-AGD-01 (M) [1.0]** — Je consulte l'agenda partagé par mois ou en liste.
**US-AGD-02 (M)** — Je navigue de mois en mois et je reviens à aujourd'hui.
**US-AGD-03 (M)** — Je filtre par nature d'événement.
**US-AGD-04 (M)** — Je crée un événement (depuis le bouton ou un jour précis, date préremplie).
CA : intitulé et date obligatoires ; fin ≥ début ; visibilité appliquée ; toast.
**US-AGD-05 (M)** — Je modifie et je retire un événement (confirmation).
**US-AGD-06 (S)** — J'active un rappel 48 h avant.
**US-AGD-07 (S)** — J'envoie une convocation depuis l'événement (canaux, destinataires = élus / liste).
**US-AGD-08 (S)** — Je prépare l'ordre du jour de l'événement (ouvre le modèle Ordre du jour du générateur).
**US-AGD-09 (S)** — J'exporte l'événement au format .ics.
**US-AGD-10 (S) [2.0]** — unii prépare la prochaine réunion et rappelle les délais de convocation (secrétaire).
**US-AGD-11 (M)** — Les échéances légales issues des dossiers apparaissent dans l'agenda.

---

### 7.8 Documents (« Création de documents »)

#### 7.8.1 Écran « Documents »
Synthèse « N documents dans l'espace de la section · charte <émetteur> appliquée automatiquement ». **Logo par défaut des documents** (aperçu, « Importer », « Reprendre celui de la marque », « Retirer »). **Partir d'un modèle** : Tract / affiche (A5 · 1 page) · Courrier à l'employeur (A4 · 1 page) · Compte rendu de séance · Note aux adhérents · Communiqué NAO (16:9) · Bulletin d'adhésion — chacun avec description et format. **Rédiger avec l'assistant** (« Depuis un dossier, un sondage ou la convention — prompt anonymisé avant envoi. » → « Ouvrir → »). **Mes documents** : titre, méta (format · modèle · modifié le), statut (Brouillon / Signé / Diffusé…), suppression (« Document supprimé — récupérable 30 jours dans la corbeille »).

**US-DOC-01 (M)** — Je crée un document à partir d'un modèle ; il s'ouvre dans l'éditeur avec un contenu exemple.
**US-DOC-02 (M)** — Je retrouve, ouvre et supprime mes documents.
**US-DOC-03 (S)** — Je définis le logo par défaut des documents.
**US-DOC-04 (M) [2.0]** — J'ouvre le générateur IA de documents.

#### 7.8.2 Éditeur de document
Barre : « Titre du document », « Imprimer / PDF », « Faire signer », « Diffuser ». Onglets du panneau gauche : **Contenu** · **Style** · **Charte graphique**.
- **Contenu** : mode **Blocs** ou **Markdown**. Blocs : Badge de rubrique, Titre principal, Intertitre, Titre secondaire, Paragraphe, Liste à puces (un élément par ligne), Encadré réglementaire, Tableau (colonnes « | », 1re ligne en-tête), Saut de page ; chaque bloc : type, déplacer, retirer, image (si le style le permet : « Retirer l'image »). Markdown : `# titre`, `## intertitre`, `- liste`, `> encadré`, `[badge]`, `| a | b |`, `---` saut de page ; conversion blocs ↔ markdown sans perte.
- **Style** : « unii propose 3 styles pour ce document » (Élu 2.0+, sinon mention d'offre) + « Adapter le texte à ce style avec unii » ; liste des styles (Classique + styles d'extensions) avec description et source ; **Images de ce style** (emplacements, état, « Ajouter » / « Retirer », astuce glisser-déposer sur l'aperçu) ; palette ; polices ; format ; note « Le style réorganise vos blocs sur la page ; le contenu n'est pas modifié. Revenez à « Classique » à tout moment. » ; avertissement images manquantes (« Ajouter les images »).
- **Charte graphique** : couleur d'accent (nuancier + code hexadécimal), couleur du texte (Noir encre, Gris ardoise, Brun chaud), police des titres et du texte (Philosopher, Montserrat, Lora, Inter, Georgia), densité (Compact / Confort), logo de l'organisation (importer, retirer ; « PNG ou SVG… Le fichier reste sur l'appareil »), **En-tête & pied de page** (Afficher l'en-tête, Afficher le pied de page, Titres en majuscules ; champs Nom de l'organisation, Section / établissement, Email de contact ; avertissement « Identité de l'émetteur saisie à la main… » + « Reprendre celle de l'organisation »), format (A4 portrait, 16:9 paysage, A5 tract), zoom (50 %, 72 %, 100 %).
- **Aperçu** paginé à droite : compteur de pages, alerte de débordement, en-tête émetteur, section, blocs, pied (contact, n° de page).

**US-EDT-01 (M)** — J'édite le contenu par blocs (ajout, modification, réordonnancement, suppression) avec aperçu en direct.
**US-EDT-02 (S)** — J'édite le contenu en Markdown ; la conversion vers les blocs est fidèle.
**US-EDT-03 (M)** — Je choisis le format de page ; la pagination et l'alerte de débordement se mettent à jour.
**US-EDT-04 (M)** — J'applique la charte graphique (couleurs, polices, densité, logo, en-tête/pied).
CA : par défaut la charte reprend l'identité de l'organisation ; une saisie manuelle de l'émetteur est signalée et réversible.
**US-EDT-05 (S)** — Je choisis un style graphique (y compris d'extension) ; mes blocs sont réorganisés sans modifier le contenu ; je reviens à Classique à tout moment.
**US-EDT-06 (S)** — J'ajoute les images requises par un style (bouton ou glisser-déposer sur l'aperçu).
**US-EDT-07 (S) [2.0]** — unii me propose 3 styles adaptés et peut adapter le texte au style choisi.
**US-EDT-08 (M)** — J'imprime / exporte en PDF.
CA : impression du seul document, une page par page de document, format respecté ; toast « PDF prêt — N pages au format … ».
**US-EDT-09 (M)** — J'envoie le document à la signature (7.9).
**US-EDT-10 (S)** — Je diffuse le document (salariés / adhérents / intranet / appli) via la feuille de diffusion.
**US-EDT-11 (S) [2.0]** — unii relit ton et clarté, simplifie pour les salariés, repère les risques juridiques (titulaire, DS, secrétaire), propose un document à produire.
**US-EDT-12 (M)** — Je renomme le document ; enregistrement automatique (« modifié le … »).

#### 7.8.3 Générateur de documents IA (« Communication & mobilisation »)
Type de document : Tract · Courrier · Ordre du jour. Points clés (+ « Passer en mode assistant »). Ton : Combatif · Pédagogique · Institutionnel. Bouton de génération. Mention : « Le prompt part anonymisé : noms, matricules et établissement sont remplacés par des jetons. La signature (<élu> — CSE) est recollée localement après génération. » Aperçu mis en page : logo, référence, titre, paragraphes, liste, pied. Encadré « Recollé côté client — jamais transmis au modèle ». Étapes : Prompt anonymisé transmis · Rédaction par le modèle · Signature recollée localement. Actions : « Imprimer le PDF », « Faire signer », « Diffuser aux salariés ». Mention IA. État vide : « Lancez la génération pour voir la mise en page automatique. »

**US-GEN-01 (M) [2.0]** — Je génère un tract, un courrier ou un ordre du jour à partir de points clés et d'un ton.
CA : refus si points clés vides (« Décrivez le document à rédiger avant de générer ») ; niveau d'anonymisation détecté ; état de chargement ; résultat mis en page à la charte ; signature recollée localement.
**US-GEN-02 (M)** — Changer le type réinitialise l'aperçu ; changer le ton après génération conserve le résultat jusqu'à régénération.
**US-GEN-03 (M)** — J'imprime, fais signer ou diffuse le document généré.
**US-GEN-04 (S)** — Je passe en mode assistant avec le contexte du générateur.

#### 7.8.4 Bibliothèque documentaire de référence
Documents : Convention collective (IDCC, version, avenants intégrés) · Code du travail — extraits CSE · Accord télétravail · PV · Règlement intérieur. Chacun : nature, titre, méta, badge (Source de l'Assistant / En vigueur / Adopté), version, extraits (référence d'article + texte).

#### 7.8.5 Aperçu de document de référence (« viewer »)
Nature, badge, titre, méta, version, extraits ; actions « Analyser sans identité », « Joindre à un dossier », « Télécharger », état du cache hors ligne ; « Préparer l'ordre du jour » (pour PV / règlement).

**US-BIB-01 (M) [1.0]** — Je consulte la convention collective et les textes de référence, avec leurs articles clés.
**US-BIB-02 (S) [2.0]** — J'analyse un texte sans identité avec l'Assistant.
**US-BIB-03 (S)** — Je joins un texte à un dossier.
**US-BIB-04 (S)** — Je télécharge un texte et je vois s'il est disponible hors ligne.

---

### 7.9 Signature électronique

Écran : titre, synthèse ; choix du document à signer (PV de séance · Courrier de saisine · Accord télétravail…) ; provenance ; aperçu (référence, titre, corps) ; blocs « Pour les élus » (nom apposé, « Signé le … » ou « Zone de signature — en attente ») et « Pour la direction » (état) ; **Signataires** (initiales, nom, rôle, statut) ; **Apposer ma signature** : « Signature avancée eIDAS : identité vérifiée par le second facteur de votre session. », Nom apposé, Style (Manuscrite · Italique · Capitales), case de consentement « Je reconnais avoir lu le document et j'accepte que ma signature électronique ait la même valeur qu'une signature manuscrite. », « Signer le document » ; **Certificat de signature** (Signataire, Horodatage qualifié, Empreinte SHA‑256, Niveau, Journal probatoire) ; « Télécharger le document signé » (PDF signé seul · PDF + certificat + preuve d'horodatage), « Envoyer aux cosignataires », « Annuler ma signature ».

**US-SIG-01 (M)** — Je choisis le document à signer et je le relis.
**US-SIG-02 (M)** — Je signe électroniquement (eIDAS avancée).
CA : bouton inactif tant que le consentement n'est pas coché ; nom et style choisis ; horodatage, empreinte et journal probatoire générés ; statut « Signé ».
**US-SIG-03 (M)** — Je télécharge le document signé, avec ou sans certificat et preuve d'horodatage.
CA : feuille de téléchargement ; fichier vérifiable sur le vérificateur eIDAS européen.
**US-SIG-04 (M)** — J'envoie le document aux cosignataires et je suis l'état de chaque signataire.
**US-SIG-05 (S)** — J'annule ma signature tant que les cosignataires n'ont pas signé.
**US-SIG-06 (S)** — Je modifie ma signature par défaut (Réglages › Signature des documents).

---

### 7.10 Messages

#### 7.10.1 Écran « Messages »
Volet gauche : titre ; onglets (Discussions / Contacts…) ; filtres avec compteurs (Tous, Non lus, Groupes, Directs, Diffusions) ; liste des conversations (initiales, nom, heure, ✓✓, aperçu préfixé, non-lus) ; état vide ; menu « Nouveau groupe », « Nouveau contact », « Nouvelle diffusion aux adhérents », « Gérer les contacts et les groupes dans les réglages → » ; annuaire (Groupes · Équipe & contacts externes · Adhérents) ; mention « Chiffrée de bout en bout — hors des outils de l'entreprise. »
Volet central (fil) : en-tête (initiales, nom, sous-titre) ; « Nouvel envoi » (diffusions) ; bandeau de chiffrement ; messages reçus/envoyés (texte, « Transféré », citation de réponse, canal + objet + pièce jointe pour les diffusions, heure, ✓✓, menu d'actions) ; **réponses unii privées** (contexte « visible par vous seule », question, réponse, ligne de ré-identification, « Insérer dans ma réponse », « Poursuivre dans l'assistant », « Masquer ») ; **mode sélection unii** (« Travaille sur : », messages sélectionnés ou passage surligné, actions, « Passer en mode assistant », dossier lié ; « Ou écrivez « @unii » suivi de votre consigne… ») ; zone de réponse (citation en cours, champ, envoi).
Volet droit (infos) : groupe (description, membres avec Admin, « Ajouter des membres », « Écrire », promouvoir/retirer admin, « Retirer ») ; contact (catégorie, téléphone, e-mail, groupes en commun, « Modifier le contact », « Voir la fiche adhérent ») ; diffusion (destinataires, dernier canal, « Les destinataires reçoivent chaque envoi individuellement… », « Gérer les listes dans Adhérents → ») ; « Mettre en sourdine », « Épingler en haut de la liste », suppression.
Écran d'accueil sans fil : « Messages de la section — Échangez avec les élus en direct ou en groupe, et retrouvez ici chaque envoi fait aux adhérents… » + « Nouvelle discussion », « Nouveau groupe », « Diffuser aux adhérents ».
Actions sur un message : Répondre · Répondre en privé à … · Écrire à … · Transférer · Envoyer dans un dossier · Créer un dossier à partir du message · Copier le texte.

**US-MSG-01 (M)** — Je consulte mes conversations (groupes de commission, directs, diffusions), filtrées et triées par activité.
**US-MSG-02 (M)** — J'envoie un message dans une conversation (Entrée pour envoyer).
CA : chiffré de bout en bout ; heure et accusé ✓✓ ; aperçu mis à jour dans la liste.
**US-MSG-03 (M)** — Je réponds à un message en le citant.
**US-MSG-04 (S)** — Je réponds en privé à l'auteur d'un message de groupe (ouvre le direct).
**US-MSG-05 (M)** — Je transfère un ou plusieurs messages à des contacts ou groupes (modale de sélection avec compteur, « Transférer »).
CA : les messages arrivent marqués « Transféré ».
**US-MSG-06 (M)** — Je verse un message dans un dossier existant ou j'en crée un (modale : « Créer un dossier à partir du message — unii propose titre, catégorie, échéance et plan d'action » ; recherche de dossier, « Verser → »).
**US-MSG-07 (S)** — Je copie le texte d'un message.
**US-MSG-08 (S) [2.0]** — Je sélectionne des messages ou un passage et je demande à unii de résumer le fil ou de proposer une réponse ; la réponse n'est visible que par moi ; je l'insère dans ma réponse.
**US-MSG-09 (S) [2.0]** — J'invoque unii en écrivant « @unii <consigne> » dans le champ.
**US-MSG-10 (M)** — Je démarre une discussion directe avec un élu, un contact externe ou un adhérent.
**US-MSG-11 (M)** — Je crée un groupe, j'ajoute/retire des membres et je nomme des administrateurs.
**US-MSG-12 (M)** — Les envois faits aux adhérents depuis « Envoyer un message » apparaissent comme diffusions ; chaque destinataire reçoit l'envoi individuellement ; les réponses arrivent en direct.
**US-MSG-13 (S)** — Je mets une conversation en sourdine, je l'épingle, je la supprime.
**US-MSG-14 (S)** — Depuis le volet d'infos, j'ouvre la fiche adhérent ou je modifie le contact/groupe.

---

### 7.11 Contacts & groupes (Réglages › Messagerie)

Écran : « ← Réglages », « L'annuaire utilisé par la messagerie : élus, adhérents et contacts externes, et les groupes de discussion avec leurs membres et administrateurs. » ; « Nouveau contact », « Nouveau groupe » ; **Groupes de discussion** (compteur ; initiales, nom, méta ; « Ouvrir », « Membres & réglages ») ; renvoi « Listes de diffusion → » ; **Contacts** filtrables par catégorie (Équipe & élus · Adhérent·e · Contact externe) : nom, catégorie, fonction · coordonnées, groupes, « Écrire », modifier ; état vide.
Modale contact : Nom complet, Fonction / mandat, Catégorie, Téléphone, E-mail ; « Les adhérents sont ajoutés automatiquement depuis le fichier Adhérents ; leurs coordonnées se modifient dans leur fiche. » ; suppression ; « Écrire » ; « Annuler » ; enregistrer.
Modale groupe : Nom du groupe, Description, Membres (compteur, puces retirables « × », liste à cocher avec catégorie et rôle) ; enregistrer.

**US-CTC-01 (M)** — Je crée, modifie et supprime un contact externe ou un élu.
CA : nom obligatoire ; e-mail/téléphone validés ; les adhérents ne sont pas modifiables ici (renvoi vers la fiche).
**US-CTC-02 (M)** — Je filtre les contacts par catégorie et je leur écris.
**US-CTC-03 (M)** — Je crée et modifie un groupe (nom, description, membres).
CA : au moins un membre ; le créateur est admin.

---

### 7.12 Adhérents / Représentants

Le module s'intitule « Adhérents » (section, UD) ou « Représentants » (CSE) — cf. §3.

#### 7.12.1 Écran principal
Kicker, titre, synthèse (« N adhérents suivis sur 3 entreprises · N cotisations en retard · N adhésions à finaliser »). Indicateurs : adhérents actifs, à jour de cotisation, retards à relancer, listes de diffusion, porteurs de mandat, établissements couverts (CSE : listes de convocation). Onglets : **Adhérents/Représentants** · **Listes de diffusion** · **Cotisations** (absent en CSE).

**Onglet liste** : filtres (Entreprise, Établissement, Section, Direction, Statut, Mandat, recherche texte) avec puces ; « Réinitialiser » ; « Créer une liste depuis ces critères » ; compteur ; sélection (« Tout sélectionner », « Effacer », « Envoyer un message ») ; lignes (initiales, nom, mandat, lieu, cotisation, statut : À jour / En retard / Adhésion en cours) ; pagination 5 par page (« Précédent », « Suivant ») ; note de sensibilité (« l'appartenance syndicale est une donnée sensible ») ; « Importer un fichier CSV », « Nouveau bulletin d'adhésion ».
**Onglet listes de diffusion** : listes (nom, type : dynamique / fixe, description, critères, effectif, canal) ; édition (« Nom de la liste », « Usage », « Terminer ») ; suppression ; « Envoyer un message » ; « Afficher les membres » ; « Modifier ».
**Onglet cotisations** : taux de recouvrement ; indicateurs (encaissé ce trimestre, en attente de règlement, de crédit d'impôt) ; **Modes de règlement** (Prélèvement SEPA, Chèque en permanence, Virement annuel — effectifs) ; **Retards de cotisation** (nom, lieu · mode, échéance, dû, « Préparer une relance », « Marquer réglé ») + « Relancer la liste « Cotisations en retard » » ; état « Toutes les cotisations sont à jour. » ; **Journal des envois** (date, objet, auteur · canal).

**US-ADH-01 (M)** — Je consulte le fichier des adhérents avec leurs statuts et indicateurs.
**US-ADH-02 (M)** — Je filtre par entreprise, établissement, section, direction, statut, mandat et texte.
CA : les filtres se combinent ; compteur mis à jour ; pagination remise à 1.
**US-ADH-03 (M)** — Je sélectionne des adhérents (un par un ou tous les résultats) et je leur envoie un message.
**US-ADH-04 (M)** — Je crée une liste de diffusion dynamique à partir des filtres courants.
CA : la liste se met à jour quand le fichier change ; type « dynamique » affiché.
**US-ADH-05 (M)** — Je gère mes listes (renommer, usage, voir les membres, supprimer, écrire).
**US-ADH-06 (M) [Trésorier]** — Je suis le recouvrement, les modes de règlement et les retards.
**US-ADH-07 (M) [Trésorier]** — Je marque une cotisation réglée.
CA : statut passe à « À jour » ; reste dû à 0 ; entrée d'historique sur la fiche ; toast.
**US-ADH-08 (M) [Trésorier]** — Je prépare une relance individuelle ou je relance toute la liste « Cotisations en retard » (modèle Relance de cotisation prérempli).
**US-ADH-09 (S)** — Je consulte le journal des envois.
**US-ADH-10 (M)** — Je crée un nouveau bulletin d'adhésion (ouvre le modèle Bulletin d'adhésion dans l'éditeur).
**US-ADH-11 (S) [2.0]** — unii rédige un message à une liste et prépare une relance (trésorier).

#### 7.12.2 Import CSV
Colonne gauche : titre (« Importer des adhérents/représentants ») ; règles (UTF‑8, en-tête, séparateur ; ou ,) ; « Télécharger le modèle CSV », « Choisir un fichier… », « Charger l'exemple » ; nom du fichier, séparateur détecté ; **Contenu du fichier — modifiable avant import** (zone texte) ; alerte colonnes obligatoires absentes ; **Contrôle des lignes** (synthèse ; n° de ligne, nom, e-mail, « Prête » / « À corriger », lieu, anomalies) ; « Importer N adhérent(s) », « Vider », « Retour aux adhérents ».
Colonne droite : **Colonnes attendues** (Prénom, Nom, Courriel, Téléphone, Entreprise, Établissement, Section, Direction, Emploi occupé, Date d'adhésion, Mode de règlement, Montant de cotisation — avec libellé et obligatoire/facultatif) ; aperçu du modèle `modele-import-adherents.csv` ; **Ce que fait l'import** : ligne valide → adhésion « Adhésion en cours », bulletin à faire signer ; doublons de courriel (fichier et base) écartés ; entreprise/section/direction inconnue créée et filtrable ; fichier lu sur l'appareil, import journalisé.

**US-IMP-01 (M)** — Je télécharge le modèle CSV.
**US-IMP-02 (M)** — Je charge un fichier (ou l'exemple) et je vois son contenu, modifiable avant import.
CA : détection du séparateur ; encodage UTF‑8 ; lecture locale.
**US-IMP-03 (M)** — Les colonnes obligatoires absentes sont signalées et bloquent l'import.
**US-IMP-04 (M)** — Chaque ligne est contrôlée (champs obligatoires, format de courriel, doublons) et marquée Prête / À corriger avec le motif.
**US-IMP-05 (M)** — J'importe les seules lignes prêtes.
CA : statut « Adhésion en cours » ; référentiels inconnus créés ; toast avec nombre importé ; journalisation.
**US-IMP-06 (S)** — Je vide l'import et je recommence.

#### 7.12.3 Fiche adhérent
En-tête : initiales, nom, poste · ancienneté, mandat, statut ; actions « Envoyer un message », « Marquer la cotisation réglée », « Préparer une relance », « Modifier la fiche », suppression. Mode édition : champs (Prénom, Nom, Courriel, Téléphone, Emploi occupé, Entreprise, Établissement, Section syndicale, Direction, Mandat, Adhérent depuis, Mode de règlement, Montant de cotisation) ; « Annuler » / « Enregistrer la fiche ». Blocs : **Coordonnées** ; **Rattachement** ; **Cotisation** (montant, mode, dernier versement, prochaine échéance, bulletin ; « Reste dû ») ; **Historique** (date, événement) ; **Documents liés** (Bulletin d'adhésion, Attestation fiscale, Notice des droits de l'adhérent, Attestation de mandat, Convocations reçues, Notice des droits du représentant — avec action ouvrir/générer) ; **Listes de diffusion** de l'adhérent (« Les messages partent en copie cachée »).

**US-FAD-01 (M)** — J'ouvre la fiche complète d'un adhérent.
**US-FAD-02 (M)** — Je modifie la fiche.
CA : validation des champs ; annulation sans effet ; entrée d'historique ; toast.
**US-FAD-03 (M)** — Je supprime un adhérent (confirmation ; droit à l'effacement).
**US-FAD-04 (M)** — Je génère les documents liés (attestation fiscale, attestation de mandat…).
**US-FAD-05 (S)** — Je vois les listes de diffusion auxquelles il appartient.

#### 7.12.4 Message aux adhérents
Colonne gauche : titre ; mode de ciblage (Sélection manuelle · Adhérents filtrés · Liste de diffusion) ; choix de la liste ; destinataires (compteur, initiales et noms, « + N ») ; **Canal** (E-mail · SMS · Notification app) ; **Modèles de message** (Relance de cotisation · Convocation à l'assemblée · Bienvenue au nouvel adhérent · Point sur les négociations) ; Objet ; Message ; « Joindre le bulletin d'adhésion » ; « Envoyer » / « Annuler ».
Colonne droite : **Aperçu de l'envoi** (note de canal, objet, corps) ; **Lien avec les documents** (« Le bulletin d'adhésion est un modèle de la bibliothèque… » ; « Ouvrir le modèle de bulletin dans l'éditeur → »).

**US-AMS-01 (M)** — J'écris aux adhérents sélectionnés, filtrés ou d'une liste.
**US-AMS-02 (M)** — Je choisis le canal ; l'aperçu s'adapte (objet masqué en SMS, longueur).
**US-AMS-03 (M)** — J'applique un modèle de message qui préremplit objet et corps.
**US-AMS-04 (S)** — Je joins le bulletin d'adhésion généré à la charte.
**US-AMS-05 (M)** — J'envoie : chaque destinataire reçoit individuellement (copie cachée), l'envoi est inscrit au journal et dans Messages (diffusion).
CA : envoi refusé sans destinataire ou sans corps ; toast avec nombre et canal.

---

### 7.13 Intranet et site public

#### 7.13.1 Écran « Intranet »
Sélecteur de site : **Intranet** · **Site internet** (nombre de pages, hôte). Public et note du site. Indicateurs : pages en ligne, en attente webmaster, en préparation, retour à traiter. Cartes : **Générateur de pages HTML** (« Points clés → page rédigée, mise au gabarit du site, HTML propre. ») ; **Suivi des publications** (file). **Gabarits de page** : Page d'accueil, Communiqué de presse, Page de campagne, Actualité, Communiqué interne, Fiche pratique, Questions-réponses, Événement, Compte rendu de séance (selon site). **Arborescence du site** (rubriques : Intranet — Accueil, Actualités, Vos droits, Négociations, Loisirs & ASC, Nous contacter ; Site public — Accueil, Actualités publiques, Nos campagnes, Adhérer, La section, Contact & presse ; avec chemin, description, nombre). **Pages de <hôte>** (titre, méta, statut : Rédigée / Envoyée au webmaster / En ligne / Retour à traiter ; suppression). Note de rôle ; « Charte de ce site ».

**US-WEB-01 (M)** — Je bascule entre intranet et site public ; chaque site a ses rubriques, gabarits, pages et charte.
**US-WEB-02 (M)** — Je crée une page à partir d'un gabarit ; elle s'ouvre dans l'éditeur.
**US-WEB-03 (M)** — Je consulte et supprime les pages d'un site avec leur statut.
**US-WEB-04 (S) [2.0]** — unii vérifie la lisibilité des pages.

#### 7.13.2 Générateur de pages HTML [2.0]
Gabarit ; rubrique de destination (+ chemin cible) ; points clés (+ mode assistant) ; ton ; thème de la page (thèmes d'extensions) ; options « Reformuler en langage clair » (« Phrases courtes, pas de jargon juridique, tutoiement exclu ») et « Générer le résumé d'accueil » (« Chapô de 240 caractères ») ; bouton ; mention « Prompt anonymisé… Le HTML produit ne contient ni script ni style en ligne… » ; état de génération (« Rédaction, mise au gabarit, puis contrôle des données personnelles ») ; la page s'ouvre dans l'éditeur.

**US-WGN-01 (M) [2.0]** — Je génère une page HTML à partir de points clés, d'un gabarit et d'une rubrique.
CA : prompt anonymisé ; HTML sémantique sans script ni style en ligne ; contrôle de données personnelles ; ouverture dans l'éditeur.
**US-WGN-02 (S)** — Je demande une reformulation en langage clair et un chapô de 240 caractères.

#### 7.13.3 Éditeur de page intranet
En-tête : URL, charte appliquée, statut. Panneau gauche : thème de la page (+ source d'extension) ; palette ; **Chapô** ; **Blocs** (libellé, édition, « Retirer » ; « Une ligne = un élément dans les blocs Liste ») ; « Ajouter une section : + <type> » ; **Circuit de publication** (note de relecture, « Retour du webmaster », « Demander une relecture », « Envoyer pour publication », « Copier le HTML »). Panneau droit : auteur ; onglets **Aperçu** / **Code HTML** ; appareil (poste / tablette / mobile) ; barre d'URL ; aperçu en cadre isolé ; code (lignes numérotées) éditable, « Régénérer depuis les blocs », avertissement « Code modifié à la main — l'aperçu suit vos modifications ; les blocs ne les reprennent pas ».

**US-WED-01 (M)** — J'édite les blocs et le chapô ; l'aperçu se met à jour en direct.
**US-WED-02 (M)** — Je prévisualise la page en poste, tablette et mobile.
**US-WED-03 (S)** — Je consulte et modifie le code HTML ; je peux régénérer depuis les blocs.
**US-WED-04 (M)** — Je demande une relecture à un autre élu.
CA : l'auteur ne peut pas être le relecteur ; statut de relecture visible.
**US-WED-05 (M)** — Je copie le HTML.
**US-WED-06 (S)** — J'applique un thème de page (extension) ; le HTML reste sémantique.

#### 7.13.4 Envoi au webmaster
Titre ; rubrique et adresse (aperçu d'URL) ; mise en ligne souhaitée (date) ; visibilité ; consignes ; options « Joindre le fichier .html », « Notifier par e-mail en plus de la file interne », « Remonter le résumé sur la page d'accueil » ; destinataire (nom, e-mail du webmaster) ; liste de contrôle (HTML validé, Feuille de style du site, Données personnelles, Navigation claire… ✓/✗) ; alerte « Aucune relecture enregistrée. Vous pouvez envoyer malgré tout : la demande indiquera « non relue » au webmaster. » ; « Envoyer pour publication » / « Annuler ».

**US-WPB-01 (M)** — J'envoie la page au webmaster avec date souhaitée, visibilité et consignes.
CA : contrôles affichés ; envoi sans relecture possible mais marqué « non relue » ; statut « Envoyée au webmaster » ; référence de demande créée.

#### 7.13.5 Suivi des publications
Synthèse ; demandes (référence, statut, titre, rubrique · date prévue · visibilité · envoyée le) ; frise d'étapes ; message ; **Retour du webmaster** ; URL publiée, « Ouvrir la page », « Relancer ».

**US-WQ-01 (M)** — Je suis l'état de mes demandes de publication et je lis les retours du webmaster.
**US-WQ-02 (S)** — Je relance le webmaster ; j'ouvre la page en ligne.
**US-WQ-03 (S)** — Un retour du webmaster place la page en « Retour à traiter » et génère une notification.

#### 7.13.6 Charte des sites
Sélecteur de site ; « Hériter de l'identité de l'organisation » (note, « Modifier l'identité ») ; **aperçu** d'en-tête de site (logo, nom, navigation, article exemple, bouton, sommaire) ; Couleur d'accent ; Couleur d'en-tête et de pied de page ; Police des titres (Philosopher, Georgia, Sans-serif système…) ; Navigation (Navigation claire · Bandeau de couleur) ; Angles (Angles nets · Arrondis doux · Très arrondis) ; Largeur de contenu (Article · Fiche étroite · Large) ; **Logo de ce site** (import, provenance, « Reprendre le logo de l'identité », taille 60–300 % de 44 px, « Réinitialiser », « Afficher le logo dans l'en-tête du site ») ; feuille CSS générée (nom + contenu) ; « Enregistrer le gabarit » / « Retour ».

**US-WCH-01 (M)** — Je fais hériter la charte d'un site de l'identité de l'organisation, ou je la surcharge.
**US-WCH-02 (M)** — Je règle couleurs, police, navigation, angles, largeur et logo avec aperçu en direct.
**US-WCH-03 (S)** — Je récupère la feuille de style générée pour le webmaster.
**US-WCH-04 (M)** — J'enregistre le gabarit ; les pages du site l'utilisent.

---

### 7.14 Communication (« Moins d'administratif, plus de terrain »)

Onglets avec compteurs : **Plan de communication** · **Rédiger avec unii** · **Pôle communication**.

#### 7.14.1 Plan de communication
Mois affiché ; compteur « à valider » ; « + Nouvelle publication » ; filtres par statut (Idée · Brouillon · À valider · Programmé · Publié) ; publications : jour (jour de semaine, n°, mois), statut cliquable, objectif, titre, méta (format · canal), extrait, « Rédiger » / « Reprendre », suppression ; état vide ; aide « Cliquez sur un statut pour le faire avancer : Idée → Brouillon → À valider → Programmé → Publié. » ; **Temps forts du mandat** (liste dépendant du type d'organisation, §3) avec « Rédiger » ou ajout en idée ; « Restaurer le plan d'exemple ».
Formats : Post réseau social · Article intranet · Newsletter · Affiche / flyer · Résumé de PV · Script vidéo courte · Sondage. Objectifs : Informer · Fédérer · Valoriser · Engager.

**US-COM-01 (M)** — Je planifie mes publications du mois et je filtre par statut.
**US-COM-02 (M)** — Je fais avancer une publication d'un statut au suivant d'un clic.
**US-COM-03 (S)** — J'ajoute un temps fort en idée ou je le rédige tout de suite.
**US-COM-04 (M)** — Je supprime une publication (confirmation).
**US-COM-05 (C)** — Je restaure le plan d'exemple.

#### 7.14.2 Rédiger avec unii [2.0]
Formulaire : Format ; Objectif (+ aide) ; Canal de diffusion ; Sujet et éléments clés (+ suggestions) ; Ton ; Date de diffusion ; bouton ; « Retour au plan » ; mention d'anonymisation et de vocabulaire (« PV, plénière, ASC, NAO, BDESE — chaque sigle est expliqué aux salariés »).
Résultat : **Proposition** (méta) avec Titre, Accroche, Texte, Appel à l'action, Visuel conseillé ; « Ajouter au plan » / « Mettre à jour le plan », « Copier », « Confier la mise en forme au pôle ». En échec : trame type étiquetée.

**US-COM-06 (M) [2.0]** — Je décris un sujet et unii rédige titre, accroche, texte, appel à l'action et visuel conseillé.
CA : sujet obligatoire ; anonymisation ; sigles expliqués ; état « unii rédige votre publication… ».
**US-COM-07 (M)** — J'ajoute la proposition au plan à la date choisie (statut Brouillon) ou je mets à jour la publication d'origine.
**US-COM-08 (S)** — Je copie le texte.
**US-COM-09 (S) [2.0]** — unii propose le plan du mois et reformule pour les salariés.

#### 7.14.3 Pôle communication uniion
Présentation (community management, contenus, réseaux, print, vidéo, événementiel) ; **Formules** à la carte (Essentiel, Confort, Premium, Excellence, Signature — réseaux, publications/mois, modération, vidéos, plus) ; mention de conditions préférentielles Élu 3.0/4.0 ; socle commun ; « Communiquer utile et responsable » ; **Supports** (Print, Digital, Vidéo & motion design, Événementiel, Création sur mesure, Objets personnalisés) ; **Votre projet** : formule envisagée, demande « Demandez votre plan de communication d'élu », confirmation « Demande transmise — rappel sous 48 h ouvrées » + récapitulatif + « Modifier la demande ».

**US-POL-01 (S)** — Je compare les formules d'accompagnement et j'en choisis une.
**US-POL-02 (S)** — J'envoie une demande de plan de communication ; je reçois une confirmation de rappel sous 48 h ouvrées ; je peux la modifier.
**US-POL-03 (S)** — Je confie la mise en forme d'une proposition au pôle.

---

### 7.15 Application mobile (pages publiées dans l'appli salariés)

Kicker « Publié dans l'application <syndicat> » ; indicateurs (pages en ligne, vues, push envoyés…) ; onglets.
**Vos pages** : espace, statut (Brouillon · En relecture · Validation FO · En ligne), type, pastille de suggestion, titre, méta (public, vues, mise à jour), « Modifier », suppression ; circuit « Brouillon → Relecture par un pair → Validation FO → En ligne dans l'application ».
**Créer une page** : modèles adaptés au téléphone (Actualité, Permanences, Contacts des élus, Événement, Vos droits, Adhésion) ; « Quelles pages créer ? Demander à unii ».
**Éditeur** : « ← Toutes les pages » ; statut ; Titre ; Type ; Visible par (Tous les salariés · Adhérents FO · Élus et mandatés) ; « Rédiger avec unii » (+ actions : adapter à la lecture mobile, etc.) ; **Contenu** : blocs Intertitre, Texte, Encadré pratique, Contact, Bouton (ajout, édition, suppression) ; **Notification push** (interrupteur, texte, compteur de caractères ; « Envoyée à la mise en ligne. À réserver aux informations utiles. ») ; **Publication** (étapes, note, bouton d'avancement, « Vérifier avec unii avant envoi ») ; **Aperçu dans l'application** (cadre de téléphone, en-tête, type, titre, public, blocs, barre Accueil · Actus · Mon syndicat · Profil, aperçu de la notification sur écran verrouillé).

**US-MOB-01 (M)** — Je consulte les pages de l'appli et leur statut.
**US-MOB-02 (M)** — Je crée une page à partir d'un modèle mobile.
**US-MOB-03 (M)** — J'édite titre, type, public et blocs, avec aperçu téléphone en direct.
**US-MOB-04 (M)** — Je fais avancer la page dans le circuit ; la relecture doit être faite par un pair (≠ auteur).
**US-MOB-05 (S)** — J'active une notification push envoyée à la mise en ligne, avec aperçu.
CA : longueur limitée ; aperçu sur écran verrouillé.
**US-MOB-06 (S) [2.0]** — unii rédige le contenu, adapte à la lecture mobile, rédige le push, vérifie avant publication, propose les pages à créer.
**US-MOB-07 (M)** — Je supprime une page (confirmation).

---

### 7.16 Formations (« Montée en compétence »)

Onglets avec compteurs : **Formations IA** · **Catalogue des formations** · **Se former avec unii**.

#### 7.16.1 Formations IA
Filtres par thème (Fondamentaux · Droit & Défense · Négociation & Stratégie · Santé & Sécurité · Communication & Mobilisation · Gouvernance, éthique & sécurité · Automatisation & Connaissance) ; sections numérotées ; fiches (type : Sensibilisation / Atelier / Atelier métier / Cas pratique / Parcours avancé ; durée ; titre ; public ; objectifs) ; « Se former avec unii » ; « Demander une session » (`reqLabel`) ; **Parcours recommandés** alignés Élu 1.0 → 4.0 (« Suivre avec unii ») ; **Formats et durées** (Sensibilisation 2–3 h ; Atelier métier 1 j ; Parcours agents IA 2 j ; Formation direction/DRH ½ j).

#### 7.16.2 Catalogue des formations
Filtres par catégorie (CSE & mandats · Santé & sécurité · Économie & restructurations · Droit & négociation · Harcèlement & RPS…) et par critères (obligatoires, agréées) ; compteur ; fiches (catégorie, « Obligatoire », « Agréée DREETS », titre, durée, modalité INTER/INTRA, description, « Réviser avec unii », « Demander une session ») ; note de financement (« formations obligatoires… financées par l'employeur ou le budget de fonctionnement du CSE… transmise au bureau pour arbitrage »).

**US-FOR-01 (M)** — Je parcours et filtre les catalogues.
**US-FOR-02 (M)** — Je demande une session de formation ; la demande est transmise au bureau pour arbitrage.
CA : bouton passe à « Demande envoyée » ; toast ; une seule demande active par formation.
**US-FOR-03 (S)** — Je suis un parcours recommandé correspondant à mon niveau d'offre.

#### 7.16.3 Se former avec unii [2.0]
**Nouvelle session** : « Cours, exemples, exercice et quiz à chaque module. » ; Thème (+ suggestions : Rôle du secrétaire du CSE, Préparer les NAO, Mener une enquête après accident, Lire la BDESE, Prévenir le harcèlement, Bien utiliser l'IA dans mon mandat, Budget ASC et règles URSSAF, Droit d'alerte du CSE) ; Temps disponible ; Niveau ; Mon rôle ; objectif facultatif ; bouton de démarrage + plan estimé (nombre de modules, durée) ; **Comment ça marche** (étapes) ; **Mes sessions** (titre, méta, progression, suppression).
**Lecteur de session** : « ← Mes sessions » ; titre, méta, % ; plan (✓/en cours, titre, minutes) ; mention de parcours type si IA indisponible ; introduction ; module : n°, titre, objectif, points (titre + texte), **Cas concret**, **Exercice d'application** (saisie + « Faire relire par unii » → **Retour de unii**), **Quiz** (choix, verdict, explication) ; « ← Module précédent » / suivant ; **Session terminée** : score, À retenir, Sources, « Attestation de suivi », « Revoir depuis le début », « Nouvelle session », « Formations du catalogue » ; **chat de module** (« Une question sur ce module ? »).

**US-FMU-01 (M) [2.0]** — Je configure une session (thème, temps, niveau, rôle, objectif) et unii génère un plan de modules.
**US-FMU-02 (M)** — Je suis les modules : cours, cas concret, exercice, quiz.
CA : progression enregistrée ; module suivant accessible ; retour arrière possible.
**US-FMU-03 (S)** — Je soumets mon exercice et unii me fait un retour.
**US-FMU-04 (M)** — Je réponds au quiz et j'obtiens verdict et explication.
**US-FMU-05 (S)** — Je pose une question sur le module en cours.
**US-FMU-06 (S)** — À la fin, je vois mon score, les points à retenir, les sources et je télécharge une attestation de suivi.
**US-FMU-07 (M)** — Je retrouve, reprends et supprime mes sessions.
**US-FMU-08 (M)** — Si l'IA est indisponible, un parcours type générique étiqueté est proposé.
**US-FMU-09 (S) [2.0]** — unii recommande une formation selon mes dossiers et mon rôle.

---

### 7.17 Reporting (« Pilotage »)

Onglets : **Bilan de mandat** · **Utilisation de l'application**. Période : 30 derniers jours · Mandat en cours · Depuis la création / Année 2026 · 12 derniers mois · Mandat 2024–2028.

**Bilan de mandat** : indicateurs (Dossiers traités, Dossiers clos, Délai moyen, Participation sondages — avec évolution) ; **Dossiers par mois** (ouverts orange / clos gris) ; **Répartition par thème** ; **Activité du mandat** (Réunions CSE, Séances de négociation, Sondages diffusés, Consultations de l'assistant, Heures de délégation, Accords signés, Salariés reçus en permanence, Élus formés SSCT) ; **Exporter le bilan** (« mise en forme attendue pour l'annexe du rapport annuel du CSE. Aucune donnée nominative de salarié ») : Bilan annuel (PDF), Données détaillées (Excel), Partager en lecture seule aux élus.
**Utilisation** : indicateurs (Élus actifs, Sessions, Durée moyenne, Usage mobile) ; **Utilisation par module** (ouvertures, tendance) ; **Sessions par semaine** (mobile / poste) ; **Assistant IA** (quota mutualisé ; Requêtes, Réponses sourcées, Reformulations de courrier, Temps estimé économisé) ; **Niveau d'anonymisation des appels** (répartition Standard / RH / RPS) ; **Contenus produits** (courriers et tracts, comptes rendus, pages intranet, sondages, pièces au coffre, signatures) ; **Élus les plus actifs** (admins seulement) ; **Fiabilité et hors ligne** (synchronisations, taux de réussite, latence médiane, incidents, connexions bloquées MFA) ; **Exporter le rapport d'usage** (agrégé uniquement : PDF, Excel) ; « Gérer les sièges et les accès → ».

**US-REP-01 (M)** — Je consulte le bilan de mandat sur la période choisie.
**US-REP-02 (M)** — J'exporte le bilan (Excel 4 onglets, CSV brut, PDF de séance) sans donnée nominative.
CA : feuille d'export ; fichier conservé 30 jours dans Paramètres → Exports.
**US-REP-03 (S)** — Je partage le bilan en lecture seule aux élus.
**US-REP-04 (S) [Admin org]** — Je consulte l'utilisation de l'application et j'exporte un rapport d'usage agrégé.
**US-REP-05 (M)** — Les statistiques nominatives sont réservées aux admins (H5).
**US-REP-06 (S) [2.0]** — unii explique un indicateur et rédige le bilan du mandat (secrétaire, trésorier).

---

### 7.18 Raccourcis (« Écosystème »)

Écran : « Vos applications externes, réunies ici. N raccourcis. » ; « Ajouter un raccourci » (Nom, Adresse https, Description facultative, Couleur ; « Annuler » / « Enregistrer ») ; tuiles (initiale colorée, nom, note, hôte ↗) ouvrant dans un nouvel onglet ; « Modifier », « Supprimer » (« Supprimer ? Oui · Non ») ; état vide.

**US-RAC-01 (M)** — J'ajoute un raccourci vers un outil externe.
CA : nom et URL https obligatoires ; URL invalide refusée.
**US-RAC-02 (M)** — J'ouvre un raccourci dans un nouvel onglet.
**US-RAC-03 (M)** — Je modifie ou supprime un raccourci (confirmation).
**US-RAC-04 (C) [2.0]** — unii suggère des raccourcis utiles.

---

### 7.19 Réglages

#### 7.19.1 Écran « Paramètres » (accueil des réglages)
En-tête « <organisation> · plan <formule>, N adhérents ». Cartes de section (badge, titre, description) : Profil · Informations de l'organisation · Notifications · Sécurité · Confidentialité & RGPD · Organisation & membres · Identité de marque · Configuration IA · Actions d'unii · Extensions · Contacts & groupes · Mode hors ligne · Prise en main · Back-office · Abonnement et paiements · Mémoire de l'assistant. Puis : Ordre du menu de gauche (US-NAV-03), Profil, Organisation, Mon activité, Signature, Session, Données de démonstration.

#### 7.19.2 Profil
Initiales, nom, fonction (« Déléguée syndicale · Secrétaire de section ») ; champs (Fonction, E-mail, Téléphone, Commissions…) ; « Coordonnées visibles par les autres élus » ; **Mon activité — <mois>** (dossiers clos, questions IA, documents générés, sondages lancés).

**US-PRF-01 (M)** — Je consulte et modifie mon profil et mes coordonnées visibles des autres élus.
**US-PRF-02 (C)** — Je vois mon activité du mois.

#### 7.19.3 Informations de l'organisation [Admin org]
Lecture : sous-titre, nature, champs (Dénomination, Sigle, SIRET, Convention collective, Effectif de l'entreprise, Sièges au CSE, Début du mandat, Fin du mandat, Adresse du local, Courriel de l'organisation, Secrétaire, Trésorier) ; note « La convention collective renseignée ici détermine le corpus interrogé par l'assistant juridique. Les en-têtes de documents et les pages intranet reprennent la dénomination et l'adresse. » Édition : « Modifier » → champs avec aide → « Enregistrer les informations » / « Annuler ».

**US-ORG-02 (M)** — Je renseigne et modifie les informations légales de l'organisation.
CA : SIRET 14 chiffres ; fin de mandat > début ; changement de convention → corpus de l'assistant mis à jour ; en-têtes de documents et pages reprennent les nouvelles valeurs.

#### 7.19.4 Signature des documents
Aperçu (nom, fonction, e-mail), « Reprise automatiquement en pied des tracts et courriers générés » ; « Signer un document », « Modifier la signature ».

**US-PRF-03 (S)** — Je définis la signature reprise en pied des documents générés.

#### 7.19.5 Session et démonstration
Session : « Ouverte depuis <appareil> — <lieu>. La déconnexion purge le cache local chiffré. » ; « Se déconnecter ». Démonstration : explication du stockage local ; « Réinitialiser la démonstration » (confirmation).

**US-DMO-01 (C)** — Je réinitialise la démonstration pour retrouver le jeu d'exemple.

#### 7.19.6 Notifications
« Par canal et par module. Les alertes urgentes ignorent le mode « ne pas déranger ». » Interrupteurs : Notifications push · Résumé par email (digest quotidien à 8 h) · SMS pour les urgences (accidents du travail, droits d'alerte) · Ne pas déranger 20 h — 7 h · Escalade automatique (sans accusé sous 4 h).

**US-NOT-01 (M)** — J'active ou désactive chaque canal de notification.
**US-NOT-02 (M)** — Les alertes urgentes passent malgré le mode ne pas déranger.
**US-NOT-03 (S)** — L'escalade automatique relance une alerte urgente non acquittée sous 4 h.

#### 7.19.7 Sécurité
Interrupteurs : Double authentification (MFA — obligatoire pour les admins, non désactivable pour eux) · Verrouillage biométrique · SSO fédération (OIDC). Lien « Sécurité de l'assistant et conformité RGPD ». **Appareils connectés** (nom, méta, « Déconnecter » ; état vide). **Journal d'audit** (date, action, auteur ; « Exporter le journal (CSV) »). **Politique organisation — Anonymisation avant inférence** (verrouillé ON, compteur d'appels, 0 identité fuitée, pièces jamais transmises, **journal d'empreintes** : empreinte, méta, « Conforme »).

**US-SEC-01 (M)** — J'active la MFA, la biométrie, le SSO OIDC.
**US-SEC-02 (M)** — Je vois mes appareils connectés et j'en déconnecte un à distance.
**US-SEC-03 (M) [Admin org]** — Je consulte et exporte le journal d'audit (CSV).
**US-SEC-04 (M)** — Je consulte le journal d'empreintes des appels IA, sans texte en clair.

#### 7.19.8 Confidentialité & RGPD
« Hébergement UE, chiffrement au repos et en transit, cloisonnement strict avec l'employeur. » **Durées de conservation** (SEC-05). **Exercer vos droits** : « Accès, rectification, effacement, portabilité — traité sous 30 jours. » ; « Exporter mes données (JSON) », « Demander l'effacement ». **Registre des traitements** : Suivi des dossiers salariés (mission de représentation, données minimisées) · Messagerie interne des élus (intérêt légitime, E2E) · Consultations IA (consentement, non réutilisées pour l'entraînement).

**US-RGP-01 (M)** — J'exporte mes données personnelles au format JSON.
CA : feuille d'export ; fichier conservé 30 jours.
**US-RGP-02 (M)** — Je demande l'effacement de mes données ; la demande est tracée et traitée sous 30 jours.
**US-RGP-03 (M)** — Je consulte les durées de conservation et le registre des traitements.

#### 7.19.9 Organisation & membres [Admin org]
Synthèse (`memberSummary`) ; indicateurs (sièges du plan, membres actifs, commissions, invitation en attente) ; « + Inviter un membre » ; liste (initiales, nom, rôle · dernière connexion, statut Actif / Invité / Suspendu, action : Relancer / Suspendre / Réactiver, retirer).

**US-MBR-01 (M)** — J'invite un membre (e-mail, rôle) par lien ou par import CSV.
CA : statut « Invité » ; sièges disponibles vérifiés ; invitation relançable.
**US-MBR-02 (M)** — Je change le rôle d'un membre (y compris « Lecture seule » pour un expert externe) ; le changement est tracé.
**US-MBR-03 (M)** — Je suspends, réactive ou retire un membre (confirmation).

#### 7.19.10 Identité de marque [Admin org]
« Marque blanche · administrateurs » ; statut (brouillon / publié) ; « Prévisualiser sur toute l'app » / « Aperçu en cours — revenir » ; « Réinitialiser » ; « Publier à l'organisation ». **Portée** : Organisation · <établissements> (surcharge). **Palette** : préréglages (Orange uniion, Rouge militant, Bleu institutionnel, Vert, Prune, Ardoise, Neutre employeur — avec description) ; Couleur principale, Secondaire, rampe dérivée, contrôle de contraste. **Mode d'affichage** : Clair · Sombre. **Typographie** : Philosopher / Inter · Montserrat / Inter · Lora / Inter · Inter seul. **Logos** : Logo — fond clair · Logo — fond sombre · Monogramme carré · Logo intranet · Logo site public (PNG/SVG ≥ 512 px, taille 60–300 %, « Réinitialiser », « Retirer » ; alerte mode sombre sans logo dédié) ; **Monogramme de repli**. **Aperçu** (connexion, navigation, carte de dossier). **Portée sur les contenus** : « Le gabarit intranet hérite de ce thème » (interrupteur) + « Ouvrir le gabarit du site intranet → ». **Journal des publications**.

**US-MRQ-01 (M)** — Je choisis une palette (préréglage ou couleurs libres) avec contrôle de contraste automatique.
**US-MRQ-02 (M)** — Je choisis le mode clair/sombre et la typographie.
**US-MRQ-03 (M)** — Je charge mes logos et règle leur taille.
CA : formats PNG/SVG ; alerte si mode sombre sans logo sombre ; monogramme utilisé en repli (avatar, favicon).
**US-MRQ-04 (M)** — Je prévisualise la marque sur toute l'application avant de publier, puis je reviens.
**US-MRQ-05 (M)** — Je publie la marque à l'organisation ; la publication est inscrite au journal.
**US-MRQ-06 (S)** — Je surcharge la marque pour un établissement ; les autres héritent du réglage organisation.
**US-MRQ-07 (S)** — Je fais hériter l'intranet du thème ou non.
**US-MRQ-08 (S)** — Je réinitialise le brouillon.

#### 7.19.11 Configuration IA [Admin org]
« Modèle utilisé par l'Assistant Juridique, la Recherche Légale et le Générateur de documents. » Garanties (anonymisation verrouillée, zéro donnée hors UE, zéro entraînement, journal d'empreintes ; compteurs). **Fournisseur & modèle** : Offre mutualisée uniion (incluse) · Anthropic — Claude (clé propre, UE) · Mistral — Large (clé propre, France). **Clé API** (masquée, afficher/masquer, « Chiffrée au repos dans un coffre dédié, jamais réaffichée en clair après enregistrement. Dernière rotation : … », Enregistrer, « Révoquer »). **Consommation — <mois>** (par usage : Assistant juridique, Génération de documents, Recherche légale ; coût estimé / quota). **Comportement du modèle** : Prudence juridique (niveaux) ; Sourçage obligatoire des réponses juridiques.
Sous-bloc démo « Connexion du modèle — démo locale » : statut, note, saisie de clé, « Enregistrer la clé », « Oublier », choix du modèle, test de connexion.

**US-CIA-01 (M)** — Je choisis le fournisseur de modèle (mutualisé ou clé propre).
**US-CIA-02 (M)** — J'enregistre, renouvelle ou révoque la clé API de l'organisation.
CA : jamais réaffichée en clair après enregistrement ; action tracée.
**US-CIA-03 (M)** — Je suis la consommation et le coût par rapport au quota.
**US-CIA-04 (S)** — Je règle la prudence juridique et le sourçage obligatoire.
**US-CIA-05 (C)** — En démo, je connecte un modèle et je teste la connexion.

#### 7.19.12 Mode hors ligne
« En visite d'usine, en sous-sol ou en déplacement : votre base documentaire reste accessible et chiffrée sur l'appareil. » **Synchronisation intelligente** (statut, « Synchroniser maintenant »). **Base documentaire** (résumé du cache ; documents : nom, méta, ouvrir, action Télécharger / Retirer du cache).

**US-OFF-01 (M)** — Je consulte la base documentaire hors connexion.
**US-OFF-02 (S)** — Je choisis les documents disponibles hors ligne et je lance une synchronisation.
CA : statut et date de dernière synchro ; conflits signalés.

#### 7.19.13 Prise en main [Admin org]
Checklist : Convention collective (« Modifier ») · Créer vos commissions (« Créer les 4 commissions » : Négociation, SSCT, ASC, Formation — chacune avec sa messagerie) · Inviter les élus (« Importer un CSV ») · Régler vos alertes (« Configurer »). Chaque étape : ✓ Terminé — revoir.

**US-ONB-01 (M)** — Je suis une checklist de configuration initiale ; chaque étape cochée reste marquée terminée.
**US-ONB-02 (S)** — Je crée en un clic les 4 commissions avec leur groupe de discussion.

#### 7.19.14 Back-office — Tableau de bord organisation [Admin org]
Périmètre (`adminScope`, sélecteur de site) ; indicateurs (dossiers ouverts, requêtes IA…) ; **Activité par commission** (Négociation, SSCT, ASC, Formation) ; **Raccourcis d'administration** : Gestion des membres · Bibliothèque documentaire · Configuration IA · Prise en main de l'organisation · Bilan & reporting CSE · Facturation & sièges.

**US-BO-01 (S)** — Je pilote l'organisation depuis un tableau de bord avec accès direct aux fonctions d'administration.

#### 7.19.15 Abonnement et paiements [Admin org]
Formule actuelle (nom, prix, renouvellement, promesse) ; périodicité (mensuelle / annuelle) ; cartes des 4 formules (Populaire, « Votre formule », prix, unité, promesse, fonctionnalités, CTA) ; mention tarifaire ; **Moyen de paiement** (type, numéro masqué, expiration, titulaire, « Modifier le moyen de paiement », mention DSP2) ; **Factures** (numéro, date · montant, état Payée/En attente, PDF ; « Tout exporter »).

**US-ABO-01 (M)** — Je consulte ma formule et je compare les offres.
**US-ABO-02 (M)** — Je change de formule (montée immédiate ; descente en fin de période).
**US-ABO-03 (M)** — Je modifie mon moyen de paiement via le prestataire.
**US-ABO-04 (M)** — Je télécharge mes factures en PDF ou toutes en export.

---

### 7.20 Panneau unii et actions d'unii [2.0]

#### 7.20.1 Panneau unii (latéral droit, 440 px)
En-tête : « unii », contexte · rôle testé, « Effacer ». Si Élu 1.0 : écran d'offre (G1). Sinon : **Contexte** (élément fixé ou choix « Élément concerné ») ; **Suggestions** ; **Actions** (libellé + description ; état vide « Aucune action activée pour votre rôle dans ce module. ») ; nombre d'actions masquées ; fil (question, réponse, « IA indisponible — trame de départ », bouton d'application `applyLabel`, « Copier », « Continuer dans l'Assistant ») ; « unii réfléchit… » ; saisie libre ; pied « Anonymisé avant envoi · unii propose, vous validez » ; lien « Réglages ».

**US-UNI-01 (M)** — J'ouvre unii depuis n'importe quel écran ; il connaît le module et l'élément ouvert.
**US-UNI-02 (M)** — Je choisis l'élément concerné quand plusieurs sont possibles.
**US-UNI-03 (M)** — Je lance une action proposée ou je pose une question libre.
**US-UNI-04 (M)** — J'applique la réponse à l'élément (ex. ajout à la chronologie du dossier), je la copie ou je continue dans l'Assistant.
**US-UNI-05 (M)** — J'efface le fil unii.
**US-UNI-06 (S)** — Les pastilles signalent dans les modules ce qui mérite mon attention.

#### 7.20.2 Écran « Actions d'unii » [Admin org]
Formule et nombre d'actions incluses (« unii est disponible à partir d'Élu 2.0 » + « Changer de formule ») ; interrupteur **Pastilles de suggestion** ; **Tester un rôle** (l'application affiche unii tel que le voit ce rôle) ; par module : nombre d'actions, liste (case, libellé, description · portée liste/élément, bouton d'application) et rôles autorisés (« Tous les rôles » ou cases par rôle) ; « Réinitialiser ».

Catalogue des actions par module :
- Accueil : Faire le point de la semaine · Par quoi commencer ?
- Dossiers : Proposer la suite à donner · Résumer la chronologie · Vérifier les délais légaux · Rédiger un courrier à la direction (titulaire, DS, secrétaire) · Prioriser mes dossiers
- Réunions : Préparer les questions à poser · Extraire décisions et actions · Résumé pour les salariés · Rédiger le projet de PV (secrétaire)
- Documents : Relire ton et clarté · Simplifier pour les salariés · Repérer les risques juridiques (titulaire, DS, secrétaire) · Proposer un document à produire
- Messages : Résumer le fil · Proposer une réponse
- Agenda : Préparer la prochaine réunion · Rappeler les délais de convocation (secrétaire)
- Communication : Proposer le plan du mois · Reformuler pour les salariés
- Application mobile : Rédiger le contenu de la page · Adapter à la lecture mobile · Rédiger la notification push · Vérifier avant publication · Proposer les pages à créer
- Formations : Recommander une formation
- Adhérents : Rédiger un message à une liste · Préparer une relance (trésorier)
- Sondages : Rédiger des questions neutres · Analyser les résultats
- Intranet : Vérifier la lisibilité des pages
- Reporting : Expliquer un indicateur · Rédiger le bilan du mandat (secrétaire, trésorier)
- Raccourcis : Suggérer des raccourcis utiles
- Réglages : Expliquer un réglage · Aider à configurer les rôles (secrétaire, DS)

**US-UAC-01 (M)** — J'active/désactive chaque action par module.
**US-UAC-02 (M)** — Je restreins une action à certains rôles ; sans rôle coché, elle est ouverte à tous.
**US-UAC-03 (S)** — Je teste l'affichage d'unii pour un rôle donné.
**US-UAC-04 (S)** — J'active/désactive les pastilles de suggestion.
**US-UAC-05 (C)** — Je réinitialise la configuration par défaut.

---

### 7.21 Extensions [Admin org]

Écran : « Les extensions ajoutent des styles, des blocs et des thèmes sans modifier le cœur d'uniion. Désactivée, une extension disparaît sans laisser de trace : vos contenus reviennent à leur rendu habituel. » Compteur ; liste (nom, statut, méta : version, éditeur, formule requise ; description ; **Autorisations** ; groupes d'éléments activables : styles de document, sections de page, thèmes de page) ; erreurs isolées (« le rendu d'origine a été utilisé à leur place ») ; extensions refusées au chargement (signature invalide, formule insuffisante) ; **Installer une extension** (adresse relative `./extensions/…` ou https, avertissement sur l'éditeur, « Installer », sources installées avec « Retirer ») ; **Auto-test de non-régression** (« Compare le rendu avec et sans extensions, et rend chaque style sur chaque document. » → résultats ✓/✗).

**US-EXT-01 (M)** — J'active/désactive une extension et chacun de ses éléments.
CA : désactivation sans trace ; contenus rendus au style Classique.
**US-EXT-02 (M)** — Je consulte les autorisations demandées par une extension.
**US-EXT-03 (M)** — J'installe une extension par son adresse et je la retire.
CA : extension non signée ou incompatible refusée avec motif ; plan requis vérifié.
**US-EXT-04 (M)** — Une erreur d'extension n'affecte jamais le rendu : le rendu d'origine est utilisé et l'erreur est journalisée.
**US-EXT-05 (S)** — Je lance l'auto-test de non-régression (rendu identique sans extensions, chaque style sur chaque document, sections sans script).

---

### 7.22 Recherche globale et notifications

**Recherche globale** : saisie dans l'en-tête → écran de résultats ; synthèse ; résultats typés (Dossier, Document, Réunion, Message, Adhérent, Article de convention…) avec titre et méta ; état vide « Aucun résultat. Essayez « harcèlement », « NAO » ou « inaptitude ». »

**US-RCH-01 (M)** — Je recherche dans tous les modules depuis l'en-tête ; les résultats s'actualisent à la frappe ; Entrée ouvre l'écran de résultats.
**US-RCH-02 (M)** — J'ouvre un résultat et je reviens à la recherche par « Retour ».
**US-RCH-03 (M)** — La recherche respecte les droits (aucun résultat hors habilitation).

**Notifications** : liste (titre, corps, heure, non lu) ; « Tout marquer comme lu ».

**US-NTF-01 (M)** — Je consulte mes notifications et j'ouvre l'élément concerné.
**US-NTF-02 (M)** — Je marque tout comme lu ; la pastille de la cloche disparaît.

---

### 7.23 Console super administrateur

Barre latérale : Supervision · Organisations · Utilisateurs · Clés API IA · Éditeur de l'application · Abonnements et paiements · Journal d'audit. Carte « Super administrateur · admin@uniion.fr ». Bandeau permanent « Périmètre plateforme — aucun accès au contenu des dossiers, messages ou pièces des organisations. Chaque action ci-dessous est tracée. »

#### 7.23.1 Supervision
État de la plateforme à date : indicateurs (clé, valeur, sous-ligne) ; alertes (titre, statut).
**US-ADM-01 (M)** — Je surveille l'état de la plateforme et les alertes.

#### 7.23.2 Organisations
Liste : nom, type · offre, membres, adhérents, requêtes IA / mois, état (Actif, Essai — N j restants, Suspendu), Suspendre / Réactiver.
**US-ADM-02 (M)** — Je consulte les organisations et leurs volumes agrégés.
**US-ADM-03 (M)** — Je suspends ou réactive une organisation (confirmation, trace).

#### 7.23.3 Utilisateurs
Recherche + filtres (tous, actifs, suspendus, invitations, MFA absente…) ; compteur ; lignes (initiales, nom, e-mail, organisation, rôle, état, MFA · vu le) ; actions « Assistance », « Réinit. MFA », « Relancer » (invitation), Suspendre / Réactiver ; état vide.
**US-ADM-04 (M)** — Je recherche un compte toutes organisations confondues.
**US-ADM-05 (M)** — Je réinitialise la MFA d'un utilisateur, je relance une invitation, je suspends/réactive un compte.
**US-ADM-06 (S)** — J'ouvre une demande d'assistance pour un utilisateur, sans accès à ses contenus.

#### 7.23.4 Clés API IA
« Les clés ne quittent jamais la passerelle serveur. Affichage et copie tracés. » « Créer une clé » (Nom, Fournisseur UE) ; liste (nom, fournisseur · créée le, état Active/Révoquée, valeur masquée, Afficher/Masquer, Copier, Renouveler, Révoquer, consommation / plafond).
**US-ADM-07 (M)** — Je crée une clé (nom + fournisseur UE).
**US-ADM-08 (M)** — J'affiche, copie, renouvelle ou révoque une clé ; chaque action est tracée.
**US-ADM-09 (S)** — Je suis la consommation par clé par rapport au plafond.

#### 7.23.5 Éditeur de l'application
Disponibilité : Mode maintenance (page d'attente) · Nouvelles organisations (inscriptions depuis le site public) · Assistant IA disponible (coupure globale). Bandeau d'information (texte + aperçu, « Appliquer à la plateforme »). **Gabarits livrés** (nom, version · mise à jour, état, publier/retirer). Version de prompt en service ; rétention des échanges IA.
**US-ADM-10 (M)** — J'active le mode maintenance.
**US-ADM-11 (M)** — J'ouvre/ferme les inscriptions de nouvelles organisations.
**US-ADM-12 (M)** — Je coupe globalement l'IA en cas d'incident.
**US-ADM-13 (S)** — Je publie un bandeau d'information visible de tous.
**US-ADM-14 (S)** — Je publie ou retire les gabarits de documents et de pages livrés à toutes les organisations.

#### 7.23.6 Abonnements et paiements
Revenu mensuel récurrent ; formules (nom, Populaire, prix, nombre d'abonnements) ; abonnements (organisation, offre · prix · état) ; « Émettre une facture », « Relancer » ; filtres.
**US-ADM-15 (M)** — Je suis le MRR et les abonnements par formule.
**US-ADM-16 (M)** — J'émets une facture et je relance un impayé.

#### 7.23.7 Journal d'audit plateforme
« Chaîne d'empreintes inaltérable — conservation 36 mois. » ; lignes (horodatage, qui, quoi, niveau) ; « Exporter (CSV signé) ».
**US-ADM-17 (M)** — Je consulte et exporte le journal d'audit plateforme signé.

---

### 7.24 Composants transverses

- **Feuille d'action (« sheet »)** : titre, sous-titre, choix d'option (libellé + aide), canaux, champ éventuel, erreur, « Annuler » / bouton de confirmation ; écran de fin (titre, lignes de résultat, « Le fichier reste disponible dans Paramètres → Exports pendant 30 jours », action de retour). Utilisée pour : réinitialisation du mot de passe, export du bilan, export du journal d'audit, export des données RGPD, convocation, diffusion, téléchargement du document signé.
- **Modale de transfert** (7.10), **Modale dossier depuis message** (7.10), **Modale contact** et **Modale groupe** (7.11), **Contrôle d'anonymisation** (7.4.3), **Aperçu chiffré** (7.3.4), **Échec d'appel IA** (5.3).
- **Toast** : confirmation de toute action, 3 s environ, non bloquant.
- **Confirmation en deux temps** pour toute suppression (DEL-01).
- **Aperçu flottant** de carte pendant le glisser-déposer Kanban.

**US-TRV-01 (M)** — Chaque action d'écriture affiche un toast de confirmation.
**US-TRV-02 (M)** — Toute suppression exige une confirmation explicite.
**US-TRV-03 (M)** — Les exports sont conservés 30 jours et retrouvables dans Paramètres → Exports.
**US-TRV-04 (M)** — Les modales se ferment par « Annuler », Échap ou clic hors zone, et rendent le focus à l'élément d'origine.

---

## 8. Modèle de données fonctionnel

| Entité | Attributs principaux | Relations |
|---|---|---|
| Organisation | type (cse/section/ud), dénomination, sigle, SIRET, convention (IDCC), effectif, sièges, mandat début/fin, adresse, courriel, formule, marque | 1‑n Membres, Dossiers, Adhérents, Sites… |
| Membre | nom, initiales, e-mail, rôles, statut, dernière connexion, MFA, SSCT | n‑n Groupes, Dossiers (référent) |
| Dossier | id, catégorie, titre, description, statut (todo/doing/done), échéance, référent | 1‑n Historique, Pièces ; 0‑n Conversations IA |
| Pièce | nom, extension, taille, déposée par, date, versions, note | Dossier |
| Conversation IA | titre, origine, messages (texte, payload, niveau, source, journal) | 0‑1 Dossier |
| Fait mémorisé | catégorie, texte, origine, date | Utilisateur |
| Sondage | question, type, réponses, cible, canal, clôture, relance, relecteurs, statut, résultats agrégés | — (aucun lien votant) |
| Réunion | type, titre, date, durée, ordre du jour, audio (état, rétention), marqueurs, transcription, PV, journal d'accès, certificat de destruction | 0‑1 Document PV |
| Événement | titre, nature, date, début, fin, lieu, visibilité, note, rappel | Organisation |
| Document | titre, modèle, format, blocs, style, charte, statut, mise à jour | 0‑1 Signature |
| Signature | document, signataires (statut), certificat (horodatage, empreinte, niveau, journal) | Document |
| Conversation (messagerie) | type (groupe/direct/diffusion), nom, membres, admins, messages, sourdine, épinglage | Contacts |
| Contact | nom, catégorie (élu/adhérent/externe), fonction, téléphone, e-mail | Groupes |
| Adhérent | prénom, nom, courriel, téléphone, emploi, entreprise, établissement, section, direction, mandat, date d'adhésion, mode de règlement, montant, statut, historique | n‑n Listes |
| Liste de diffusion | nom, type (dynamique/fixe), critères, usage, canal | Adhérents |
| Site / Page web | site (intranet/public), rubrique, gabarit, thème, chapô, blocs, HTML, statut, relecture, demande de publication, retour webmaster | Charte du site |
| Publication (communication) | date, format, objectif, canal, titre, accroche, texte, CTA, visuel, statut | — |
| Page mobile | titre, type, public, blocs, push, statut, vues | — |
| Session de formation | thème, temps, niveau, rôle, objectif, modules, progression, score | Utilisateur |
| Raccourci | nom, URL, description, couleur | Utilisateur |
| Extension | source, nom, version, autorisations, éléments activés, erreurs | Organisation |
| Journal d'audit | horodatage, acteur, action, objet, empreinte | Organisation / Plateforme |

---

## 9. Exigences non fonctionnelles

- **Performance** : premier affichage < 2 s sur 4G ; navigation entre modules < 300 ms ; latence médiane IA affichée dans le reporting.
- **Disponibilité** : 99,5 % mensuelle ; page de maintenance ; supervision externe.
- **Sécurité** : OWASP ASVS niveau 2 ; test d'intrusion avant mise en production ; MFA admins ; sessions révocables.
- **Conformité** : RGPD (AIPD, registre, contrats de sous-traitance, droits sous 30 jours) ; eIDAS (signature avancée, horodatage qualifié) ; DSP2 (paiement).
- **Accessibilité** : RGAA 4 / WCAG 2.1 AA.
- **Compatibilité** : deux dernières versions de Chrome, Firefox, Safari, Edge ; iOS 16+, Android 12+.
- **Internationalisation** : français uniquement ; formats de date et de montant français.
- **Sauvegardes** : chiffrées, hors site, testées par restauration périodique.
- **Observabilité** : journaux techniques sans donnée personnelle ; alertes sur taux d'erreur et échecs de connexion.

---

## 10. Matrice de traçabilité (récapitulatif)

| Module | Préfixes | Nombre d'US |
|---|---|---|
| Organisation | ORG | 2 |
| Navigation | NAV | 4 |
| Authentification | AUTH | 9 |
| Accueil | ACC | 5 |
| Dossiers + pièces | DOS, PCE | 17 + 6 |
| Assistant, anonymisation, mémoire | AST, ANO, MEM | 15 + 5 + 5 |
| Sondages | SDG | 17 |
| Réunions | REU | 13 |
| Agenda | AGD | 11 |
| Documents, éditeur, générateur, bibliothèque | DOC, EDT, GEN, BIB | 4 + 12 + 4 + 4 |
| Signature | SIG | 6 |
| Messages, contacts | MSG, CTC | 14 + 3 |
| Adhérents, import, fiche, message | ADH, IMP, FAD, AMS | 11 + 6 + 5 + 5 |
| Intranet | WEB, WGN, WED, WPB, WQ, WCH | 4 + 2 + 6 + 1 + 3 + 4 |
| Communication, pôle | COM, POL | 9 + 3 |
| Application mobile | MOB | 7 |
| Formations | FOR, FMU | 3 + 9 |
| Reporting | REP | 6 |
| Raccourcis | RAC | 4 |
| Réglages | PRF, DMO, NOT, SEC, RGP, MBR, MRQ, CIA, OFF, ONB, BO, ABO | 3+1+3+4+3+3+8+5+2+2+1+4 |
| unii | UNI, UAC | 6 + 5 |
| Extensions | EXT | 5 |
| Recherche, notifications | RCH, NTF | 3 + 2 |
| Console super admin | ADM | 17 |
| Transverse | TRV | 4 |
| **Total** | | **325** |

---

## 11. Glossaire

- **ASC** : activités sociales et culturelles du CSE.
- **BDESE** : base de données économiques, sociales et environnementales.
- **CSE** : comité social et économique. **CSSCT** : commission santé, sécurité et conditions de travail.
- **DS** : délégué syndical. **UD** : union départementale.
- **NAO** : négociation annuelle obligatoire.
- **PV** : procès-verbal de séance.
- **RPS** : risques psychosociaux.
- **IDCC** : identifiant de convention collective.
- **eIDAS** : règlement européen sur l'identification et la signature électroniques.
- **Payload** : texte effectivement transmis au modèle, après masquage.
- **Jeton** : marqueur remplaçant une donnée identifiante (ex. `[MATRICULE]`).
- **unii** : assistant contextuel intégré à chaque module.
- **Charte** : ensemble des règles graphiques appliquées aux documents ou à un site.

# Inventaire de fidélité — uniion App v3

Référence figée : `uniion App v3.dc.html` (proto-v3.0, 2026-10-23). Généré automatiquement depuis le gabarit : 87 sections, lignes 1–7234.

**Règle** : une section n'est « conforme » que si les 6 cases sont cochées, captures prototype / application jointes à la demande de fusion. Écart visuel toléré : 0,5 % par capture.

Cases : V-B visuel bureau 1440 · V-T tablette 1024 · V-M mobile 390 · É tous les états · A toutes les actions · L libellés identiques (`libelles-v3.json`).

## Sommaire

| ID | Section | Lignes | États | Actions | Champs | Libellés |
|---|---|---|---|---|---|---|
| [AUTH](#auth) | Connexion (identifiant, SSO, double authentification, accès admin) | 42–130 | 8 | 4 | 3 | 28 |
| [ADM](#adm) | Console super-admin — coque | 131–168 | 3 | 2 | 0 | 6 |
| [ADM-SUP](#adm-sup) | Console admin — Supervision | 169–192 | 1 | 0 | 0 | 2 |
| [ADM-ORG](#adm-org) | Console admin — Organisations | 193–220 | 1 | 1 | 0 | 6 |
| [ADM-USR](#adm-usr) | Console admin — Utilisateurs | 221–266 | 4 | 2 | 1 | 7 |
| [ADM-KEY](#adm-key) | Console admin — Clés IA | 267–321 | 4 | 3 | 1 | 11 |
| [ADM-EDI](#adm-edi) | Console admin — Éditeur (paramètres plateforme) | 322–371 | 2 | 3 | 1 | 11 |
| [ADM-FAC](#adm-fac) | Console admin — Offres & facturation | 372–413 | 4 | 1 | 0 | 7 |
| [ADM-LOG](#adm-log) | Console admin — Journaux | 414–438 | 1 | 1 | 0 | 3 |
| [COQ-SB](#coq-sb) | Coque — barre latérale bureau | 439–505 | 8 | 3 | 0 | 6 |
| [COQ-MH](#coq-mh) | Coque — en-tête mobile | 506–535 | 7 | 2 | 1 | 2 |
| [COQ-UNII](#coq-unii) | Coque — bandeau unii | 536–544 | 1 | 1 | 0 | 1 |
| [ACC](#acc) | Accueil | 545–620 | 1 | 3 | 0 | 13 |
| [LEC](#lec) | Lecteur document / séance | 621–656 | 3 | 1 | 0 | 4 |
| [DOS](#dos) | Dossiers kanban | 657–775 | 12 | 6 | 1 | 10 |
| [DOS-NEW](#dos-new) | Nouveau dossier | 776–807 | 3 | 2 | 2 | 6 |
| [DOS-DET](#dos-det) | Detail dossier | 808–985 | 8 | 8 | 5 | 22 |
| [REP](#rep) | Reporting | 986–1231 | 7 | 3 | 0 | 27 |
| [PJ](#pj) | Pieces jointes | 1232–1320 | 4 | 4 | 0 | 12 |
| [SIG](#sig) | Signature electronique | 1321–1455 | 13 | 4 | 1 | 17 |
| [IA](#ia) | Assistant ia | 1456–1636 | 17 | 9 | 1 | 20 |
| [SON-NEW](#son-new) | Nouveau sondage | 1637–1652 | 1 | 1 | 0 | 3 |
| [SON-NEW-1](#son-new-1) | Étape 1 : questions | 1653–1698 | 3 | 2 | 2 | 5 |
| [SON-NEW-2](#son-new-2) | Étape 2 : diffusion | 1699–1763 | 5 | 3 | 0 | 7 |
| [SON-NEW-3](#son-new-3) | Étape 3 : relecture & diffusion | 1764–1841 | 6 | 2 | 0 | 10 |
| [SON](#son) | Liste sondages | 1842–1871 | 1 | 2 | 0 | 4 |
| [SON-DET](#son-det) | Detail sondage | 1872–1908 | 1 | 1 | 0 | 5 |
| [REU](#reu) | Reunions — liste | 1909–1983 | 4 | 3 | 1 | 11 |
| [REU-DIC](#reu-dic) | Reunions — dictaphone | 1984–1991 | 1 | 1 | 0 | 1 |
| [REU-DIC-1](#reu-dic-1) | Consentement | 1992–2035 | 1 | 2 | 0 | 5 |
| [REU-DIC-2](#reu-dic-2) | Attente d'autorisation micro | 2036–2050 | 1 | 1 | 0 | 4 |
| [REU-DIC-3](#reu-dic-3) | En cours / pause / terminé | 2051–2130 | 9 | 2 | 0 | 9 |
| [REU-DET](#reu-det) | Reunions — detail | 2131–2273 | 7 | 3 | 0 | 22 |
| [DOC](#doc) | Espace documents — accueil | 2274–2361 | 4 | 4 | 1 | 11 |
| [DOC-EDI](#doc-edi) | Espace documents — editeur | 2362–2389 | 1 | 2 | 1 | 4 |
| [DOC-EDI-C](#doc-edi-c) | Panneau contenu | 2390–2463 | 9 | 4 | 3 | 12 |
| [DOC-EDI-S](#doc-edi-s) | Panneau style (fourni par les extensions) | 2464–2534 | 11 | 4 | 1 | 10 |
| [DOC-EDI-CH](#doc-edi-ch) | Panneau charte | 2535–2729 | 18 | 7 | 5 | 14 |
| [DOC-GEN](#doc-gen) | Generateur de documents | 2730–2834 | 10 | 4 | 1 | 16 |
| [RAC](#rac) | Raccourcis | 2835–2902 | 4 | 3 | 3 | 17 |
| [AGE](#age) | Agenda partagé | 2903–3131 | 10 | 11 | 6 | 31 |
| [ADH](#adh) | Adherents — liste / groupes / cotisations | 3132–3377 | 15 | 11 | 5 | 24 |
| [ADH-IMP](#adh-imp) | Adherents — import csv | 3378–3485 | 7 | 3 | 1 | 21 |
| [ADH-FIC](#adh-fic) | Adherents — fiche | 3486–3621 | 9 | 4 | 1 | 15 |
| [ADH-MSG](#adh-msg) | Adherents — message | 3622–3721 | 3 | 4 | 3 | 14 |
| [INT](#int) | Intranet — accueil | 3722–3894 | 10 | 6 | 0 | 7 |
| [INT-GEN](#int-gen) | Intranet — generateur de pages | 3895–3992 | 4 | 5 | 1 | 18 |
| [INT-EDI](#int-edi) | Intranet — editeur de page | 3993–4113 | 13 | 6 | 4 | 16 |
| [INT-PUB](#int-pub) | Intranet — envoi au webmaster | 4114–4189 | 2 | 4 | 3 | 12 |
| [INT-SUI](#int-sui) | Intranet — suivi des publications | 4190–4239 | 4 | 1 | 0 | 5 |
| [INT-CHA](#int-cha) | Intranet — gabarit du site | 4240–4405 | 6 | 7 | 2 | 25 |
| [NOT](#not) | Centre de notifications | 4406–4427 | 1 | 1 | 0 | 2 |
| [RCH](#rch) | Recherche | 4428–4450 | 2 | 1 | 0 | 2 |
| [UNII-CFG](#unii-cfg) | Reglages unii | 4451–4511 | 6 | 3 | 0 | 15 |
| [EXT](#ext) | Extensions | 4512–4598 | 6 | 4 | 1 | 13 |
| [PAR](#par) | Parametres | 4599–4650 | 2 | 3 | 0 | 5 |
| [PAR-PRO](#par-pro) | Profil | 4651–4841 | 9 | 8 | 1 | 38 |
| [COM](#com) | Communication | 4842–4855 | 2 | 1 | 0 | 2 |
| [COM-PLAN](#com-plan) | Plan éditorial | 4856–4917 | 5 | 4 | 0 | 9 |
| [COM-ATE](#com-ate) | Atelier de contenus | 4918–4992 | 6 | 4 | 6 | 19 |
| [COM-POL](#com-pol) | Pôle communication | 4993–5079 | 4 | 2 | 1 | 18 |
| [MOB](#mob) | Application mobile | 5080–5293 | 10 | 9 | 4 | 30 |
| [FOR](#for) | Formations | 5294–5313 | 3 | 1 | 1 | 3 |
| [FOR-IA](#for-ia) | Catalogue ia | 5314–5379 | 2 | 3 | 0 | 9 |
| [FOR-GEN](#for-gen) | Catalogue généraliste | 5380–5417 | 3 | 2 | 0 | 5 |
| [FOR-UNII](#for-unii) | Formation avec unii | 5418–5591 | 17 | 9 | 4 | 32 |
| [CTC](#ctc) | Contacts & groupes | 5592–5648 | 4 | 5 | 1 | 15 |
| [MEM](#mem) | Memoire assistant | 5649–5722 | 5 | 4 | 2 | 11 |
| [PAR-NOT](#par-not) | Preferences notifications | 5723–5743 | 1 | 1 | 0 | 2 |
| [SEC-IA](#sec-ia) | Securite — documentation ia | 5744–5784 | 1 | 2 | 0 | 7 |
| [PAR-SEC](#par-sec) | Securite | 5785–5843 | 2 | 2 | 0 | 8 |
| [PAR-RGPD](#par-rgpd) | Rgpd | 5844–5917 | 1 | 1 | 0 | 15 |
| [PAR-MBR](#par-mbr) | Membres | 5918–5955 | 1 | 2 | 0 | 3 |
| [PAR-MAR](#par-mar) | Identite de marque | 5956–6169 | 8 | 8 | 5 | 36 |
| [PAR-IA](#par-ia) | Config ia | 6170–6310 | 5 | 4 | 1 | 24 |
| [MSG](#msg) | Messages — liste + fil + infos | 6311–6656 | 47 | 20 | 2 | 47 |
| [OFF](#off) | Mode hors ligne | 6657–6692 | 1 | 2 | 0 | 5 |
| [ONB](#onb) | Onboarding | 6693–6715 | 1 | 1 | 0 | 1 |
| [ADB](#adb) | Tableau de bord admin | 6716–6779 | 3 | 2 | 0 | 4 |
| [MOD-ANON](#mod-anon) | Fenêtre — Contrôle d'anonymisation | 6786–6890 | 9 | 3 | 0 | 18 |
| [MOD-IAERR](#mod-iaerr) | Fenêtre — Erreur IA | 6891–6909 | 2 | 1 | 0 | 4 |
| [UNII](#unii) | Panneau unii (assistant latéral) | 6910–7034 | 20 | 7 | 2 | 18 |
| [MOD-FWM](#mod-fwm) | Fenêtre — fwm (transfert/webmaster) | 7035–7057 | 1 | 2 | 1 | 2 |
| [MOD-DPM](#mod-dpm) | Fenêtre — dpm | 7058–7082 | 2 | 2 | 1 | 6 |
| [MOD-CTM](#mod-ctm) | Fenêtre — contact | 7083–7110 | 3 | 3 | 4 | 8 |
| [MOD-GRM](#mod-grm) | Fenêtre — groupe | 7111–7145 | 2 | 3 | 3 | 6 |
| [MOD-SHEET](#mod-sheet) | Feuille mobile (sheet) | 7146–7234 | 10 | 3 | 1 | 6 |

**Totaux** : 499 conditions d'affichage, 309 actions, 102 champs, 1027 libellés.

---

## AUTH

**Connexion (identifiant, SSO, double authentification, accès admin)** · lignes 42–130 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `notAuthed`
- [ ] `isDesktop`
- [ ] `isMobile`
- [ ] `authStepId`
- [ ] `authHasErr`
- [ ] `authStepSso`
- [ ] `authStepMfa`
- [ ] `authIsAdmin`

**Listes répétées** : `authCells` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `onAuthEmail` → « Mot de passe »
- [ ] Click `authSso`
- [ ] Click `authSsoConfirm`
- [ ] Click `authSubmitMfa`

**Attributs (placeholder, aria, title)** :
- placeholder: prenom.nom@syndicat.fr
- aria-label: Code à six chiffres

<details><summary>Libellés statiques (28)</summary>

- L'outil des élus, pas celui de la direction.
- Dossiers chiffrés de bout en bout, assistant juridique sourcé sur votre convention, consultations des salariés et bilan de mandat. Hébergement en France, aucun accès employeur.
- Chiffrement AES-256
- RGPD · données en France
- Anonymisation avant inférence IA
- Connexion
- Compte militant de la section syndicale Métallurgie — Valenciennes.
- Adresse professionnelle
- Mot de passe
- Continuer
- ou
- SSO fédération (SAML)
- Mot de passe oublié ?
- Accès super administrateur (admin@uniion.fr)
- Redirection SSO
- Authentification déléguée à l'annuaire de la fédération. Aucun mot de passe n'est stocké par uniion.
- Fournisseur d'identité
- idp.federation-metallurgie.fr
- Assertion SAML 2.0 signée · attributs mandat et établissement transmis.
- S'authentifier sur l'annuaire
- Revenir au mot de passe
- Vérification en deux étapes
- Vérifier et ouvrir la session
- Renvoyer un code
- Utiliser une clé de sécurité
- Changer de compte
- Compte plateforme — la session ouvrira la console d'administration, sans accès aux contenus des organisations.
- Démonstration : le code valide est `{authDemoCode}`.

</details>

## ADM

**Console super-admin — coque** · écran « Console admin » · lignes 131–168 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adminAuthed`
- [ ] `n.active`
- [ ] `n.idle`

**Listes répétées** : `adm.nav` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `n.go` → « {{ n.label }} »
- [ ] Click `adm.logout`

**Attributs (placeholder, aria, title)** :
- title: Se déconnecter
- aria-label: Se déconnecter

<details><summary>Libellés statiques (6)</summary>

- uniion
- Console d'administration
- SA
- Super administrateur
- admin@uniion.fr
- Périmètre plateforme — aucun accès au contenu des dossiers, messages ou pièces des organisations. Chaque action ci-dessous est tracée.

</details>

## ADM-SUP

**Console admin — Supervision** · lignes 169–192 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adm.isSup`

**Listes répétées** : `adm.kpis`, `adm.alerts` — tester 0, 1 et n éléments.

<details><summary>Libellés statiques (2)</summary>

- Supervision
- État de la plateforme au 11 septembre 2026.

</details>

## ADM-ORG

**Console admin — Organisations** · lignes 193–220 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adm.isOrgs`

**Listes répétées** : `adm.orgs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `o.suspend`

<details><summary>Libellés statiques (6)</summary>

- Organisations
- Sections, unions et CSE hébergés sur la plateforme.
- `{o.type}` · offre `{o.offre}`
- Membres
- Adhérents
- Requêtes IA / mois

</details>

## ADM-USR

**Console admin — Utilisateurs** · lignes 221–266 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adm.isUsers`
- [ ] `f.on`
- [ ] `f.off`
- [ ] `adm.usersEmpty`

**Listes répétées** : `adm.filters`, `adm.users` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `adm.onQuery`
- [ ] Click `u.impersonate`

**Attributs (placeholder, aria, title)** :
- placeholder: Rechercher un nom, un e-mail, une organisation

<details><summary>Libellés statiques (7)</summary>

- Utilisateurs
- Tous les comptes, toutes organisations confondues. `{adm.usersCount}` affiché(s).
- Aucun compte ne correspond à cette recherche.
- `{u.mfaLabel}` · vu `{u.vu}`
- Assistance
- Réinit. MFA
- Relancer

</details>

## ADM-KEY

**Console admin — Clés IA** · lignes 267–321 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adm.isKeys`
- [ ] `adm.keyNew`
- [ ] `p.on`
- [ ] `p.off`

**Listes répétées** : `adm.keyProviders`, `adm.keys` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `adm.keyAdd`
- [ ] Click `p.go`
- [ ] Click `k.reveal`

**Attributs (placeholder, aria, title)** :
- placeholder: Ex. Production — synthèse

<details><summary>Libellés statiques (11)</summary>

- Clés API IA
- Les clés ne quittent jamais la passerelle serveur. Affichage et copie tracés.
- Créer une clé
- Nom de la clé
- Fournisseur (UE)
- Annuler
- Créer
- `{k.fournisseur}` · créée le `{k.creee}`
- Copier
- Renouveler
- plafond `{k.quota}`

</details>

## ADM-EDI

**Console admin — Éditeur (paramètres plateforme)** · lignes 322–371 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adm.isEditor`
- [ ] `adm.edBannerShown`

**Listes répétées** : `adm.edToggles`, `adm.edTemplates` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `t.toggle`
- [ ] Click `adm.edPublish`
- [ ] Click `t.act`

**Attributs (placeholder, aria, title)** :
- placeholder: Ex. Maintenance planifiée samedi 13/09 de 8 h à 10 h.

<details><summary>Libellés statiques (11)</summary>

- Éditeur de l'application
- Réglages globaux, message d'information et gabarits livrés à toutes les organisations.
- Disponibilité
- Bandeau d'information (visible par tous)
- Aperçu : `{adm.edBanner}`
- Appliquer à la plateforme
- Gabarits livrés
- Modèles de documents et de pages proposés par défaut dans chaque organisation.
- `{t.v}` · mis à jour le `{t.maj}`
- Version de prompt en service :
- · rétention des échanges IA :

</details>

## ADM-FAC

**Console admin — Offres & facturation** · lignes 372–413 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adm.isBilling`
- [ ] `p.pop`
- [ ] `p.on`
- [ ] `p.off`

**Listes répétées** : `adm.billPlans`, `adm.billRows`, `b.plans` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `b.invoice`

<details><summary>Libellés statiques (7)</summary>

- Abonnements et paiements
- Revenu mensuel récurrent :
- Populaire
- abonnement(s)
- `{b.offre}` · `{b.prix}` · `{b.etat}`
- Émettre une facture
- Relancer

</details>

## ADM-LOG

**Console admin — Journaux** · lignes 414–438 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adm.isLogs`

**Listes répétées** : `adm.logs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `adm.exportLogs`

<details><summary>Libellés statiques (3)</summary>

- Journal d'audit
- Chaîne d'empreintes inaltérable — conservation 36 mois.
- Exporter (CSV signé)

</details>

## COQ-SB

**Coque — barre latérale bureau** · lignes 439–505 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `authed`
- [ ] `isDesktop`
- [ ] `sbFull`
- [ ] `brandDefaultLogo`
- [ ] `brandHasCustomLogo`
- [ ] `sbMini`
- [ ] `item.active`
- [ ] `item.idle`

**Listes répétées** : `navItems` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `sbToggle`
- [ ] Click `item.go` → « {{ item.label }} »
- [ ] Click `goAssistant`

**Attributs (placeholder, aria, title)** :
- title: Réduire le menu
- aria-label: Réduire le menu
- title: Déplier le menu
- aria-label: Déplier le menu
- title: Se déconnecter
- aria-label: Se déconnecter
- title: Assistant IA
- aria-label: Assistant IA
- aria-label: Mon profil

<details><summary>Libellés statiques (6)</summary>

- u
- Assistant IA
- Une question de droit ?
- Ouvrir le chat
- SM
- Déléguée syndicale

</details>

## COQ-MH

**Coque — en-tête mobile** · lignes 506–535 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isMobile`
- [ ] `brandDefaultLogo`
- [ ] `brandHasCustomLogo`
- [ ] `showBack`
- [ ] `unii.hasSugg`
- [ ] `unii.locked`
- [ ] `hasUnread`

**Actions** :
- [ ] Click `goBack`
- [ ] Click `goNotifs`

**Attributs (placeholder, aria, title)** :
- placeholder: Rechercher un dossier, un document, une réponse IA…
- title: Demander à unii
- aria-label: Demander à unii
- title: Se déconnecter
- aria-label: Se déconnecter

<details><summary>Libellés statiques (2)</summary>

- ← Retour
- unii

</details>

## COQ-UNII

**Coque — bandeau unii** · lignes 536–544 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `unii.showStrip`

**Listes répétées** : `unii.suggs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `sg.go`

<details><summary>Libellés statiques (1)</summary>

- unii suggère

</details>

## ACC

**Accueil** · lignes 545–620 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isAccueil`

**Listes répétées** : `quickActions`, `homeDossiers`, `agenda` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `goAccident` → « Urgent »
- [ ] Click `qa.go` → « {{ qa.label }} »
- [ ] Click `ev.go` → « {{ ev.date }} »

<details><summary>Libellés statiques (13)</summary>

- Bonjour,
- `{orgName}` · `{openCount}` dossiers ouverts, 1 échéance légale cette semaine
- Urgent
- il y a 10 min
- Accident Atelier B
- Enquête CSSCT déclenchée. Accusé de réception attendu sous 4 h.
- Sondage NAO en cours
- Priorités salariales 2027
- 75 % de participation
- Mes dossiers
- Tout voir
- Agenda partagé
- Prochaines échéances

</details>

## LEC

**Lecteur document / séance** · lignes 621–656 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isViewer`
- [ ] `viewerIsDoc`
- [ ] `viewerIsEvent`

**Listes répétées** : `viewer.extracts` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `viewerAsk`

<details><summary>Libellés statiques (4)</summary>

- Analyser sans identité
- Joindre à un dossier
- Télécharger
- Préparer l'ordre du jour

</details>

## DOS

**Dossiers kanban** · lignes 657–775 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isDossiers`
- [ ] `c.isGhost`
- [ ] `c.isCard`
- [ ] `c.hasUniiTip`
- [ ] `c.grabbed`
- [ ] `c.canLeft`
- [ ] `c.canRight`
- [ ] `c.aiOpen`
- [ ] `m.isUser`
- [ ] `m.isBot`
- [ ] `c.aiTyping`
- [ ] `col.empty`

**Listes répétées** : `columns`, `col.items`, `c.aiMsgs`, `c.aiSuggest` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `goNouveau`
- [ ] Click `c.go` → « {{ c.tag }} »
- [ ] Click `c.moveLeft`
- [ ] Click `c.aiClose`
- [ ] Click `s.go`
- [ ] Click `c.go`

**Attributs (placeholder, aria, title)** :
- aria-label: Fermer l'assistant
- placeholder: Question sur ce dossier…
- aria-label: Envoyer à l'assistant

<details><summary>Libellés statiques (10)</summary>

- Gestion de projet
- Suivi des demandes
- `{dossierCount}` dossiers · 2 échéances légales · mandat de déléguée syndicale
- Glissez une carte pour changer son état — ou sélectionnez-la et utilisez ← →
- + Nouveau dossier
- Carte saisie — ← → pour déplacer, Espace pour déposer
- IA
- Assistant · `{c.aiLevel}`
- Analyse complète
- Déposez un dossier ici

</details>

## DOS-NEW

**Nouveau dossier** · lignes 776–807 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isNouveau`
- [ ] `t.selected`
- [ ] `t.idle`

**Listes répétées** : `tagOptions` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `onNewTitle` → « Catégorie »
- [ ] Change `onNewDesc`

**Attributs (placeholder, aria, title)** :
- placeholder: ex. Demande de reclassement — atelier peinture
- placeholder: Faits, date, service concerné, demande du salarié…

<details><summary>Libellés statiques (6)</summary>

- Nouveau dossier
- Visible uniquement des élus. Données minimisées (RGPD).
- Intitulé
- Catégorie
- Contexte
- Créer le dossier

</details>

## DOS-DET

**Detail dossier** · lignes 808–985 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isDossier`
- [ ] `dossier.reading`
- [ ] `dossier.editing`
- [ ] `m.isUser`
- [ ] `m.isBot`
- [ ] `dchatTyping`
- [ ] `e.selected`
- [ ] `e.idle`

**Listes répétées** : `dossier.timeline`, `dchatContext`, `dchatMsgs`, `dchatSuggest`, `elus` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `dossier.edit`
- [ ] Change `dossier.onLong` → « Échéance »
- [ ] Change `onNote`
- [ ] Click `goCourrier`
- [ ] Click `dchatToAsst`
- [ ] Click `s.go`
- [ ] Click `goIaSecu`
- [ ] Click `e.go` → « {{ e.initials }} »

**Attributs (placeholder, aria, title)** :
- placeholder: Ajouter une note au dossier…
- title: Ouvrir ce sujet dans l'Assistant
- placeholder: Poser une question sur ce dossier…
- aria-label: Envoyer à l'assistant

<details><summary>Libellés statiques (22)</summary>

- Modifier le dossier
- Intitulé
- Description
- Échéance
- Terminer la modification
- Statut
- Référent
- Historique
- Ajouter
- Actions
- Analyser sans identité →
- Générer un courrier à la direction
- Pièces jointes
- Assistant du dossier
- Contexte chargé
- Mode assistant
- En savoir plus sur la sécurité
- Analyse complète →
- Assigner à un élu
- Seuls les élus formés SSCT apparaissent en gras.
- Cloisonnement
- Ce dossier est chiffré et invisible pour l'employeur. Journal d'accès conservé 5 ans (audit RGPD).

</details>

## REP

**Reporting** · lignes 986–1231 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isReporting`
- [ ] `p.selected`
- [ ] `p.idle`
- [ ] `t.selected`
- [ ] `t.idle`
- [ ] `repIsCse`
- [ ] `repIsUsage`

**Listes répétées** : `repPeriods`, `repTabs`, `repKpis`, `repMonths`, `repThemes`, `repRows`, `useKpis`, `useModules`, `useWeeks`, `useAiRows`, `useAnon`, `useProd`, `useTop`, `useHealth` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `p.go`
- [ ] Click `repExportPdf`
- [ ] Click `useExportPdf`

<details><summary>Libellés statiques (27)</summary>

- Pilotage
- Reporting
- Dossiers par mois
- Ouverts en orange, clos en gris.
- Répartition par thème
- Activité du mandat
- Exporter le bilan
- Le bilan reprend la mise en forme attendue pour l'annexe du rapport annuel du CSE. Aucune donnée nominative de salarié n'y figure.
- Bilan annuel (PDF)
- Données détaillées (Excel)
- Partager en lecture seule aux élus
- Utilisation par module
- Ouvertures d'écran sur la période, tous élus confondus.
- Sessions par semaine
- Mobile en orange, poste de travail en gris.
- Assistant IA
- Quota mutualisé de l'organisation · `{useAiQuota}`
- Niveau d'anonymisation des appels
- Contenus produits
- Élus les plus actifs
- Visible des seuls administrateurs de l'organisation.
- Fiabilité et hors ligne
- Exporter le rapport d'usage
- Statistiques agrégées uniquement. Aucun contenu de dossier, de message ou de requête IA n'est exporté.
- Rapport d'usage (PDF)
- Données brutes (Excel)
- Gérer les sièges et les accès →

</details>

## PJ

**Pieces jointes** · lignes 1232–1320 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isPieces`
- [ ] `uploading`
- [ ] `noPieces`
- [ ] `hasPiece`

**Listes répétées** : `pieces`, `piece.versions` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `pickFile` → « Déposer un document »
- [ ] Click `p.go` → « {{ p.ext }} »
- [ ] Click `openPiece`
- [ ] Click `attachToDoc`

<details><summary>Libellés statiques (12)</summary>

- Coffre du dossier
- Pièces jointes
- Déposer un document
- PDF, image, audio · 25 Mo max · chiffré à l'envoi
- Aucune pièce pour l'instant. Les documents déposés ici sont chiffrés et invisibles pour l'employeur.
- Ouvrir l'aperçu
- Versions
- Déposer une nouvelle version
- Joindre à un courrier
- Supprimer la pièce
- Traçabilité
- Chaque dépôt, ouverture et suppression est horodaté dans le journal d'audit. Les pièces suivent la durée de conservation du dossier (5 ans).

</details>

## SIG

**Signature electronique** · lignes 1321–1455 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isSignature`
- [ ] `doc.selected`
- [ ] `doc.idle`
- [ ] `sigHasOrigin`
- [ ] `sigSigned`
- [ ] `sigIsScript`
- [ ] `sigIsSerif`
- [ ] `sigIsPrint`
- [ ] `sigUnsigned`
- [ ] `st.selected`
- [ ] `st.idle`
- [ ] `sigCanSign`
- [ ] `sigBlocked`

**Listes répétées** : `sigDocs`, `sigSigners`, `sigStyles`, `sigCert` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `doc.go`
- [ ] Change `onSigName` → « Style »
- [ ] Click `sigSign`
- [ ] Click `sigDownload`

<details><summary>Libellés statiques (17)</summary>

- Signature électronique
- Provenance : `{sigOrigin}`
- Pour les élus
- Signé le `{sigStamp}`
- Zone de signature — en attente
- Pour la direction
- Signataires
- Apposer ma signature
- Signature avancée eIDAS : identité vérifiée par le second facteur de votre session.
- Nom apposé
- Style
- Je reconnais avoir lu le document et j'accepte que ma signature électronique ait la même valeur qu'une signature manuscrite.
- Signer le document
- Certificat de signature
- Télécharger le document signé
- Envoyer aux cosignataires
- Annuler ma signature

</details>

## IA

**Assistant ia** · écran « Assistant IA » · lignes 1456–1636 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isAssistant`
- [ ] `asst.notFull`
- [ ] `asst.hasBack`
- [ ] `asst.full`
- [ ] `asst.empty`
- [ ] `l.selected`
- [ ] `l.idle`
- [ ] `m.isUser`
- [ ] `m.payload`
- [ ] `m.isBot`
- [ ] `m.reidLine`
- [ ] `m.logLine`
- [ ] `m.hasSuggest`
- [ ] `m.canMemo`
- [ ] `m.memoDone`
- [ ] `typing`
- [ ] `showAiDisclaimer`

**Listes répétées** : `asst.filters`, `asst.convs`, `anonLevels`, `messages`, `presets` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `asst.goBack`
- [ ] Click `asst.toggleFull`
- [ ] Click `asst.newConv`
- [ ] Click `fl.go`
- [ ] Click `cv.del`
- [ ] Click `l.go`
- [ ] Click `m.memoAccept`
- [ ] Click `p.go`
- [ ] Click `goIaSecu`

**Attributs (placeholder, aria, title)** :
- title: Gérer la mémoire de l'assistant
- aria-label: Supprimer la conversation
- title: Supprimer
- placeholder: Posez votre question…

<details><summary>Libellés statiques (20)</summary>

- Intelligence artificielle
- Votre expert juridique de poche
- Sourcé sur la Convention Métallurgie et le Code du travail
- ← `{asst.backLabel}`
- Nouvelle conversation
- Nouveau dossier guidé
- Historique
- `{cv.when}` · `{cv.n}`
- Aucune conversation pour ce filtre.
- uniion Assistant
- Aucune identité transmise
- Niveau d'anonymisation
- Reçu par le modèle
- `{m.levelLabel}` · `{m.tagCount}`
- Retenir pour la suite ?
- Mémoriser
- Ignorer
- ✓ En mémoire
- Réponses produites par un modèle de langage souverain hébergé dans l'Union européenne, sur le seul corpus de votre organisation (convention, accords, PV) et à partir d'un texte anonymisé — à vérifier avant tout usage contentieux.
- En savoir plus sur la sécurité

</details>

## SON-NEW

**Nouveau sondage** · lignes 1637–1652 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isNewPoll`

**Listes répétées** : `npSteps` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `s.go` → « {{ s.n }} »

<details><summary>Libellés statiques (3)</summary>

- Consultation des salariés
- Nouveau sondage
- Vote anonyme, une seule réponse par salarié. Aucune donnée nominative n'est conservée.

</details>

## SON-NEW-1

**Étape 1 : questions** · lignes 1653–1698 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `npStep1`
- [ ] `t.selected`
- [ ] `t.idle`

**Listes répétées** : `npTypes`, `npOptions` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `onNpTitle` → « Type de réponse »
- [ ] Change `o.onChange`

**Attributs (placeholder, aria, title)** :
- placeholder: ex. Quelle priorité pour la NAO 2027 ?
- title: Supprimer

<details><summary>Libellés statiques (5)</summary>

- Question posée aux salariés
- Type de réponse
- Réponses proposées
- + Ajouter une réponse
- Propositions de l'assistant

</details>

## SON-NEW-2

**Étape 2 : diffusion** · lignes 1699–1763 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `npStep2`
- [ ] `t.selected`
- [ ] `t.idle`
- [ ] `c.selected`
- [ ] `c.idle`

**Listes répétées** : `npTargets`, `npCloses` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `t.go` → « {{ t.label }} »
- [ ] Click `c.go`
- [ ] Click `toggleRemind`

<details><summary>Libellés statiques (7)</summary>

- Cible
- Clôture du vote
- Vote strictement anonyme
- Imposé par la configuration de l'organisation — les réponses ne sont jamais reliées à un salarié.
- Verrouillé
- Relance automatique
- Rappel push aux non-répondants à 48 h de la clôture.

</details>

## SON-NEW-3

**Étape 3 : relecture & diffusion** · lignes 1764–1841 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `npStep3`
- [ ] `npCanReview`
- [ ] `npAwaiting`
- [ ] `npApproved`
- [ ] `npHasPrev`
- [ ] `npHasNext`

**Listes répétées** : `npPreviewOptions`, `npChecks`, `npValidators` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `npSendReview`
- [ ] Click `npNext`

<details><summary>Libellés statiques (10)</summary>

- Aperçu côté salarié
- Tel qu'il apparaîtra dans l'app et sur l'affichage QR code.
- Vote anonyme
- Contrôles de conformité
- Modération
- Envoyer en relecture
- Relancer les relecteurs
- Diffuser à `{npAudienceCount}` salariés
- ← Étape précédente
- Enregistrer le brouillon

</details>

## SON

**Liste sondages** · lignes 1842–1871 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isSondages`

**Listes répétées** : `polls` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `newPoll`
- [ ] Click `p.del.act`

<details><summary>Libellés statiques (4)</summary>

- Démocratie sociale
- Sondages salariés
- Votes anonymes · 416 salariés inscrits
- + Lancer un sondage

</details>

## SON-DET

**Detail sondage** · lignes 1872–1908 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isSondage`

**Listes répétées** : `poll.results` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `goTractFromPoll`

<details><summary>Libellés statiques (5)</summary>

- Résultats
- Générer le tract →
- Relancer les non-répondants
- Anonymat garanti
- Aucun lien technique n'est conservé entre l'identité du votant et son choix.

</details>

## REU

**Reunions — liste** · lignes 1909–1983 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isReunions`
- [ ] `noImport`
- [ ] `hasImport`
- [ ] `importDone`

**Listes répétées** : `importSteps`, `reunionList` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `goRecord` → « Enregistrer une réunion »
- [ ] Change `onAudioFile` → « {{ importName }} »
- [ ] Click `confirmImportBtn`

<details><summary>Libellés statiques (11)</summary>

- Séances & procès-verbaux
- Réunions
- Enregistrer une réunion
- Dictaphone avec marqueurs de séance. Consentement des participants demandé avant le premier octet.
- Importer un enregistrement
- Fichier du dictaphone, de la visio ou de la salle. Chiffré sur l'appareil, même règle de destruction.
- Choisir un fichier audio
- Créer la réunion
- Annuler
- Toutes les réunions
- `{re.date}` · `{re.dur}`

</details>

## REU-DIC

**Reunions — dictaphone** · lignes 1984–1991 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isRecord`

**Actions** :
- [ ] Click `backToReunions`

<details><summary>Libellés statiques (1)</summary>

- Réunions

</details>

## REU-DIC-1

**Consentement** · lignes 1992–2035 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `recConsent`

**Listes répétées** : `recTypes`, `recChecks`, `recPolicy` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `rt.go`
- [ ] Click `startRec`

<details><summary>Libellés statiques (5)</summary>

- Avant d'enregistrer
- L'enregistrement d'une séance suppose l'accord des personnes présentes. Deux confirmations sont requises avant que le micro ne s'ouvre.
- Type de réunion
- Ce qui est fait de l'enregistrement
- Le navigateur demandera l'accès au micro. En cas de refus, la maquette basculera en enregistrement simulé.

</details>

## REU-DIC-2

**Attente d'autorisation micro** · lignes 2036–2050 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `recAsking`

**Actions** :
- [ ] Click `recSimNow`

<details><summary>Libellés statiques (4)</summary>

- Autorisation du micro demandée
- Acceptez l'accès dans le bandeau du navigateur. Sans réponse au bout de quelques secondes, la maquette passe en enregistrement simulé.
- Continuer en simulé
- Annuler

</details>

## REU-DIC-3

**En cours / pause / terminé** · lignes 2051–2130 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `recActive`
- [ ] `recErr`
- [ ] `recRunning`
- [ ] `recPaused`
- [ ] `recStoppable`
- [ ] `recDone`
- [ ] `recMarkable`
- [ ] `recHasMarks`
- [ ] `recNoMarks`

**Listes répétées** : `recBars`, `markerBtns`, `recMarks` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `pauseRec`
- [ ] Click `mk.go`

<details><summary>Libellés statiques (9)</summary>

- Pause
- Reprendre
- Arrêter
- Enregistrer la séance
- Supprimer
- Marqueurs de séance
- Un tap pendant la réunion : le marqueur devient un point d'ancrage du PV, horodaté à la seconde.
- Marqueurs posés
- Aucun marqueur pour l'instant. Posez-en un au moment d'un vote, d'un engagement de la direction ou d'un désaccord.

</details>

## REU-DET

**Reunions — detail** · lignes 2131–2273 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isReunion`
- [ ] `reu.hasOrdre`
- [ ] `reu.hasAudio`
- [ ] `reu.isDestroyed`
- [ ] `reu.hasMarkers`
- [ ] `reu.noMarkers`
- [ ] `reu.hasAccess`

**Listes répétées** : `reu.ordre`, `reu.proofs`, `reu.markers`, `extractFamilies`, `reu.access` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `backToReunions`
- [ ] Click `reu.writePv`
- [ ] Click `reu.cert`

<details><summary>Libellés statiques (22)</summary>

- Réunions
- `{reu.date}` · durée `{reu.dur}`
- Procès-verbal
- Marqueurs
- Enregistrement
- Ordre du jour
- Passer en mode assistant
- Écouter l'enregistrement
- En savoir plus sur la sécurité
- Rétention de l'audio
- Destruction certifiée dès l'approbation du PV, ou à échéance des 30 jours — au premier des deux.
- Audio détruit
- Destruction certifiée
- Enregistrement et transcription supprimés le `{reu.destroyedWhen}`, à l'approbation du PV. Voici ce qui subsiste comme preuve.
- Télécharger le certificat de destruction
- Marqueurs de séance
- Points d'ancrage du PV. Chaque marqueur pointe la seconde exacte du passage.
- Aucun marqueur sur cette séance.
- Transcription & extraction
- Transcription et extraction passent par l'anonymisation avant inférence : les noms deviennent des jetons, recollés côté client.
- Journal d'accès à l'enregistrement
- `{a.what}` · `{a.when}`

</details>

## DOC

**Espace documents — accueil** · lignes 2274–2361 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isDocs`
- [ ] `charteHasLogo`
- [ ] `charteNoLogo`
- [ ] `canUseBrandLogo`

**Listes répétées** : `docModels`, `docList` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `onLogoFile`
- [ ] Click `goAiDoc` → « Rédiger avec l'assistant »
- [ ] Click `dd.open` → « {{ dd.title }} »
- [ ] Click `dd.del.act`

**Attributs (placeholder, aria, title)** :
- aria-label: Logo par défaut des documents
- aria-label: Rédiger un document avec l'assistant

<details><summary>Libellés statiques (11)</summary>

- Création de documents
- Documents
- aucun
- Logo par défaut des documents
- Reprendre celui de la marque
- Retirer
- Partir d'un modèle
- Rédiger avec l'assistant
- Depuis un dossier, un sondage ou la convention — prompt anonymisé avant envoi.
- Ouvrir →
- Mes documents

</details>

## DOC-EDI

**Espace documents — editeur** · lignes 2362–2389 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isDocEdit`

**Listes répétées** : `docTabs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `backToDocs`
- [ ] Click `docDiffuse`

**Attributs (placeholder, aria, title)** :
- aria-label: Revenir à la liste des documents
- aria-label: Panneaux de l'éditeur

<details><summary>Libellés statiques (4)</summary>

- Titre du document
- Imprimer / PDF
- Faire signer
- Diffuser

</details>

## DOC-EDI-C

**Panneau contenu** · lignes 2390–2463 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `docTabContent`
- [ ] `dsx.hasMissing`
- [ ] `docModeBlocks`
- [ ] `b.editable`
- [ ] `b.canImg`
- [ ] `b.hasImg`
- [ ] `b.isBreak`
- [ ] `b.hint`
- [ ] `docModeSource`

**Listes répétées** : `docModes`, `blockInserts`, `docBlocks` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `dsx.goSlots`
- [ ] Click `b.up`
- [ ] Change `b.onImg`
- [ ] Change `onDocSource`

**Attributs (placeholder, aria, title)** :
- aria-label: Déplacer ce bloc vers le haut
- aria-label: Déplacer ce bloc vers le bas
- aria-label: Supprimer ce bloc
- aria-label: Image du bloc
- aria-label: Source Markdown du document

<details><summary>Libellés statiques (12)</summary>

- Ajouter les images
- Contenu
- Retirer l'image
- nouvelle page
- Markdown :
- # titre
- ## intertitre
- - liste
- &gt; encadré
- [badge]
- | a | b |
- saut de page.

</details>

## DOC-EDI-S

**Panneau style (fourni par les extensions)** · lignes 2464–2534 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `docTabStyle`
- [ ] `dsx.hasSuggs`
- [ ] `dsx.hasAsk`
- [ ] `dsx.locked`
- [ ] `dsx.hasCur`
- [ ] `dsx.hasNotice`
- [ ] `dsx.hasSlots`
- [ ] `sl.hasImg`
- [ ] `dsx.hasPals`
- [ ] `dsx.hasFonts`
- [ ] `dsx.hasFmt`

**Listes répétées** : `dsx.suggs`, `dsx.list`, `dsx.slots`, `dsx.pals`, `dsx.fonts` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `sg.go` → « {{ sg.el }} »
- [ ] Click `dsx.classic.go` → « {{ dsx.classic.label }} »
- [ ] Change `sl.onImg`
- [ ] Click `f.go`

<details><summary>Libellés statiques (10)</summary>

- unii propose 3 styles pour ce document
- Adapter le texte à ce style avec unii
- Les propositions de style par unii sont incluses à partir de l'offre Élu 2.0.
- Style graphique
- Images de ce style
- Retirer
- Astuce : glissez une image directement sur l'aperçu de la page.
- Palette
- Polices
- Le style réorganise vos blocs sur la page ; le contenu n'est pas modifié. Revenez à « Classique » à tout moment.

</details>

## DOC-EDI-CH

**Panneau charte** · lignes 2535–2729 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `docTabCharte`
- [ ] `charteHasLogo`
- [ ] `charteNoLogo`
- [ ] `charteIdentOverride`
- [ ] `docOverflow`
- [ ] `pg.isExt`
- [ ] `pg.showHeader`
- [ ] `pg.hasLogo`
- [ ] `b.isExt`
- [ ] `b.isTag`
- [ ] `b.isH1`
- [ ] `b.isH2`
- [ ] `b.isH3`
- [ ] `b.isP`
- [ ] `b.isUl`
- [ ] `b.isQuote`
- [ ] `b.isTable`
- [ ] `pg.showFooter`

**Listes répétées** : `accentSwatches`, `inkSwatches`, `fontOptions`, `densityOpts`, `charteSwitches`, `charteFields`, `formatOpts`, `zoomOpts`, `docPages`, `pg.blocks`, `b.items`, `b.cells` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `sw.go`
- [ ] Change `onTitleFont` → « {{ f.label }} »
- [ ] Click `dn.go`
- [ ] Change `onLogoFile`
- [ ] Change `f.onChange` → « Identité de l'émetteur saisie à la main : elle ne suit plus  »
- [ ] Click `fo.go`
- [ ] Drop `dsx.drop` → « {{ pg.extEl }} »

**Attributs (placeholder, aria, title)** :
- aria-label: Logo actuel de l'organisation
- aria-label: Logo de l'organisation

<details><summary>Libellés statiques (14)</summary>

- Couleur d'accent
- Code hexadécimal
- Couleur du texte
- Police des titres
- Police du texte
- Densité du texte
- Logo de l'organisation
- aucun
- Importer un logo
- Retirer le logo
- PNG ou SVG, fond transparent de préférence. Le fichier reste sur l'appareil.
- En-tête & pied de page
- Identité de l'émetteur saisie à la main : elle ne suit plus les informations de l'organisation.
- Reprendre celle de l'organisation

</details>

## DOC-GEN

**Generateur de documents** · lignes 2730–2834 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isTract`
- [ ] `dt.selected`
- [ ] `dt.idle`
- [ ] `t.selected`
- [ ] `t.idle`
- [ ] `tractReady`
- [ ] `brandDefaultLogo`
- [ ] `brandHasCustomLogo`
- [ ] `signable`
- [ ] `tractEmpty`

**Listes répétées** : `docTypes`, `tones`, `doc.items`, `genTrace` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `dt.go`
- [ ] Click `t.go`
- [ ] Click `goIaSecu`
- [ ] Click `printDoc`

<details><summary>Libellés statiques (16)</summary>

- Communication & mobilisation
- Générateur de documents
- Type de document
- Points clés
- Passer en mode assistant
- Ton
- Le prompt part anonymisé : noms, matricules et établissement sont remplacés par des jetons. La signature (Sophie Marchand — CSE) est recollée localement après génération.
- En savoir plus sur la sécurité
- — `{li.text}`
- Recollé côté client — jamais transmis au modèle
- Imprimer le PDF
- Faire signer
- Diffuser aux salariés
- Document généré par IA — à relire avant diffusion.
- aperçu du document
- Lancez la génération pour voir la mise en page automatique.

</details>

## RAC

**Raccourcis** · écran « Raccourcis » · lignes 2835–2902 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isRaccourcis`
- [ ] `sc.editing`
- [ ] `sc.empty`
- [ ] `s.armed`

**Listes répétées** : `sc.colors`, `sc.items` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `sc.add`
- [ ] Change `sc.setNote` → « Couleur »
- [ ] Click `s.del`

**Attributs (placeholder, aria, title)** :
- placeholder: Ex. Légifrance
- placeholder: https://
- placeholder: À quoi sert ce lien
- aria-label: Couleur

<details><summary>Libellés statiques (17)</summary>

- Écosystème
- Raccourcis
- Vos applications externes, réunies ici. `{sc.count}`.
- Ajouter un raccourci
- Nom
- Adresse (https://…)
- Description (facultatif)
- Couleur
- Annuler
- Enregistrer
- Aucun raccourci. Ajoutez vos outils (visio, fédération, Légifrance, drive…) pour les retrouver ici.
- `{s.host}` ↗
- Supprimer ?
- Oui
- Non
- Modifier
- Supprimer

</details>

## AGE

**Agenda partagé** · écran « Agenda » · lignes 2903–3131 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isAgenda`
- [ ] `ag.filterOn`
- [ ] `ag.isMonth`
- [ ] `dy.hasMore`
- [ ] `ag.isList`
- [ ] `ag.newOpen`
- [ ] `ag.newClosed`
- [ ] `ag.selEmpty`
- [ ] `ag.hasEvt`
- [ ] `ag.evt.hasInvites`

**Listes répétées** : `ag.views`, `ag.types`, `ag.dayNames`, `ag.weeks`, `w.days`, `dy.chips`, `ag.agenda`, `ag.f.types`, `ag.f.visibs`, `ag.selList`, `ag.evt.invites`, `ag.upcoming` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `ag.prev`
- [ ] Click `v.go`
- [ ] Click `dy.pick`
- [ ] Click `ag.cancelNew`
- [ ] Change `ag.f.onDate` → « Début »
- [ ] Change `ag.f.onLieu` → « Visibilité »
- [ ] Change `ag.f.onNotes` → « Rappel 48 h avant »
- [ ] Click `ag.addHere`
- [ ] Click `ag.evt.close`
- [ ] Click `ag.evt.edit`
- [ ] Click `u.open` → « {{ u.title }} »

**Attributs (placeholder, aria, title)** :
- aria-label: Mois précédent
- aria-label: Mois suivant
- aria-label: Affichage
- placeholder: Ex. CSE extraordinaire — réorganisation
- placeholder: Salle du conseil, local syndical, visioconférence…
- placeholder: Préparation, documents à réunir, position à arrêter…
- aria-label: Rappel 48 h avant
- aria-label: Fermer le détail

<details><summary>Libellés statiques (31)</summary>

- Planification partagée
- Agenda
- `{ag.intro}` `{ag.count}`.
- Aujourd'hui
- Nouvel événement
- Tout afficher
- `{e.when}` · `{e.hours}`
- Annuler
- Intitulé
- Nature
- Date
- Début
- Fin
- Lieu
- Visibilité
- Note interne
- Rappel 48 h avant
- + Ajouter
- `{e.hours}` · `{e.lieu}`
- Aucun événement ce jour-là. Cliquez sur « Ajouter » pour inscrire une séance, une permanence ou une échéance.
- Fermer
- Quand
- Où
- Organisation
- Visibilité — `{ag.evt.visib}` : `{ag.evt.visibNote}`
- Modifier
- Convoquer
- Ordre du jour
- Exporter .ics
- Retirer
- Prochaines échéances

</details>

## ADH

**Adherents — liste / groupes / cotisations** · écran « Adhérents » · lignes 3132–3377 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adh.isList`
- [ ] `adh.tabList`
- [ ] `adh.hasCrit`
- [ ] `adh.hasSel`
- [ ] `a.selected`
- [ ] `a.hasMandat`
- [ ] `a.showPill`
- [ ] `adh.empty`
- [ ] `adh.hasPager`
- [ ] `adh.showCotis`
- [ ] `adh.tabGroupes`
- [ ] `g.editing`
- [ ] `g.reading`
- [ ] `adh.tabCotis`
- [ ] `adh.noRetard`

**Listes répétées** : `adh.stats`, `adh.tabs`, `adh.filters`, `fl.opts`, `adh.critChips`, `adh.list`, `adh.groupes`, `g.chips`, `adh.cotisStats`, `adh.modes`, `adh.retards`, `adh.log` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `tb.go`
- [ ] Change `fl.on` → « {{ o.label }} »
- [ ] Change `adh.onGName`
- [ ] Click `adh.clearSel`
- [ ] Click `a.open` → « {{ a.initials }} »
- [ ] Click `a.open`
- [ ] Click `adh.goImport`
- [ ] Change `g.onRename` → « Usage »
- [ ] Click `g.send`
- [ ] Click `adh.relanceAll`
- [ ] Click `rt.relance`

**Attributs (placeholder, aria, title)** :
- aria-label: Vues du module adhérents
- placeholder: Nom, courriel, emploi…
- placeholder: Nom de la liste de diffusion…
- aria-label: Nom de la nouvelle liste de diffusion
- aria-label: Page précédente
- aria-label: Page suivante

<details><summary>Libellés statiques (24)</summary>

- Réinitialiser
- Créer une liste depuis ces critères
- Tout sélectionner
- Effacer
- Envoyer un message
- Précédent
- Suivant
- Importer un fichier CSV
- Nouveau bulletin d'adhésion
- Nom de la liste
- Usage
- Terminer
- Modifier
- `{adh.listNote}` Créez-en une depuis le premier onglet en combinant les critères de filtre.
- Taux de recouvrement
- Modes de règlement
- Retards de cotisation
- Relancer la liste « Cotisations en retard »
- `{rt.where}` · `{rt.mode}`
- Préparer une relance
- Marquer réglé
- Toutes les cotisations sont à jour.
- Journal des envois
- `{lg.who}` · `{lg.canal}`

</details>

## ADH-IMP

**Adherents — import csv** · écran « Import CSV adhérents » · lignes 3378–3485 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adh.imp.isImport`
- [ ] `adh.imp.hasText`
- [ ] `adh.imp.hasMissing`
- [ ] `rw.valid`
- [ ] `rw.invalid`
- [ ] `rw.hasNotes`
- [ ] `adh.imp.canImport`

**Listes répétées** : `adh.imp.rows`, `rw.notes`, `adh.imp.cols` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `adh.imp.download`
- [ ] Change `adh.imp.onText` → « Colonnes obligatoires absentes de l'en-tête : {{ adh.imp.mis »
- [ ] Click `adh.imp.run`

**Attributs (placeholder, aria, title)** :
- placeholder: Collez ici le contenu de votre fichier CSV…

<details><summary>Libellés statiques (21)</summary>

- Adhésions
- Fichier CSV encodé en UTF-8, une ligne d'en-tête puis une ligne par adhérent. Séparateur point-virgule ou virgule, les deux sont acceptés.
- Télécharger le modèle CSV
- Choisir un fichier…
- Charger l'exemple
- Séparateur : `{adh.imp.sepLabel}`
- Contenu du fichier — modifiable avant import
- Colonnes obligatoires absentes de l'en-tête : `{adh.imp.missing}`. Repartez du modèle pour conserver les intitulés attendus.
- Contrôle des lignes
- Prête
- À corriger
- Importer `{adh.imp.okCount}` adhérent(s)
- Vider
- Retour aux adhérents
- Colonnes attendues
- modele-import-adherents.csv
- Ce que fait l'import
- Chaque ligne valide crée une adhésion au statut « Adhésion en cours », bulletin à faire signer.
- Les doublons de courriel, dans le fichier comme dans le fichier des adhérents, sont écartés.
- Une entreprise, section ou direction inconnue est créée à l'import et reste filtrable.
- Le fichier n'est lu que sur l'appareil : rien n'est envoyé à un serveur, l'import est journalisé.

</details>

## ADH-FIC

**Adherents — fiche** · écran « Fiche adhérent » · lignes 3486–3621 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adh.isFiche`
- [ ] `adh.fiche.hasMandat`
- [ ] `adh.fiche.showPill`
- [ ] `adh.fiche.canPaid`
- [ ] `adh.fiche.reading`
- [ ] `adh.fiche.editing`
- [ ] `adh.fiche.showCotis`
- [ ] `adh.fiche.hasDu`
- [ ] `h.ok`

**Listes répétées** : `adh.fiche.fields`, `adh.fiche.coords`, `adh.fiche.crit`, `adh.fiche.cotis`, `adh.fiche.histo`, `adh.fiche.docs`, `adh.fiche.groupes` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `adh.fiche.back`
- [ ] Click `adh.fiche.msg`
- [ ] Click `adh.fiche.cancelEdit`
- [ ] Click `d.act`

<details><summary>Libellés statiques (15)</summary>

- ← `{adh.fiche.backLabel}`
- `{adh.fiche.poste}` · `{adh.fiche.since}`
- Envoyer un message
- Marquer la cotisation réglée
- Préparer une relance
- Modifier la fiche
- Annuler
- Enregistrer la fiche
- Coordonnées
- Rattachement
- Cotisation
- Reste dû : `{adh.fiche.du}`
- Documents liés
- Listes de diffusion
- `{adh.fiche.listNote}` Les messages partent en copie cachée.

</details>

## ADH-MSG

**Adherents — message** · écran « Message aux adhérents » · lignes 3622–3721 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `adh.isMsg`
- [ ] `adh.msg.isGroupe`
- [ ] `adh.msg.hasMore`

**Listes répétées** : `adh.msg.cibles`, `adh.msg.groupOpts`, `adh.msg.names`, `adh.msg.canaux`, `adh.msg.models` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `c.go`
- [ ] Change `adh.msg.onCorps` → « Joindre le bulletin d'adhésion »
- [ ] Click `adh.msg.send`
- [ ] Click `adh.msg.bulletinDoc`

**Attributs (placeholder, aria, title)** :
- aria-label: Choix des destinataires
- placeholder: Objet du message…
- placeholder: Votre message aux adhérents…
- aria-label: Joindre le bulletin d'adhésion

<details><summary>Libellés statiques (14)</summary>

- Communication
- Liste de diffusion
- Canal
- Modèles de message
- Objet
- Message
- Joindre le bulletin d'adhésion
- Pièce jointe générée depuis le modèle de la bibliothèque documentaire, à la charte de l'organisation.
- Envoyer
- Annuler
- Aperçu de l'envoi
- Lien avec les documents
- Le bulletin d'adhésion est un modèle de la bibliothèque : identité, situation professionnelle, cotisation, mandat SEPA et mention RGPD sur la donnée sensible.
- Ouvrir le modèle de bulletin dans l'éditeur →

</details>

## INT

**Intranet — accueil** · écran « Intranet » · lignes 3722–3894 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isIntranet`
- [ ] `siteIsPublic`
- [ ] `siteIsIntra`
- [ ] `b.isBar`
- [ ] `b.isImg`
- [ ] `b.isMap`
- [ ] `b.isRow`
- [ ] `b.isFaces`
- [ ] `b.isForm`
- [ ] `b.isBullets`

**Listes répétées** : `siteTabs`, `webStats`, `webModels`, `m.pv`, `webRubriques`, `webPageList` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `t.go` → « {{ t.label }} »
- [ ] Click `goWebGen` → « Générateur de pages HTML »
- [ ] Click `m.create`
- [ ] Click `rb.go` → « {{ rb.label }} »
- [ ] Click `pp.open` → « {{ pp.title }} »
- [ ] Click `pp.del.act`

**Attributs (placeholder, aria, title)** :
- aria-label: Choisir le site à gérer

<details><summary>Libellés statiques (7)</summary>

- Générateur de pages HTML
- Points clés → page rédigée, mise au gabarit du site, HTML propre.
- Suivi des publications
- Gabarits de page
- Arborescence du site
- Pages de `{siteHost}`
- Charte de ce site

</details>

## INT-GEN

**Intranet — generateur de pages** · écran « Générateur de pages » · lignes 3895–3992 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isWebGen`
- [ ] `wgx.has`
- [ ] `wgRunning`
- [ ] `wgWaiting`

**Listes répétées** : `wgModels`, `wgRubs`, `wgTones`, `wgx.themes` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `m.go`
- [ ] Click `wgToAsst`
- [ ] Click `th.go`
- [ ] Click `wgResumeToggle` → « Générer le résumé d'accueil »
- [ ] Click `goIaSecu`

<details><summary>Libellés statiques (18)</summary>

- Intranet
- Générateur de pages HTML
- Gabarit
- Rubrique de destination
- Points clés
- Passer en mode assistant
- Ton
- Thème de la page
- Reformuler en langage clair
- Phrases courtes, pas de jargon juridique, tutoiement exclu.
- Générer le résumé d'accueil
- Chapô de 240 caractères pour la page d'accueil de l'intranet.
- Prompt anonymisé avant envoi. Le HTML produit ne contient ni script ni style en ligne : seules les classes de la feuille du site sont utilisées.
- En savoir plus sur la sécurité
- génération du balisage…
- Rédaction, mise au gabarit, puis contrôle des données personnelles.
- aperçu de la page
- La page générée s'ouvre dans l'éditeur, avec aperçu navigateur et code HTML.

</details>

## INT-EDI

**Intranet — editeur de page** · écran « Éditeur de page intranet » · lignes 3993–4113 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isWebEdit`
- [ ] `pgx.has`
- [ ] `pgx.hasPals`
- [ ] `b.canDel`
- [ ] `pgx.hasSecs`
- [ ] `pgHasBack`
- [ ] `pgNotReviewed`
- [ ] `isTabPreview`
- [ ] `pgx.hasDevs`
- [ ] `pgx.isFrame`
- [ ] `pgx.noFrame`
- [ ] `isTabCode`
- [ ] `srcDirty`

**Listes répétées** : `pgx.themes`, `pgx.pals`, `webBlocks`, `pgx.secs`, `webTabs`, `pgx.devs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `backToIntranet`
- [ ] Click `th.go`
- [ ] Click `b.del`
- [ ] Click `askReviewFn`
- [ ] Click `dv.go`
- [ ] Click `resetSrc`

**Attributs (placeholder, aria, title)** :
- aria-label: Revenir à l'intranet
- aria-label: Titre de la page
- aria-label: Largeur d'aperçu
- aria-label: Code HTML de la page

<details><summary>Libellés statiques (16)</summary>

- Thème de la page
- Palette
- Chapô
- Blocs
- Modifiez le contenu : l'aperçu se met à jour en direct.
- Retirer
- Une ligne = un élément dans les blocs Liste.
- Ajouter une section :
- + `{s.label}`
- Circuit de publication
- Retour du webmaster
- Demander une relecture
- Envoyer pour publication
- Copier le HTML
- Régénérer depuis les blocs
- Code modifié à la main — l'aperçu suit vos modifications ; les blocs ne les reprennent pas.

</details>

## INT-PUB

**Intranet — envoi au webmaster** · écran « Envoi au webmaster » · lignes 4114–4189 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isWebPub`
- [ ] `pubBlocked`

**Listes répétées** : `pubVisOpts`, `pubChecklist` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `onPubSlug` → « {{ pubUrlPreview }} »
- [ ] Change `onPubMsg` → « Joindre le fichier .html »
- [ ] Click `pubHomeToggle` → « Remonter le résumé sur la page d'accueil »
- [ ] Click `sendPub`

**Attributs (placeholder, aria, title)** :
- aria-label: Adresse de la page
- aria-label: Date de mise en ligne
- placeholder: Emplacement dans la rubrique, visuel à reprendre, date d'archivage…

<details><summary>Libellés statiques (12)</summary>

- Demande de publication
- Envoyer au webmaster
- Rubrique et adresse
- Mise en ligne souhaitée
- Visibilité
- Consignes pour le webmaster
- Joindre le fichier .html
- Notifier par e-mail en plus de la file interne
- Remonter le résumé sur la page d'accueil
- Aucune relecture enregistrée. Vous pouvez envoyer malgré tout : la demande indiquera « non relue » au webmaster.
- Envoyer pour publication
- Annuler

</details>

## INT-SUI

**Intranet — suivi des publications** · écran « Suivi des publications » · lignes 4190–4239 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isWebQueue`
- [ ] `st.on`
- [ ] `q.hasBack`
- [ ] `q.isPub`

**Listes répétées** : `webQueue`, `q.steps` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `q.open`

<details><summary>Libellés statiques (5)</summary>

- Suivi des publications
- `{q.rubrique}` · mise en ligne prévue `{q.date}` · `{q.vis}` · `{q.sentAt}`
- Retour du webmaster
- Ouvrir la page
- Relancer

</details>

## INT-CHA

**Intranet — gabarit du site** · écran « Charte des sites » · lignes 4240–4405 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isWebCharte`
- [ ] `wcPreviewHasLogo`
- [ ] `wcPreviewMono`
- [ ] `wcCustom`
- [ ] `wcLogoHasImg`
- [ ] `wcLogoOwn`

**Listes répétées** : `wcSiteTabs`, `wcAccents`, `wcHeads`, `wcFonts`, `wcNavs`, `wcRadii`, `wcGabarits` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `t.go` → « {{ t.label }} »
- [ ] Click `wcGoBrand`
- [ ] Click `a.go`
- [ ] Click `n.go`
- [ ] Change `onWcLogoFile` → « {{ wcLogoFrom }} »
- [ ] Change `onWcLogoScale` → « De 60 à 300 % de la hauteur de référence (44 px), proportion »
- [ ] Click `wcSaved`

**Attributs (placeholder, aria, title)** :
- aria-label: Site à charter
- aria-label: Hériter de l'identité de l'organisation
- aria-label: Aperçu de la charte
- aria-label: Choisir cette couleur d'accent
- aria-label: Choisir cette couleur d'en-tête
- aria-label: Afficher le logo dans l'en-tête

<details><summary>Libellés statiques (25)</summary>

- Charte des sites
- Chaque site a sa charte : l'intranet peut rester sobre pendant que le site public porte les couleurs de l'organisation. Le HTML transmis au webmaster reste sémantique — ces réglages décrivent la feuille de style du site.
- Hériter de l'identité de l'organisation
- Modifier l'identité
- Actualités
- Vos droits
- Contact
- Salaires : la section maintient ses revendications
- Le chapô résume la page en une phrase, avec la police et les couleurs retenues pour ce site.
- Donner votre avis
- Sur cette page
- Couleur d'accent
- Couleur d'en-tête et de pied de page
- Police des titres
- Navigation
- Angles
- Largeur de contenu
- Logo de ce site
- Reprendre le logo de l'identité
- Taille du logo dans l'en-tête
- Réinitialiser
- De 60 à 300 % de la hauteur de référence (44 px), proportions conservées.
- Afficher le logo dans l'en-tête du site
- Enregistrer le gabarit
- Retour

</details>

## NOT

**Centre de notifications** · lignes 4406–4427 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isNotifs`

**Listes répétées** : `notifications` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `markAllRead`

<details><summary>Libellés statiques (2)</summary>

- Notifications
- Tout marquer comme lu

</details>

## RCH

**Recherche** · lignes 4428–4450 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isSearch`
- [ ] `noResults`

**Listes répétées** : `searchResults` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `s.go` → « {{ s.kind }} »

<details><summary>Libellés statiques (2)</summary>

- Recherche globale
- Aucun résultat. Essayez « harcèlement », « NAO » ou « inaptitude ».

</details>

## UNII-CFG

**Reglages unii** · écran « Actions d'unii » · lignes 4451–4511 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isUniiCfg`
- [ ] `unii.cfg.custom`
- [ ] `unii.cfg.planOk`
- [ ] `unii.locked`
- [ ] `md.lot`
- [ ] `a.hasApply`

**Listes répétées** : `unii.cfg.roles`, `unii.cfg.mods`, `md.acts`, `a.roles` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `unii.cfg.reset`
- [ ] Click `unii.cfg.togglePills`
- [ ] Click `a.toggle`

**Attributs (placeholder, aria, title)** :
- aria-label: Pastilles de suggestion

<details><summary>Libellés statiques (15)</summary>

- Actions d'unii
- Choisissez les actions qu'unii propose dans chaque module et les rôles qui peuvent les utiliser. Sans rôle coché, l'action est ouverte à tous.
- Réinitialiser
- Formule
- unii inclus · `{unii.cfg.count}`
- unii est disponible à partir d'Élu 2.0
- Changer de formule
- Pastilles de suggestion
- unii signale dans les modules ce qui mérite votre attention : échéance proche, brouillon à relire, messages non lus.
- Tester un rôle
- — l'application affiche les actions d'unii telles que les voit ce rôle.
- Actions applicables
- `{a.desc}` · `{a.scope}`
- · bouton « `{a.applyLabel}` »
- Tous les rôles

</details>

## EXT

**Extensions** · écran « Extensions » · lignes 4512–4598 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isExtensions`
- [ ] `ext.empty`
- [ ] `x.hasErrs`
- [ ] `ext.hasOrphan`
- [ ] `ext.hasSources`
- [ ] `ext.hasTest`

**Listes répétées** : `ext.list`, `x.perms`, `x.groups`, `g.items`, `x.errs`, `ext.orphan`, `ext.sources`, `ext.testRes` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `ext.back`
- [ ] Click `x.toggle`
- [ ] Change `ext.onUrl`
- [ ] Click `ext.test`

**Attributs (placeholder, aria, title)** :
- aria-label: Revenir aux paramètres
- aria-label: Activer l'extension
- placeholder: ./extensions/mon-extension.js
- aria-label: Adresse de l'extension

<details><summary>Libellés statiques (13)</summary>

- Extensions
- Les extensions ajoutent des styles, des blocs et des thèmes sans modifier le cœur d'uniion. Désactivée, une extension disparaît sans laisser de trace : vos contenus reviennent à leur rendu habituel.
- Aucune extension chargée.
- Autorisations
- Erreurs isolées — le rendu d'origine a été utilisé à leur place
- Extensions refusées au chargement
- Installer une extension
- Indiquez l'adresse du fichier de l'extension : chemin relatif (./extensions/…) ou adresse https. N'installez que des extensions dont vous connaissez l'éditeur.
- Installer
- Retirer
- Auto-test de non-régression
- Compare le rendu avec et sans extensions, et rend chaque style sur chaque document.
- Lancer l'auto-test

</details>

## PAR

**Parametres** · lignes 4599–4650 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isParams`
- [ ] `navOrderCustom`

**Listes répétées** : `settings`, `navOrderRows` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `s.go` → « {{ s.badge }} »
- [ ] Click `navOrderReset`
- [ ] Click `nr.up`

<details><summary>Libellés statiques (5)</summary>

- Paramètres
- `{orgName}` · plan Fédération, 84 adhérents
- Ordre du menu de gauche
- Réinitialiser
- Placez en tête les modules que vous ouvrez le plus souvent. L'ordre s'applique aussitôt à la barre latérale et à la barre de navigation mobile.

</details>

## PAR-PRO

**Profil** · lignes 4651–4841 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isProfil`
- [ ] `org.reading`
- [ ] `org.editing`
- [ ] `f.hasHint`
- [ ] `c.on`
- [ ] `c.off`
- [ ] `p.pop`
- [ ] `p.current`
- [ ] `p.other`

**Listes répétées** : `profileFields`, `org.types`, `org.rows`, `org.fields`, `stats`, `plan.cycles`, `plan.cards`, `p.feats`, `plan.factures` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `toggleVisible`
- [ ] Click `t.go`
- [ ] Change `f.on` → « {{ f.hint }} »
- [ ] Click `goSignature`
- [ ] Click `resetDemo`
- [ ] Click `p.pick`
- [ ] Click `plan.changeCard`
- [ ] Click `f.dl`

<details><summary>Libellés statiques (38)</summary>

- SM
- Déléguée syndicale · Secrétaire de section
- Coordonnées visibles par les autres élus
- Informations de l'organisation
- Modifier
- Annuler
- Nature de l'organisation
- La convention collective renseignée ici détermine le corpus interrogé par l'assistant juridique. Les en-têtes de documents et les pages intranet reprennent la dénomination et l'adresse.
- Enregistrer les informations
- Mon activité — août
- Signature des documents
- Reprise automatiquement en pied des tracts et courriers générés.
- Sophie Marchand
- Déléguée syndicale — Section de Valenciennes
- sophie.marchand@cse-valenciennes.fr
- Signer un document
- Modifier la signature
- Session
- Ouverte depuis iPhone 15 — Valenciennes. La déconnexion purge le cache local chiffré.
- Se déconnecter
- Données de démonstration
- Cette maquette conserve vos saisies (dossiers, `{w.memberMany}`, événements, identité de marque) dans le navigateur, sur cet appareil uniquement. Rien n'est envoyé à un serveur.
- Réinitialiser la démonstration
- Abonnement et paiements
- Formule
- — `{plan.currentPrix}`. `{plan.renew}`.
- Populaire
- Votre formule
- Formule actuelle
- * Au-delà, 9 € HT par dossier supplémentaire. Prix hors taxes, TVA 20 %. Résiliation à tout moment, effet en fin de période.
- Moyen de paiement
- Expire `{plan.card.exp}` · `{plan.card.nom}`
- Modifier le moyen de paiement
- Paiement traité par un prestataire européen conforme DSP2. Aucun numéro de carte n'est stocké par uniion.
- Factures
- Tout exporter
- `{f.date}` · `{f.montant}`
- PDF

</details>

## COM

**Communication** · écran « Communication » · lignes 4842–4855 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isCommunication`
- [ ] `tb.hasN`

**Listes répétées** : `com.tabs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `tb.go` → « {{ tb.label }} »

**Attributs (placeholder, aria, title)** :
- aria-label: Communication

<details><summary>Libellés statiques (2)</summary>

- Moins d'administratif, plus de terrain
- Communication

</details>

## COM-PLAN

**Plan éditorial** · lignes 4856–4917 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `com.isPlan`
- [ ] `com.hasToValidate`
- [ ] `p.hasContent`
- [ ] `com.noRows`
- [ ] `com.planCustom`

**Listes répétées** : `com.filters`, `com.rows`, `com.moments` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `com.newPost`
- [ ] Click `p.next`
- [ ] Click `p.del.act`
- [ ] Click `m.add`

**Attributs (placeholder, aria, title)** :
- title: Ajouter au plan en idée
- aria-label: Ajouter au plan

<details><summary>Libellés statiques (9)</summary>

- Octobre 2026
- + Nouvelle publication
- « `{p.excerpt}`… »
- Aucune publication à ce statut.
- Cliquez sur un statut pour le faire avancer : Idée → Brouillon → À valider → Programmé → Publié.
- Temps forts du mandat
- Les rendez-vous qui méritent une prise de parole. Ajoutez-les en idée ou rédigez-les tout de suite.
- Rédiger
- Restaurer le plan d'exemple

</details>

## COM-ATE

**Atelier de contenus** · lignes 4918–4992 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `com.isAtelier`
- [ ] `com.hasOut`
- [ ] `com.noOut`
- [ ] `com.outBusy`
- [ ] `com.out.local`
- [ ] `com.out.hasVisuel`

**Listes répétées** : `com.f.fmts`, `com.f.objs`, `com.f.canaux`, `com.f.sugg`, `com.f.tons` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `x.go`
- [ ] Click `com.f.cancel`
- [ ] Change `com.out.onTitre` → « Accroche »
- [ ] Change `com.out.onAppel` → « Visuel conseillé · »

<details><summary>Libellés statiques (19)</summary>

- Format
- Objectif
- Canal de diffusion
- Sujet et éléments clés
- Ton
- Date de diffusion
- Retour au plan
- Noms et identifiants sont anonymisés avant l'envoi à l'IA. unii écrit avec le vocabulaire des `{com.people}` : PV, plénière, ASC, NAO, BDESE — chaque sigle est expliqué aux salariés.
- Proposition
- Choisissez un format, un objectif et décrivez le sujet. unii propose un titre, une accroche, le texte et un appel à l'action, à relire avant diffusion.
- unii rédige votre publication…
- Trame type — l'IA n'a pas répondu. Complétez les passages entre crochets.
- Titre
- Accroche
- Texte
- Appel à l'action
- Visuel conseillé ·
- Copier
- Confier la mise en forme au pôle

</details>

## COM-POL

**Pôle communication** · lignes 4993–5079 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `com.isPole`
- [ ] `com.noReq`
- [ ] `com.hasReq`
- [ ] `com.hasReqNote`

**Listes répétées** : `com.inclus`, `com.formules`, `fo.rows`, `com.socle`, `com.approche`, `com.supports` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `fo.go`
- [ ] Change `com.onNote`

<details><summary>Libellés statiques (18)</summary>

- Pôle communication uniion
- Donnez de la voix à votre mandat, sans y passer vos soirées
- Community management, contenus, réseaux sociaux, print, vidéo et événementiel : l'équipe uniion aide les `{com.people}` à informer les salariés, animer leur communauté et montrer l'impact de leurs actions. L'IA accélère la production, notre équipe garantit la qualité et le ton juste.
- Votre community manager d'élus, à la carte
- Déléguez tout ou partie de votre communication, au niveau qui correspond à votre mandat. Ces formules sont distinctes des offres Élu 1.0 à 4.0 ; les abonnés Élu 3.0 et 4.0 bénéficient de conditions préférentielles.
- Le socle de toutes les formules
- Communiquer utile et responsable
- Tous vos supports, au même endroit
- Du tract à la journée bien-être, des supports clairs et cohérents pour vos temps forts.
- Votre projet
- Du besoin à la création : parlons de vos objectifs, de votre identité et de vos temps forts.
- Formule envisagée :
- — modifiable ci-dessus.
- Demandez votre plan de communication d'élu
- Demande transmise — rappel sous 48 h ouvrées
- « `{com.reqNote}` »
- Modifier la demande
- uniion : accompagnement juridique, économique, formation, solutions digitales, communication et assistance pour les CSE et les syndicats.

</details>

## MOB

**Application mobile** · écran « Application mobile » · lignes 5080–5293 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isMobApp`
- [ ] `mob.isList`
- [ ] `p.hasSugg`
- [ ] `mob.isEdit`
- [ ] `mob.e.pushOn`
- [ ] `b.isH`
- [ ] `b.isP`
- [ ] `b.isInfo`
- [ ] `b.isContact`
- [ ] `b.isBtn`

**Listes répétées** : `mob.kpis`, `mob.tabs`, `mob.pages`, `mob.tpls`, `mob.e.types`, `mob.e.auds`, `mob.e.acts`, `mob.e.blocks`, `mob.e.adds`, `mob.e.steps` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `tb.go`
- [ ] Click `p.sugg`
- [ ] Click `m.go` → « {{ m.label }} »
- [ ] Click `mob.back`
- [ ] Click `x.go`
- [ ] Change `mob.e.onSubj`
- [ ] Click `b.up`
- [ ] Click `mob.e.togglePush`
- [ ] Click `mob.e.advance`

**Attributs (placeholder, aria, title)** :
- aria-label: Application mobile
- aria-label: Monter
- aria-label: Descendre
- aria-label: Supprimer le bloc
- aria-label: Notification push
- placeholder: Ex. NAO 2027 : la direction propose 0,8 %. Nos réponses dans l'appli.

<details><summary>Libellés statiques (30)</summary>

- Publié dans l'application FO
- Application mobile
- Vos pages
- Modifier
- Circuit de publication : Brouillon → Relecture par un pair → Validation FO → En ligne dans l'application.
- Créer une page
- Partez d'un modèle adapté au téléphone, ou laissez unii rédiger une première version.
- Quelles pages créer ? Demander à unii
- ← Toutes les pages
- Titre de la page
- Type de page
- Visible par
- Rédiger avec unii
- unii propose une page prête pour le téléphone — vous relisez avant tout envoi.
- Contenu
- Ajouter :
- + `{a.label}`
- Notification push
- Envoyée à la mise en ligne. À réserver aux informations utiles.
- Publication
- Vérifier avec unii avant envoi
- Aperçu dans l'application
- 9:41
- ●●● 5G
- FO
- Accueil
- Actus
- Mon syndicat
- Profil
- FO · `{mob.e.spaceName}`

</details>

## FOR

**Formations** · écran « Formations » · lignes 5294–5313 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isFormations`
- [ ] `tb.hasN`
- [ ] `fm.showSearch`

**Listes répétées** : `fm.tabs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `tb.go` → « {{ tb.label }} »

**Attributs (placeholder, aria, title)** :
- aria-label: Formations
- placeholder: Rechercher une formation, un public, un objectif…
- aria-label: Rechercher une formation

<details><summary>Libellés statiques (3)</summary>

- Montée en compétence
- Formations
- Deux catalogues pour vous former au mandat, et un mode où unii construit avec vous une session sur mesure, au rythme que vous choisissez.

</details>

## FOR-IA

**Catalogue ia** · lignes 5314–5379 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `fm.isIa`
- [ ] `fm.iaNone`

**Listes répétées** : `fm.iaTypes`, `fm.iaSections`, `sc.items`, `it.obj`, `fm.parcours`, `fm.formats` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `f.go`
- [ ] Click `it.unii`
- [ ] Click `pc.unii`

<details><summary>Libellés statiques (9)</summary>

- Se former avec unii
- Aucune formation ne correspond à ces critères.
- Parcours recommandés
- Alignés sur les niveaux d'offre Élu 1.0 à 4.0.
- Suivre avec unii
- Formats et durées
- Format
- Durée
- Public

</details>

## FOR-GEN

**Catalogue généraliste** · lignes 5380–5417 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `fm.isGen`
- [ ] `it.oblig`
- [ ] `fm.genNone`

**Listes répétées** : `fm.genCats`, `fm.genModes`, `fm.gen` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `f.go`
- [ ] Click `it.unii`

<details><summary>Libellés statiques (5)</summary>

- Obligatoire
- Agréée DREETS
- Réviser avec unii
- Aucune formation ne correspond à ces critères.
- Les formations obligatoires des élus (économique, SSCT) sont financées par l'employeur ou le budget de fonctionnement du CSE selon leur nature. Une demande de session est transmise au bureau pour arbitrage.

</details>

## FOR-UNII

**Formation avec unii** · lignes 5418–5591 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `fm.isUnii`
- [ ] `fm.busy`
- [ ] `fm.showSetup`
- [ ] `fm.noSessions`
- [ ] `fm.inSession`
- [ ] `fm.s.local`
- [ ] `fm.s.notDone`
- [ ] `fm.s.showIntro`
- [ ] `fm.s.m.hasEx`
- [ ] `fm.s.m.hasFb`
- [ ] `fm.s.m.answered`
- [ ] `fm.s.hasPrev`
- [ ] `fm.s.finished`
- [ ] `fm.s.hasSources`
- [ ] `cm.isU`
- [ ] `cm.isB`
- [ ] `fm.s.chatBusy`

**Listes répétées** : `fm.setup.sugg`, `fm.setup.durs`, `fm.setup.levels`, `fm.setup.roles`, `fm.how`, `fm.sessions`, `fm.s.plan`, `fm.s.m.points`, `fm.s.m.choices`, `fm.s.retenir`, `fm.s.chat` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `fm.setup.onTheme`
- [ ] Click `s.go`
- [ ] Click `fm.setup.start`
- [ ] Click `ss.open` → « {{ ss.title }} »
- [ ] Click `fm.s.quit`
- [ ] Change `fm.s.m.onEx`
- [ ] Click `ch.go`
- [ ] Click `fm.s.attest`
- [ ] Change `fm.s.onChat`

**Attributs (placeholder, aria, title)** :
- placeholder: Ex. : mener une enquête après un accident du travail
- placeholder: Ex. : savoir rédiger la demande d'enquête et préparer les questions
- placeholder: Votre réponse…
- placeholder: Ex. : que se passe-t-il si l'employeur refuse ?
- aria-label: Question à unii

<details><summary>Libellés statiques (32)</summary>

- unii prépare votre session
- Nouvelle session avec unii
- Cours, exemples, exercice et quiz à chaque module.
- Thème de la session
- Temps disponible
- Niveau
- Mon rôle
- Ce que je veux savoir faire à la fin (facultatif)
- Comment ça marche
- Mes sessions
- Aucune session pour l'instant.
- ← Mes sessions
- Parcours type : l'IA n'était pas disponible. Le contenu est générique — relancez la session quand la connexion IA est rétablie.
- unii ·
- Objectif :
- Cas concret
- À vous · exercice d'application
- Retour de unii ·
- Quiz
- `{fm.s.m.verdict}` ·
- ← Module précédent
- Session terminée
- À retenir
- Sources ·
- Attestation de suivi
- Revoir depuis le début
- Nouvelle session
- Formations du catalogue
- unii
- Une question sur ce module ?
- unii réfléchit…
- Demander

</details>

## CTC

**Contacts & groupes** · écran « Contacts & groupes » · lignes 5592–5648 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isContacts`
- [ ] `p.hasGroups`
- [ ] `p.notMe`
- [ ] `ctp.noRows`

**Listes répétées** : `ctp.groups`, `ctp.cats`, `ctp.rows` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `ctp.back`
- [ ] Click `ctp.newContact`
- [ ] Click `g.open`
- [ ] Click `k.go`
- [ ] Click `p.msg`

**Attributs (placeholder, aria, title)** :
- placeholder: Rechercher un nom, une fonction, un groupe…
- aria-label: Rechercher

<details><summary>Libellés statiques (15)</summary>

- ← Réglages
- Messagerie
- Contacts & groupes
- L'annuaire utilisé par la messagerie : élus, adhérents et contacts externes, et les groupes de discussion avec leurs membres et administrateurs.
- Nouveau contact
- Nouveau groupe
- Groupes de discussion
- Ouvrir
- Membres & réglages
- Les listes de diffusion aux adhérents se gèrent dans Adhérents ; chaque envoi apparaît dans Messages.
- Listes de diffusion →
- Contacts
- `{p.role}` · `{p.coords}`
- Écrire
- Aucun contact ne correspond.

</details>

## MEM

**Memoire assistant** · écran « Mémoire de l'assistant » · lignes 5649–5722 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isMemoire`
- [ ] `it.notEditing`
- [ ] `it.editing`
- [ ] `mem.empty`
- [ ] `mem.hasAny`

**Listes répétées** : `mem.cats`, `mem.groups`, `g.items` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `mem.toggleAll`
- [ ] Click `mem.add`
- [ ] Change `it.onEdit` → « {{ it.meta }} »
- [ ] Click `mem.wipe`

**Attributs (placeholder, aria, title)** :
- aria-label: Activer ou suspendre la mémoire
- placeholder: Ex. : l'accord de méthode NAO prévoit 3 réunions avant le 31 mars.
- aria-label: Activer ou désactiver cet élément

<details><summary>Libellés statiques (11)</summary>

- Assistant IA
- Mémoire de l'assistant
- Les faits retenus ici accompagnent chaque question posée à l'IA, d'une conversation à l'autre. Ils restent dans ce navigateur, sont anonymisés avant envoi et ne sont jamais cités comme source juridique.
- Utiliser la mémoire dans les réponses
- Ajouter un élément
- Ajouter à la mémoire
- Modifier
- Oublier
- Enregistrer
- Annuler
- La mémoire est vide. Ajoutez un élément ci-dessus, ou cliquez « Mémoriser » sous une réponse de l'Assistant.

</details>

## PAR-NOT

**Preferences notifications** · lignes 5723–5743 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isPrefs`

**Listes répétées** : `prefRows` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `p.go`

<details><summary>Libellés statiques (2)</summary>

- Notifications
- Par canal et par module. Les alertes urgentes ignorent le mode « ne pas déranger ».

</details>

## SEC-IA

**Securite — documentation ia** · écran « Sécurité de l'IA » · lignes 5744–5784 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isIaSecu`

**Listes répétées** : `iaSecu.chapters`, `c.items`, `iaSecu.docs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `iaSecu.back`
- [ ] Click `iaSecu.contact`

<details><summary>Libellés statiques (7)</summary>

- ← Sécurité
- Documentation
- Sécurité, anonymisation et conformité
- Ce que l'application met en œuvre lorsqu'un modèle de langage est sollicité, ce qui est garanti par contrat, et ce qui reste de votre responsabilité en tant qu'élu.
- Documentation de référence
- Pièces tenues à disposition des élus et de l'inspection du travail, sur demande auprès de l'administrateur.
- Écrire au délégué à la protection des données

</details>

## PAR-SEC

**Securite** · lignes 5785–5843 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isSecurite`
- [ ] `noDevices`

**Listes répétées** : `secRows`, `devices`, `auditLog` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `s.go`
- [ ] Click `dv.go`

<details><summary>Libellés statiques (8)</summary>

- Sécurité
- Sécurité de l'assistant et conformité RGPD
- Modèle souverain, anonymisation, durées de conservation, documentation de référence.
- Appareils connectés
- Déconnecter
- Aucun autre appareil connecté.
- Journal d'audit
- Exporter le journal (CSV)

</details>

## PAR-RGPD

**Rgpd** · lignes 5844–5917 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isRgpd`

**Listes répétées** : `anonFootprints`, `retention`, `registre` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `exportData`

**Attributs (placeholder, aria, title)** :
- aria-label: Anonymisation avant inférence — verrouillée par la politique de l'organisation

<details><summary>Libellés statiques (15)</summary>

- Politique organisation
- Anonymisation avant inférence
- Le coffre CSE — dossiers, pièces, noms, matricules — reste local. Le modèle ne reçoit qu'un payload masqué, relu et confirmé par l'élu. Zéro donnée nominative hors UE, zéro entraînement, journal d'empreintes sans clair.
- 0 identité fuitée
- Pièces jointes jamais transmises
- Verrouillé ON
- Journal d'empreintes — aucun texte en clair
- Conforme
- Confidentialité & RGPD
- Hébergement UE, chiffrement au repos et en transit, cloisonnement strict avec l'employeur.
- Exercer vos droits
- Accès, rectification, effacement, portabilité — traité sous 30 jours.
- Exporter mes données (JSON)
- Demander l'effacement
- Registre des traitements

</details>

## PAR-MBR

**Membres** · lignes 5918–5955 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isMembres`

**Listes répétées** : `orgStats`, `members` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `invite`
- [ ] Click `m.del.act`

<details><summary>Libellés statiques (3)</summary>

- Organisation & membres
- + Inviter un membre
- `{m.role}` · `{m.last}`

</details>

## PAR-MAR

**Identite de marque** · lignes 5956–6169 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isMarque`
- [ ] `brandPreviewOn`
- [ ] `brandPreviewOff`
- [ ] `s.selected`
- [ ] `s.idle`
- [ ] `l.hasImg`
- [ ] `l.isMono`
- [ ] `brandDarkNoLogo`

**Listes répétées** : `brandScopes`, `brandPresets`, `brandRamp`, `brandModes`, `brandFonts`, `brandLogos`, `brandNavGhosts`, `brandLog` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `brandTogglePreview`
- [ ] Click `s.go`
- [ ] Click `p.go` → « {{ p.label }} »
- [ ] Change `onBrandAccent2` → « {{ brandAccent2 }} »
- [ ] Click `m.go` → « {{ m.label }} »
- [ ] Change `l.onFile` → « Taille »
- [ ] Change `onBrandInitials` → « Utilisé quand aucun logo n'est chargé — dans les avatars et  »
- [ ] Click `brandToggleIntranet`

**Attributs (placeholder, aria, title)** :
- aria-label: Couleur principale
- aria-label: Couleur secondaire

<details><summary>Libellés statiques (36)</summary>

- Marque blanche · administrateurs
- Identité de marque
- Aperçu en cours — revenir
- Prévisualiser sur toute l'app
- Réinitialiser
- Publier à l'organisation
- Portée
- Palette
- Toute l'interface, les documents générés et les pages intranet suivent la couleur principale.
- Couleur principale
- Secondaire
- Rampe dérivée automatiquement
- Mode d'affichage
- Typographie
- Aa
- Logos
- PNG ou SVG détouré, 512 px de côté minimum. Le monogramme sert d'avatar, de favicon et de repli. Les deux derniers emplacements sont facultatifs : sans eux, les sites reprennent le logo fond clair.
- Taille
- Retirer
- Mode sombre actif sans logo dédié : c'est le logo fond clair qui sera utilisé, au risque d'être illisible. Chargez une version claire détourée.
- Monogramme de repli
- Utilisé quand aucun logo n'est chargé — dans les avatars et le favicon.
- Chaque logo a sa propre taille, de 60 à 300 %, proportions conservées : le logo fond clair (ou fond sombre selon le mode) règle la barre latérale et l'en-tête mobile, les logos intranet et site public règlent l'en-tête des sites. Une taille propre à un site peut être définie dans Intranet · Charte des sites.
- Aperçu
- Écran de connexion, navigation et carte de dossier, avec le brouillon en cours.
- L'outil des élus, pas celui de la direction.
- Juridique
- Signalement — atelier B
- Enquête paritaire demandée le 20 août, réponse attendue sous 8 jours.
- SM
- J−3
- Portée sur les contenus
- Le gabarit intranet hérite de ce thème
- Les pages publiées reprennent la couleur, les polices et le logo. La charte du site reste surchargeable pour respecter la maquette du webmaster.
- Ouvrir le gabarit du site intranet →
- Journal des publications

</details>

## PAR-IA

**Config ia** · lignes 6170–6310 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isApikey`
- [ ] `llm.hasKey`
- [ ] `llm.testMsg`
- [ ] `p.selected`
- [ ] `p.idle`

**Listes répétées** : `llm.models`, `providers`, `usage`, `prudenceSteps` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Input `llm.onKey`
- [ ] Click `p.go` → « {{ p.name }} »
- [ ] Click `toggleKey`
- [ ] Click `ps.go`

**Attributs (placeholder, aria, title)** :
- placeholder: sk-ant-api03-…
- aria-label: Anonymisation avant inférence — verrouillée sur activé

<details><summary>Libellés statiques (24)</summary>

- Connexion du modèle — démo locale
- Enregistrer la clé
- Oublier
- Modèle
- Clé à créer sur console.anthropic.com (facturation API distincte de l’abonnement Claude). Usage démo personnelle uniquement : ne partagez pas ce fichier une fois la clé enregistrée.
- Admin organisation
- Configuration IA
- Modèle utilisé par l'Assistant Juridique, la Recherche Légale et le Générateur de documents.
- Anonymisation avant inférence
- Verrouillée par la politique de l'organisation — non désactivable en séance.
- Zéro donnée nominative hors Union européenne.
- Zéro réutilisation pour l'entraînement — clause contractuelle avec le fournisseur.
- Journal d'empreintes sans texte en clair.
- 0 identité fuitée
- Fournisseur & modèle
- Clé API
- Chiffrée au repos dans un coffre dédié, jamais réaffichée en clair après enregistrement. Dernière rotation : 14/06/2026.
- Révoquer
- Consommation — août
- Coût estimé
- 84,20 € / 150 € de quota
- Comportement du modèle
- Prudence juridique
- Sourçage obligatoire des réponses juridiques

</details>

## MSG

**Messages — liste + fil + infos** · écran « Messages » · lignes 6311–6656 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `wa.shell`
- [ ] `wa.showList`
- [ ] `wa.hasQ`
- [ ] `wa.isChats`
- [ ] `f.hasN`
- [ ] `c.isBc`
- [ ] `c.mineTick`
- [ ] `c.muted`
- [ ] `c.pinned`
- [ ] `c.hasUnread`
- [ ] `wa.noRows`
- [ ] `wa.isContacts`
- [ ] `wa.hasGroups`
- [ ] `wa.showChat`
- [ ] `wa.showBack`
- [ ] `wa.isBc`
- [ ] `m.isSys`
- [ ] `m.mine`
- [ ] `m.fwd`
- [ ] `m.hasReply`
- [ ] `m.hasChan`
- [ ] `m.hasSubj`
- [ ] `m.hasAtt`
- [ ] `m.checked`
- [ ] `m.menuOpen`
- [ ] `m.theirs`
- [ ] `m.showWho`
- [ ] `m.isAi`
- [ ] `m.reid`
- [ ] `m.ok`
- [ ] `th.busy`
- [ ] `th.panel`
- [ ] `th.hasQuote`
- [ ] `th.selMode`
- [ ] `wa.hasReply`
- [ ] `wa.showEmpty`
- [ ] `wa.infoOpen`
- [ ] `wa.info.canEdit`
- [ ] `wa.info.canEditCt`
- [ ] `wa.info.isAdh`
- [ ] `wa.info.isBc`
- [ ] `wa.info.hasDesc`
- [ ] `wa.info.isDirect`
- [ ] `wa.info.hasCtGroups`
- [ ] `wa.info.isGroup`
- [ ] `u.isAdmin`
- [ ] `u.canAct`

**Listes répétées** : `wa.panes`, `wa.filters`, `wa.rows`, `wa.groupRows`, `wa.teamRows`, `wa.adhRows`, `convo.messages`, `m.acts`, `th.presets`, `wa.info.members` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `wa.newChat`
- [ ] Click `p.go`
- [ ] Click `f.go` → « {{ f.label }} »
- [ ] Click `wa.newGroup` → « Nouveau groupe »
- [ ] Click `wa.newBc` → « Nouvelle diffusion aux adhérents »
- [ ] Click `p.go` → « {{ p.initials }} »
- [ ] Click `wa.back`
- [ ] Click `wa.bcSend`
- [ ] Click `wa.closeMenu` → « Messages chiffrés de bout en bout. Ni l'employeur ni uniion  »
- [ ] Click `m.toggleMenu`
- [ ] Click `x.go`
- [ ] Click `m.insert`
- [ ] Click `th.clear`
- [ ] Click `th.toDossier`
- [ ] Click `attach`
- [ ] Click `wa.closeInfo`
- [ ] Click `wa.info.edit`
- [ ] Click `wa.info.bcList`
- [ ] Click `u.msg`
- [ ] Click `wa.info.togglePin`

**Attributs (placeholder, aria, title)** :
- title: Nouvelle discussion
- aria-label: Nouvelle discussion
- title: Nouveau groupe
- aria-label: Nouveau groupe
- title: Nouvelle diffusion aux adhérents
- aria-label: Nouvelle diffusion aux adhérents
- aria-label: Vue
- aria-label: Rechercher
- aria-label: Effacer la recherche
- aria-label: Retour aux discussions
- title: Solliciter unii sur ce fil
- title: Infos
- aria-label: Infos de la discussion
- aria-label: Actions sur le message
- title: Actions
- aria-label: Fermer unii
- aria-label: Annuler la réponse
- title: Joindre
- aria-label: Joindre un fichier
- aria-label: Votre message
- aria-label: Envoyer
- aria-label: Fermer les infos
- aria-label: Mettre en sourdine
- aria-label: Épingler

<details><summary>Libellés statiques (47)</summary>

- `{c.prefix}``{c.preview}`
- Nouveau groupe
- Nouveau contact
- Nouvelle diffusion aux adhérents
- Gérer les contacts et les groupes dans les réglages →
- Groupes
- Équipe & contacts externes
- Adhérents
- Chiffrée de bout en bout — hors des outils de l'entreprise.
- Nouvel envoi
- unii
- Messages chiffrés de bout en bout. Ni l'employeur ni uniion ne peuvent les lire.
- Transféré
- ✓ sélectionné
- `{m.ctxLabel}` · visible par vous seule
- « `{m.ask}` »
- Insérer dans ma réponse
- Poursuivre dans l'assistant
- Masquer
- unii travaille sur « `{th.busyAsk}` »
- Travaille sur :
- Touchez les messages à inclure, ou surlignez un passage à la souris.
- Passer en mode assistant
- Ou écrivez « @unii » suivi de votre consigne dans le champ ci-dessous. Les réponses de unii ne sont visibles que par vous.
- Messages de la section
- Échangez avec les élus en direct ou en groupe, et retrouvez ici chaque envoi fait aux adhérents depuis « Envoyer un message ».
- Nouvelle discussion
- Diffuser aux adhérents
- Chiffrée de bout en bout
- Modifier le groupe
- Modifier le contact
- Voir la fiche adhérent
- Description
- Catégorie
- Téléphone
- E-mail
- Groupes en commun
- Destinataires
- Dernier canal
- Les destinataires reçoivent chaque envoi individuellement et ne voient pas les autres. Leurs réponses arrivent en message direct.
- Gérer les listes dans Adhérents →
- Ajouter des membres
- Admin
- Écrire
- Retirer
- Mettre en sourdine
- Épingler en haut de la liste

</details>

## OFF

**Mode hors ligne** · lignes 6657–6692 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isOffline`

**Listes répétées** : `docs` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `toggleAuto`
- [ ] Click `dc.open` → « {{ dc.name }} »

<details><summary>Libellés statiques (5)</summary>

- Mode hors ligne
- En visite d'usine, en sous-sol ou en déplacement : votre base documentaire reste accessible et chiffrée sur l'appareil.
- Synchronisation intelligente
- Base documentaire
- `{dc.meta}` · ouvrir

</details>

## ONB

**Onboarding** · lignes 6693–6715 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isOnboarding`

**Listes répétées** : `onbSteps` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `st.go`

<details><summary>Libellés statiques (1)</summary>

- Prise en main

</details>

## ADB

**Tableau de bord admin** · lignes 6716–6779 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `isAdmin`
- [ ] `si.selected`
- [ ] `si.idle`

**Listes répétées** : `sites`, `kpis`, `commissionStats`, `adminLinks` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `si.go`
- [ ] Click `al.go` → « {{ al.label }} »

<details><summary>Libellés statiques (4)</summary>

- Back-office
- Tableau de bord organisation
- Activité par commission
- Raccourcis d'administration

</details>

## MOD-ANON

**Fenêtre — Contrôle d'anonymisation** · lignes 6786–6890 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `anonOpen`
- [ ] `l.selected`
- [ ] `l.idle`
- [ ] `anonNoTag`
- [ ] `anonHasPieces`
- [ ] `anonResidual`
- [ ] `anonClearAllowed`
- [ ] `anonIsRps`
- [ ] `previewOpen`

**Listes répétées** : `anonLevels`, `anonTags` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `l.go`
- [ ] Click `anonRaise`
- [ ] Click `closePreview`

**Attributs (placeholder, aria, title)** :
- aria-label: Contrôle d'anonymisation
- aria-label: Fermer l'aperçu

<details><summary>Libellés statiques (18)</summary>

- Contrôle d'anonymisation
- `{anonOrigin}` — le coffre CSE reste local. Vérifiez ce que le modèle va recevoir avant l'envoi.
- Texte original — reste dans le coffre
- Payload masqué — part au modèle
- Aucune donnée nominative détectée dans cette requête.
- `{anonPiecesCount}` pièce(s) jointe(s) conservée(s) dans le coffre — jamais transmises au modèle. `{anonPiecesLabel}`.
- Ce que le modèle reçoit à la place
- Envoi bloqué — un identifiant échappe au filtre
- Détecté en clair : `{anonResidualWords}`. Relevez le niveau d'anonymisation avant tout envoi.
- Relever le niveau et masquer
- Annuler
- Envoyer en clair
- Niveau RPS : mode « envoyer en clair » indisponible.
- Confirmer l'envoi au modèle
- Aperçu chiffré
- Consultation tracée dans le journal d'audit du dossier — déchiffrement local, aucun envoi au serveur.
- Faire signer
- Fermer

</details>

## MOD-IAERR

**Fenêtre — Erreur IA** · lignes 6891–6909 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `aiErrOpen`
- [ ] `aiHasRetry`

**Actions** :
- [ ] Click `aiRetry`

<details><summary>Libellés statiques (4)</summary>

- Appel au modèle en échec
- Aucune réponse simulée n'a été substituée : rien n'a été produit ni enregistré.
- Réessayer
- Fermer

</details>

## UNII

**Panneau unii (assistant latéral)** · écran « Panneau unii » · lignes 6910–7034 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `unii.isOpen`
- [ ] `unii.hasMsgs`
- [ ] `unii.locked`
- [ ] `unii.unlocked`
- [ ] `unii.itemFixed`
- [ ] `unii.hasItems`
- [ ] `unii.hasPanelSuggs`
- [ ] `unii.noActs`
- [ ] `unii.hasHidden`
- [ ] `mm.u`
- [ ] `mm.b`
- [ ] `mm.local`
- [ ] `mm.canApply`
- [ ] `unii.busy`
- [ ] `hasToast`
- [ ] `isMobile`
- [ ] `item.active`
- [ ] `item.idle`
- [ ] `dragging`
- [ ] `fwm.open`

**Listes répétées** : `unii.itemOpts`, `unii.panelSuggs`, `unii.acts`, `unii.msgs`, `navItemsM` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `unii.close` → « unii »
- [ ] Click `unii.clear`
- [ ] Change `unii.onItem` → « {{ o.label }} »
- [ ] Click `a.go` → « {{ a.label }} »
- [ ] Click `mm.apply`
- [ ] Click `unii.send`
- [ ] Click `item.go` → « {{ item.label }} »

**Attributs (placeholder, aria, title)** :
- aria-label: unii
- aria-label: Fermer
- placeholder: Posez une question sur ce module…
- aria-label: Envoyer

<details><summary>Libellés statiques (18)</summary>

- unii
- `{unii.ctxLabel}` · `{unii.roleLabel}`
- Effacer
- À partir d'Élu 2.0
- unii vous accompagne dans chaque module
- Suite à donner aux dossiers, questions à poser en séance, relecture des documents, résumés pour les salariés. Votre formule actuelle : Élu 1.0.
- Voir les formules
- Contexte :
- Élément concerné
- Suggestions
- Actions
- Aucune action activée pour votre rôle dans ce module. Posez votre question ci-dessous.
- IA indisponible — trame de départ
- Copier
- Continuer dans l'Assistant
- unii réfléchit…
- Anonymisé avant envoi · unii propose, vous validez
- Réglages

</details>

## MOD-FWM

**Fenêtre — fwm (transfert/webmaster)** · lignes 7035–7057 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `dpm.open`

**Listes répétées** : `fwm.rows` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `fwm.onQ` → « {{ x.check }} »
- [ ] Click `fwm.close`

**Attributs (placeholder, aria, title)** :
- placeholder: Rechercher une discussion…

<details><summary>Libellés statiques (2)</summary>

- Annuler
- Transférer

</details>

## MOD-DPM

**Fenêtre — dpm** · lignes 7058–7082 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `dpm.noRows`
- [ ] `ctm.open`

**Listes répétées** : `dpm.rows` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `dpm.create` → « Créer un dossier à partir du message »
- [ ] Click `x.go` → « {{ x.title }} »

**Attributs (placeholder, aria, title)** :
- placeholder: Rechercher un dossier…

<details><summary>Libellés statiques (6)</summary>

- Créer un dossier à partir du message
- unii propose titre, catégorie, échéance et plan d'action
- Ou verser dans un dossier existant
- Verser →
- Aucun dossier ne correspond.
- Annuler

</details>

## MOD-CTM

**Fenêtre — contact** · lignes 7083–7110 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `ctm.showCats`
- [ ] `ctm.canDel`
- [ ] `grm.open`

**Listes répétées** : `ctm.cats` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `ctm.onName` → « Fonction / mandat »
- [ ] Change `ctm.onTel` → « E-mail »
- [ ] Click `ctm.close`

**Attributs (placeholder, aria, title)** :
- placeholder: Prénom Nom
- placeholder: Élu titulaire, avocat conseil…
- placeholder: nom@exemple.fr

<details><summary>Libellés statiques (8)</summary>

- Nom complet
- Fonction / mandat
- Catégorie
- Téléphone
- E-mail
- Les adhérents sont ajoutés automatiquement depuis le fichier Adhérents ; leurs coordonnées se modifient dans leur fiche.
- Écrire
- Annuler

</details>

## MOD-GRM

**Fenêtre — groupe** · lignes 7111–7145 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `grm.hasChips`
- [ ] `sheetOpen`

**Listes répétées** : `grm.chips`, `grm.cands` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Change `grm.onName` → « Description »
- [ ] Change `grm.onQ` → « {{ x.check }} »
- [ ] Click `grm.close`

**Attributs (placeholder, aria, title)** :
- placeholder: Commission Égalité professionnelle
- placeholder: Objet du groupe, règles d'échange…
- aria-label: Retirer
- placeholder: Ajouter un élu, un adhérent, un contact…

<details><summary>Libellés statiques (6)</summary>

- Nom du groupe
- Description
- Membres
- `{ch.name}` ×
- `{x.catLabel}` · `{x.role}`
- Annuler

</details>

## MOD-SHEET

**Feuille mobile (sheet)** · lignes 7146–7234 du prototype

- [ ] V-B  - [ ] V-T  - [ ] V-M  - [ ] É  - [ ] A  - [ ] L

**États / conditions d'affichage** (chacun = une capture) :
- [ ] `sheetForm`
- [ ] `o.selected`
- [ ] `o.idle`
- [ ] `sheetHasChecks`
- [ ] `ch.on`
- [ ] `ch.off`
- [ ] `sheetHasField`
- [ ] `sheetHasErr`
- [ ] `sheetDone`
- [ ] `sheetIsFile`

**Listes répétées** : `sheetOptions`, `sheetChecks`, `sheetDoneLines` — tester 0, 1 et n éléments.

**Actions** :
- [ ] Click `o.pick` → « {{ o.label }} »
- [ ] Click `ch.toggle` → « {{ ch.label }} »
- [ ] Click `sheetClose`

<details><summary>Libellés statiques (6)</summary>

- Canaux
- Annuler
- Le fichier reste disponible dans
- Paramètres → Exports
- pendant 30 jours.
- Fermer

</details>

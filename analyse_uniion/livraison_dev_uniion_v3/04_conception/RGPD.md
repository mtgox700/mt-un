# Audit RGPD — uniion

Date : 2 septembre 2026. Portée : `uniion App.dc.html` (≈9 650 lignes), prototype fonctionnel.
Cet audit porte sur les **traitements que les fonctionnalités impliquent**, indépendamment du fait que
la plupart des services distants soient encore simulés. Il complète `SECURITE.md` (exigences techniques)
et `AUDIT.md` (état de câblage).

Avertissement : ce document est une analyse de conception, pas un avis juridique. La qualification
définitive des responsabilités et des bases légales relève du DPO de la fédération et, le cas échéant,
d'un conseil extérieur.

---

## 1. Qui est responsable de quoi

C'est le point le plus structurant et il n'est aujourd'hui **tranché nulle part dans le produit**.

- Le **CSE est une personne morale distincte de l'employeur**. Il est responsable de traitement pour ses
  propres fichiers : demandes des salariés, dossiers, comptes rendus, ASC.
- L'**organisation syndicale** (section, fédération) est responsable d'un autre traitement, disjoint :
  le fichier des adhérents et les cotisations.
- L'**éditeur de uniion** est sous-traitant des deux, au sens de l'article 28.

Conséquence de conception : **les données du CSE et celles du syndicat ne doivent pas se mélanger**, alors
que le prototype les fait cohabiter dans un même espace, sous un même compte, avec une navigation continue
entre l'onglet Dossiers (CSE) et l'onglet Adhérents (syndicat). Un élu du CSE non syndiqué n'a aucun titre
à consulter le fichier des adhérents ; un responsable de section n'a pas à lire les demandes individuelles
adressées au CSE.

**Recommandation 1 (bloquante).** Séparer les deux périmètres : deux responsables de traitement, deux jeux
de rôles, deux journaux d'audit, idéalement deux bases logiques. Faire apparaître le périmètre actif dans
l'interface (un bandeau « Espace CSE » / « Espace syndicat » plutôt qu'une simple entrée de menu). Rédiger
deux contrats de sous-traitance distincts et deux registres.

---

## 2. Traitements identifiés, par fonctionnalité

| Fonctionnalité | Données | Base légale envisageable | Sensibilité |
| --- | --- | --- | --- |
| Dossiers / demandes de salariés | Identité, emploi, récit de la situation, santé et faits de harcèlement possibles | Mission d'intérêt légitime du CSE, obligations légales (art. 6-1-c/f) | **Élevée** — art. 9 dès qu'un dossier touche la santé |
| Pièces jointes chiffrées | Certificats, courriers, constats | Idem | **Élevée** |
| Fichier des adhérents | Identité, coordonnées, emploi, section, cotisations | Consentement / intérêt légitime du syndicat sur ses membres | **Art. 9 — appartenance syndicale** |
| Cotisations | Montants, mode de règlement, échéances, attestations fiscales | Obligation légale comptable | **Art. 9 par déduction** |
| Import CSV | Tout le fichier adhérents en une opération | Idem | **Art. 9** |
| Campagnes de message | Destinataires, canal, historique d'envoi | Consentement (prospection interne), intérêt légitime (convocations statutaires) | Art. 9 |
| Assistant juridique (LLM) | Question de l'élu, corpus, éventuels résidus non masqués | Intérêt légitime, sous réserve de la minimisation | **Élevée** |
| Réunions — enregistrement audio | Voix de tous les participants, propos tenus | **Consentement de chaque participant** | **Élevée** — donnée biométrique potentielle |
| Comptes rendus / PV | Propos attribués nommément | Obligation légale (PV du CSE) | Moyenne |
| Sondages internes | Réponses des salariés, participation | Consentement | Moyenne à élevée selon l'objet |
| Messagerie interne | Échanges entre élus | Intérêt légitime | Moyenne |
| Pages intranet | Contenu publié, auteur | Intérêt légitime | Faible, sauf si des noms de salariés y figurent |
| Agenda partagé | Événements, lieux, invités, visibilité | Intérêt légitime | Faible à moyenne |
| Comptes et membres | Identité, rôle, dernière connexion | Exécution du contrat | Faible |
| Reporting d'usage | Statistiques d'activité par élu | Intérêt légitime | **Attention : risque de surveillance** |

---

## 3. Points de non-conformité relevés

### 3.1 Aucune information des personnes concernées

Le prototype ne comporte **aucune mention d'information** (art. 13-14) à destination :

- du salarié qui saisit le CSE d'une demande ;
- de l'adhérent dont la fiche est créée, en particulier lors d'un **import CSV** — l'adhérent n'a alors
  jamais interagi avec l'application ;
- du participant à une réunion enregistrée ;
- du répondant à un sondage.

**Recommandation 2.** Une notice d'information par traitement, atteignable depuis l'écran qui collecte,
et non uniquement depuis un menu Réglages. Pour l'import CSV : imposer une case déclarative « les personnes
importées ont été informées » et générer un courriel d'information type.

### 3.2 Aucun exercice des droits outillé

L'écran RGPD existe mais n'expose ni accès, ni rectification, ni effacement, ni portabilité, ni opposition
pour les **personnes concernées** — seulement des réglages pour l'élu.

**Recommandation 3.** Ajouter un module « Demandes d'exercice de droits » : réception, qualification,
délai d'un mois affiché, recherche transverse par personne (dossiers, adhérents, messages, PV, sondages),
export de portabilité, suppression avec conservation d'une preuve d'exécution. La recherche transverse
existante est un bon socle technique : elle doit pouvoir être exécutée « au nom d'une personne ».

### 3.3 Enregistrement des réunions

Le consentement est demandé à l'élu qui enregistre, pas aux participants. Or l'enregistrement d'une
réunion du CSE capte la voix de la direction, des élus et des invités.

**Recommandation 4.** Consentement **par participant**, recueilli avant le démarrage et révocable ;
mention audible ou affichée en début de séance ; interdiction d'enregistrer si un participant refuse ;
la destruction certifiée déjà prévue à l'approbation du PV est un bon dispositif — le conserver et le
journaliser.

### 3.4 Assistant juridique et modèle de langage

Positif : le masquage est **imposé avant tout appel** (`maskOrRefuse`), l'envoi est annulé si un résidu
est détecté, et le filtre de méta-questions empêche l'exfiltration d'informations techniques.

Faiblesses :

- Les appels partent **depuis le navigateur**, avec les prompts et le corpus côté client. Le sous-traitant
  du modèle est donc appelé sans médiation, sans journalisation serveur et sans contrôle de quota.
- Le masquage repose sur des motifs et une liste de sentinelles : c'est une réduction du risque, pas une
  anonymisation au sens du RGPD. Les données restent des **données à caractère personnel pseudonymisées**.
- Rien n'interdit à un élu de coller un récit détaillé dans le champ libre.

**Recommandation 5.** Passerelle serveur obligatoire ; contrat de sous-traitance et localisation UE du
fournisseur inscrits dans le registre ; interdiction contractuelle d'entraînement sur les données ;
durée de conservation nulle côté fournisseur (zero data retention) ; journal des requêtes **sans contenu
en clair** (déjà prévu au modèle de données) ; et, côté interface, un avertissement au premier usage
expliquant que le masquage ne dispense pas de la minimisation.

### 3.5 Reporting d'usage — risque de surveillance des élus

L'écran de reporting produit des statistiques d'activité par élu et par commission. Utilisé par un
administrateur, cela devient un outil de mesure de l'activité syndicale individuelle.

**Recommandation 6.** N'exposer les statistiques individuelles qu'à l'élu lui-même ; agréger et
anonymiser (seuil minimal de 5 personnes) pour toute vue collective ; documenter cette limite dans le
registre.

### 3.6 Durées de conservation non définies

Aucune durée n'est portée par les données. Le prototype ne perd les informations qu'au rechargement, ce qui
masque le problème.

**Recommandation 7.** Fixer et implémenter des durées, par exemple : dossier clos + 5 ans (prescription),
PV pendant la durée du mandat + archivage légal, enregistrement audio détruit à l'approbation du PV
(déjà prévu), fiche adhérent jusqu'à la démission + purge, pièces comptables de cotisation 10 ans,
requêtes IA 12 mois sans contenu, journal d'audit 3 ans. Prévoir une purge automatique et une
notification avant échéance.

### 3.7 Suppressions non réellement effaçantes

Les suppressions ajoutées (dossier, adhérent, document, page, sondage, membre) retirent l'objet de l'état
mais les messages annoncent parfois une corbeille de 30 jours qui n'existe pas.

**Recommandation 8.** Distinguer explicitement **archivage** (réversible, accès restreint) et
**effacement** (irréversible, avec preuve). Ne promettre dans l'interface que ce que le back-end fait.
Toute suppression d'une donnée art. 9 doit produire une entrée d'audit inaltérable.

### 3.8 Transferts et sous-traitants ultérieurs

Deux appels tiers depuis le navigateur de l'élu : le **fournisseur du modèle** et **Google Fonts**.
Le second suffit à transmettre l'adresse IP d'un élu à un tiers hors UE, sans base légale.

**Recommandation 9.** Héberger les polices localement (correctif immédiat, sans effet visuel), et
n'autoriser aucun appel sortant depuis le client hors de l'infrastructure de l'éditeur. Politique de
sécurité de contenu (CSP) stricte.

### 3.9 Analyse d'impact (AIPD) non réalisée

Le traitement cumule plusieurs critères de la liste CNIL : **données sensibles** (appartenance syndicale,
santé), **personnes vulnérables** (salariés en situation de subordination), **croisement de données**,
**usage innovant** (modèle de langage). Une AIPD est requise.

**Recommandation 10 (bloquante avant mise en production).** Conduire une AIPD par périmètre — un pour
le CSE, un pour le fichier syndical — et la faire viser par le DPO.

### 3.10 Sécurité — écarts observés

- Aucune persistance chiffrée réelle : le chiffrement affiché est déclaratif.
- Le fichier adhérents est chargé intégralement en mémoire, sans pagination ni contrôle serveur des filtres.
- Les rôles existent à l'écran mais aucune autorisation n'est vérifiée côté serveur (il n'y a pas de serveur).
- MFA présenté comme réglable, non contraint pour les rôles sensibles.

**Recommandation 11.** MFA obligatoire pour trésorier et administrateurs ; autorisation contrôlée à chaque
requête, jamais dans le client ; chiffrement au repos avec clés hors base ; journal d'audit append-only
sur toute lecture du fichier adhérents et de tout dossier.

---

## 4. Ce qui est déjà bien conçu

À préserver dans les développements futurs :

- **Masquage imposé avant l'appel au modèle**, avec refus en cas de résidu — le bon ordre des opérations.
- **Filtre applicatif des méta-questions** en amont du prompt : la défense ne repose pas sur le modèle.
- **Échec honnête** de l'IA, sans repli sur une réponse fabriquée localement.
- **Destruction certifiée** de l'audio à l'approbation du PV, avec preuves.
- **Visibilité explicite** sur les événements d'agenda et les pages intranet (élus / adhérents / tous).
- **Validation ligne à ligne** de l'import CSV, qui empêche l'entrée de données incohérentes.
- **Confirmation à deux temps** sur les suppressions.

---

## 5. Ordre de traitement recommandé

1. Séparer les responsabilités CSE / syndicat (§1) — décision de conception, à prendre avant le back-end.
2. AIPD par périmètre (§3.9).
3. Passerelle serveur pour le modèle, polices locales, CSP (§3.4, §3.8).
4. Autorisation et journal d'audit côté serveur ; MFA contraint (§3.10).
5. Notices d'information sur les écrans de collecte (§3.1).
6. Durées de conservation et purge (§3.6), archivage vs effacement (§3.7).
7. Module d'exercice des droits (§3.2).
8. Consentement par participant pour les réunions (§3.3).
9. Anonymisation du reporting (§3.5).

Les points 1 à 4 conditionnent la mise en service ; les points 5 à 9 peuvent être livrés par
incréments, à condition d'être planifiés dès la première version.

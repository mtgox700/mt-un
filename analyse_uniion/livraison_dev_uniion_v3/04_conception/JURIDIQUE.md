# Contenus juridiques et conformité — ce qui reste à produire

Version 1 — 5 septembre 2026. Le prototype ne contient **aucun texte juridique réel** : tous les
contenus ci-dessous doivent être rédigés ou validés par un juriste avant mise en ligne. Ce document
les liste avec leur emplacement dans le produit et le point de blocage associé.

## 1. Textes à produire

| Document | Emplacement | Point de vigilance |
|---|---|---|
| Conditions générales d'utilisation | Écran de connexion, Réglages | Qualité des parties : le contrat lie l'éditeur et l'organisation syndicale, pas les militants individuellement |
| Politique de confidentialité | Pied de page des sites, Réglages | Doit distinguer les traitements de l'éditeur (sous-traitant) et de l'organisation (responsable) |
| Mention d'information des adhérents | Bulletin d'adhésion, page publique « Adhérer » | Article 13 RGPD : finalités, base légale, durées, destinataires, droits |
| Mention d'information des salariés saisissants | Formulaire de saisine intranet et public | La saisine crée un dossier : le dire avant la saisie, pas après |
| Bulletin d'adhésion | Bibliothèque de documents | Consentement explicite au traitement de l'appartenance syndicale (article 9-2-a) |
| Mandat SEPA | Bulletin d'adhésion | Mentions obligatoires du prélèvement, révocation |
| Déclaration d'accessibilité | Pied de page des sites générés (déjà prévu) | Obligatoire ; ne peut être publiée qu'après audit RGAA |
| Mentions légales des sites | Pied de page des sites générés (déjà prévu) | Éditeur, responsable de publication, hébergeur |
| Politique de conservation | Réglages · Sécurité | Reprend les durées de MODELE_DONNEES.md, opposable |
| Charte d'usage de l'assistant IA | Écran Sécurité de l'IA | Ce qui peut et ne peut pas être soumis au modèle, responsabilité de la relecture humaine |

## 2. Analyse d'impact (AIPD) — obligatoire

Elle est requise, sans marge d'appréciation : le produit traite à grande échelle des données de
l'article 9 (appartenance syndicale, santé au travail) et met en œuvre un modèle de langage sur des
données relatives à des personnes en situation de vulnérabilité vis-à-vis de leur employeur.

Éléments déjà réunis dans le dossier : description des traitements (MODELE_DONNEES.md), mesures
techniques (SECURITE.md), durées de conservation, matrice d'autorisations (AUTORISATIONS.md),
pipeline IA et masquage (API.md §2). Restent à produire : appréciation de la nécessité et de la
proportionnalité, analyse des risques pour les personnes (accès de l'employeur, réidentification par
les agrégats, fuite via le modèle), plan de traitement des risques, consultation du délégué à la
protection des données, et — le cas échéant — consultation des personnes concernées.

**Risque principal identifié, à traiter explicitement** : la seule existence d'un compte sur le
produit révèle une appartenance syndicale. Toute notification, tout e-mail sortant, tout export et
tout nom de domaine doivent être conçus pour ne pas trahir cette appartenance auprès de l'employeur
ou d'un tiers.

## 3. Sous-traitance et localisation

L'écran `Sécurité de l'IA` promet aujourd'hui à l'utilisateur un hébergement souverain et un
modèle non entraîné sur ses données. **Cette promesse doit être tenue par contrat ou reformulée avant
mise en ligne** — c'est un engagement affiché, pas une intention interne.

À formaliser : contrat de sous-traitance (article 28 RGPD) avec l'éditeur et avec le fournisseur du
modèle ; localisation de l'inférence dans l'Union européenne, écrite ; interdiction contractuelle
d'entraînement et de conservation ; durée de rétention côté fournisseur (cible : zéro) ; conditions
de réversibilité et d'export en fin de contrat ; registre des sous-traitants ultérieurs ; procédure
de notification de violation sous 72 h ; assurance et responsabilité.

## 4. Contenus métier à valider par un juriste

- **Corpus de l'assistant juridique** : périmètre (Code du travail, convention collective IDCC de
  l'organisation, accords d'entreprise), version datée, procédure de mise à jour. Une réponse
  fondée sur un texte abrogé est un risque pour le militant qui l'utilise en réunion.
- **Modèles de documents** : procès-verbaux, courriers, tracts, appels de cotisation, reçus,
  attestations fiscales — par **type d'organisation** (CSE, section syndicale, union départementale).
  Les modèles actuels sont encore rédigés en vocabulaire CSE alors que la démonstration est passée en
  section syndicale.
- **Modèles de messages aux adhérents** : relance de cotisation, convocation, appel à mobilisation —
  formulations vérifiées au regard du droit syndical et du RGPD (finalité, désinscription).
- **Avertissement de responsabilité de l'assistant** : une réponse du modèle n'est pas un conseil
  juridique ; la relecture humaine est requise avant tout usage externe. Déjà présent dans
  l'interface, à valider dans sa formulation.

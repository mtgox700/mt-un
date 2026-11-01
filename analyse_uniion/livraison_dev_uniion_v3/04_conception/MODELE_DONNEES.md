# Modèle de données

Version 2 — 5 septembre 2026. Les sections d'origine décrivent les entités du prototype ; la section
« Entités ajoutées » couvre ce qui manquait (agenda, type d'organisation, listes dynamiques, sites,
audit) ; suivent les règles de rétention par entité et le schéma formel de référence.

## Organisation et personnes

- **Organisation** : nom, sigle, **type** (`cse` | `section` | `ud`), convention collective (IDCC),
  adresse, e-mail, établissements, sièges ou adhérents souscrits, échéance de facturation.
  Le **type** pilote le vocabulaire, la visibilité du module Cotisations, les types d'événements
  d'agenda et les niveaux de visibilité. Il n'est **pas modifiable par l'utilisateur final** : il change
  la base légale des traitements (voir RGPD.md). Un changement de nature de l'organisation passe par une
  migration explicite et une nouvelle information des personnes.
- **Utilisateur / élu** : identité, mandat (titulaire, suppléant, secrétaire, trésorier), rôles
  (élu, référent SSCT, communication, administrateur), établissement, formation SSCT (oui/non),
  visibilité des coordonnées, préférences de notification, appareils et sessions.

## Dossiers

- **Dossier** : id, intitulé, catégorie (Juridique, Santé, Négociation, Discipline, Égalité…),
  description courte et longue, statut (`todo` / `doing` / `done`), échéance, référent,
  établissement, niveau d'anonymisation déduit, question d'analyse par défaut.
- **Entrée d'historique** : date, titre, corps, auteur.
- **Note** : texte, auteur, date.
- **Pièce jointe** : nom, type, taille, empreinte, date de dépôt, déposant, journal d'accès.
- **Conversation d'assistant liée au dossier** : messages (rôle, texte, source citée, niveau
  d'anonymisation, empreinte de requête).

## Assistant IA

- **Requête** : id, empreinte, niveau d'anonymisation, nombre d'entités masquées, surface d'origine
  (assistant, dossier, document, page intranet, compte rendu), prompt système utilisé, horodatage,
  coût/quota consommé, résultat (succès / erreur / refus par garde-fou). Sans contenu en clair.
- **Réponse** : sources citées (article, convention), latence.

## Adhérents

- **Adhérent** : id, prénom, nom, initiales, e-mail, téléphone, emploi occupé, entreprise, établissement,
  section syndicale, direction, date d'adhésion, mode de règlement, montant de cotisation, statut de
  cotisation (à jour / en retard / exonéré), historique de règlements, listes de diffusion déduites,
  consentement de contact. **Donnée sensible (art. 9 RGPD).**
- **Liste de diffusion** : id, libellé, type (`dyn` par critères / `fixe` par identifiants), critères
  (établissement, section, direction, statut), identifiants pour les listes fixes, description, canal
  (e-mail, SMS, notification app, messagerie interne, affichage), date du dernier recalcul.
- **Campagne de message** : liste cible, modèle (relance de cotisation, convocation à l'assemblée…),
  objet, corps, canal, planification, état d'envoi par destinataire, désinscriptions.
- **Import** : fichier source, encodage, séparateur, colonnes attendues (`ADH_CSV_COLS` : prénom, nom,
  e-mail, téléphone, entreprise, établissement, section, direction, emploi, date d'adhésion, mode de
  règlement, montant), rapport par ligne (valide / rejetée avec motif / avertie), auteur, horodatage.
- **Cotisation** : adhérent, période, montant, mode, date d'encaissement, pièce justificative,
  attestation fiscale annuelle.
- **Bulletin d'adhésion** : gabarit de la bibliothèque de documents (identité, situation
  professionnelle, cotisation, mandat SEPA).

## Sondages

- **Sondage** : titre, type (choix unique, multiple, échelle), options, cible (tous, établissement,
  collège), date de clôture, relance, statut de modération (brouillon, en validation, validé, diffusé,
  clos), validateur.
- **Réponse** : anonyme par construction, agrégats seulement.

## Documents

- **Document** : titre, gabarit (courrier, tract, compte rendu, NAO…), format (A4, large), statut
  (Brouillon, Relu, Signé, Diffusé), date de mise à jour, blocs de contenu, source Markdown/HTML.
- **Bloc** : type (titre, paragraphe, liste, citation, signature), contenu.
- **Signature** : signataire, style, consentement, horodatage, document scellé.

## Réunions

- **Séance** : type (CSE ordinaire, extraordinaire, négociation), date, participants, marqueurs
  temporels, accès autorisés, enregistrement, transcription, compte rendu, statut de relecture.

## Intranet

- **Page** : titre, rubrique, slug, chapô, blocs, auteur, statut (Brouillon, En relecture, Prête,
  Envoyée, Publiée), relecture (relecteur, date, avis), demande de publication (rubrique, date de mise
  en ligne, visibilité, pièce jointe HTML, message au webmaster), historique de la demande.
- **Rubrique** : libellé, ordre, visibilité.
- **Gabarit du site** : couleurs, polices, CSS personnalisé.

## Reporting

- **Bilan de mandat** (agrégats) : dossiers ouverts/clos par mois, thèmes, réunions, négociations,
  sondages, heures de délégation, accords signés — par période (année, 12 mois glissants, mandat).
- **Télémétrie d'usage** (agrégats) : élus actifs, sessions par semaine et par type d'appareil,
  ouvertures par module, appels IA et quota, niveaux d'anonymisation, contenus produits, synchronisations
  hors ligne et conflits, latence, incidents, connexions bloquées. Une vue nominative « élus les plus
  actifs » réservée aux administrateurs.

## Messagerie

- **Fil** : participants, sujet, chiffrement, dernier message.
- **Message** : auteur, texte, pièces jointes, accusé de lecture, horodatage.

## Transverse

- **Notification** : type, urgence, cible, lu/non lu, action associée.
- **Événement d'audit** : acteur, action, objet, horodatage, appareil, adresse (conservation 5 ans).
- **Tâche de file** : nature (e-mail webmaster, export, appel IA), état, tentatives, dernière erreur.

## Entités ajoutées (version 2)

### Événement d'agenda
- `id`, `titre`, `type` (selon le type d'organisation : réunion de section, négociation, HSCT,
  permanence, formation, congrès, réunion CSE, commission…), `debut`, `fin`, `journee_entiere`,
  `lieu`, `description`, `createur_id`, `visibilite` (`section` | `bureau` | `prive`),
  `recurrence` (RRULE), `serie_id`, `occurrence_exclue`, `dossier_id` et `reunion_id` facultatifs,
  `version`, `supprime_le`.
- **Participant** : `evenement_id`, `personne_id` ou `email_externe`, `reponse`
  (`en_attente` | `accepte` | `refuse`), `role` (`organisateur` | `participant` | `informe`).
- **Rappel** : `evenement_id`, `delai` (minutes avant), `canal`, `etat`, `envoye_le`.
- Contrainte : la visibilité est appliquée **côté serveur à la lecture** (AUTORISATIONS.md §3.8).

### Liste de diffusion dynamique
- `id`, `libelle`, `type` (`dyn` | `fixe`), `description`, `canal`,
  `criteres` : établissement, section, direction, statut de cotisation, dates d'adhésion, mandat —
  combinés en ET, chaque critère acceptant plusieurs valeurs (OU) ;
  `membres_fixes` pour les listes fixes, `recalcul_planifie`, `dernier_recalcul`,
  `effectif_dernier_recalcul`.
- Le recalcul est **serveur et planifié** : une liste n'est jamais figée à sa création.

### Site et charte de site
- **Site** : `id` (`intranet` | `public`), `hote`, `audience`, `indexable`,
  `authentification_requise`.
- **Rubrique** : `id`, `site_id`, `libelle`, `chemin`, `ordre`, `description`.
- **Charte de site** : `site_id`, `herite_identite`, `accent`, `couleur_entete`,
  `police_titre`, `largeur_contenu`, `navigation` (`inline` | `bandeau`),
  `angles` (`net` | `doux` | `rond`), `logo_affiche`, `logo_src`,
  `logo_echelle` (60–300). En héritage, accent, couleur d'en-tête et police dérivent de l'identité
  de l'organisation.
- **Page** : ajouter `site_id` à l'entité Page décrite plus haut.

### Identité de marque
- `preset`, `accent`, `accent_fort`, `mode`, `polices`, `produit`,
  `logo_clair`, `logo_sombre`, `monogramme`, `logo_intranet`, `logo_public`,
  `initiales`, `echelles_logo` (une par emplacement, 60–300 %), `teinte_connexion`,
  `favicon`, `heritage_sites`, `surcharges_par_etablissement`.
- **Journal d'identité** : date, auteur, description de la publication.

### Événement d'audit
- `id`, `acteur_id`, `acteur_role`, `action` (verbe normalisé : lecture, création,
  modification, suppression, export, envoi, changement de rôle, refus), `ressource_type`,
  `ressource_id`, `horodatage`, `appareil`, `adresse_ip_tronquee`, `motif`,
  `article_9`, `trace_requete`.
- **Non modifiable** : table en ajout seul, empreinte chaînée recommandée. Conservation 5 ans.

### Requête IA — compléments
- `prompt_version`, `corpus_version`, `modele_alias`, `cout_centimes`,
  `residuel_detecte` (types uniquement, jamais les valeurs), `refus_motif`
  (`meta_question` | `masquage_incomplet` | `quota`).

### Tâche de file — compléments
- `tentatives`, `prochaine_tentative`, `derniere_erreur`, `idempotency_key`, `etat`.

## Rétention par entité

Durées à confirmer par le délégué à la protection des données de l'organisation ; celles proposées
tiennent compte des prescriptions applicables et de l'intérêt de la défense.

| Entité | Conservation | Déclencheur | Après échéance |
|---|---|---|---|
| Dossier clos | 5 ans | Clôture | Anonymisation, agrégats conservés |
| Dossier contentieux | 10 ans | Fin de procédure | Anonymisation |
| Pièce jointe de dossier | Suit le dossier | — | Suppression définitive |
| Note et historique de dossier | Suit le dossier | — | Suppression définitive |
| Conversation d'assistant liée à un dossier | 2 ans | Dernier message | Suppression |
| Requête IA (métadonnées, sans contenu) | 12 mois | Appel | Suppression |
| Adhérent actif | Durée de l'adhésion | — | — |
| Adhérent radié ou démissionnaire | 3 ans | Fin d'adhésion | Suppression, agrégats conservés |
| Cotisation et pièce comptable | 10 ans | Exercice clos | Archivage comptable |
| Attestation fiscale | 6 ans | Émission | Suppression |
| Campagne de message (contenu) | 12 mois | Envoi | Suppression, statistiques conservées |
| Désinscription | 3 ans | Demande | Conservation du seul témoin de refus |
| Sondage et agrégats | 5 ans | Clôture | Agrégats seuls |
| Réponse individuelle à un sondage | Aucune | — | Anonyme par construction |
| Document signé | 10 ans | Signature | Archivage scellé |
| Document brouillon | 2 ans | Dernière modification | Suppression |
| Enregistrement audio de réunion | 90 jours | Enregistrement | Suppression automatique |
| Transcription de réunion | 2 ans | Séance | Suppression |
| Compte rendu approuvé | 10 ans | Approbation | Archivage |
| Événement d'agenda passé | 3 ans | Date de fin | Suppression |
| Page de site publiée | Publication + 2 ans | Dépublication | Archive hors ligne |
| Message chiffré | 12 mois | Envoi | Suppression du blob |
| Notification | 90 jours | Émission | Suppression |
| Journal d'audit | 5 ans | Événement | Suppression |
| Télémétrie d'usage (agrégats) | 24 mois | Période | Suppression |
| Session et appareil | 90 jours après dernière activité | — | Suppression |
| Compte révoqué | 3 mois puis anonymisation | Fin de mandat | Anonymisation |
| Corbeille (suppression logique) | 30 jours | Suppression | Suppression définitive |

Chaque durée doit être **implémentée par une tâche planifiée vérifiable**, avec compte rendu
d'exécution consultable par le délégué à la protection des données. Une durée non appliquée par le
code n'est pas une durée de conservation, c'est une intention.

## Schéma formel

Schéma de référence à livrer avec le code : `schema/uniion.sql` (PostgreSQL, source de vérité) et
`schema/uniion.d.ts` (types partagés côté client). Conventions : identifiants texte préfixés
(`dos_`, `adh_`, `evt_`), `version` entier sur toute table modifiable (concurrence
optimiste), `cree_le` / `modifie_le` / `supprime_le` partout, et `organisation_id` sur
**toutes** les tables métier avec politique de sécurité par ligne (RLS) : le cloisonnement entre
organisations est une contrainte de base de données, pas une condition applicative.

Chiffrement au repos : les colonnes d'article 9 (appartenance syndicale, santé au travail) et les
pièces jointes sont chiffrées avec une clé par organisation, distincte de la clé de sauvegarde.

## Entités ajoutées (version 3 — 1er octobre 2026)

### Contact
- `id`, `organisation_id`, `categorie` (`elu` | `adherent` | `externe`), `nom`, `fonction`,
  `telephone`, `email`, `personne_id` (compte uniion, facultatif), `adherent_id` (facultatif), `cree_par`, `supprime_le`.
- Les contacts `adherent` sont **dérivés** du fichier Adhérents et non modifiables ici.
- Un contact `externe` (avocat, expert) n'a pas de compte : il ne peut pas recevoir de message dans
  l'application tant qu'il n'est pas invité.

### Conversation (remplace « Fil »)
- `id`, `type` (`direct` | `groupe` | `diffusion`), `nom`, `description`, `avatar`, `cree_par`, `cree_le`.
- `direct` : exactement deux participants, unique par paire.
- `groupe` : **Membre de conversation** `conversation_id`, `personne_id`, `admin` (bool), `ajoute_par`, `ajoute_le`.
  Au moins un administrateur ; le dernier ne peut pas partir sans en désigner un autre.
- `diffusion` : `liste_id` (liste de diffusion adhérents) **ou** `destinataires_figes[]` (sélection ponctuelle).
  Les destinataires ne se voient pas entre eux ; leurs réponses arrivent en `direct`.
- **Préférences par participant** : `sourdine` (bool ou échéance), `epinglee`, `dernier_lu_message_id`.
  Le compteur non lu se calcule à partir de `dernier_lu_message_id`.

### Message
- `id`, `conversation_id`, `auteur_id`, `type` (`texte` | `systeme` | `envoi_adherents`), `texte` (chiffré),
  `objet` (envoi aux adhérents), `canal` (`app` | `email` | `sms`), `nb_destinataires`,
  `reponse_a` (`message_id` + conversation d'origine si réponse en privé), `transfere_de` (`message_id`),
  `pieces[]`, `cree_le`, `modifie_le`, `supprime_le`.
- Messages `systeme` : création, renommage, ajout, retrait, nomination d'admin. Générés par le serveur.
- **Filtres de liste** (calculés serveur) : non lues ; *sans réponse de ma part* (dernier message non
  système d'un autre auteur, hors diffusion) ; *dernier message de moi* ; groupes ; diffusions.

### Versement en dossier
- `dossier_id`, `message_id`, `verse_par`, `verse_le`. Le dossier reçoit une **copie figée** du texte,
  de l'auteur, de la conversation et de l'horodatage : la suppression du message ne l'efface pas.

### Conversation IA
- `id`, `personne_id`, `origine` (`assistant` | `dossier` | `documents` | `intranet` | `reunions` | `messages` | `formations`),
  `objet_ref`, `titre`, `tours[]` (question masquée, réponse, citations, version de prompt), `dossier_cree_id`, `cree_le`, `maj_le`.
- Privée à l'utilisateur. Rétention proposée : 12 mois, purge à la fin de mandat.

### Élément de mémoire de l'assistant
- `id`, `personne_id`, `categorie` (`mandat` | `textes` | `redaction` | `sujets`), `texte` (anonymisé), `actif`, `source` (`manuel` | `memoriser`), `cree_le`.
- Injecté dans chaque appel IA de l'utilisateur, **jamais cité comme source juridique**.
- Interrupteur global `memoire_active` par personne.

### Formations
- **Formation du catalogue** : `id`, `catalogue` (`ia` | `generaliste`), `thematique`, `type`, `titre`, `duree`, `public`,
  `objectifs[]`, `description`, `modalite` (`INTER` | `INTRA` | `INTER_INTRA`), `obligatoire`, `agrement` (organisme, numéro, échéance), `publie`.
  Contenu administrable par l'éditeur, pas en dur.
- **Parcours recommandé** : `niveau` (Élu 1.0 à 4.0), `formations[]`.
- **Demande de session** : `formation_id`, `demandeur_id`, `statut` (`envoyee` | `acceptee` | `refusee` | `planifiee`), `commentaire`, `evenement_agenda_id`.
- **Session unii** : `id`, `personne_id`, `theme`, `duree_min` (15 | 30 | 60 | 120 | 180), `niveau`, `role`, `objectif`,
  `version_prompt`, `modules[]` (titre, minutes, objectif, points, exemple, exercice, quiz), `module_courant`,
  `modules_termines[]`, `reponses_quiz{}`, `exercices{}` et `retours{}` (chiffrés), `questions[]`, `terminee_le`, `genere_localement` (repli).
- **Attestation de suivi** : `session_id`, `emise_le`, `empreinte`. Mention obligatoire : sans valeur de formation agréée.

### Préférences d'interface
- `menu_reduit`, `theme`, `ordre_navigation`, `raccourcis`. Seules données admises en stockage local.

### Rétention — compléments v3
| Entité | Conservation |
|---|---|
| Message de groupe ou direct | durée du mandat + 12 mois, sauf versement en dossier |
| Envoi aux adhérents | 3 ans (preuve d'information), contenu et nombre de destinataires |
| Conversation IA | 12 mois glissants |
| Mémoire de l'assistant | jusqu'à suppression par l'utilisateur ou fin de mandat |
| Session unii | 24 mois ; attestations 5 ans |
| Demande de session | 3 ans |

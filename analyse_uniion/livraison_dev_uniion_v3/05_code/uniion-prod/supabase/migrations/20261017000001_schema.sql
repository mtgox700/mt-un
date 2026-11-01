-- uniion — migration 1/7 : schéma de référence
-- Source : design_handoff_uniion/schema/uniion.sql (5 sept. 2026), sans la section RLS.
-- La RLS est réécrite pour Supabase dans 20261017000004_grants_rls.sql (claims JWT au lieu de
-- current_setting('uniion.*')) et corrige un défaut du fichier d'origine : la politique
-- « dossier_par_organisation » étant permissive, elle s'additionnait à « dossier_par_perimetre » et
-- ouvrait TOUS les dossiers de l'organisation à tout membre.
-- pgcrypto est installé par Supabase dans le schéma « extensions ».

-- uniion — schéma de référence
-- Version 1 — 5 septembre 2026. PostgreSQL 15+.
-- Source de vérité du modèle décrit dans MODELE_DONNEES.md.
--
-- Principes appliqués partout :
--   * identifiants texte préfixés, générés applicativement (jamais séquentiels, jamais devinables) ;
--   * organisation_id sur toute table métier + politique de sécurité par ligne (RLS) : le
--     cloisonnement entre organisations est une contrainte de base, pas une condition applicative ;
--   * version integer pour la concurrence optimiste (If-Match) ;
--   * cree_le / modifie_le / supprime_le : la suppression est logique, purge à 30 jours ;
--   * les colonnes d'article 9 et les pièces jointes sont chiffrées applicativement (bytea), avec
--     une clé par organisation distincte de la clé de sauvegarde.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- types
create type org_type          as enum ('cse', 'section', 'ud');
create type role_membre       as enum ('militant', 'communication', 'tresorier', 'admin');
create type dossier_statut    as enum ('todo', 'doing', 'done');
create type niveau_masquage   as enum ('aucun', 'partiel', 'strict');
create type surface_ia        as enum ('assistant', 'dossier', 'document', 'page', 'compte_rendu');
create type refus_ia          as enum ('meta_question', 'masquage_incomplet', 'quota');
create type statut_cotisation as enum ('a_jour', 'en_retard', 'exonere');
create type type_liste        as enum ('dyn', 'fixe');
create type visibilite_evt    as enum ('section', 'bureau', 'prive');
create type reponse_invite    as enum ('en_attente', 'accepte', 'refuse');
create type site_id           as enum ('intranet', 'public');
create type page_statut       as enum ('brouillon', 'relue', 'en_attente_webmaster', 'publiee', 'retournee');
create type doc_statut        as enum ('brouillon', 'relu', 'signe', 'diffuse');
create type sondage_statut    as enum ('brouillon', 'en_validation', 'valide', 'diffuse', 'clos');
create type etat_tache        as enum ('en_attente', 'en_cours', 'termine', 'echec_definitif');
create type etat_envoi        as enum ('en_attente', 'envoye', 'echec', 'desinscrit');

-- ---------------------------------------------------------------- socle
create table organisation (
  id                text primary key,                    -- org_…
  nom               text not null,
  sigle             text not null,
  type              org_type not null,                   -- pilote vocabulaire, cotisations, agenda
  idcc              text,
  adresse           text,
  email             text,
  sieges_souscrits  integer not null default 0,
  echeance_facture  date,
  seed_version      integer not null default 0,          -- réconciliation du jeu de démonstration
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  version           integer not null default 1
);
comment on column organisation.type is
  'Non modifiable par l''utilisateur final : change la base légale des traitements. Migration explicite.';

create table etablissement (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  libelle           text not null,
  unique (organisation_id, libelle)
);

create table personne (
  id                text primary key,                    -- per_…
  organisation_id   text not null references organisation on delete cascade,
  prenom            text not null,
  nom               text not null,
  email             text not null,
  telephone         text,
  mandat            text,                                -- « Déléguée syndicale · secrétaire de section »
  mandat_debut      date,
  mandat_fin        date,                                -- pilote la révocation à 24 h
  etablissement_id  text references etablissement,
  formation_sst     boolean not null default false,
  coord_visibles    boolean not null default true,
  mfa_actif         boolean not null default false,
  desactive_le      timestamptz,
  anonymise_le      timestamptz,
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  version           integer not null default 1,
  unique (organisation_id, email)
);

create table personne_role (
  personne_id       text not null references personne on delete cascade,
  role              role_membre not null,
  attribue_par      text references personne,
  attribue_le       timestamptz not null default now(),
  primary key (personne_id, role)
);

create table appareil (
  id                text primary key,
  personne_id       text not null references personne on delete cascade,
  libelle           text,                                -- « iPhone 15 — Valenciennes »
  cle_publique      bytea,                               -- messagerie chiffrée bout en bout
  derniere_activite timestamptz,
  revoque_le        timestamptz
);

create table session (
  id                text primary key,
  personne_id       text not null references personne on delete cascade,
  appareil_id       text references appareil on delete cascade,
  expire_le         timestamptz not null,
  invalidee_le      timestamptz
);

-- ---------------------------------------------------------------- dossiers
create table dossier (
  id                text primary key,                    -- dos_…
  organisation_id   text not null references organisation on delete cascade,
  intitule          text not null,
  categorie         text not null,
  description       text,
  detail_chiffre    bytea,                               -- art. 9 (santé au travail) : chiffré
  statut            dossier_statut not null default 'todo',
  echeance          date,
  referent_id       text not null references personne,
  etablissement_id  text references etablissement,
  niveau_masquage   niveau_masquage not null default 'partiel',
  clos_le           timestamptz,
  contentieux       boolean not null default false,       -- rétention 10 ans au lieu de 5
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  supprime_le       timestamptz,
  version           integer not null default 1
);
create index on dossier (organisation_id, statut) where supprime_le is null;

-- Périmètre d'accès : le référent + les personnes explicitement ajoutées. Aucun rôle ne donne
-- accès à l'ensemble des dossiers (AUTORISATIONS.md §3.1).
create table dossier_acces (
  dossier_id        text not null references dossier on delete cascade,
  personne_id       text not null references personne on delete cascade,
  ajoute_par        text references personne,
  ajoute_le         timestamptz not null default now(),
  primary key (dossier_id, personne_id)
);

create table dossier_historique (
  id                text primary key,
  dossier_id        text not null references dossier on delete cascade,
  titre             text not null,
  corps             text,
  auteur_id         text not null references personne,
  cree_le           timestamptz not null default now()
);
comment on table dossier_historique is 'Ajout seul : pas de UPDATE, pas de DELETE.';

create table dossier_note (
  id                text primary key,
  dossier_id        text not null references dossier on delete cascade,
  texte_chiffre     bytea not null,
  auteur_id         text not null references personne,
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  version           integer not null default 1
);

create table piece_jointe (
  id                text primary key,
  dossier_id        text not null references dossier on delete cascade,
  nom               text not null,
  type_mime         text not null,
  taille_octets     bigint not null check (taille_octets <= 80 * 1024 * 1024),
  empreinte         text not null,                       -- sha-256
  chemin_chiffre    text not null,
  antivirus_ok      boolean not null default false,      -- indisponible au téléchargement si faux
  depose_par        text not null references personne,
  cree_le           timestamptz not null default now(),
  supprime_le       timestamptz
);

create table piece_acces_log (
  id                bigserial primary key,
  piece_id          text not null references piece_jointe on delete cascade,
  personne_id       text not null references personne,
  action            text not null,                       -- 'lecture' | 'telechargement'
  horodatage        timestamptz not null default now()
);

-- ---------------------------------------------------------------- assistant IA
-- Aucun contenu en clair : ni question, ni réponse. Métadonnées seulement.
create table requete_ia (
  id                text primary key,                    -- air_…
  organisation_id   text not null references organisation on delete cascade,
  personne_id       text not null references personne,
  surface           surface_ia not null,
  dossier_id        text references dossier,
  empreinte_requete text not null,
  niveau_masquage   niveau_masquage not null,
  entites_masquees  integer not null default 0,
  residuel_types    text[] not null default '{}',        -- types détectés, jamais les valeurs
  refus             refus_ia,
  prompt_version    text not null,
  corpus_version    text not null,
  modele_alias      text not null,
  jetons_entree     integer, jetons_sortie integer,
  cout_centimes     integer,
  latence_ms        integer,
  succes            boolean not null,
  cree_le           timestamptz not null default now()
);
create index on requete_ia (organisation_id, cree_le desc);

create table ia_citation (
  id                bigserial primary key,
  requete_id        text not null references requete_ia on delete cascade,
  reference         text not null,                       -- « C. trav., art. L2312-8 »
  libelle           text,
  url               text,
  confiance         numeric(3,2)
);

-- Conversation liée à un dossier : contenu conservé (l'utilisateur la relit), chiffré, 2 ans.
create table dossier_conversation (
  id                text primary key,
  dossier_id        text not null references dossier on delete cascade,
  role              text not null check (role in ('user', 'assistant')),
  texte_chiffre     bytea not null,
  source            text,
  requete_id        text references requete_ia,
  cree_le           timestamptz not null default now()
);

-- ---------------------------------------------------------------- adhérents (article 9)
create table adherent (
  id                text primary key,                    -- adh_…
  organisation_id   text not null references organisation on delete cascade,
  prenom            text not null,
  nom               text not null,
  email             text,
  telephone         text,
  emploi            text,
  entreprise        text,
  etablissement_id  text references etablissement,
  section           text,
  direction         text,
  date_adhesion     date,
  date_fin_adhesion date,                                -- déclenche la rétention à 3 ans
  mode_reglement    text,
  montant_cotisation numeric(8,2),
  statut_cotisation statut_cotisation not null default 'a_jour',
  consentement_contact boolean not null default false,
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  supprime_le       timestamptz,
  version           integer not null default 1
);
comment on table adherent is
  'Appartenance syndicale : donnée de l''article 9 RGPD. Accès restreint au rôle tresorier, toute
   lecture nominative inscrite au journal d''audit. Chiffrement au repos par clé d''organisation.';
create index on adherent (organisation_id, statut_cotisation) where supprime_le is null;
create index on adherent (organisation_id, nom, prenom) where supprime_le is null;

create table cotisation (
  id                text primary key,
  adherent_id       text not null references adherent on delete cascade,
  periode           text not null,                       -- '2026' | '2026-T3'
  montant           numeric(8,2) not null,
  mode              text,
  encaisse_le       date,
  piece_justificative text,
  saisi_par         text references personne,            -- traçabilité de la saisie trésorier
  cree_le           timestamptz not null default now(),
  unique (adherent_id, periode)
);

create table attestation_fiscale (
  id                text primary key,
  adherent_id       text not null references adherent on delete cascade,
  annee             integer not null,
  montant_total     numeric(8,2) not null,
  emise_le          date not null,
  unique (adherent_id, annee)
);

create table liste_diffusion (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  libelle           text not null,
  type              type_liste not null,
  description       text,
  canal             text not null,
  criteres          jsonb not null default '{}',         -- ET entre critères, OU dans un critère
  recalcul_planifie text,                                -- expression cron
  dernier_recalcul  timestamptz,
  effectif_dernier  integer,
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  supprime_le       timestamptz,
  version           integer not null default 1
);
comment on column liste_diffusion.criteres is
  'Recalcul serveur planifié : une liste dynamique n''est jamais figée à sa création.';

create table liste_membre_fixe (
  liste_id          text not null references liste_diffusion on delete cascade,
  adherent_id       text not null references adherent on delete cascade,
  primary key (liste_id, adherent_id)
);

create table campagne (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  liste_id          text references liste_diffusion,
  modele            text,
  objet             text not null,
  corps             text not null,
  canal             text not null,
  planifiee_le      timestamptz,
  creee_par         text not null references personne,
  cree_le           timestamptz not null default now()
);

create table campagne_envoi (
  id                bigserial primary key,
  campagne_id       text not null references campagne on delete cascade,
  adherent_id       text not null references adherent on delete cascade,
  etat              etat_envoi not null default 'en_attente',
  tentatives        integer not null default 0,
  derniere_erreur   text,
  envoye_le         timestamptz
);

create table desinscription (
  id                bigserial primary key,
  organisation_id   text not null references organisation on delete cascade,
  email_empreinte   text not null,                       -- témoin de refus, sans l'adresse en clair
  canal             text not null,
  demande_le        timestamptz not null default now(),
  unique (organisation_id, email_empreinte, canal)
);

create table import_adherents (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  fichier_nom       text not null,
  encodage          text,
  separateur        text,
  lignes_total      integer not null,
  lignes_valides    integer not null,
  lignes_rejetees   integer not null,
  rapport           jsonb not null default '[]',         -- motif par ligne
  lance_par         text not null references personne,
  cree_le           timestamptz not null default now()
);

-- ---------------------------------------------------------------- agenda
create table evenement (
  id                text primary key,                    -- evt_…
  organisation_id   text not null references organisation on delete cascade,
  titre             text not null,
  type              text not null,                       -- dépend de organisation.type
  debut             timestamptz not null,
  fin               timestamptz not null,
  journee_entiere   boolean not null default false,
  lieu              text,
  description       text,
  createur_id       text not null references personne,
  visibilite        visibilite_evt not null default 'section',
  recurrence        text,                                -- RRULE (RFC 5545)
  serie_id          text,
  occurrence_exclue timestamptz[],
  dossier_id        text references dossier,
  reunion_id        text,
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  supprime_le       timestamptz,
  version           integer not null default 1,
  check (fin >= debut)
);
create index on evenement (organisation_id, debut) where supprime_le is null;
comment on column evenement.visibilite is
  'Filtrée côté serveur à la LECTURE : un événement « bureau » ne doit jamais transiter vers un
   client non habilité, même masqué à l''affichage.';

create table evenement_participant (
  evenement_id      text not null references evenement on delete cascade,
  personne_id       text references personne on delete cascade,
  email_externe     text,
  reponse           reponse_invite not null default 'en_attente',
  role              text not null default 'participant',
  check (personne_id is not null or email_externe is not null)
);

create table evenement_rappel (
  id                bigserial primary key,
  evenement_id      text not null references evenement on delete cascade,
  delai_minutes     integer not null,
  canal             text not null,
  etat              etat_tache not null default 'en_attente',
  envoye_le         timestamptz
);

-- ---------------------------------------------------------------- sites
create table site_charte (
  organisation_id   text not null references organisation on delete cascade,
  site              site_id not null,
  hote              text not null,
  indexable         boolean not null default false,
  auth_requise      boolean not null default true,
  herite_identite   boolean not null default true,
  accent            text,
  couleur_entete    text,
  police_titre      text,
  largeur_contenu   integer not null default 760,
  navigation        text not null default 'inline',      -- 'inline' | 'bandeau'
  angles            text not null default 'doux',        -- 'net' | 'doux' | 'rond'
  logo_affiche      boolean not null default true,
  logo_src          text,
  logo_echelle      integer not null default 100 check (logo_echelle between 60 and 300),
  modifie_le        timestamptz not null default now(),
  version           integer not null default 1,
  primary key (organisation_id, site)
);

create table rubrique (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  site              site_id not null,
  libelle           text not null,
  chemin            text not null,
  ordre             integer not null default 0,
  description       text
);

create table page (
  id                text primary key,                    -- pag_…
  organisation_id   text not null references organisation on delete cascade,
  site              site_id not null,
  rubrique_id       text references rubrique,
  titre             text not null,
  slug              text not null,
  chapo             text,
  blocs             jsonb not null default '[]',
  html_assaini     text,                                 -- produit par le serveur, liste blanche
  statut            page_statut not null default 'brouillon',
  auteur_id         text not null references personne,
  relecteur_id      text references personne,            -- doit différer de auteur_id
  relecture_note    text,
  relecture_le      timestamptz,
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  depubliee_le      timestamptz,
  supprime_le       timestamptz,
  version           integer not null default 1,
  unique (organisation_id, site, slug),
  check (relecteur_id is null or relecteur_id <> auteur_id)
);

create table demande_publication (
  id                text primary key,                    -- PUB-2026-0xx
  page_id           text not null references page on delete cascade,
  date_mise_en_ligne date,
  visibilite        text,
  message           text,
  retour_webmaster  text,
  transmise_le      timestamptz not null default now(),
  publiee_le        timestamptz
);

-- ---------------------------------------------------------------- documents, sondages, réunions
create table document (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  titre             text not null,
  gabarit           text not null,
  format            text not null default 'A4',
  statut            doc_statut not null default 'brouillon',
  blocs             jsonb not null default '[]',
  auteur_id         text not null references personne,
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now(),
  supprime_le       timestamptz,
  version           integer not null default 1
);

create table signature (
  id                text primary key,
  document_id       text not null references document on delete cascade,
  signataire_id     text not null references personne,
  prestataire       text not null,                       -- eIDAS
  horodatage_jeton  text not null,
  pdf_scelle        text not null,
  signe_le          timestamptz not null default now()
);

create table sondage (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  titre             text not null,
  type              text not null,
  options           jsonb not null default '[]',
  cible             text,
  cloture_le        timestamptz,
  statut            sondage_statut not null default 'brouillon',
  auteur_id         text not null references personne,
  validateur_id     text references personne,            -- doit différer de auteur_id
  cree_le           timestamptz not null default now(),
  version           integer not null default 1,
  check (validateur_id is null or validateur_id <> auteur_id)
);

-- Anonyme par construction : aucun lien vers une personne, jamais.
create table sondage_reponse (
  id                bigserial primary key,
  sondage_id        text not null references sondage on delete cascade,
  valeur            jsonb not null,
  recue_le          timestamptz not null default now()
);

create table reunion (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  type              text not null,
  date_seance       timestamptz not null,
  participants      jsonb not null default '[]',
  audio_chemin      text,                                -- purge automatique à 90 jours
  audio_supprime_le timestamptz,
  transcription     text,
  compte_rendu      text,
  approuve_le       timestamptz,
  cree_le           timestamptz not null default now(),
  version           integer not null default 1
);

-- ---------------------------------------------------------------- messagerie (E2E)
create table fil (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  sujet             text,
  cree_le           timestamptz not null default now()
);

create table fil_participant (
  fil_id            text not null references fil on delete cascade,
  personne_id       text not null references personne on delete cascade,
  primary key (fil_id, personne_id)
);

-- Le serveur stocke un blob qu'il ne peut pas lire : aucun rôle, y compris admin, ne déchiffre.
create table message (
  id                text primary key,
  fil_id            text not null references fil on delete cascade,
  auteur_id         text not null references personne,
  charge_chiffree   bytea not null,
  cles_destinataires jsonb not null,                     -- clé de contenu chiffrée par appareil
  envoye_le         timestamptz not null default now(),
  lu_par            jsonb not null default '{}'
);

-- ---------------------------------------------------------------- transverse
create table notification (
  id                text primary key,
  organisation_id   text not null references organisation on delete cascade,
  personne_id       text not null references personne on delete cascade,
  type              text not null,
  urgence           text,
  charge            jsonb not null default '{}',
  lu_le             timestamptz,
  cree_le           timestamptz not null default now()
);

-- Ajout seul. Empreinte chaînée : toute altération d'une ligne casse la chaîne.
create table audit (
  id                bigserial primary key,
  organisation_id   text not null references organisation on delete cascade,
  acteur_id         text references personne,
  acteur_role       role_membre,
  action            text not null,
  ressource_type    text not null,
  ressource_id      text,
  motif             text,
  article_9         boolean not null default false,
  appareil          text,
  ip_tronquee       inet,
  trace_requete     text,
  empreinte_prec    text,
  empreinte         text not null,
  horodatage        timestamptz not null default now()
);
create index on audit (organisation_id, horodatage desc);
create index on audit (organisation_id, article_9) where article_9;
revoke update, delete on audit from public;

create table tache_file (
  id                text primary key,
  organisation_id   text references organisation on delete cascade,
  nature            text not null,                       -- 'email' | 'export' | 'ia' | 'ics' | 'retention'
  charge            jsonb not null default '{}',
  etat              etat_tache not null default 'en_attente',
  tentatives        integer not null default 0,
  prochaine_tentative timestamptz,
  derniere_erreur   text,
  idempotency_key   text unique,
  cree_le           timestamptz not null default now()
);

-- Journal d'exécution des purges : une durée de conservation non exécutée n'est pas une durée.
create table execution_retention (
  id                bigserial primary key,
  entite            text not null,
  lignes_traitees   integer not null,
  lignes_supprimees integer not null,
  lignes_anonymisees integer not null,
  execute_le        timestamptz not null default now(),
  duree_ms          integer
);

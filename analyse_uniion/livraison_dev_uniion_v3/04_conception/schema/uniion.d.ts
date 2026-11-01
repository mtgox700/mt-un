// uniion — types partagés client / serveur
// Version 1 — 5 septembre 2026. Miroir de schema/uniion.sql (source de vérité).
// Aucune donnée d'article 9 ne doit apparaître dans un type exposé à un rôle non habilité :
// les listes d'adhérents sont typées séparément des agrégats (voir AdherentAgrege).

export type OrgType = 'cse' | 'section' | 'ud';
export type RoleMembre = 'militant' | 'communication' | 'tresorier' | 'admin';
export type DossierStatut = 'todo' | 'doing' | 'done';
export type NiveauMasquage = 'aucun' | 'partiel' | 'strict';
export type SurfaceIA = 'assistant' | 'dossier' | 'document' | 'page' | 'compte_rendu';
export type RefusIA = 'meta_question' | 'masquage_incomplet' | 'quota';
export type StatutCotisation = 'a_jour' | 'en_retard' | 'exonere';
export type VisibiliteEvt = 'section' | 'bureau' | 'prive';
export type SiteId = 'intranet' | 'public';
export type PageStatut = 'brouillon' | 'relue' | 'en_attente_webmaster' | 'publiee' | 'retournee';
export type DocStatut = 'brouillon' | 'relu' | 'signe' | 'diffuse';
export type SondageStatut = 'brouillon' | 'en_validation' | 'valide' | 'diffuse' | 'clos';
export type EtatTache = 'en_attente' | 'en_cours' | 'termine' | 'echec_definitif';
export type EtatEnvoi = 'en_attente' | 'envoye' | 'echec' | 'desinscrit';

/** Champs présents sur toute ressource modifiable. `version` alimente l'en-tête If-Match. */
export interface Base {
  id: string;
  cree_le: string;
  modifie_le: string;
  supprime_le?: string | null;
  version: number;
}

export interface Organisation extends Base {
  nom: string;
  sigle: string;
  /** Non modifiable par l'utilisateur final : change la base légale des traitements. */
  type: OrgType;
  idcc?: string;
  adresse?: string;
  email?: string;
  sieges_souscrits: number;
  echeance_facture?: string;
}

export interface Personne extends Base {
  organisation_id: string;
  prenom: string;
  nom: string;
  email: string;
  telephone?: string;
  mandat?: string;
  mandat_debut?: string;
  mandat_fin?: string;
  etablissement_id?: string;
  roles: RoleMembre[];
  formation_sst: boolean;
  coord_visibles: boolean;
  mfa_actif: boolean;
  desactive_le?: string | null;
}

export interface Dossier extends Base {
  organisation_id: string;
  intitule: string;
  categorie: string;
  description?: string;
  statut: DossierStatut;
  echeance?: string;
  referent_id: string;
  etablissement_id?: string;
  niveau_masquage: NiveauMasquage;
  clos_le?: string | null;
  contentieux: boolean;
  /** Renvoyé uniquement aux personnes du périmètre du dossier. */
  acces?: string[];
}

export interface DossierHistorique {
  id: string;
  dossier_id: string;
  titre: string;
  corps?: string;
  auteur_id: string;
  cree_le: string;
}

export interface PieceJointe {
  id: string;
  dossier_id: string;
  nom: string;
  type_mime: string;
  taille_octets: number;
  empreinte: string;
  /** Faux ⇒ non téléchargeable : analyse antivirus en cours. */
  antivirus_ok: boolean;
  depose_par: string;
  cree_le: string;
}

/** Article 9 RGPD. Type réservé aux réponses adressées au rôle `tresorier`. */
export interface Adherent extends Base {
  organisation_id: string;
  prenom: string;
  nom: string;
  email?: string;
  telephone?: string;
  emploi?: string;
  entreprise?: string;
  etablissement_id?: string;
  section?: string;
  direction?: string;
  date_adhesion?: string;
  date_fin_adhesion?: string | null;
  mode_reglement?: string;
  montant_cotisation?: number;
  statut_cotisation: StatutCotisation;
  consentement_contact: boolean;
}

/** Ce que reçoit un rôle non habilité : des effectifs, jamais des personnes. */
export interface AdherentAgrege {
  effectif_total: number;
  par_etablissement: Record<string, number>;
  par_statut: Record<StatutCotisation, number>;
  /** Absent si l'effectif concerné est inférieur à 5 (réidentification). */
  taux_a_jour?: number;
}

export interface CriteresListe {
  etablissement?: string[];
  section?: string[];
  direction?: string[];
  statut_cotisation?: StatutCotisation[];
  date_adhesion_avant?: string;
  date_adhesion_apres?: string;
  mandat?: string[];
}

export interface ListeDiffusion extends Base {
  organisation_id: string;
  libelle: string;
  type: 'dyn' | 'fixe';
  description?: string;
  canal: string;
  criteres: CriteresListe;
  recalcul_planifie?: string;
  dernier_recalcul?: string;
  effectif_dernier?: number;
  /** Jamais renvoyé au rôle `communication` : il cible une liste sans en voir les membres. */
  membres?: string[];
}

export interface Evenement extends Base {
  organisation_id: string;
  titre: string;
  type: string;
  debut: string;
  fin: string;
  journee_entiere: boolean;
  lieu?: string;
  description?: string;
  createur_id: string;
  /** Filtrée côté serveur à la lecture. */
  visibilite: VisibiliteEvt;
  recurrence?: string;
  serie_id?: string;
  occurrence_exclue?: string[];
  dossier_id?: string;
  reunion_id?: string;
  participants?: EvenementParticipant[];
}

export interface EvenementParticipant {
  personne_id?: string;
  email_externe?: string;
  reponse: 'en_attente' | 'accepte' | 'refuse';
  role: 'organisateur' | 'participant' | 'informe';
}

export interface SiteCharte {
  organisation_id: string;
  site: SiteId;
  hote: string;
  indexable: boolean;
  auth_requise: boolean;
  /** Vrai : accent, couleur d'en-tête et police dérivent de l'identité de l'organisation. */
  herite_identite: boolean;
  accent?: string;
  couleur_entete?: string;
  police_titre?: string;
  largeur_contenu: number;
  navigation: 'inline' | 'bandeau';
  angles: 'net' | 'doux' | 'rond';
  logo_affiche: boolean;
  logo_src?: string;
  /** 60 à 300 %. */
  logo_echelle: number;
  version: number;
}

export type BlocPage =
  | { id: string; t: 'p' | 'h2' | 'callout'; text: string }
  | { id: string; t: 'list'; items: string[] }
  | { id: string; t: 'cta'; text: string; href: string }
  | { id: string; t: 'file'; text: string }
  | { id: string; t: 'img'; text: string };

export interface Page extends Base {
  organisation_id: string;
  site: SiteId;
  rubrique_id?: string;
  titre: string;
  slug: string;
  chapo?: string;
  blocs: BlocPage[];
  /** Produit par le serveur : liste blanche de balises et d'attributs. */
  html_assaini?: string;
  statut: PageStatut;
  auteur_id: string;
  /** Doit différer de `auteur_id` : la relecture par un pair est une règle serveur. */
  relecteur_id?: string;
  relecture_note?: string;
  relecture_le?: string;
}

// ---------------------------------------------------------------- API

export interface Page_<T> {
  data: T[];
  page: { next?: string | null; count: number; total_estime?: number };
}

export type CodeErreur =
  | 'champ_invalide' | 'csv_malforme' | 'masquage_incomplet'
  | 'session_expiree' | 'mfa_requis'
  | 'role_insuffisant' | 'donnee_article_9' | 'validation_par_pair_requise'
  | 'introuvable' | 'conflit_version' | 'doublon'
  | 'fichier_trop_lourd' | 'regle_metier'
  | 'quota_ia_atteint' | 'trop_de_requetes'
  | 'ia_indisponible' | 'maintenance';

export interface Erreur {
  erreur: {
    code: CodeErreur;
    message: string;
    details?: Record<string, unknown>;
    trace: string;
  };
}

export interface DemandeIA {
  surface: SurfaceIA;
  /** Déjà masqué par le client ; le serveur ré-applique son propre masquage. */
  question: string;
  niveau_masquage: NiveauMasquage;
  contexte?: { dossier_id?: string; page_id?: string; reunion_id?: string };
  format: 'texte' | 'json';
  prompt_version: string;
}

export interface ReponseIA {
  reponse: string;
  citations: Array<{
    reference: string;
    libelle?: string;
    url?: string;
    extrait?: string;
    confiance?: number;
  }>;
  masquage: {
    niveau: NiveauMasquage;
    entites_masquees: number;
    /** Types détectés uniquement, jamais les valeurs. Non vide ⇒ l'appel a été annulé. */
    residuel: string[];
  };
  usage: { jetons_entree: number; jetons_sortie: number; cout_centimes: number };
  modele: { alias: string; prompt_version: string };
  requete_id: string;
}

export interface OperationSync {
  op: 'creation' | 'modification' | 'suppression';
  ressource: string;
  id: string;
  version: number;
  charge: Record<string, unknown>;
}

export interface ResultatSync {
  id: string;
  resultat: 'applique' | 'conflit' | 'refuse';
  /** Présent si `conflit` : version serveur à comparer, jamais appliquée d'office. */
  serveur?: Record<string, unknown>;
  code?: CodeErreur;
}

export type EvenementFlux =
  | { type: 'dossier.maj'; dossier_id: string }
  | { type: 'page.publiee'; page_id: string; site: SiteId }
  | { type: 'agenda.rappel'; evenement_id: string }
  | { type: 'campagne.terminee'; campagne_id: string; envoyes: number; echecs: number }
  | { type: 'ia.quota'; restant: number; reinitialisation: string };

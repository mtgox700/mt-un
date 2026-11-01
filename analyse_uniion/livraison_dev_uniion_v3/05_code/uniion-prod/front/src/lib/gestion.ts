import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from './supabase';

// Appels aux fonctions du schéma « api » : messages d'erreur ramenés à des phrases utiles.
export async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.schema('api').rpc(fn, args);
  if (error) {
    const m = error.message ?? '';
    throw new Error(
      error.code === '40001' ? 'Cette fiche a été modifiée entre-temps. Rechargez-la avant d\'enregistrer.'
      : error.code === '42501' ? (m.includes('double') ? 'Double authentification requise.' : 'Action non autorisée pour votre rôle.')
      : error.code === 'P0002' ? 'Élément introuvable.'
      : error.code === '22023' ? m.charAt(0).toUpperCase() + m.slice(1) + '.'
      : 'Opération impossible. Réessayez dans un instant.');
  }
  return data as T;
}

// ---------------------------------------------------------------- adhérents
export type StatutCotisation = 'a_jour' | 'en_retard' | 'exonere';
export const COTISATION: Record<StatutCotisation, { libelle: string; ton: 'ok' | 'danger' | 'neutre' }> = {
  a_jour: { libelle: 'À jour', ton: 'ok' }, en_retard: { libelle: 'En retard', ton: 'danger' }, exonere: { libelle: 'Exonéré', ton: 'neutre' },
};
export interface Adherent {
  id: string; prenom: string; nom: string; email: string | null; telephone: string | null; emploi: string | null; entreprise: string | null;
  etablissement_id: string | null; section: string | null; direction: string | null; date_adhesion: string | null; date_fin_adhesion: string | null;
  mode_reglement: string | null; montant_cotisation: number | null; statut_cotisation: StatutCotisation; consentement_contact: boolean; version: number;
}
export interface Filtres { recherche?: string; statut_cotisation?: StatutCotisation[]; etablissement_id?: string[] }

export const useEtablissements = () => useQuery({
  queryKey: ['etablissements'], staleTime: 300_000,
  queryFn: async () => {
    const { data, error } = await supabase.from('etablissement').select('id, libelle').order('libelle');
    if (error) throw new Error('Lecture impossible.');
    return data as { id: string; libelle: string }[];
  },
});

// Chaque appel est journalisé côté serveur (lecture nominative, article 9) : pas de rafraîchissement automatique.
export const useAdherents = (f: Filtres, limite: number, actif: boolean) => useQuery({
  queryKey: ['adherents', f, limite], enabled: actif, staleTime: Infinity, refetchOnWindowFocus: false, placeholderData: (p) => p,
  queryFn: () => rpc<Adherent[]>('adherents_lister', { p_filtres: f, p_limite: limite, p_decalage: 0 }),
});
export const useAdherent = (id: string | null) => useQuery({
  queryKey: ['adherent', id], enabled: !!id, staleTime: Infinity, refetchOnWindowFocus: false,
  queryFn: () => rpc<Adherent>('adherent_lire', { p_id: id }),
});
export const useAgregats = () => useQuery({
  queryKey: ['adherents-agregats'], refetchOnWindowFocus: false,
  queryFn: () => rpc<{ total: number; par_statut: Record<string, number | null> | null; par_etablissement: Record<string, number | null> | null }>('adherents_agregats'),
});
export function useEnregistrerAdherent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (a: Partial<Adherent>) => rpc<Adherent>('adherent_enregistrer', { p: a }),
    onSuccess: (a) => { qc.setQueryData(['adherent', a.id], a); qc.invalidateQueries({ queryKey: ['adherents'] }); qc.invalidateQueries({ queryKey: ['adherents-agregats'] }); },
  });
}
export function useSupprimerAdherent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, motif }: { id: string; motif: string }) => rpc('adherent_supprimer', { p_id: id, p_motif: motif }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['adherents'] }); qc.invalidateQueries({ queryKey: ['adherents-agregats'] }); },
  });
}

export interface RapportImport { id: string | null; total: number; valides: number; rejetees: number; doublons: number; rapport: { ligne: number; motifs: string[] }[] }
export const importer = (fichier: string, separateur: string, lignes: Record<string, string>[], simuler: boolean) =>
  rpc<RapportImport>('adherents_importer', { p_fichier: fichier, p_separateur: separateur, p_lignes: lignes, p_simuler: simuler });

// ---------------------------------------------------------------- lecture CSV (dans le navigateur)
export const COLONNES_CSV: { k: string; libelle: string; requis: boolean; alias: string[] }[] = [
  { k: 'prenom', libelle: 'Prénom', requis: true, alias: ['prenom', 'firstname'] },
  { k: 'nom', libelle: 'Nom', requis: true, alias: ['nom', 'lastname', 'nomdefamille'] },
  { k: 'email', libelle: 'E-mail', requis: true, alias: ['email', 'mail', 'courriel', 'adressemail', 'adresseemail'] },
  { k: 'telephone', libelle: 'Téléphone', requis: false, alias: ['telephone', 'tel', 'portable', 'mobile'] },
  { k: 'entreprise', libelle: 'Entreprise', requis: true, alias: ['entreprise', 'societe', 'employeur'] },
  { k: 'etablissement', libelle: 'Établissement', requis: true, alias: ['etablissement', 'site'] },
  { k: 'section', libelle: 'Section', requis: false, alias: ['section'] },
  { k: 'direction', libelle: 'Direction', requis: false, alias: ['direction', 'service'] },
  { k: 'emploi', libelle: 'Emploi', requis: false, alias: ['emploi', 'poste', 'fonction', 'emploioccupe'] },
  { k: 'date_adhesion', libelle: "Date d'adhésion", requis: false, alias: ['dateadhesion', 'datedadhesion', 'adhesion'] },
  { k: 'mode_reglement', libelle: 'Mode de règlement', requis: false, alias: ['modereglement', 'modedereglement', 'reglement'] },
  { k: 'montant', libelle: 'Montant', requis: false, alias: ['montant', 'cotisation', 'montantcotisation'] },
  { k: 'consentement', libelle: 'Consentement aux envois (oui/non)', requis: false, alias: ['consentement', 'consentementcontact', 'optin'] },
];
const norm = (s: string) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');

export async function lireCsv(f: File) {
  const octets = await f.arrayBuffer();
  let texte: string, encodage = 'UTF-8';
  try { texte = new TextDecoder('utf-8', { fatal: true }).decode(octets); }
  catch { texte = new TextDecoder('windows-1252').decode(octets); encodage = 'Windows-1252'; }  // export Excel français
  texte = texte.replace(/^\uFEFF/, '');
  const premiere = texte.split(/\r?\n/, 1)[0] ?? '';
  const sep = (premiere.match(/;/g)?.length ?? 0) >= (premiere.match(/,/g)?.length ?? 0) ? ';' : ',';
  const lignes: string[][] = []; let champ = '', ligne: string[] = [], guillemets = false;
  for (let i = 0; i < texte.length; i++) {
    const c = texte[i]!;
    if (guillemets) { if (c === '"') { if (texte[i + 1] === '"') { champ += '"'; i++; } else guillemets = false; } else champ += c; continue; }
    if (c === '"') guillemets = true;
    else if (c === sep) { ligne.push(champ); champ = ''; }
    else if (c === '\n' || c === '\r') { if (c === '\r' && texte[i + 1] === '\n') i++; ligne.push(champ); lignes.push(ligne); ligne = []; champ = ''; }
    else champ += c;
  }
  if (champ || ligne.length) { ligne.push(champ); lignes.push(ligne); }
  const [entete = [], ...corps] = lignes.filter((l) => l.some((x) => x.trim()));
  const carte = entete.map((h) => COLONNES_CSV.find((c) => c.alias.includes(norm(h)))?.k ?? null);
  const reconnues = new Set(carte.filter(Boolean) as string[]);
  return {
    encodage, sep,
    ignorees: entete.filter((_h, i) => !carte[i]),
    manquantes: COLONNES_CSV.filter((c) => c.requis && !reconnues.has(c.k)).map((c) => c.libelle),
    reconnues: COLONNES_CSV.filter((c) => reconnues.has(c.k)).map((c) => c.libelle),
    lignes: corps.map((l) => Object.fromEntries(carte.flatMap((k, i) => (k ? [[k, (l[i] ?? '').trim()]] : [])))) as Record<string, string>[],
  };
}
export function telechargerModele() {
  const csv = COLONNES_CSV.map((c) => c.k).join(';') + '\n' + 'Prénom;Nom;prenom.nom@exemple.fr;06 00 00 00 00;Entreprise SA;Site principal;Section A;Production;Opérateur;01/09/2026;Prélèvement;13,40;oui\n';
  const url = URL.createObjectURL(new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8' }));
  Object.assign(document.createElement('a'), { href: url, download: 'modele-import-adherents.csv' }).click();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

// ---------------------------------------------------------------- membres
export type Role = 'militant' | 'communication' | 'tresorier' | 'admin';
export const ROLES: { id: Role; libelle: string; aide: string }[] = [
  { id: 'militant', libelle: 'Militant', aide: 'Dossiers, agenda, assistant' },
  { id: 'communication', libelle: 'Communication', aide: 'Tracts, intranet, diffusions' },
  { id: 'tresorier', libelle: 'Trésorier', aide: 'Fichier adhérents · 2 au plus · double authentification' },
  { id: 'admin', libelle: 'Administrateur', aide: 'Membres et réglages · 2 au minimum · double authentification' },
];
export interface Membre { id: string; prenom: string; nom: string; email: string; mandat: string | null; mandat_fin: string | null; bureau: boolean; roles: Role[]; double_auth: boolean; invitation_acceptee: boolean }

export const useMembres = () => useQuery({ queryKey: ['membres'], queryFn: () => rpc<{ sieges: number; membres: Membre[] }>('membres_lister') });
export function useActionMembre() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (corps: Record<string, unknown>) => {
      const { data, error } = await supabase.functions.invoke('membres', { body: corps });
      if (error) {
        const c = await (error as { context?: Response }).context?.json?.().catch(() => null);
        const m: string = c?.erreur ?? 'Action impossible.';
        throw new Error(m.charAt(0).toUpperCase() + m.slice(1) + (m.endsWith('.') ? '' : '.'));
      }
      return data;
    },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['membres'] }); qc.invalidateQueries({ queryKey: ['collegues'] }); },
  });
}

// ---------------------------------------------------------------- réglages
export interface Profil { prenom: string; nom: string; email: string; telephone: string | null; mandat: string | null; mandat_fin: string | null; coord_visibles: boolean }
export const useProfil = () => useQuery({ queryKey: ['profil'], queryFn: () => rpc<Profil>('mon_profil') });
export const useOrganisations = () => useQuery({ queryKey: ['organisations'], queryFn: () => rpc<{ organisation_id: string; nom: string; sigle: string }[]>('mes_organisations') });

export type Theme = 'clair' | 'sombre' | 'systeme';
export function appliquerTheme(t: Theme = (localStorage.getItem('uniion.theme') as Theme) ?? 'systeme') {
  const sombre = t === 'sombre' || (t === 'systeme' && matchMedia('(prefers-color-scheme: dark)').matches);
  document.documentElement.dataset.theme = sombre ? 'dark' : 'light';
  document.documentElement.style.colorScheme = sombre ? 'dark' : 'light';
}

// ---------------------------------------------------------------- trésorerie
export interface Cotisation { id: string; adherent_id: string; periode: string; montant: number; mode: string | null; encaisse_le: string | null; piece_justificative: string | null }
export const useCotisations = (adherent: string | null) => useQuery({
  queryKey: ['cotisations', adherent], enabled: !!adherent, staleTime: Infinity, refetchOnWindowFocus: false,
  queryFn: () => rpc<Cotisation[]>('cotisations_lister', { p_adherent: adherent }),
});
export function useEnregistrerCotisation(adherent: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (c: Partial<Cotisation>) => rpc<Cotisation>('cotisation_enregistrer', { p: { ...c, adherent_id: adherent } }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['cotisations', adherent] }); qc.invalidateQueries({ queryKey: ['tresorerie'] }); },
  });
}
export function useSupprimerCotisation(adherent: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, motif }: { id: string; motif: string }) => rpc('cotisation_supprimer', { p_id: id, p_motif: motif }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['cotisations', adherent] }); qc.invalidateQueries({ queryKey: ['tresorerie'] }); },
  });
}
export const useSynthese = (annee: number) => useQuery({
  queryKey: ['tresorerie', annee], refetchOnWindowFocus: false,
  queryFn: () => rpc<{ encaisse: number; cotisants: number; en_retard: number; attestations: number }>('tresorerie_synthese', { p_annee: annee }),
});
export interface Attestation { prenom: string; nom: string; annee: number; montant: number; emise_le: string; organisation: string; sigle: string; adresse: string | null }
export const lireAttestation = (adherent: string, annee: number) => rpc<Attestation>('attestation_lire', { p_adherent: adherent, p_annee: annee });
export const euros = (n: number) => n.toLocaleString('fr-FR', { style: 'currency', currency: 'EUR' });

// ---------------------------------------------------------------- diffusions
export interface Liste { id: string; libelle: string; type: 'dyn' | 'fixe'; description: string | null; canal: string; criteres: Record<string, string[]>; dernier_recalcul: string | null }
export interface Campagne { id: string; liste_id: string | null; objet: string; corps: string; canal: string; planifiee_le: string | null; creee_par: string; cree_le: string }
export const useListes = () => useQuery({ queryKey: ['listes'], queryFn: async () => {
  const { data, error } = await supabase.from('liste_diffusion').select('id, libelle, type, description, canal, criteres, dernier_recalcul').is('supprime_le', null).order('libelle');
  if (error) throw new Error('Listes indisponibles.');
  return data as Liste[];
} });
export const useEffectif = (liste: string | null) => useQuery({ queryKey: ['effectif', liste], enabled: !!liste, queryFn: () => rpc<number | null>('liste_effectif', { p_liste: liste }) });
export const useCriteres = () => useQuery({ queryKey: ['criteres'], staleTime: 300_000, queryFn: () => rpc<{ section: string[]; direction: string[] }>('criteres_disponibles') });
export function useCreerListe() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (l: Pick<Liste, 'libelle' | 'criteres' | 'description'>) => {
      const { data, error } = await supabase.from('liste_diffusion').insert({ ...l, type: 'dyn', canal: 'email' }).select('id').single();
      if (error) throw new Error('Création réservée au trésorier (double authentification).');
      return data.id as string;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['listes'] }),
  });
}
export const useCampagnes = () => useQuery({ queryKey: ['campagnes'], queryFn: async () => {
  const { data, error } = await supabase.from('campagne').select('id, liste_id, objet, corps, canal, planifiee_le, creee_par, cree_le').order('cree_le', { ascending: false });
  if (error) throw new Error('Campagnes indisponibles.');
  return data as Campagne[];
} });
export const useSuivi = (campagne: string) => useQuery({ queryKey: ['suivi', campagne], refetchInterval: 20_000, queryFn: () => rpc<Record<string, number> | null>('campagne_suivi', { p_campagne: campagne }) });
export function useCreerCampagne() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (c: Pick<Campagne, 'liste_id' | 'objet' | 'corps' | 'planifiee_le'>) => {
      const { data, error } = await supabase.from('campagne').insert({ ...c, canal: 'email' }).select('id').single();
      if (error) throw new Error('Création impossible.');
      return data.id as string;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['campagnes'] }),
  });
}
export function useLancerCampagne() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => rpc<number>('campagne_envoyer', { p_campagne: id }),
    onSuccess: (_n, id) => { qc.invalidateQueries({ queryKey: ['suivi', id] }); qc.invalidateQueries({ queryKey: ['listes'] }); },
  });
}

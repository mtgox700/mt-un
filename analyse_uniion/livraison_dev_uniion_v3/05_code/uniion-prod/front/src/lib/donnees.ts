import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from './supabase';

export type Statut = 'todo' | 'doing' | 'done';
export const STATUTS: { id: Statut; libelle: string; pastille: string }[] = [
  { id: 'todo', libelle: 'À traiter', pastille: 'var(--danger2)' },
  { id: 'doing', libelle: 'En cours', pastille: 'var(--ac)' },
  { id: 'done', libelle: 'Terminé', pastille: 'var(--ok)' },
];
export const CATEGORIES = ['Juridique', 'Harcèlement', 'CSSCT', 'Négociation', 'ASC', 'Formation', 'Autre'];

export interface Personne { id: string; prenom: string; nom: string; mandat?: string | null }
export interface Dossier {
  id: string; intitule: string; categorie: string; description: string | null; statut: Statut; echeance: string | null;
  referent_id: string; niveau_masquage: 'aucun' | 'partiel' | 'strict'; contentieux: boolean; clos_le: string | null;
  modifie_le: string; version: number; referent: Pick<Personne, 'prenom' | 'nom'> | null;
}
export interface Piece { id: string; nom: string; type_mime: string; taille_octets: number; antivirus_ok: boolean; depose_par: string; cree_le: string }
export interface Evenement { id: string; titre: string; corps: string | null; cree_le: string; auteur: Pick<Personne, 'prenom' | 'nom'> | null }
export interface Note { id: string; texte: string; auteur_id: string; cree_le: string }
export interface Tour { id: string; role: 'user' | 'assistant'; texte: string; cree_le: string }

const COLONNES = 'id, intitule, categorie, description, statut, echeance, referent_id, niveau_masquage, contentieux, clos_le, modifie_le, version, referent:referent_id(prenom, nom)';

export class Conflit extends Error { constructor() { super('Ce dossier a été modifié entre-temps par une autre personne. Vos changements n\'ont pas été appliqués ; la version à jour est affichée.'); } }

// Appel d'Edge Function : remonte le message d'erreur du serveur, jamais la trace technique.
export async function appeler<T>(fn: string, body: unknown): Promise<T> {
  const { data, error } = await supabase.functions.invoke(fn, { body: body as Record<string, unknown> });
  if (error) {
    const corps = await (error as { context?: Response }).context?.json?.().catch(() => null);
    throw new Error(corps?.erreur ?? 'Service indisponible. Réessayez dans un instant.');
  }
  return data as T;
}
const verifier = <T,>({ data, error }: { data: T | null; error: { message: string } | null }) => {
  if (error) throw new Error('Lecture impossible.');
  return data as T;
};

// ---------------------------------------------------------------- dossiers
export const useDossiers = () => useQuery({
  queryKey: ['dossiers'],
  queryFn: async () => verifier<Dossier[]>(await supabase.from('dossier').select(COLONNES).is('supprime_le', null)
    .order('echeance', { ascending: true, nullsFirst: false }).order('modifie_le', { ascending: false }) as never),
});

export const useDossier = (id: string) => useQuery({
  queryKey: ['dossier', id],
  queryFn: async () => verifier<Dossier | null>(await supabase.from('dossier').select(COLONNES).eq('id', id).is('supprime_le', null).maybeSingle() as never),
});

export function useCreerDossier() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (d: Pick<Dossier, 'intitule' | 'categorie' | 'description' | 'echeance'>) =>
      verifier<Dossier>(await supabase.from('dossier').insert(d).select(COLONNES).single() as never),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['dossiers'] }),
  });
}

type Modif = Partial<Pick<Dossier, 'intitule' | 'categorie' | 'description' | 'statut' | 'echeance' | 'niveau_masquage' | 'contentieux'>> & { supprime_le?: string };
export function useModifierDossier() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ d, modif }: { d: Dossier; modif: Modif }) => {
      const { data, error } = await supabase.from('dossier').update(modif).eq('id', d.id).eq('version', d.version).select(COLONNES).maybeSingle();
      if (error) throw new Error('Enregistrement impossible.');
      if (!data) throw new Conflit();
      return data as unknown as Dossier;
    },
    onMutate: async ({ d, modif }) => {  // déplacement immédiat sur le tableau
      await qc.cancelQueries({ queryKey: ['dossiers'] });
      const avant = qc.getQueryData<Dossier[]>(['dossiers']);
      qc.setQueryData<Dossier[]>(['dossiers'], (l) => l?.map((x) => (x.id === d.id ? { ...x, ...modif } as Dossier : x)));
      return { avant };
    },
    onError: (_e, _v, ctx) => { if (ctx?.avant) qc.setQueryData(['dossiers'], ctx.avant); },
    onSettled: (_r, _e, { d }) => {
      qc.invalidateQueries({ queryKey: ['dossiers'] });
      qc.invalidateQueries({ queryKey: ['dossier', d.id] });
      qc.invalidateQueries({ queryKey: ['historique', d.id] });
    },
  });
}

export const useHistorique = (id: string) => useQuery({
  queryKey: ['historique', id],
  queryFn: async () => verifier<Evenement[]>(await supabase.from('dossier_historique').select('id, titre, corps, cree_le, auteur:auteur_id(prenom, nom)')
    .eq('dossier_id', id).order('cree_le', { ascending: false }) as never),
});

// ---------------------------------------------------------------- périmètre
export const useAcces = (id: string) => useQuery({
  queryKey: ['acces', id],
  queryFn: async () => verifier<{ personne: Personne }[]>(await supabase.from('dossier_acces').select('personne:personne_id(id, prenom, nom, mandat)').eq('dossier_id', id) as never)
    .map((a) => a.personne),
});
export const useCollegues = (actif: boolean) => useQuery({
  queryKey: ['collegues'], enabled: actif,
  queryFn: async () => verifier<Personne[]>(await supabase.schema('api').from('collegues').select('id, prenom, nom, mandat').order('nom') as never),
});
export function useModifierAcces(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ personneId, ajouter }: { personneId: string; ajouter: boolean }) => {
      const r = ajouter
        ? await supabase.from('dossier_acces').insert({ dossier_id: id, personne_id: personneId })
        : await supabase.from('dossier_acces').delete().eq('dossier_id', id).eq('personne_id', personneId);
      if (r.error) throw new Error('Réservé au référent du dossier.');
    },
    onSettled: () => qc.invalidateQueries({ queryKey: ['acces', id] }),
  });
}

// ---------------------------------------------------------------- contenus chiffrés (Edge Function « coffre »)
export const useDetail = (id: string) => useQuery({ queryKey: ['detail', id], queryFn: () => appeler<{ texte: string }>('coffre', { action: 'detail.lire', dossier_id: id }).then((r) => r.texte) });
export function useEcrireDetail(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (texte: string) => appeler('coffre', { action: 'detail.ecrire', dossier_id: id, texte }),
    onSuccess: (_r, texte) => qc.setQueryData(['detail', id], texte),
  });
}
export const useNotes = (id: string) => useQuery({ queryKey: ['notes', id], queryFn: () => appeler<Note[]>('coffre', { action: 'note.lister', dossier_id: id }) });
export function useAjouterNote(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (texte: string) => appeler('coffre', { action: 'note.ajouter', dossier_id: id, texte }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notes', id] }),
  });
}
export const useConversation = (id: string) => useQuery({ queryKey: ['conversation', id], enabled: !!id, queryFn: () => appeler<Tour[]>('coffre', { action: 'conversation.lister', dossier_id: id }) });
export const verserConversation = (id: string, tours: { role: 'user' | 'assistant'; texte: string }[], requeteId?: string) =>
  appeler('coffre', { action: 'conversation.ajouter', dossier_id: id, tours, requete_id: requeteId });

// ---------------------------------------------------------------- pièces (Edge Function « pieces »)
export const TYPES_ACCEPTES = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'text/plain', 'text/csv',
  'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.oasis.opendocument.text', 'application/vnd.oasis.opendocument.spreadsheet', 'message/rfc822', 'audio/mpeg', 'audio/mp4'];
export const TAILLE_MAX = 80 * 1024 * 1024;

export const usePieces = (id: string) => useQuery({
  queryKey: ['pieces', id],
  queryFn: async () => verifier<Piece[]>(await supabase.from('piece_jointe').select('id, nom, type_mime, taille_octets, antivirus_ok, depose_par, cree_le')
    .eq('dossier_id', id).order('cree_le', { ascending: false }) as never),
  // Pièce en attente d'analyse : on revient voir sans que l'utilisateur recharge.
  refetchInterval: (q) => (q.state.data?.some((p) => !p.antivirus_ok) ? 15_000 : false),
});

export function useDeposerPiece(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (f: File) => {
      if (f.size > TAILLE_MAX) throw new Error(`« ${f.name} » dépasse 80 Mo.`);
      if (!TYPES_ACCEPTES.includes(f.type)) throw new Error(`« ${f.name} » : type de fichier non accepté.`);
      const corps = new FormData(); corps.append('dossier_id', id); corps.append('fichier', f);
      return appeler<{ id: string; antivirus: 'ok' | 'indisponible' }>('pieces', corps);
    },
    onSettled: () => { qc.invalidateQueries({ queryKey: ['pieces', id] }); qc.invalidateQueries({ queryKey: ['historique', id] }); },
  });
}

// Le fichier déchiffré arrive en flux ; il n'existe qu'en mémoire, le temps de l'ouvrir.
export async function ouvrirPiece(p: Piece, mode: 'apercu' | 'telecharger') {
  const recu = await appeler<Blob | string>('pieces', { action: mode, piece_id: p.id });
  const blob = typeof recu === 'string' ? new Blob([recu], { type: p.type_mime }) : recu;  // text/* arrive décodé
  const url = URL.createObjectURL(blob);
  if (mode === 'apercu') window.open(url, '_blank', 'noopener');
  else Object.assign(document.createElement('a'), { href: url, download: p.nom }).click();
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}
export function useSupprimerPiece(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (pieceId: string) => appeler('pieces', { action: 'supprimer', piece_id: pieceId }),
    onSettled: () => qc.invalidateQueries({ queryKey: ['pieces', id] }),
  });
}

// ---------------------------------------------------------------- moi
export const usePersonne = (id: string | null) => useQuery({
  queryKey: ['personne', id], enabled: !!id,
  queryFn: async () => verifier<Personne>(await supabase.from('personne').select('id, prenom, nom, mandat').eq('id', id!).single() as never),
});

// ---------------------------------------------------------------- formats
export const octets = (n: number) => (n < 1024 ? `${n} o` : n < 1048576 ? `${Math.round(n / 1024)} Ko` : `${(n / 1048576).toFixed(1).replace('.', ',')} Mo`);
export const date = (iso: string | null, court = false) => !iso ? '' : new Date(iso).toLocaleDateString('fr-FR', court ? { day: 'numeric', month: 'short' } : { day: 'numeric', month: 'long', year: 'numeric' });
export const heure = (iso: string) => new Date(iso).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
export function echeance(iso: string | null) {
  if (!iso) return { texte: 'Sans échéance', urgent: false };
  const j = Math.round((new Date(iso + 'T00:00:00').getTime() - new Date(new Date().toDateString()).getTime()) / 864e5);
  if (j < 0) return { texte: `En retard de ${-j} j`, urgent: true };
  if (j === 0) return { texte: "Aujourd'hui", urgent: true };
  if (j === 1) return { texte: 'Demain', urgent: true };
  return { texte: j < 14 ? `Dans ${j} j` : date(iso, true), urgent: false };
}
export const initiales = (p?: Pick<Personne, 'prenom' | 'nom'> | null) => p ? (p.prenom[0] ?? '') + (p.nom[0] ?? '') : '?';
export const nomCourt = (p?: Pick<Personne, 'prenom' | 'nom'> | null) => p ? `${p.prenom} ${p.nom[0] ?? ''}.` : '—';

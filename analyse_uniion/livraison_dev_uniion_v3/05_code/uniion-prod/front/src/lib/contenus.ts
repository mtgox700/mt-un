import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from './supabase';
import type { Bloc } from './extensions';

// ---------------------------------------------------------------- agenda
export type Visibilite = 'section' | 'bureau' | 'prive';
export const VISIBILITES: { id: Visibilite; libelle: string; aide: string }[] = [
  { id: 'section', libelle: "Toute l'organisation", aide: 'Visible de tous les membres.' },
  { id: 'bureau', libelle: 'Bureau', aide: 'Visible des seuls membres du bureau et des invités. Filtré sur le serveur.' },
  { id: 'prive', libelle: 'Invités seulement', aide: 'Visible de vous et des personnes invitées.' },
];
export const TYPES_EVT = [
  { id: 'cse', libelle: 'Réunion CSE', fond: 'var(--acBg)', texte: 'var(--acTx2)', point: 'var(--ac2)' },
  { id: 'nego', libelle: 'Négociation', fond: 'var(--infoBg)', texte: 'var(--infoTx2)', point: 'var(--info)' },
  { id: 'perm', libelle: 'Permanence', fond: 'var(--okBg)', texte: 'var(--okTx)', point: 'var(--ok)' },
  { id: 'form', libelle: 'Formation', fond: 'var(--priBg)', texte: 'var(--pri)', point: 'var(--pri)' },
  { id: 'ag', libelle: 'Assemblée', fond: 'var(--warnBg)', texte: 'var(--warnTx)', point: 'var(--warnTx)' },
  { id: 'ech', libelle: 'Échéance', fond: 'var(--dangerBg)', texte: 'var(--dangerTx2)', point: 'var(--danger)' },
];
export const typeEvt = (id: string) => TYPES_EVT.find((t) => t.id === id) ?? TYPES_EVT[0]!;

export interface Participant { personne_id: string; reponse: 'en_attente' | 'accepte' | 'refuse'; personne: { prenom: string; nom: string } | null }
export interface Evenement {
  id: string; titre: string; type: string; debut: string; fin: string; journee_entiere: boolean; lieu: string | null; description: string | null;
  createur_id: string; visibilite: Visibilite; dossier_id: string | null; version: number;
  createur: { prenom: string; nom: string } | null; dossier: { intitule: string } | null; participants: Participant[];
}
const COL_EVT = 'id, titre, type, debut, fin, journee_entiere, lieu, description, createur_id, visibilite, dossier_id, version, createur:createur_id(prenom, nom), dossier:dossier_id(intitule), participants:evenement_participant(personne_id, reponse, personne:personne_id(prenom, nom))';

export const useEvenements = (de: Date, a: Date) => useQuery({
  queryKey: ['evenements', de.toISOString(), a.toISOString()], placeholderData: (p) => p,
  queryFn: async () => {
    const { data, error } = await supabase.from('evenement').select(COL_EVT).is('supprime_le', null)
      .lt('debut', a.toISOString()).gte('fin', de.toISOString()).order('debut');
    if (error) throw new Error('Agenda indisponible.');
    return data as unknown as Evenement[];
  },
});

export type SaisieEvt = Pick<Evenement, 'titre' | 'type' | 'debut' | 'fin' | 'journee_entiere' | 'lieu' | 'description' | 'visibilite' | 'dossier_id'>;
export function useEnregistrerEvt() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ e, avant, invites }: { e: SaisieEvt; avant?: Evenement; invites: string[] }) => {
      let id = avant?.id;
      if (avant) {
        const { data, error } = await supabase.from('evenement').update(e).eq('id', avant.id).eq('version', avant.version).select('id').maybeSingle();
        if (error) throw new Error('Enregistrement impossible.');
        if (!data) throw new Error("L'événement a été modifié entre-temps. Rouvrez-le pour voir la version à jour.");
      } else {
        const { data, error } = await supabase.from('evenement').insert(e).select('id').single();
        if (error) throw new Error('Création impossible.');
        id = data.id;
      }
      const deja = new Set((avant?.participants ?? []).map((p) => p.personne_id));
      const ajout = invites.filter((p) => !deja.has(p)), retrait = [...deja].filter((p) => !invites.includes(p));
      if (ajout.length) { const r = await supabase.from('evenement_participant').insert(ajout.map((p) => ({ evenement_id: id, personne_id: p }))); if (r.error) throw new Error('Invitations incomplètes.'); }
      if (retrait.length) await supabase.from('evenement_participant').delete().eq('evenement_id', id!).in('personne_id', retrait);
      return id!;
    },
    onSettled: () => qc.invalidateQueries({ queryKey: ['evenements'] }),
  });
}
export function useActionEvt() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (a: { supprimer: Evenement } | { repondre: Evenement; personneId: string; reponse: Participant['reponse'] }) => {
      const r = 'supprimer' in a
        ? await supabase.from('evenement').update({ supprime_le: new Date().toISOString() }).eq('id', a.supprimer.id)
        : await supabase.from('evenement_participant').update({ reponse: a.reponse }).eq('evenement_id', a.repondre.id).eq('personne_id', a.personneId);
      if (r.error) throw new Error('Action impossible.');
    },
    onSettled: () => qc.invalidateQueries({ queryKey: ['evenements'] }),
  });
}

// Fichier .ics produit sur l'appareil, sans passer par un tiers.
export function exporterIcs(e: Evenement) {
  const f = (d: string) => new Date(d).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const j = (d: string) => d.slice(0, 10).replace(/-/g, '');
  const esc = (s: string) => s.replace(/[\\;,]/g, (c) => '\\' + c).replace(/\n/g, '\\n');
  const ics = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//uniion//agenda//FR', 'BEGIN:VEVENT', `UID:${e.id}@uniion`, `DTSTAMP:${f(new Date().toISOString())}`,
    e.journee_entiere ? `DTSTART;VALUE=DATE:${j(e.debut)}` : `DTSTART:${f(e.debut)}`, e.journee_entiere ? `DTEND;VALUE=DATE:${j(new Date(new Date(e.fin).getTime() + 864e5).toISOString())}` : `DTEND:${f(e.fin)}`,
    `SUMMARY:${esc(e.titre)}`, e.lieu ? `LOCATION:${esc(e.lieu)}` : '', 'END:VEVENT', 'END:VCALENDAR'].filter(Boolean).join('\r\n');
  const url = URL.createObjectURL(new Blob([ics], { type: 'text/calendar' }));
  Object.assign(document.createElement('a'), { href: url, download: 'evenement.ics' }).click();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

// ---------------------------------------------------------------- documents
export type StatutDoc = 'brouillon' | 'relu' | 'signe' | 'diffuse';
export const STATUTS_DOC: Record<StatutDoc, { libelle: string; ton: 'neutre' | 'accent' | 'ok' | 'alerte' }> = {
  brouillon: { libelle: 'Brouillon', ton: 'neutre' }, relu: { libelle: 'Relu', ton: 'alerte' }, signe: { libelle: 'Signé', ton: 'ok' }, diffuse: { libelle: 'Diffusé', ton: 'accent' },
};
export const FORMATS: Record<string, { libelle: string; w: number; h: number }> = {
  a4: { libelle: 'A4 portrait', w: 595, h: 842 }, a5: { libelle: 'A5 portrait', w: 420, h: 595 }, wide: { libelle: 'Paysage', w: 842, h: 595 },
};
export interface Doc { id: string; titre: string; gabarit: string; format: string; statut: StatutDoc; blocs: Bloc[]; apparence: { palette?: string; police?: string }; auteur_id: string; modifie_le: string; version: number; auteur: { prenom: string; nom: string } | null }
const COL_DOC = 'id, titre, gabarit, format, statut, blocs, apparence, auteur_id, modifie_le, version, auteur:auteur_id(prenom, nom)';

export const MODELES: { id: string; libelle: string; desc: string; style: string; blocs: Omit<Bloc, 'id'>[] }[] = [
  { id: 'vierge', libelle: 'Page blanche', desc: 'Un titre et un paragraphe.', style: 'classique', blocs: [{ type: 'h1', text: 'Titre' }, { type: 'p', text: '' }] },
  { id: 'tract', libelle: 'Tract', desc: 'Accroche, revendications, rendez-vous.', style: 'choc', blocs: [{ type: 'tag', text: 'NAO 2027' }, { type: 'h1', text: 'Titre du tract' }, { type: 'ul', text: 'Première revendication\nDeuxième revendication\nTroisième revendication' }, { type: 'quote', text: 'Rendez-vous : date, heure, lieu' }] },
  { id: 'cr', libelle: 'Compte rendu', desc: 'Séance, points abordés, suites.', style: 'journal', blocs: [{ type: 'tag', text: 'Compte rendu' }, { type: 'h1', text: 'Séance du …' }, { type: 'p', text: 'Ce qu\'il faut retenir en une phrase.' }, { type: 'h2', text: 'Points abordés' }, { type: 'ul', text: '' }, { type: 'h2', text: 'Prochaines étapes' }, { type: 'table', text: 'Date | Étape\n' }] },
  { id: 'courrier', libelle: 'Courrier', desc: 'À la direction ou à l\'inspection du travail.', style: 'institutionnel', blocs: [{ type: 'p', text: 'Objet : ' }, { type: 'p', text: 'Madame, Monsieur,' }, { type: 'p', text: '' }, { type: 'p', text: 'Veuillez agréer, Madame, Monsieur, l\'expression de nos salutations distinguées.' }] },
];
export const nouvelIdBloc = () => 'b' + crypto.randomUUID().slice(0, 8);

export const useDocuments = () => useQuery({
  queryKey: ['documents'],
  queryFn: async () => {
    const { data, error } = await supabase.from('document').select(COL_DOC).is('supprime_le', null).order('modifie_le', { ascending: false });
    if (error) throw new Error('Documents indisponibles.');
    return data as unknown as Doc[];
  },
});
export const useDocument = (id: string) => useQuery({
  queryKey: ['document', id], refetchOnWindowFocus: false,
  queryFn: async () => {
    const { data, error } = await supabase.from('document').select(COL_DOC).eq('id', id).is('supprime_le', null).maybeSingle();
    if (error) throw new Error('Document indisponible.');
    return data as unknown as Doc | null;
  },
});
export function useCreerDocument() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (m: (typeof MODELES)[number] & { styleDispo: boolean }) => {
      const { data, error } = await supabase.from('document').insert({ titre: m.id === 'vierge' ? 'Sans titre' : m.libelle, gabarit: m.styleDispo ? m.style : 'classique', format: 'a4',
        blocs: m.blocs.map((b) => ({ ...b, id: nouvelIdBloc() })), apparence: {} }).select('id').single();
      if (error) throw new Error('Création impossible.');
      return data.id as string;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['documents'] }),
  });
}
export function useEnregistrerDocument() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ d, modif }: { d: Doc; modif: Partial<Pick<Doc, 'titre' | 'gabarit' | 'format' | 'statut' | 'blocs' | 'apparence'>> & { supprime_le?: string } }) => {
      // Les images ne sont jamais enregistrées dans le document : seule la référence au média l'est.
      const m = modif.blocs ? { ...modif, blocs: modif.blocs.map(({ img: _img, ...b }) => b) } : modif;
      const { data, error } = await supabase.from('document').update(m).eq('id', d.id).eq('version', d.version).select(COL_DOC).maybeSingle();
      if (error) throw new Error(error.message.includes('signé') ? 'Document signé : son contenu ne peut plus être modifié.' : 'Enregistrement impossible.');
      if (!data) throw new Error('Ce document a été modifié dans un autre onglet ou par une autre personne. Rechargez-le.');
      return data as unknown as Doc;
    },
    onSuccess: (d) => { qc.setQueryData(['document', d.id], d); qc.invalidateQueries({ queryKey: ['documents'] }); },
  });
}

// ---------------------------------------------------------------- médias (bucket privé « media »)
async function reduire(f: File): Promise<{ blob: Blob; l: number; h: number }> {
  const img = await createImageBitmap(f);
  const k = Math.min(1, 1400 / Math.max(img.width, img.height));
  const c = Object.assign(document.createElement('canvas'), { width: Math.round(img.width * k), height: Math.round(img.height * k) });
  c.getContext('2d')!.drawImage(img, 0, 0, c.width, c.height);
  // Réencodage : les métadonnées EXIF (position GPS, appareil) disparaissent.
  const blob = await new Promise<Blob>((ok, ko) => c.toBlob((b) => (b ? ok(b) : ko(new Error('conversion'))), 'image/webp', 0.85));
  return { blob, l: c.width, h: c.height };
}
export async function deposerMedia(f: File, o: { orgId: string; personneId: string; documentId: string; identifiable: boolean; consentement: boolean }) {
  if (!['image/jpeg', 'image/png', 'image/webp', 'image/heic'].includes(f.type)) throw new Error('Image JPEG, PNG ou WebP attendue.');
  if (o.identifiable && !o.consentement) throw new Error("Une personne reconnaissable n'apparaît qu'avec son accord écrit.");
  const { blob, l, h } = await reduire(f);
  if (blob.size > 5 * 1024 * 1024) throw new Error('Image trop lourde après réduction.');
  const chemin = `${o.orgId}/${o.personneId}/${crypto.randomUUID()}.webp`;
  const up = await supabase.storage.from('media').upload(chemin, blob, { contentType: 'image/webp', upsert: false });
  if (up.error) throw new Error('Dépôt impossible.');
  const { data, error } = await supabase.from('media').insert({ chemin, type_mime: 'image/webp', taille_octets: blob.size, largeur: l, hauteur: h,
    personne_identifiable: o.identifiable, consentement_image: o.identifiable ? true : null, document_id: o.documentId }).select('id').single();
  if (error) { await supabase.storage.from('media').remove([chemin]); throw new Error('Enregistrement impossible.'); }
  return data.id as string;
}

// Résout les médias d'un document en URL locales (blob:), libérées à la fermeture.
export function useImages(ids: string[]) {
  const [urls, setUrls] = useState<Record<string, string>>({});
  const cle = [...new Set(ids)].sort().join(',');
  useEffect(() => {
    let vivant = true; const crees: string[] = [];
    (async () => {
      const liste = cle ? cle.split(',') : [];
      if (!liste.length) return;
      const { data } = await supabase.from('media').select('id, chemin').in('id', liste);
      const res: Record<string, string> = {};
      for (const m of data ?? []) {
        const { data: b } = await supabase.storage.from('media').download(m.chemin);
        if (b) { const u = URL.createObjectURL(b); crees.push(u); res[m.id] = u; }
      }
      if (vivant) setUrls(res);
    })();
    return () => { vivant = false; crees.forEach(URL.revokeObjectURL); };
  }, [cle]);
  return urls;
}

export const useOrganisation = (orgId: string | null) => useQuery({
  queryKey: ['organisation', orgId], enabled: !!orgId, staleTime: 300_000,
  queryFn: async () => {
    const { data } = await supabase.from('organisation').select('nom, sigle, email, type').eq('id', orgId!).maybeSingle();
    return data as { nom: string; sigle: string; email: string | null; type: 'cse' | 'section' | 'ud' } | null;
  },
});

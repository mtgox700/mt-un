import { useEffect, useSyncExternalStore } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from './supabase';

// Chargeur d'extensions. Seules les extensions du registre (base), activées par un administrateur,
// sont chargées : fichier servi par uniion (/ext/…), intégrité SRI vérifiée par le navigateur,
// signature Ed25519 de l'éditeur vérifiée ici. Aucune adresse libre, aucun code tiers.
export interface Bloc { id: string; type: string; text: string; media?: string; img?: string }
export interface DocStyle {
  id: string; label: string; desc?: string; formats: string[]; suits?: string[]; uniiHint?: string; notice?: string;
  palettes: { id: string; label: string; colors: { a: string; b: string; c: string; d: string } }[];
  fonts: { id: string; label: string; head: string; body: string; hand?: string }[];
  slots?: { id: string; label: string; type: string; index: number; optional?: boolean }[];
  render: (ctx: unknown) => unknown; ext: string;
}
export interface DocBlock { type: string; label: string; ph?: string; rows?: number; sample?: string; hint?: string; accepts?: 'image'; estimateHeight?: (b: Bloc) => number; render: (b: Bloc, k: unknown) => unknown; ext: string }
interface Manifeste { id: string; version: string; apiVersion: number; name: string; assets?: { css?: string[] }; contributes?: { docStyles?: DocStyle[]; docBlocks?: DocBlock[] } }
interface Activation { id: string; version: string; fichier: string; integrite_sri: string; signature: string; elements_desactives: string[] }

const etat = { manifestes: new Map<string, Manifeste>(), erreurs: [] as string[], version: 0 };
const abonnes = new Set<() => void>();
const signaler = () => { etat.version++; abonnes.forEach((f) => f()); };
const attendues = new Map<string, Activation>();

type HoteUniion = { register?: (m: Manifeste) => void; queue?: Manifeste[] };
function installerHote() {
  const w = window as unknown as { uniion?: HoteUniion };
  const U: HoteUniion = (w.uniion = w.uniion ?? {});
  if (U.register) return;
  U.register = (m) => {
    const a = attendues.get(m?.id);
    if (!a) { etat.erreurs.push(`Extension « ${m?.id} » refusée : absente du registre.`); return signaler(); }
    if (m.apiVersion !== 1 || m.version !== a.version) { etat.erreurs.push(`« ${m.name} » : version inattendue.`); return signaler(); }
    for (const css of m.assets?.css ?? []) {  // polices auto-hébergées uniquement
      if (!/^\/fonts\/[a-z0-9.-]+\.css$/.test(css) || document.querySelector(`link[href="${css}"]`)) continue;
      document.head.append(Object.assign(document.createElement('link'), { rel: 'stylesheet', href: css }));
    }
    etat.manifestes.set(m.id, m); signaler();
  };
  (U.queue ?? []).splice(0).forEach((m) => U.register!(m));
}

const b64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
async function signatureValide(a: Activation) {
  const cle = import.meta.env.VITE_EXT_CLE_PUBLIQUE as string | undefined;
  if (!cle) return false;
  try {
    const k = await crypto.subtle.importKey('raw', b64(cle), { name: 'Ed25519' }, false, ['verify']);
    return await crypto.subtle.verify({ name: 'Ed25519' }, k, b64(a.signature), new TextEncoder().encode(a.integrite_sri));
  } catch { return null; }  // navigateur sans Ed25519 : on s'en remet au SRI et au registre
}

async function charger(a: Activation) {
  if (attendues.has(a.id) || !/^\/ext\/[a-z0-9.-]+\.js$/.test(a.fichier) || !/^sha384-[A-Za-z0-9+/=]+$/.test(a.integrite_sri)) return;
  const sig = await signatureValide(a);
  if (sig === false) { etat.erreurs.push(`Extension « ${a.id} » refusée : signature de l'éditeur invalide.`); return signaler(); }
  attendues.set(a.id, a);
  installerHote();
  const s = Object.assign(document.createElement('script'), { src: a.fichier, integrity: a.integrite_sri, crossOrigin: 'anonymous', async: true });
  s.onerror = () => { etat.erreurs.push(`Extension « ${a.id} » non chargée : fichier altéré ou indisponible.`); signaler(); };
  document.head.append(s);
}

export function useExtensions() {
  const { data } = useQuery({ queryKey: ['extensions'], staleTime: Infinity, queryFn: async () => {
    const { data, error } = await supabase.schema('api').rpc('extensions_actives');
    if (error) throw new Error('Registre des extensions indisponible.');
    return data as Activation[];
  } });
  useEffect(() => { data?.forEach(charger); }, [data]);
  useSyncExternalStore((f) => { abonnes.add(f); return () => abonnes.delete(f); }, () => etat.version);
  const coupes = new Set((data ?? []).flatMap((a) => a.elements_desactives));
  const styles: DocStyle[] = [], blocs: DocBlock[] = [];
  etat.manifestes.forEach((m) => {
    m.contributes?.docStyles?.forEach((x) => !coupes.has(x.id) && styles.push({ ...x, ext: m.id }));
    m.contributes?.docBlocks?.forEach((x) => !coupes.has(x.type) && blocs.push({ ...x, ext: m.id }));
  });
  return { styles, blocs, erreurs: etat.erreurs, pret: !!data && [...attendues.keys()].every((id) => etat.manifestes.has(id)) };
}

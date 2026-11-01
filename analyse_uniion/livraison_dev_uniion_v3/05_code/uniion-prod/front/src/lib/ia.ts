import { supabase } from './supabase';

export type Surface = 'assistant' | 'dossier' | 'dossier_guide' | 'document' | 'communication' | 'page' | 'compte_rendu' | 'messagerie' | 'formation';
export interface ReponseIa { id: string; reponse?: string; erreur?: string; refus?: string; residuel?: string[]; apercu_masque?: string; apercus?: string[]; correspondances: { jeton: string; type: string }[] }

// Remplace llmText/llmJson du prototype. Le texte part en clair sur TLS vers la passerelle, qui
// masque, refuse si résidu, appelle le modèle et renvoie la réponse avec les jetons. La table
// jeton → valeur claire est reconstruite ICI à partir du texte saisi : elle ne quitte jamais l'appareil.
export async function demanderUnii(surface: Surface, texte: string, options: { dossierId?: string; historique?: { role: 'user' | 'assistant'; texte: string }[] } = {}) {
  const { data, error } = await supabase.functions.invoke<ReponseIa>('ai-ask', {
    body: { surface, texte, dossier_id: options.dossierId, historique: options.historique },
  });
  if (error) {
    const corps = await (error as { context?: Response }).context?.json?.().catch(() => null);
    return { id: '', erreur: corps?.erreur ?? "L'assistant est indisponible.", refus: corps?.refus, residuel: corps?.residuel, correspondances: [] } as ReponseIa;
  }
  return data!;
}

// Ré-identification locale : l'utilisateur relit la réponse avec les vrais noms.
// Chaque morceau masqué (historique + question) est aligné sur son texte clair ; la table
// jeton → valeur est construite ici et n'est jamais transmise.
export function reidentifier(reponse: string, masques: string | string[], clairs: string | string[]) {
  const m = Array.isArray(masques) ? masques : [masques];
  const c = Array.isArray(clairs) ? clairs : [clairs];
  const table = new Map<string, string>();
  m.forEach((apercu, i) => aligner(apercu, c[i] ?? '', table));
  return table.size ? reponse.replace(/\[[A-Z_]+_\d+\]/g, (j) => table.get(j) ?? j) : reponse;
}
function aligner(apercuMasque: string, texteClair: string, table: Map<string, string>) {
  const jetons = [...apercuMasque.matchAll(/\[[A-Z_]+_\d+\]/g)].map((m) => m[0]);
  if (!jetons.length) return;
  const motif = apercuMasque.split(/(\[[A-Z_]+_\d+\])/).map((p) => (/^\[[A-Z_]+_\d+\]$/.test(p) ? '(.+?)' : p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))).join('');
  const m = new RegExp('^' + motif + '$', 's').exec(texteClair);
  if (!m) return;
  jetons.forEach((j, i) => { if (!table.has(j) && m[i + 1]) table.set(j, m[i + 1]!); });
}

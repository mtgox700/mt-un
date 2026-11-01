// Passerelle IA unique (API.md §2 et §6, bloquant 1.1).
// Le client envoie du texte EN CLAIR sur la connexion TLS ; le masquage de référence se fait ici,
// avec le dictionnaire de l'organisation. Rien n'est conservé en clair : requete_ia ne garde que
// des métadonnées et l'empreinte du texte masqué. La table de correspondance repart vers le client,
// qui ré-identifie localement la réponse.
import { CORS, json, sha256, utilisateur } from '../_shared/auth.ts';
import { detecterNiveau, estQuestionMeta, masquer, type Dictionnaire, type Niveau } from '../_shared/masque.ts';
import { CORPUS_VERSION, PROMPT_VERSION, PROMPTS, REPONSE_META } from './prompts.ts';

const SURFACES = new Set(Object.keys(PROMPTS));
const QUOTA_JOUR = Number(Deno.env.get('QUOTA_IA_JOUR') ?? '150');
const FOURNISSEUR = Deno.env.get('AI_PROVIDER') ?? 'mistral';
const MODELE = Deno.env.get('AI_MODEL') ?? 'mistral-large-latest';
const ALIAS = Deno.env.get('AI_MODEL_ALIAS') ?? 'unii-v1';  // seul nom visible côté client et journaux
const NIVEAU_DB: Record<Niveau, string> = { standard: 'partiel', rh: 'partiel', rps: 'strict' };

interface Tour { role: 'user' | 'assistant'; texte: string }

async function appelerModele(systeme: string, tours: Tour[], max: number) {
  const cle = Deno.env.get('AI_API_KEY')!;
  const t0 = Date.now();
  if (FOURNISSEUR === 'mistral') {
    const r = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${cle}` },
      body: JSON.stringify({ model: MODELE, max_tokens: max, temperature: 0.2,
        messages: [{ role: 'system', content: systeme }, ...tours.map((t) => ({ role: t.role, content: t.texte }))] }),
    });
    if (!r.ok) throw new Error(`fournisseur ${r.status}`);
    const d = await r.json();
    return { texte: d.choices[0].message.content as string, entree: d.usage?.prompt_tokens, sortie: d.usage?.completion_tokens, ms: Date.now() - t0 };
  }
  if (FOURNISSEUR === 'anthropic') {
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST', headers: { 'content-type': 'application/json', 'x-api-key': cle, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({ model: MODELE, max_tokens: max, system: systeme, messages: tours.map((t) => ({ role: t.role, content: t.texte })) }),
    });
    if (!r.ok) throw new Error(`fournisseur ${r.status}`);
    const d = await r.json();
    return { texte: d.content.map((c: { text?: string }) => c.text ?? '').join(''), entree: d.usage?.input_tokens, sortie: d.usage?.output_tokens, ms: Date.now() - t0 };
  }
  throw new Error('AI_PROVIDER inconnu');
}

async function dictionnaire(admin: Utilisateur['admin'], orgId: string): Promise<Dictionnaire> {
  const [p, a, e, o] = await Promise.all([
    admin.from('personne').select('prenom, nom').eq('organisation_id', orgId),
    admin.from('adherent').select('prenom, nom').eq('organisation_id', orgId).is('supprime_le', null),
    admin.from('etablissement').select('libelle').eq('organisation_id', orgId),
    admin.from('organisation').select('nom').eq('id', orgId).single(),
  ]);
  return {
    personnes: [...(p.data ?? []), ...(a.data ?? [])],
    lieux: (e.data ?? []).map((x) => x.libelle),
    employeurs: o.data?.nom ? [o.data.nom] : [],
  };
}
type Utilisateur = Exclude<Awaited<ReturnType<typeof utilisateur>>, Response>;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  if (req.method !== 'POST') return json({ erreur: 'méthode' }, 405);
  const u = await utilisateur(req);
  if (u instanceof Response) return u;

  let corps: { surface: string; texte: string; niveau?: Niveau; dossier_id?: string; historique?: Tour[]; max?: number };
  try { corps = await req.json(); } catch { return json({ erreur: 'corps invalide' }, 400); }
  const { surface, texte } = corps;
  if (!SURFACES.has(surface) || typeof texte !== 'string' || !texte.trim() || texte.length > 12000) return json({ erreur: 'requête invalide' }, 400);
  const historique = (corps.historique ?? []).slice(-10);

  const id = 'air_' + crypto.randomUUID().replaceAll('-', '');
  const journal = (champs: Record<string, unknown>) => u.admin.from('requete_ia').insert({
    id, organisation_id: u.orgId, personne_id: u.personneId, surface, dossier_id: corps.dossier_id ?? null,
    prompt_version: PROMPT_VERSION, corpus_version: CORPUS_VERSION, modele_alias: ALIAS, ...champs,
  });

  if (estQuestionMeta(texte)) {
    await journal({ empreinte_requete: await sha256(texte), niveau_masquage: 'aucun', refus: 'meta_question', succes: false });
    return json({ id, reponse: REPONSE_META, correspondances: [], local: true });
  }

  const { count } = await u.admin.from('requete_ia').select('id', { count: 'exact', head: true })
    .eq('personne_id', u.personneId).gte('cree_le', new Date(Date.now() - 864e5).toISOString());
  if ((count ?? 0) >= QUOTA_JOUR) {
    await journal({ empreinte_requete: await sha256(texte), niveau_masquage: 'aucun', refus: 'quota', succes: false });
    return json({ id, refus: 'quota', erreur: 'Quota quotidien atteint.' }, 429);
  }

  if (corps.dossier_id) {  // contrôle de périmètre avec les droits de l'utilisateur
    const { data } = await u.client.from('dossier').select('id').eq('id', corps.dossier_id).maybeSingle();
    if (!data) return json({ erreur: 'dossier inaccessible' }, 404);
  }

  const niveau = corps.niveau ?? detecterNiveau([texte, ...historique.map((h) => h.texte)].join(' '));
  const dico = await dictionnaire(u.admin, u.orgId);
  const tout = masquer([...historique.map((h) => h.texte), texte].join('\n\u241E\n'), niveau, dico);
  if (tout.residuel.length) {
    await journal({ empreinte_requete: await sha256(tout.masque), niveau_masquage: NIVEAU_DB[niveau],
      entites_masquees: tout.correspondances.length, residuel_types: tout.residuel, refus: 'masquage_incomplet', succes: false });
    return json({ id, refus: 'masquage_incomplet', residuel: tout.residuel,
      erreur: 'Envoi refusé : un identifiant probable échappe au masquage. Reformulez sans nom propre.' }, 422);
  }
  const morceaux = tout.masque.split('\n\u241E\n');
  const tours: Tour[] = [...historique.map((h, i) => ({ role: h.role, texte: morceaux[i] })), { role: 'user', texte: morceaux.at(-1)! }];

  try {
    const r = await appelerModele(PROMPTS[surface], tours, Math.min(corps.max ?? 1200, 4000));
    await journal({ empreinte_requete: await sha256(tout.masque), niveau_masquage: NIVEAU_DB[niveau],
      entites_masquees: tout.correspondances.length, jetons_entree: r.entree, jetons_sortie: r.sortie, latence_ms: r.ms, succes: true });
    return json({ id, reponse: r.texte, niveau, correspondances: tout.correspondances.map(({ jeton, type }) => ({ jeton, type })),
      apercu_masque: morceaux.at(-1), apercus: morceaux });
  } catch (e) {
    await journal({ empreinte_requete: await sha256(tout.masque), niveau_masquage: NIVEAU_DB[niveau],
      entites_masquees: tout.correspondances.length, succes: false });
    console.error('ai-ask', id, (e as Error).message);  // jamais de contenu dans les journaux
    return json({ id, erreur: "L'assistant est indisponible. Réessayez dans un instant." }, 502);
  }
});

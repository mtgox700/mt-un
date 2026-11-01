import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

export const CORS = {
  'Access-Control-Allow-Origin': Deno.env.get('SITE_URL') ?? '',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
};

export const json = (corps: unknown, statut = 200) =>
  new Response(JSON.stringify(corps), { status: statut, headers: { ...CORS, 'content-type': 'application/json' } });

export interface Utilisateur { client: SupabaseClient; admin: SupabaseClient; personneId: string; orgId: string; aal: string; roles: string[] }

export const clientAdmin = () =>
  createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });

export const nouvelId = (prefixe: string) => prefixe + '_' + crypto.randomUUID().replaceAll('-', '');

// Exige un rôle (et la double authentification par défaut). Renvoie une réponse d'erreur ou null.
export function exiger(u: Utilisateur, role: string, mfa = true): Response | null {
  if (!u.roles.includes(role)) return json({ erreur: `rôle ${role} requis` }, 403);
  if (mfa && u.aal !== 'aal2') return json({ erreur: 'double authentification requise' }, 403);
  return null;
}

// Journal d'audit (ajout seul, empreinte chaînée posée par déclencheur).
export async function journaliser(u: Pick<Utilisateur, 'admin' | 'orgId' | 'personneId' | 'roles'>, action: string,
  ressourceType: string, ressourceId: string | null, motif: string | null = null, article9 = false) {
  const ordre = ['admin', 'tresorier', 'communication', 'militant'];
  const role = ordre.find((r) => u.roles.includes(r)) ?? null;
  const { error } = await u.admin.from('audit').insert({ organisation_id: u.orgId, acteur_id: u.personneId, acteur_role: role,
    action, ressource_type: ressourceType, ressource_id: ressourceId, motif, article_9: article9 });
  if (error) throw new Error('journal indisponible');  // pas d'action sensible sans trace
}

// Client « utilisateur » (RLS appliquée) pour les contrôles d'accès, client « admin » (service_role)
// pour ce que la RLS interdit au client : écriture des journaux, déchiffrement.
export async function utilisateur(req: Request): Promise<Utilisateur | Response> {
  const auth = req.headers.get('authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json({ erreur: 'non authentifié' }, 401);
  const url = Deno.env.get('SUPABASE_URL')!;
  const client = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: auth } }, auth: { persistSession: false },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return json({ erreur: 'session invalide' }, 401);
  // Revalidation en base (compte actif, organisation) : on ne fait pas confiance au seul jeton.
  const { data: moi } = await client.schema('api').rpc('moi');
  if (!moi?.personne_id || !moi?.org_id) return json({ erreur: 'aucune organisation active' }, 403);
  return { client, admin: clientAdmin(), personneId: moi.personne_id, orgId: moi.org_id, aal: moi.aal ?? 'aal1', roles: moi.roles ?? [] };
}

export async function sha256(t: string) {
  const h = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(t));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(import.meta.env.VITE_SUPABASE_URL, import.meta.env.VITE_SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    // Session en sessionStorage : fermée avec l'onglet. Aucune donnée métier n'est stockée localement.
    storage: window.sessionStorage,
    storageKey: 'uniion.session',
  },
});

export interface Moi { personne_id: string | null; org_id: string | null; roles: string[]; bureau: boolean; aal: string }

export async function moi(): Promise<Moi | null> {
  const { data, error } = await supabase.schema('api').rpc('moi');
  if (error) return null;
  return data as Moi;
}

export const aRole = (m: Moi | null, r: string) => !!m?.roles.includes(r);
// Rôles exigeant la double authentification (accès article 9 ou administration)
export const mfaRequise = (m: Moi | null) => aRole(m, 'tresorier') || aRole(m, 'admin');

// Sonde de supervision (Uptime Kuma, toutes les minutes). Répond 200 si tout va bien, 503 sinon.
// Protégée par un jeton dédié : SANTE_JETON. Ne renvoie aucune donnée métier.
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  if (req.headers.get('x-sante') !== Deno.env.get('SANTE_JETON')) return new Response('interdit', { status: 403 });
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
  const [ret, file, ia] = await Promise.all([
    admin.schema('api').rpc('retention_a_jour'),
    admin.from('tache_file').select('id', { count: 'exact', head: true }).eq('etat', 'en_attente')
      .lt('cree_le', new Date(Date.now() - 30 * 60e3).toISOString()),
    admin.from('requete_ia').select('succes').gte('cree_le', new Date(Date.now() - 15 * 60e3).toISOString()).is('refus', null),
  ]);
  const echecsIa = (ia.data ?? []).filter((r) => !r.succes).length;
  const etat = {
    base: !ret.error,
    retention_a_jour: ret.data === true,
    file_en_retard: file.count ?? 0,
    ia_taux_echec: ia.data?.length ? echecsIa / ia.data.length : 0,
  };
  const ok = etat.base && etat.retention_a_jour && etat.file_en_retard < 100 && etat.ia_taux_echec <= 0.05;
  return new Response(JSON.stringify(etat), { status: ok ? 200 : 503, headers: { 'content-type': 'application/json' } });
});

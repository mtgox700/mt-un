// Désinscription en un clic (lien de chaque e-mail, en-tête List-Unsubscribe). Sans session :
// le lien porte l'identifiant d'envoi et une empreinte qui ne peut être calculée qu'en connaissant
// l'adresse. On conserve seulement le témoin de refus (empreinte), jamais l'adresse.
import { clientAdmin, CORS, json } from '../_shared/auth.ts';

const admin = clientAdmin();
const sha = async (t: string) => [...new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(t)))]
  .map((b) => b.toString(16).padStart(2, '0')).join('');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  const url = new URL(req.url);
  const corps = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
  const e = String(corps.e ?? url.searchParams.get('e') ?? '');
  const k = String(corps.k ?? url.searchParams.get('k') ?? '');
  if (!/^\d+$/.test(e) || !/^[0-9a-f]{64}$/.test(k)) return json({ erreur: 'lien invalide' }, 400);

  const { data: envoi } = await admin.from('campagne_envoi')
    .select('id, adherent:adherent_id(email), campagne:campagne_id(canal, organisation_id)').eq('id', e).maybeSingle();
  const a = envoi?.adherent as unknown as { email: string | null } | null;
  const c = envoi?.campagne as unknown as { canal: string; organisation_id: string } | null;
  if (!envoi || !a?.email || !c) return json({ ok: true });  // réponse identique : pas d'énumération
  if ((await sha(c.organisation_id + ':' + a.email.trim().toLowerCase() + ':' + envoi.id)) !== k) return json({ ok: true });

  await admin.from('desinscription').upsert({
    organisation_id: c.organisation_id, canal: c.canal, email_empreinte: await sha(c.organisation_id + ':' + a.email.trim().toLowerCase()),
  }, { onConflict: 'organisation_id,email_empreinte,canal', ignoreDuplicates: true });
  await admin.from('audit').insert({ organisation_id: c.organisation_id, action: 'adherent.desinscription', ressource_type: 'campagne_envoi', ressource_id: String(envoi.id), article_9: true });
  return json({ ok: true });
});

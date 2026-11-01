// File de tâches (tache_file), déclenchée chaque minute par pg_cron via pg_net.
// Natures : retention (suppression de fichiers échus), antivirus (réanalyse), email (envoi aux
// adhérents avec contrôle du consentement AU MOMENT DE L'ENVOI). Reprise exponentielle, abandon à 6 essais.
import { clientAdmin } from '../_shared/auth.ts';
import { dechiffrerOctets } from '../_shared/coffre.ts';
import { analyser } from '../_shared/antivirus.ts';

const LOT = 50;
const MAX_ESSAIS = 6;
const admin = clientAdmin();

async function empreinteEmail(orgId: string, email: string) {
  const h = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(orgId + ':' + email.trim().toLowerCase()));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function envoyerBrevo(a: { email: string; nom: string }, objet: string, html: string, desinscription: string) {
  const r = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'api-key': Deno.env.get('BREVO_API_KEY')! },
    body: JSON.stringify({
      sender: { email: Deno.env.get('EXPEDITEUR_EMAIL'), name: Deno.env.get('EXPEDITEUR_NOM') ?? 'uniion' },
      to: [{ email: a.email, name: a.nom }], subject: objet,
      htmlContent: html + `<p style="font-size:12px;color:#555">Vous recevez ce message en tant qu'adhérent. <a href="${desinscription}">Se désinscrire</a></p>`,
      headers: { 'List-Unsubscribe': `<${desinscription}>`, 'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click' },
    }),
  });
  if (!r.ok) throw new Error(`brevo ${r.status}`);
}

const echapper = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));

async function traiter(t: { id: string; organisation_id: string; nature: string; charge: Record<string, string> }) {
  switch (t.nature) {
    case 'retention': {
      const { error } = await admin.storage.from(t.charge.bucket).remove([t.charge.chemin]);
      if (error && !/not found/i.test(error.message)) throw new Error('suppression stockage');
      return;
    }
    case 'antivirus': {
      const { data: p } = await admin.from('piece_jointe').select('id, chemin_chiffre').eq('id', t.charge.piece_id).maybeSingle();
      if (!p) return;
      const { data: blob } = await admin.storage.from('pieces').download(p.chemin_chiffre);
      if (!blob) throw new Error('pièce absente du stockage');
      const clair = await dechiffrerOctets(t.organisation_id, new Uint8Array(await blob.arrayBuffer()), ':' + p.id);
      const verdict = await analyser(clair);
      if (verdict === 'ok') { await admin.from('piece_jointe').update({ antivirus_ok: true }).eq('id', p.id); return; }
      if (verdict === 'infecte') {
        await admin.storage.from('pieces').remove([p.chemin_chiffre]);
        await admin.from('piece_jointe').update({ supprime_le: new Date().toISOString() }).eq('id', p.id);
        await admin.from('audit').insert({ organisation_id: t.organisation_id, action: 'piece.rejet_antivirus', ressource_type: 'piece_jointe', ressource_id: p.id });
        return;
      }
      throw new Error('antivirus indisponible');
    }
    case 'email': {
      const { data: envoi } = await admin.from('campagne_envoi').select('id, etat, adherent_id, campagne:campagne_id(objet, corps, canal, organisation_id)')
        .eq('id', t.charge.envoi_id).maybeSingle();
      if (!envoi || envoi.etat !== 'en_attente') return;
      const c = envoi.campagne as unknown as { objet: string; corps: string; canal: string; organisation_id: string };
      const { data: a } = await admin.from('adherent').select('prenom, nom, email, consentement_contact, supprime_le').eq('id', envoi.adherent_id).maybeSingle();
      // Contrôles À L'ENVOI (bloquant 1.6) : adhérent actif, consentement, pas de désinscription.
      let bloque = !a || a.supprime_le || !a.email || !a.consentement_contact;
      if (!bloque) {
        const { count } = await admin.from('desinscription').select('id', { count: 'exact', head: true })
          .eq('organisation_id', c.organisation_id).eq('canal', c.canal).eq('email_empreinte', await empreinteEmail(c.organisation_id, a!.email!));
        bloque = (count ?? 0) > 0;
      }
      if (bloque) { await admin.from('campagne_envoi').update({ etat: 'desinscrit' }).eq('id', envoi.id); return; }
      const lien = `${Deno.env.get('SITE_URL')}/desinscription?e=${encodeURIComponent(envoi.id)}&k=${await empreinteEmail(c.organisation_id, a!.email! + ':' + envoi.id)}`;
      const html = echapper(c.corps).replace(/\n/g, '<br>').replace(/\{prenom\}/g, echapper(a!.prenom));
      await envoyerBrevo({ email: a!.email!, nom: `${a!.prenom} ${a!.nom}` }, c.objet, `<div style="font-family:system-ui;line-height:1.5">${html}</div>`, lien);
      await admin.from('campagne_envoi').update({ etat: 'envoye', envoye_le: new Date().toISOString(), tentatives: 1 }).eq('id', envoi.id);
      return;
    }
    default:
      throw new Error('nature inconnue');
  }
}

Deno.serve(async (req) => {
  if (req.headers.get('x-file') !== Deno.env.get('FILE_JETON')) return new Response('interdit', { status: 403 });
  const { data: taches } = await admin.from('tache_file').select('id, organisation_id, nature, charge, tentatives')
    .eq('etat', 'en_attente').or(`prochaine_tentative.is.null,prochaine_tentative.lte.${new Date().toISOString()}`)
    .order('cree_le').limit(LOT);
  let ok = 0, ko = 0;
  for (const t of taches ?? []) {
    // Verrou optimiste : une autre exécution concurrente ne prend pas la même tâche.
    const { data: pris } = await admin.from('tache_file').update({ etat: 'en_cours' }).eq('id', t.id).eq('etat', 'en_attente').select('id');
    if (!pris?.length) continue;
    try {
      await traiter(t);
      await admin.from('tache_file').update({ etat: 'termine' }).eq('id', t.id);
      ok++;
    } catch (e) {
      const n = t.tentatives + 1;
      await admin.from('tache_file').update({
        etat: n >= MAX_ESSAIS ? 'echec_definitif' : 'en_attente', tentatives: n,
        prochaine_tentative: new Date(Date.now() + 2 ** n * 60_000).toISOString(),
        derniere_erreur: (e as Error).message.slice(0, 200),  // message technique, jamais de contenu
      }).eq('id', t.id);
      ko++;
    }
  }
  return new Response(JSON.stringify({ traitees: ok, echecs: ko }), { headers: { 'content-type': 'application/json' } });
});

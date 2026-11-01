// Coffre : lecture et écriture des colonnes chiffrées. Le contrôle d'accès est fait avec le client
// UTILISATEUR (RLS), le chiffrement avec la clé hors base, l'écriture avec le client admin.
import { CORS, json, nouvelId, utilisateur } from '../_shared/auth.ts';
import { chiffrer, dechiffrer } from '../_shared/coffre.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  const u = await utilisateur(req);
  if (u instanceof Response) return u;
  const { action, ...p } = await req.json().catch(() => ({}));

  const accesDossier = async (d: string) => !!(await u.client.from('dossier').select('id').eq('id', d).maybeSingle()).data;
  const membreFil = async (f: string) => !!(await u.client.from('fil').select('id').eq('id', f).maybeSingle()).data;

  switch (action) {
    case 'note.lister': {
      if (!(await accesDossier(p.dossier_id))) return json({ erreur: 'dossier inaccessible' }, 404);
      const { data } = await u.admin.from('dossier_note').select('id, texte_chiffre, auteur_id, cree_le, modifie_le')
        .eq('dossier_id', p.dossier_id).order('cree_le');
      return json(await Promise.all((data ?? []).map(async (n) => ({ ...n, texte_chiffre: undefined, texte: await dechiffrer(u.orgId, n.texte_chiffre) }))));
    }
    case 'note.ajouter': {
      if (!(await accesDossier(p.dossier_id))) return json({ erreur: 'dossier inaccessible' }, 404);
      if (typeof p.texte !== 'string' || !p.texte.trim() || p.texte.length > 20000) return json({ erreur: 'texte invalide' }, 400);
      const id = nouvelId('not');
      const { error } = await u.admin.from('dossier_note').insert({ id, dossier_id: p.dossier_id, auteur_id: u.personneId, texte_chiffre: await chiffrer(u.orgId, p.texte) });
      return error ? json({ erreur: 'écriture impossible' }, 500) : json({ id });
    }
    case 'message.lister': {
      if (!(await membreFil(p.fil_id))) return json({ erreur: 'fil inaccessible' }, 404);
      const { data } = await u.admin.from('message').select('id, auteur_id, charge_chiffree, envoye_le, lu_par')
        .eq('fil_id', p.fil_id).order('envoye_le', { ascending: false }).limit(Math.min(p.limite ?? 50, 200));
      return json(await Promise.all((data ?? []).map(async (m) => ({ ...m, charge_chiffree: undefined, texte: await dechiffrer(u.orgId, m.charge_chiffree) }))));
    }
    case 'message.envoyer': {
      if (!(await membreFil(p.fil_id))) return json({ erreur: 'fil inaccessible' }, 404);
      if (typeof p.texte !== 'string' || !p.texte.trim() || p.texte.length > 10000) return json({ erreur: 'texte invalide' }, 400);
      const id = nouvelId('msg');
      const { error } = await u.admin.from('message').insert({ id, fil_id: p.fil_id, auteur_id: u.personneId, charge_chiffree: await chiffrer(u.orgId, p.texte) });
      return error ? json({ erreur: 'écriture impossible' }, 500) : json({ id });
    }
    case 'detail.lire': {
      if (!(await accesDossier(p.dossier_id))) return json({ erreur: 'dossier inaccessible' }, 404);
      const { data } = await u.admin.from('dossier').select('detail_chiffre').eq('id', p.dossier_id).single();
      return json({ texte: data?.detail_chiffre ? await dechiffrer(u.orgId, data.detail_chiffre) : '' });
    }
    case 'detail.ecrire': {
      if (!(await accesDossier(p.dossier_id))) return json({ erreur: 'dossier inaccessible' }, 404);
      if (typeof p.texte !== 'string' || p.texte.length > 50000) return json({ erreur: 'texte invalide' }, 400);
      const { error } = await u.admin.from('dossier').update({ detail_chiffre: p.texte ? await chiffrer(u.orgId, p.texte) : null, modifie_le: new Date().toISOString() })
        .eq('id', p.dossier_id);
      return error ? json({ erreur: 'écriture impossible' }, 500) : json({ ok: true });
    }
    case 'conversation.lister': {
      if (!(await accesDossier(p.dossier_id))) return json({ erreur: 'dossier inaccessible' }, 404);
      const { data } = await u.admin.from('dossier_conversation').select('id, role, texte_chiffre, source, requete_id, cree_le')
        .eq('dossier_id', p.dossier_id).order('cree_le');
      return json(await Promise.all((data ?? []).map(async (c) => ({ ...c, texte_chiffre: undefined, texte: await dechiffrer(u.orgId, c.texte_chiffre) }))));
    }
    case 'conversation.ajouter': {
      // Le client verse la question (en clair, déjà vue par l'utilisateur) et la réponse ré-identifiée.
      if (!(await accesDossier(p.dossier_id))) return json({ erreur: 'dossier inaccessible' }, 404);
      const tours = Array.isArray(p.tours) ? p.tours.slice(0, 2) : [];
      if (!tours.length || tours.some((t: { role: string; texte: string }) => !['user', 'assistant'].includes(t.role) || typeof t.texte !== 'string' || t.texte.length > 20000))
        return json({ erreur: 'tours invalides' }, 400);
      const lignes = await Promise.all(tours.map(async (t: { role: string; texte: string; source?: string }) => ({
        id: nouvelId('cnv'), dossier_id: p.dossier_id, role: t.role, texte_chiffre: await chiffrer(u.orgId, t.texte),
        source: t.source ?? null, requete_id: p.requete_id ?? null })));
      const { error } = await u.admin.from('dossier_conversation').insert(lignes);
      return error ? json({ erreur: 'écriture impossible' }, 500) : json({ ids: lignes.map((l) => l.id) });
    }
    default:
      return json({ erreur: 'action inconnue' }, 400);
  }
});

// Gestion des membres (EXPLOITATION.md §5, AUTORISATIONS.md). Réservée à l'administrateur avec
// double authentification ; chaque action est journalisée. L'ouverture d'une organisation est
// réservée à l'éditeur (jeton OUVERTURE_JETON, utilisé depuis la future console super-admin).
import { CORS, clientAdmin, exiger, journaliser, json, nouvelId, utilisateur } from '../_shared/auth.ts';

const ROLES = ['militant', 'communication', 'tresorier', 'admin'];
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const SITE = Deno.env.get('SITE_URL') ?? '';

type Admin = ReturnType<typeof clientAdmin>;

// Invite un compte Auth (ou réutilise celui qui existe : élu dans plusieurs organisations).
async function compteAuth(admin: Admin, email: string): Promise<string> {
  const { data, error } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo: `${SITE}/bienvenue` });
  if (!error && data.user) return data.user.id;
  // Déjà inscrit : on retrouve l'identifiant et on envoie un lien de connexion.
  const { data: existant } = await admin.schema('api').rpc('auth_id_par_email', { p_email: email });
  if (!existant) throw new Error('invitation impossible');
  await admin.auth.signInWithOtp({ email, options: { shouldCreateUser: false, emailRedirectTo: `${SITE}/bienvenue` } });
  return existant as string;
}

async function creerPersonne(admin: Admin, orgId: string, p: Record<string, string>, roles: string[], par: string | null) {
  const email = String(p.email ?? '').trim().toLowerCase();
  if (!EMAIL.test(email) || !p.prenom?.trim() || !p.nom?.trim()) throw new Error('prénom, nom et e-mail valides requis');
  if (!roles.length || roles.some((r) => !ROLES.includes(r))) throw new Error('rôles invalides');
  const uid = await compteAuth(admin, email);
  const id = nouvelId('per');
  const { error } = await admin.from('personne').insert({
    id, organisation_id: orgId, prenom: p.prenom.trim(), nom: p.nom.trim(), email, mandat: p.mandat ?? null,
    mandat_debut: p.mandat_debut ?? null, mandat_fin: p.mandat_fin ?? null, etablissement_id: p.etablissement_id ?? null,
    bureau: p.bureau === 'true' || (p.bureau as unknown) === true, auth_user_id: uid,
  });
  if (error) throw new Error(error.code === '23505' ? 'cette personne est déjà membre' : 'création impossible');
  await admin.from('personne_role').insert(roles.map((role) => ({ personne_id: id, role, attribue_par: par })));
  return id;
}

async function compterRole(admin: Admin, orgId: string, role: string, sauf?: string) {
  let q = admin.from('personne_role').select('personne_id, personne!inner(organisation_id, desactive_le)', { count: 'exact', head: true })
    .eq('role', role).eq('personne.organisation_id', orgId).is('personne.desactive_le', null);
  if (sauf) q = q.neq('personne_id', sauf);
  return (await q).count ?? 0;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  const corps = await req.json().catch(() => ({}));
  const { action, ...p } = corps;

  // ---- Ouverture d'organisation : éditeur uniquement, deux administrateurs obligatoires
  if (action === 'organisation.ouvrir') {
    const jeton = Deno.env.get('OUVERTURE_JETON');
    if (!jeton || req.headers.get('x-ouverture') !== jeton) return json({ erreur: 'interdit' }, 403);
    const admins = Array.isArray(p.administrateurs) ? p.administrateurs : [];
    if (admins.length < 2) return json({ erreur: 'deux administrateurs au minimum (EXPLOITATION.md §5)' }, 400);
    if (!['cse', 'section', 'ud'].includes(p.type)) return json({ erreur: 'type invalide' }, 400);
    const admin = clientAdmin();
    const orgId = nouvelId('org');
    const { error } = await admin.from('organisation').insert({ id: orgId, nom: p.nom, sigle: p.sigle, type: p.type, idcc: p.idcc ?? null,
      sieges_souscrits: p.sieges ?? 0 });
    if (error) return json({ erreur: 'création impossible' }, 400);
    try {
      const ids = [];
      for (const a of admins) ids.push(await creerPersonne(admin, orgId, a, ['militant', 'admin'], null));
      await admin.from('audit').insert({ organisation_id: orgId, action: 'organisation.ouvrir', ressource_type: 'organisation', ressource_id: orgId });
      return json({ organisation_id: orgId, administrateurs: ids });
    } catch (e) {
      await admin.from('organisation').delete().eq('id', orgId);
      return json({ erreur: (e as Error).message }, 400);
    }
  }

  const u = await utilisateur(req);
  if (u instanceof Response) return u;
  const refus = exiger(u, 'admin');
  if (refus) return refus;

  try {
    switch (action) {
      case 'membre.inviter': {
        const roles: string[] = Array.isArray(p.roles) && p.roles.length ? p.roles : ['militant'];
        if (roles.includes('tresorier') && (await compterRole(u.admin, u.orgId, 'tresorier')) >= 2)
          return json({ erreur: 'deux trésoriers au plus par organisation' }, 409);
        const { data: org } = await u.admin.from('organisation').select('sieges_souscrits').eq('id', u.orgId).single();
        const { count } = await u.admin.from('personne').select('id', { count: 'exact', head: true }).eq('organisation_id', u.orgId).is('desactive_le', null);
        if (org && org.sieges_souscrits > 0 && (count ?? 0) >= org.sieges_souscrits) return json({ erreur: 'plus de siège disponible' }, 409);
        const id = await creerPersonne(u.admin, u.orgId, p, roles, u.personneId);
        await journaliser(u, 'membre.inviter', 'personne', id, roles.join(','));
        return json({ id });
      }

      case 'membre.roles': {
        const roles: string[] = p.roles ?? [];
        if (!roles.length || roles.some((r) => !ROLES.includes(r))) return json({ erreur: 'rôles invalides' }, 400);
        const { data: cible } = await u.admin.from('personne').select('id').eq('id', p.personne_id).eq('organisation_id', u.orgId).is('desactive_le', null).maybeSingle();
        if (!cible) return json({ erreur: 'membre introuvable' }, 404);
        if (!roles.includes('admin') && (await compterRole(u.admin, u.orgId, 'admin', p.personne_id)) < 2)
          return json({ erreur: "l'organisation doit garder deux administrateurs" }, 409);
        if (roles.includes('tresorier') && (await compterRole(u.admin, u.orgId, 'tresorier', p.personne_id)) >= 2)
          return json({ erreur: 'deux trésoriers au plus par organisation' }, 409);
        await u.admin.from('personne_role').delete().eq('personne_id', p.personne_id);
        await u.admin.from('personne_role').insert(roles.map((role) => ({ personne_id: p.personne_id, role, attribue_par: u.personneId })));
        await journaliser(u, 'membre.roles', 'personne', p.personne_id, roles.join(','), roles.includes('tresorier'));
        return json({ ok: true });
      }

      case 'membre.desactiver': {
        // Fin de mandat : désactivation, réattribution des dossiers, coupure des sessions.
        if (p.personne_id === u.personneId) return json({ erreur: 'impossible de se désactiver soi-même' }, 400);
        if (!p.repreneur_id) return json({ erreur: 'désignez un repreneur pour ses dossiers' }, 400);
        const { data: cible } = await u.admin.from('personne').select('id, auth_user_id').eq('id', p.personne_id).eq('organisation_id', u.orgId).is('desactive_le', null).maybeSingle();
        const { data: rep } = await u.admin.from('personne').select('id').eq('id', p.repreneur_id).eq('organisation_id', u.orgId).is('desactive_le', null).maybeSingle();
        if (!cible || !rep) return json({ erreur: 'membre ou repreneur introuvable' }, 404);
        const { data: roles } = await u.admin.from('personne_role').select('role').eq('personne_id', cible.id);
        if (roles?.some((r) => r.role === 'admin') && (await compterRole(u.admin, u.orgId, 'admin', cible.id)) < 2)
          return json({ erreur: "l'organisation doit garder deux administrateurs" }, 409);
        const maintenant = new Date().toISOString();
        await u.admin.from('dossier').update({ referent_id: rep.id }).eq('referent_id', cible.id).eq('organisation_id', u.orgId);
        await u.admin.from('dossier_acces').delete().eq('personne_id', cible.id);
        await u.admin.from('fil_participant').delete().eq('personne_id', cible.id);
        await u.admin.from('appareil').update({ revoque_le: maintenant }).eq('personne_id', cible.id);
        await u.admin.from('personne').update({ desactive_le: maintenant, mandat_fin: maintenant.slice(0, 10) }).eq('id', cible.id);
        // Plus aucune personne active pour ce compte : sessions coupées (le jeton en cours est déjà
        // inopérant, app.personne_id() revérifiant desactive_le à chaque requête).
        if (cible.auth_user_id) {
          const { count } = await u.admin.from('personne').select('id', { count: 'exact', head: true }).eq('auth_user_id', cible.auth_user_id).is('desactive_le', null);
          if (!count) await u.admin.auth.admin.updateUserById(cible.auth_user_id, { ban_duration: '876000h' });
        }
        await journaliser(u, 'membre.desactiver', 'personne', cible.id, p.motif ?? 'fin de mandat');
        return json({ ok: true });
      }

      case 'membre.mfa_reinitialiser': {
        // Perte du téléphone : supprime les facteurs TOTP ; le membre se réenrôle à la connexion suivante.
        const { data: cible } = await u.admin.from('personne').select('auth_user_id').eq('id', p.personne_id).eq('organisation_id', u.orgId).maybeSingle();
        if (!cible?.auth_user_id) return json({ erreur: 'membre introuvable' }, 404);
        const { data } = await u.admin.auth.admin.mfa.listFactors({ userId: cible.auth_user_id });
        for (const f of data?.factors ?? []) await u.admin.auth.admin.mfa.deleteFactor({ id: f.id, userId: cible.auth_user_id });
        await journaliser(u, 'membre.mfa_reinitialiser', 'personne', p.personne_id, p.motif ?? null);
        return json({ ok: true });
      }

      case 'membre.bureau': {
        await u.admin.from('personne').update({ bureau: !!p.bureau }).eq('id', p.personne_id).eq('organisation_id', u.orgId);
        await journaliser(u, 'membre.bureau', 'personne', p.personne_id, String(!!p.bureau));
        return json({ ok: true });
      }

      default:
        return json({ erreur: 'action inconnue' }, 400);
    }
  } catch (e) {
    return json({ erreur: (e as Error).message }, 400);
  }
});

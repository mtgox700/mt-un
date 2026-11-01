import { useState } from 'react';
import type { Moi } from '../lib/supabase';
import { ROLES, useActionMembre, useMembres, type Membre, type Role } from '../lib/gestion';
import { date } from '../lib/donnees';
import { EnTete } from '../ui/Coque';
import { Alerte, Avatar, Bloc, Bouton, Champ, Chargement, Icone, I, Pastille, Vide, s } from '../ui/kit';

const libRole = (r: Role) => ROLES.find((x) => x.id === r)?.libelle ?? r;

export function Membres({ moi }: { moi: Moi }) {
  const { data, isLoading, error } = useMembres();
  const [invite, setInvite] = useState(false);
  const [ouvert, setOuvert] = useState<string | null>(null);
  const n = data?.membres.length ?? 0;

  return (
    <>
      <EnTete titre="Membres" sous="Comptes des élus et militants. Chaque action est inscrite au journal d'audit."
        action={!invite && <Bouton variante="primaire" onClick={() => setInvite(true)} disabled={!!data?.sieges && n >= data.sieges}><Icone d={I.plus} taille={16} />Inviter</Bouton>} />
      {data && !!data.sieges && <p style={{ ...s.discret, margin: '-10px 0 18px' }}>{n} siège{n > 1 ? 's' : ''} occupé{n > 1 ? 's' : ''} sur {data.sieges}.</p>}
      {invite && <Invitation fermer={() => setInvite(false)} />}
      {error && <Alerte>{(error as Error).message}</Alerte>}
      {isLoading ? <Chargement /> : !data?.membres.length ? <Vide>Aucun membre.</Vide> : (
        <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {data.membres.map((m) => <Ligne key={m.id} m={m} moi={moi} tous={data.membres} ouvert={ouvert === m.id} basculer={() => setOuvert(ouvert === m.id ? null : m.id)} />)}
        </ul>
      )}
    </>
  );
}

function Ligne({ m, moi, tous, ouvert, basculer }: { m: Membre; moi: Moi; tous: Membre[]; ouvert: boolean; basculer: () => void }) {
  const action = useActionMembre();
  const [roles, setRoles] = useState<Role[]>(m.roles);
  const [fin, setFin] = useState<{ repreneur: string; motif: string } | null>(null);
  const [ok, setOk] = useState('');
  const soi = m.id === moi.personne_id;
  const faire = (corps: Record<string, unknown>, message: string, apres?: () => void) => {
    setOk(''); action.mutate(corps, { onSuccess: () => { setOk(message); apres?.(); } });
  };
  const sensible = m.roles.includes('admin') || m.roles.includes('tresorier');

  return (
    <li style={{ ...s.carte, padding: 0 }}>
      <button type="button" onClick={basculer} aria-expanded={ouvert} style={{ width: '100%', border: 'none', background: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 12, padding: '14px 18px', textAlign: 'left', fontFamily: 'inherit', flexWrap: 'wrap' }}>
        <Avatar p={m} taille={38} />
        <span style={{ flex: '1 1 200px', minWidth: 0 }}>
          <span style={{ display: 'block', fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{m.prenom} {m.nom}{soi && <span style={{ fontWeight: 500, color: 'var(--ink5)' }}> (vous)</span>}</span>
          <span style={{ ...s.discret, fontSize: 12.5 }}>{m.mandat ?? m.email}{m.mandat_fin ? ` · mandat jusqu'au ${date(m.mandat_fin)}` : ''}</span>
        </span>
        <span style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {m.roles.filter((r) => r !== 'militant').map((r) => <Pastille key={r} ton="accent">{libRole(r)}</Pastille>)}
          {m.bureau && <Pastille>Bureau</Pastille>}
          {!m.invitation_acceptee && <Pastille ton="alerte">Invitation en attente</Pastille>}
          {sensible && !m.double_auth && m.invitation_acceptee && <Pastille ton="danger">Double auth. non activée</Pastille>}
        </span>
      </button>

      {ouvert && (
        <div style={{ borderTop: '1px solid var(--bd)', padding: 18, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <span style={s.surtitre}>Rôles</span>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 8 }}>
              {ROLES.map((r) => (
                <label key={r.id} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', border: '1px solid var(--bd2)', borderRadius: 14, padding: '10px 12px', cursor: 'pointer', background: roles.includes(r.id) ? 'var(--acBg2)' : 'var(--surface)' }}>
                  <input type="checkbox" checked={roles.includes(r.id)} onChange={(e) => setRoles(e.target.checked ? [...roles, r.id] : roles.filter((x) => x !== r.id))} style={{ width: 18, height: 18, marginTop: 1 }} />
                  <span><span style={{ display: 'block', fontSize: 13.5, fontWeight: 600 }}>{r.libelle}</span><span style={{ ...s.discret, fontSize: 11.5 }}>{r.aide}</span></span>
                </label>
              ))}
            </div>
            {roles.join() !== m.roles.join() && <Bouton variante="primaire" style={{ alignSelf: 'flex-start' }} disabled={!roles.length || action.isPending}
              onClick={() => faire({ action: 'membre.roles', personne_id: m.id, roles }, 'Rôles mis à jour. Ils s\'appliquent à sa prochaine requête.')}>Enregistrer les rôles</Bouton>}
          </div>

          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <Bouton onClick={() => faire({ action: 'membre.bureau', personne_id: m.id, bureau: !m.bureau }, m.bureau ? 'Retiré du bureau.' : 'Ajouté au bureau.')}>{m.bureau ? 'Retirer du bureau' : 'Ajouter au bureau'}</Bouton>
            {m.double_auth && !soi && <Bouton onClick={() => { const motif = prompt('Motif de la réinitialisation (ex. : téléphone perdu) :'); if (motif?.trim()) faire({ action: 'membre.mfa_reinitialiser', personne_id: m.id, motif: motif.trim() }, 'Double authentification réinitialisée : le membre la réactivera à sa prochaine connexion.'); }}>Réinitialiser la double authentification</Bouton>}
            {!soi && !fin && <Bouton variante="discret" style={{ color: 'var(--dangerTx2)' }} onClick={() => setFin({ repreneur: '', motif: 'Fin de mandat' })}>Fin de mandat…</Bouton>}
          </div>

          {fin && (
            <section style={{ border: '1px solid var(--dangerBd)', background: 'var(--dangerBg)', borderRadius: 16, padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
              <p style={{ ...s.texte, margin: 0, color: 'var(--dangerTx2)' }}>L'accès est coupé immédiatement. Ses dossiers sont confiés au repreneur ; il est retiré des dossiers partagés et des fils de discussion.</p>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 10 }}>
                <Champ libelle="Repreneur des dossiers"><select value={fin.repreneur} onChange={(e) => setFin({ ...fin, repreneur: e.target.value })} style={s.saisie}>
                  <option value="" disabled>Choisir…</option>{tous.filter((x) => x.id !== m.id).map((x) => <option key={x.id} value={x.id}>{x.prenom} {x.nom}</option>)}</select></Champ>
                <Champ libelle="Motif"><input value={fin.motif} onChange={(e) => setFin({ ...fin, motif: e.target.value })} style={s.saisie} /></Champ>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <Bouton variante="danger" disabled={!fin.repreneur || !fin.motif.trim() || action.isPending}
                  onClick={() => faire({ action: 'membre.desactiver', personne_id: m.id, repreneur_id: fin.repreneur, motif: fin.motif.trim() }, '', () => setFin(null))}>Désactiver le compte</Bouton>
                <Bouton variante="discret" onClick={() => setFin(null)}>Annuler</Bouton>
              </div>
            </section>
          )}
          {action.error && <Alerte>{(action.error as Error).message}</Alerte>}
          {ok && <Alerte ton="ok">{ok}</Alerte>}
        </div>
      )}
    </li>
  );
}

function Invitation({ fermer }: { fermer: () => void }) {
  const action = useActionMembre();
  const [f, setF] = useState({ prenom: '', nom: '', email: '', mandat: '', mandat_fin: '' });
  const [roles, setRoles] = useState<Role[]>(['militant']);
  const maj = (k: keyof typeof f) => (e: { target: { value: string } }) => setF({ ...f, [k]: e.target.value });
  return (
    <Bloc titre="Inviter un membre" style={{ marginBottom: 18 }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12 }}>
        <Champ libelle="Prénom"><input value={f.prenom} onChange={maj('prenom')} style={s.saisie} /></Champ>
        <Champ libelle="Nom"><input value={f.nom} onChange={maj('nom')} style={s.saisie} /></Champ>
        <Champ libelle="E-mail"><input type="email" value={f.email} onChange={maj('email')} style={s.saisie} /></Champ>
        <Champ libelle="Mandat"><input value={f.mandat} onChange={maj('mandat')} placeholder="Ex. : élue titulaire CSE" style={s.saisie} /></Champ>
        <Champ libelle="Fin de mandat" aide="Le compte sera désactivé automatiquement à cette date."><input type="date" value={f.mandat_fin} onChange={maj('mandat_fin')} style={s.saisie} /></Champ>
      </div>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {ROLES.map((r) => (
          <label key={r.id} style={{ display: 'inline-flex', gap: 8, alignItems: 'center', border: '1px solid var(--bd2)', borderRadius: 99, padding: '8px 14px', minHeight: 40, boxSizing: 'border-box', cursor: 'pointer', fontSize: 13, fontWeight: 600, background: roles.includes(r.id) ? 'var(--acBg)' : 'var(--surface)', color: roles.includes(r.id) ? 'var(--acTx2)' : 'var(--ink4)' }}>
            <input type="checkbox" checked={roles.includes(r.id)} onChange={(e) => setRoles(e.target.checked ? [...roles, r.id] : roles.filter((x) => x !== r.id))} />{r.libelle}
          </label>
        ))}
      </div>
      {action.error && <Alerte>{(action.error as Error).message}</Alerte>}
      <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
        <Bouton variante="discret" onClick={fermer}>Annuler</Bouton>
        <Bouton variante="primaire" disabled={!f.prenom.trim() || !f.nom.trim() || !f.email.trim() || !roles.length || action.isPending}
          onClick={() => action.mutate({ action: 'membre.inviter', ...f, mandat: f.mandat || null, mandat_fin: f.mandat_fin || null, roles }, { onSuccess: fermer })}>
          {action.isPending ? 'Envoi…' : "Envoyer l'invitation"}</Bouton>
      </div>
    </Bloc>
  );
}

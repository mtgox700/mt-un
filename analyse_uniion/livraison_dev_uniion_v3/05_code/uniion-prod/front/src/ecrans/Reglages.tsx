import { useEffect, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase, aRole, mfaRequise, type Moi } from '../lib/supabase';
import { useExtensions } from '../lib/extensions';
import { appliquerTheme, useOrganisations, useProfil, type Theme } from '../lib/gestion';
import { date } from '../lib/donnees';
import { EnTete } from '../ui/Coque';
import { Alerte, Bloc, Bouton, Champ, Chargement, Pastille, s } from '../ui/kit';

export function Reglages({ moi }: { moi: Moi }) {
  return (
    <>
      <EnTete titre="Réglages" />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 380px), 1fr))', gap: 18, alignItems: 'start' }}>
        <Profil moi={moi} />
        <Securite moi={moi} />
        <Organisations moi={moi} />
        <Apparence />
        {aRole(moi, 'admin') && <Extensions moi={moi} />}
      </div>
    </>
  );
}

function Profil({ moi }: { moi: Moi }) {
  const qc = useQueryClient();
  const { data, isLoading } = useProfil();
  const [tel, setTel] = useState<string | null>(null);
  const [etat, setEtat] = useState<'' | 'ok' | 'erreur'>('');
  const enregistrer = async (modif: { telephone?: string | null; coord_visibles?: boolean }) => {
    setEtat('');
    const { error } = await supabase.from('personne').update(modif).eq('id', moi.personne_id!);
    setEtat(error ? 'erreur' : 'ok');
    if (!error) { setTel(null); qc.invalidateQueries({ queryKey: ['profil'] }); }
  };
  if (isLoading || !data) return <Bloc titre="Mon profil"><Chargement /></Bloc>;
  return (
    <Bloc titre="Mon profil">
      <dl style={{ margin: 0, display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '8px 16px', fontSize: 13.5 }}>
        <dt style={{ color: 'var(--ink5)' }}>Nom</dt><dd style={{ margin: 0, fontWeight: 600 }}>{data.prenom} {data.nom}</dd>
        <dt style={{ color: 'var(--ink5)' }}>E-mail</dt><dd style={{ margin: 0 }}>{data.email}</dd>
        <dt style={{ color: 'var(--ink5)' }}>Mandat</dt><dd style={{ margin: 0 }}>{data.mandat ?? '—'}{data.mandat_fin ? ` · jusqu'au ${date(data.mandat_fin)}` : ''}</dd>
      </dl>
      <p style={{ ...s.discret, margin: 0 }}>Nom, e-mail et mandat sont tenus par un administrateur de votre organisation.</p>
      <Champ libelle="Téléphone">
        <div style={{ display: 'flex', gap: 8 }}>
          <input type="tel" value={tel ?? data.telephone ?? ''} onChange={(e) => setTel(e.target.value)} style={{ ...s.saisie, flex: 1 }} />
          {tel !== null && tel !== (data.telephone ?? '') && <Bouton variante="primaire" onClick={() => enregistrer({ telephone: tel.trim() || null })}>Enregistrer</Bouton>}
        </div>
      </Champ>
      <label style={{ display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 13.5, color: 'var(--ink3)', lineHeight: 1.5 }}>
        <input type="checkbox" checked={data.coord_visibles} onChange={(e) => enregistrer({ coord_visibles: e.target.checked })} style={{ width: 18, height: 18, marginTop: 2 }} />
        <span>Afficher mon e-mail et mon téléphone aux autres membres de l'organisation</span>
      </label>
      {etat === 'ok' && <Alerte ton="ok">Enregistré.</Alerte>}
      {etat === 'erreur' && <Alerte>Enregistrement impossible.</Alerte>}
    </Bloc>
  );
}

function Securite({ moi }: { moi: Moi }) {
  const [facteurs, setFacteurs] = useState<{ id: string; friendly_name?: string; created_at: string }[] | null>(null);
  const [enrol, setEnrol] = useState<{ id: string; qr: string; secret: string } | null>(null);
  const [code, setCode] = useState('');
  const [mdp, setMdp] = useState<{ etape: 'code' | 'saisie'; nonce: string; nouveau: string } | null>(null);
  const [msg, setMsg] = useState<{ ton: 'ok' | 'danger'; texte: string } | null>(null);
  const charger = async () => { const { data } = await supabase.auth.mfa.listFactors(); setFacteurs(data?.totp.filter((f) => f.status === 'verified') ?? []); };
  useEffect(() => { charger(); }, []);

  const commencer = async () => {
    setMsg(null);
    const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName: 'uniion ' + new Date().toLocaleDateString('fr-FR') });
    if (error || !data) { setMsg({ ton: 'danger', texte: "Impossible de préparer l'activation." }); return; }
    setEnrol({ id: data.id, qr: data.totp.qr_code, secret: data.totp.secret });
  };
  const confirmer = async () => {
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: enrol!.id, code: code.replace(/\s/g, '') });
    if (error) { setMsg({ ton: 'danger', texte: 'Code incorrect ou expiré.' }); return; }
    setEnrol(null); setCode(''); setMsg({ ton: 'ok', texte: 'Double authentification activée.' }); charger();
  };
  const demanderCode = async () => {
    setMsg(null);
    const { error } = await supabase.auth.reauthenticate();
    if (error) { setMsg({ ton: 'danger', texte: 'Envoi du code impossible. Réessayez dans une minute.' }); return; }
    setMdp({ etape: 'code', nonce: '', nouveau: '' });
  };
  const changer = async () => {
    const { error } = await supabase.auth.updateUser({ password: mdp!.nouveau, nonce: mdp!.nonce.trim() });
    if (error) { setMsg({ ton: 'danger', texte: /weak|password/i.test(error.message) ? 'Mot de passe trop faible : 12 caractères, majuscules, minuscules, chiffres et symboles.' : 'Code incorrect ou expiré.' }); return; }
    setMdp(null); setMsg({ ton: 'ok', texte: 'Mot de passe modifié.' });
  };

  return (
    <Bloc titre="Sécurité">
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <span style={{ flex: 1, fontSize: 14, fontWeight: 600 }}>Double authentification</span>
        {facteurs === null ? <Chargement /> : facteurs.length ? <Pastille ton="ok">Activée</Pastille> : <Pastille ton="alerte">Non activée</Pastille>}
      </div>
      <p style={{ ...s.discret, margin: 0 }}>{mfaRequise(moi) ? 'Obligatoire pour votre rôle. En cas de perte du téléphone, un administrateur peut la réinitialiser.' : 'Recommandée : un code à 6 chiffres vous sera demandé à chaque connexion.'}</p>
      {facteurs && !facteurs.length && !enrol && <Bouton variante="primaire" style={{ alignSelf: 'flex-start' }} onClick={commencer}>Activer</Bouton>}
      {enrol && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'flex-start' }}>
          <img src={enrol.qr} alt="QR code à scanner avec votre application d'authentification" style={{ width: 180, height: 180, background: '#FFFFFF', borderRadius: 12, padding: 8 }} />
          <code style={{ fontSize: 12, wordBreak: 'break-all', color: 'var(--ink4)' }}>Clé manuelle : {enrol.secret}</code>
          <div style={{ display: 'flex', gap: 8 }}>
            <input inputMode="numeric" autoComplete="one-time-code" value={code} onChange={(e) => setCode(e.target.value)} aria-label="Code à 6 chiffres" placeholder="123 456" style={{ ...s.saisie, width: 140, letterSpacing: 3, textAlign: 'center' }} />
            <Bouton variante="primaire" onClick={confirmer} disabled={code.replace(/\s/g, '').length !== 6}>Valider</Bouton>
          </div>
        </div>
      )}

      <div style={{ borderTop: '1px solid var(--bd)', paddingTop: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <span style={{ fontSize: 14, fontWeight: 600 }}>Mot de passe</span>
        {!mdp ? <Bouton style={{ alignSelf: 'flex-start' }} onClick={demanderCode}>Changer le mot de passe</Bouton> : <>
          <p style={{ ...s.discret, margin: 0 }}>Un code de confirmation vient de vous être envoyé par e-mail.</p>
          <Champ libelle="Code reçu par e-mail"><input inputMode="numeric" autoComplete="one-time-code" value={mdp.nonce} onChange={(e) => setMdp({ ...mdp, nonce: e.target.value })} style={s.saisie} /></Champ>
          <Champ libelle="Nouveau mot de passe" aide="12 caractères au moins, avec majuscules, minuscules, chiffres et symboles."><input type="password" autoComplete="new-password" value={mdp.nouveau} onChange={(e) => setMdp({ ...mdp, nouveau: e.target.value })} style={s.saisie} /></Champ>
          <div style={{ display: 'flex', gap: 8 }}>
            <Bouton variante="primaire" onClick={changer} disabled={!mdp.nonce.trim() || mdp.nouveau.length < 12}>Modifier</Bouton>
            <Bouton variante="discret" onClick={() => setMdp(null)}>Annuler</Bouton>
          </div>
        </>}
      </div>
      {msg && <Alerte ton={msg.ton}>{msg.texte}</Alerte>}
      <Bouton variante="discret" style={{ alignSelf: 'flex-start', color: 'var(--dangerTx2)' }} onClick={() => supabase.auth.signOut({ scope: 'global' })}>Se déconnecter de tous les appareils</Bouton>
    </Bloc>
  );
}

function Organisations({ moi }: { moi: Moi }) {
  const { data } = useOrganisations();
  const [erreur, setErreur] = useState('');
  if (!data || data.length < 2) return null;
  const basculer = async (org: string) => {
    setErreur('');
    const { error } = await supabase.schema('api').rpc('basculer_organisation', { p_org: org });
    if (error) { setErreur('Bascule impossible.'); return; }
    await supabase.auth.refreshSession();
    location.assign('/');  // repart d'un état vierge : aucune donnée de l'organisation précédente ne reste en mémoire
  };
  return (
    <Bloc titre="Mes organisations">
      <p style={{ ...s.discret, margin: 0 }}>Vous êtes membre de plusieurs organisations. Leurs données restent strictement séparées.</p>
      <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>
        {data.map((o) => (
          <li key={o.organisation_id} style={{ display: 'flex', alignItems: 'center', gap: 10, border: '1px solid var(--bd)', borderRadius: 14, padding: '10px 12px' }}>
            <span style={{ flex: 1, fontSize: 13.5, fontWeight: 600 }}>{o.sigle} <span style={{ fontWeight: 400, color: 'var(--ink5)' }}>· {o.nom}</span></span>
            {o.organisation_id === moi.org_id ? <Pastille ton="accent">Active</Pastille> : <Bouton style={{ padding: '7px 12px', minHeight: 36, fontSize: 12 }} onClick={() => basculer(o.organisation_id)}>Basculer</Bouton>}
          </li>
        ))}
      </ul>
      {erreur && <Alerte>{erreur}</Alerte>}
    </Bloc>
  );
}

function Apparence() {
  const [t, setT] = useState<Theme>(() => (localStorage.getItem('uniion.theme') as Theme) ?? 'systeme');
  const choisir = (x: Theme) => { setT(x); localStorage.setItem('uniion.theme', x); appliquerTheme(x); };
  return (
    <Bloc titre="Apparence">
      <div role="radiogroup" aria-label="Thème" style={{ display: 'flex', gap: 4, background: 'var(--chip)', borderRadius: 99, padding: 4, alignSelf: 'flex-start' }}>
        {([['clair', 'Clair'], ['sombre', 'Sombre'], ['systeme', 'Comme le système']] as const).map(([v, l]) => (
          <button key={v} type="button" role="radio" aria-checked={t === v} onClick={() => choisir(v)} style={{ cursor: 'pointer', border: 'none', borderRadius: 99, padding: '8px 14px', minHeight: 36, fontSize: 12.5, fontWeight: 700, fontFamily: 'inherit',
            background: t === v ? 'var(--surface)' : 'transparent', color: t === v ? 'var(--ink)' : 'var(--ink5)', boxShadow: t === v ? '0 1px 3px rgba(17,24,39,.08)' : 'none' }}>{l}</button>
        ))}
      </div>
    </Bloc>
  );
}

// Extensions : seules celles du registre uniion (signées) peuvent être activées ; chaque style ou bloc se coupe un à un.
interface Registre { id: string; version: string; nom: string; editeur: string; publiee_le: string }
interface Activation { extension_id: string; version: string; elements_desactives: string[] }
function Extensions({ moi }: { moi: Moi }) {
  const qc = useQueryClient();
  const ext = useExtensions();
  const [erreur, setErreur] = useState('');
  const { data: registre } = useQuery({ queryKey: ['registre-ext'], queryFn: async () => {
    const { data } = await supabase.from('extension').select('id, version, nom, editeur, publiee_le').order('publiee_le', { ascending: false });
    return (data ?? []) as Registre[];
  } });
  const { data: actives } = useQuery({ queryKey: ['activations-ext'], queryFn: async () => {
    const { data } = await supabase.from('extension_activation').select('extension_id, version, elements_desactives');
    return (data ?? []) as Activation[];
  } });
  const apres = (e: { error: unknown }) => {
    if (e.error) { setErreur('Action impossible.'); return; }
    setErreur(''); qc.invalidateQueries({ queryKey: ['activations-ext'] });
    // Le code d'une extension chargée reste en mémoire : un rechargement applique le changement partout.
    qc.invalidateQueries({ queryKey: ['extensions'] });
  };
  const derniere = new Map<string, Registre>();
  (registre ?? []).forEach((x) => { if (!derniere.has(x.id)) derniere.set(x.id, x); });
  const activer = async (x: Registre) => apres(await supabase.from('extension_activation').upsert({ organisation_id: moi.org_id, extension_id: x.id, version: x.version, active_par: moi.personne_id, elements_desactives: [] }));
  const couper = async (x: Registre) => apres(await supabase.from('extension_activation').delete().eq('extension_id', x.id));
  const basculer = async (a: Activation, el: string) => {
    const l = a.elements_desactives.includes(el) ? a.elements_desactives.filter((e) => e !== el) : [...a.elements_desactives, el];
    apres(await supabase.from('extension_activation').update({ elements_desactives: l, active_par: moi.personne_id }).eq('extension_id', a.extension_id));
  };
  return (
    <Bloc titre="Extensions">
      <p style={{ ...s.discret, margin: 0 }}>Seules les extensions publiées et signées par uniion sont proposées. Aucune ne peut envoyer de donnée hors de l'application.</p>
      {![...derniere.values()].length && <p style={{ ...s.discret, margin: 0 }}>Aucune extension au registre.</p>}
      {[...derniere.values()].map((x) => {
        const a = actives?.find((y) => y.extension_id === x.id);
        const maj = a && a.version !== x.version;
        const elements = [...ext.styles.filter((st) => st.ext === x.id).map((st) => ({ id: st.id, libelle: st.label, genre: 'Style' })),
                          ...ext.blocs.filter((b) => b.ext === x.id).map((b) => ({ id: b.type, libelle: b.label, genre: 'Bloc' }))];
        const coupes = a?.elements_desactives ?? [];
        return (
          <div key={x.id} style={{ border: '1px solid var(--bd)', borderRadius: 14, padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <span style={{ flex: 1, fontSize: 14, fontWeight: 600 }}>{x.nom} <span style={{ fontWeight: 400, color: 'var(--ink5)' }}>{x.version} · {x.editeur}</span></span>
              {a ? <Pastille ton="ok">Active{maj ? ` (${a.version})` : ''}</Pastille> : <Pastille>Inactive</Pastille>}
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {!a && <Bouton variante="primaire" onClick={() => activer(x)}>Activer</Bouton>}
              {maj && <Bouton variante="primaire" onClick={() => activer(x)}>Passer en {x.version}</Bouton>}
              {a && <Bouton variante="discret" style={{ color: 'var(--dangerTx2)' }} onClick={() => couper(x)}>Désactiver</Bouton>}
            </div>
            {a && !!elements.length && (
              <details>
                <summary style={{ cursor: 'pointer', fontSize: 13, fontWeight: 600, minHeight: 32 }}>Styles et blocs proposés ({elements.length - coupes.length}/{elements.length})</summary>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 6, marginTop: 8 }}>
                  {elements.map((el) => (
                    <label key={el.id} style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 13, minHeight: 32 }}>
                      <input type="checkbox" checked={!coupes.includes(el.id)} onChange={() => basculer(a, el.id)} style={{ width: 16, height: 16 }} />
                      <span>{el.libelle} <span style={{ color: 'var(--ink5)', fontSize: 11.5 }}>{el.genre}</span></span>
                    </label>
                  ))}
                </div>
              </details>
            )}
          </div>
        );
      })}
      {ext.erreurs.map((m) => <Alerte key={m}>{m}</Alerte>)}
      {erreur && <Alerte>{erreur}</Alerte>}
    </Bloc>
  );
}

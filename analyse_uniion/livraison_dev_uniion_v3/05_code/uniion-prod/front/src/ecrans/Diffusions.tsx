import { useState, type ReactNode } from 'react';
import { aRole, type Moi } from '../lib/supabase';
import { COTISATION, useCampagnes, useCreerCampagne, useCreerListe, useCriteres, useEffectif, useEtablissements, useLancerCampagne, useListes, useSuivi, type Campagne, type Liste } from '../lib/gestion';
import { heure } from '../lib/donnees';
import { EnTete } from '../ui/Coque';
import { Alerte, Bloc, Bouton, Champ, Chargement, Icone, I, Pastille, Vide, s } from '../ui/kit';

const ETATS: Record<string, string> = { en_attente: 'En attente', envoye: 'Envoyés', echec: 'Échecs', desinscrit: 'Désinscrits depuis' };

export function Diffusions({ moi }: { moi: Moi }) {
  const peutLancer = aRole(moi, 'tresorier') || aRole(moi, 'admin');
  const tresorier = aRole(moi, 'tresorier');
  const listes = useListes();
  const campagnes = useCampagnes();
  const [nouvelleListe, setNouvelleListe] = useState(false);
  const [nouvelle, setNouvelle] = useState(false);
  return (
    <>
      <EnTete titre="Diffusions" sous="E-mails aux adhérents. Seuls ceux qui ont consenti et ne se sont pas désinscrits les reçoivent, vérifié au moment de chaque envoi. Chaque message porte un lien de désinscription."
        action={!nouvelle && <Bouton variante="primaire" onClick={() => setNouvelle(true)}><Icone d={I.plus} taille={16} />Nouvelle campagne</Bouton>} />
      {nouvelle && <Composer listes={listes.data ?? []} fermer={() => setNouvelle(false)} />}

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 18, alignItems: 'flex-start' }}>
        <Bloc titre="Campagnes" style={{ flex: '2 1 460px' }}>
          {campagnes.error && <Alerte>{(campagnes.error as Error).message}</Alerte>}
          {campagnes.isLoading ? <Chargement /> : !campagnes.data?.length ? <Vide>Aucune campagne.</Vide> : (
            <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
              {campagnes.data.map((c) => <LigneCampagne key={c.id} c={c} liste={listes.data?.find((l) => l.id === c.liste_id)} peutLancer={peutLancer} />)}
            </ul>
          )}
          {!peutLancer && <p style={{ ...s.discret, margin: 0 }}>Vous préparez les campagnes ; le trésorier ou un administrateur les envoie.</p>}
        </Bloc>
        <Bloc titre="Listes" style={{ flex: '1 1 300px' }} action={tresorier && !nouvelleListe && <Bouton style={{ padding: '7px 12px', minHeight: 36, fontSize: 12 }} onClick={() => setNouvelleListe(true)}>Nouvelle liste</Bouton>}>
          <p style={{ ...s.discret, margin: 0 }}>Une liste se recalcule à chaque envoi d'après ses critères : rien à tenir à jour à la main.</p>
          {nouvelleListe && <NouvelleListe fermer={() => setNouvelleListe(false)} />}
          {listes.isLoading ? <Chargement /> : !listes.data?.length ? <Vide>Aucune liste.</Vide> : listes.data.map((l) => <LigneListe key={l.id} l={l} />)}
        </Bloc>
      </div>
    </>
  );
}

function LigneListe({ l }: { l: Liste }) {
  const { data: n, isLoading } = useEffectif(l.id);
  const { data: etabs } = useEtablissements();
  const crit = Object.entries(l.criteres ?? {}).map(([k, v]) => (k === 'etablissement_id' ? v.map((id) => etabs?.find((e) => e.id === id)?.libelle ?? '…')
    : k === 'statut_cotisation' ? v.map((x) => COTISATION[x as keyof typeof COTISATION]?.libelle ?? x) : v).join(', ')).join(' · ');
  return (
    <div style={{ border: '1px solid var(--bd)', borderRadius: 12, padding: '10px 12px', display: 'flex', flexDirection: 'column', gap: 4 }}>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
        <strong style={{ flex: 1, fontSize: 13.5 }}>{l.libelle}</strong>
        <span style={{ fontSize: 12.5, color: 'var(--ink4)', fontWeight: 600 }}>{isLoading ? '…' : n == null ? '< 5' : `${n} joignable${n > 1 ? 's' : ''}`}</span>
      </div>
      <span style={{ ...s.discret, fontSize: 12 }}>{crit || 'Tous les adhérents'}</span>
    </div>
  );
}

function NouvelleListe({ fermer }: { fermer: () => void }) {
  const creer = useCreerListe();
  const { data: etabs } = useEtablissements();
  const { data: criteres } = useCriteres();
  const [libelle, setLibelle] = useState('');
  const [c, setC] = useState<Record<string, string[]>>({});
  const basculer = (k: string, v: string) => setC((x) => { const l = x[k] ?? []; const n = l.includes(v) ? l.filter((y) => y !== v) : [...l, v]; const r = { ...x, [k]: n }; if (!n.length) delete r[k]; return r; });
  const puce = (k: string, v: string, lib: string) => (
    <button key={k + v} type="button" aria-pressed={!!c[k]?.includes(v)} onClick={() => basculer(k, v)} style={{ cursor: 'pointer', border: '1px solid var(--bd2)', borderRadius: 99, padding: '6px 11px', minHeight: 34, fontSize: 12.5, fontWeight: 600, fontFamily: 'inherit',
      background: c[k]?.includes(v) ? 'var(--acBg)' : 'var(--surface)', color: c[k]?.includes(v) ? 'var(--acTx2)' : 'var(--ink4)' }}>{lib}</button>
  );
  const groupe = (titre: string, enfants: ReactNode[]) => !!enfants.length && <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}><span style={s.surtitre}>{titre}</span><div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>{enfants}</div></div>;
  return (
    <div style={{ border: '1px solid var(--acBd)', background: 'var(--acBg2)', borderRadius: 14, padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
      <Champ libelle="Nom de la liste"><input value={libelle} onChange={(e) => setLibelle(e.target.value)} placeholder="Ex. : Site Nord — à jour" style={{ ...s.saisie, background: 'var(--surface)' }} /></Champ>
      {groupe('Établissement', (etabs ?? []).map((e) => puce('etablissement_id', e.id, e.libelle)))}
      {groupe('Section', (criteres?.section ?? []).map((x) => puce('section', x, x)))}
      {groupe('Direction', (criteres?.direction ?? []).map((x) => puce('direction', x, x)))}
      {groupe('Cotisation', Object.entries(COTISATION).map(([k, v]) => puce('statut_cotisation', k, v.libelle)))}
      {creer.error && <Alerte>{(creer.error as Error).message}</Alerte>}
      <div style={{ display: 'flex', gap: 8 }}>
        <Bouton variante="primaire" disabled={!libelle.trim() || creer.isPending} onClick={() => creer.mutate({ libelle: libelle.trim(), criteres: c, description: null }, { onSuccess: fermer })}>Créer</Bouton>
        <Bouton variante="discret" onClick={fermer}>Annuler</Bouton>
      </div>
    </div>
  );
}

function Composer({ listes, fermer }: { listes: Liste[]; fermer: () => void }) {
  const creer = useCreerCampagne();
  const [f, setF] = useState({ liste_id: listes[0]?.id ?? '', objet: '', corps: 'Bonjour {prenom},\n\n', planifiee_le: '' });
  return (
    <Bloc titre="Nouvelle campagne" style={{ marginBottom: 18 }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12 }}>
        <Champ libelle="Liste"><select value={f.liste_id} onChange={(e) => setF({ ...f, liste_id: e.target.value })} style={s.saisie}>
          {!listes.length && <option value="">Aucune liste : demandez au trésorier d'en créer une</option>}
          {listes.map((l) => <option key={l.id} value={l.id}>{l.libelle}</option>)}</select></Champ>
        <Champ libelle="Envoi programmé (facultatif)"><input type="datetime-local" value={f.planifiee_le} onChange={(e) => setF({ ...f, planifiee_le: e.target.value })} style={s.saisie} /></Champ>
      </div>
      <Champ libelle="Objet"><input value={f.objet} maxLength={150} onChange={(e) => setF({ ...f, objet: e.target.value })} style={s.saisie} /></Champ>
      <Champ libelle="Message" aide="{prenom} est remplacé par le prénom de chaque destinataire. Le lien de désinscription est ajouté automatiquement.">
        <textarea value={f.corps} rows={8} maxLength={20000} onChange={(e) => setF({ ...f, corps: e.target.value })} style={{ ...s.saisie, resize: 'vertical', lineHeight: 1.55 }} />
      </Champ>
      {creer.error && <Alerte>{(creer.error as Error).message}</Alerte>}
      <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
        <Bouton variante="discret" onClick={fermer}>Annuler</Bouton>
        <Bouton variante="primaire" disabled={!f.liste_id || !f.objet.trim() || !f.corps.trim() || creer.isPending}
          onClick={() => creer.mutate({ liste_id: f.liste_id, objet: f.objet.trim(), corps: f.corps, planifiee_le: f.planifiee_le ? new Date(f.planifiee_le).toISOString() : null }, { onSuccess: fermer })}>Enregistrer le brouillon</Bouton>
      </div>
    </Bloc>
  );
}

function LigneCampagne({ c, liste, peutLancer }: { c: Campagne; liste?: Liste; peutLancer: boolean }) {
  const { data: suivi } = useSuivi(c.id);
  const lancer = useLancerCampagne();
  const [confirmer, setConfirmer] = useState(false);
  const { data: n } = useEffectif(confirmer ? c.liste_id : null);
  const lancee = !!suivi && Object.keys(suivi).length > 0;
  return (
    <li style={{ border: '1px solid var(--bd)', borderRadius: 14, padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
        <strong style={{ flex: 1, fontSize: 14 }}>{c.objet}</strong>
        {lancee ? <Pastille ton="ok">Lancée</Pastille> : <Pastille>Brouillon</Pastille>}
      </div>
      <span style={{ ...s.discret, fontSize: 12 }}>{liste?.libelle ?? 'Liste supprimée'} · créée {heure(c.cree_le)}{c.planifiee_le ? ` · programmée ${heure(c.planifiee_le)}` : ''}</span>
      {lancee && <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', fontSize: 13 }}>{Object.entries(suivi!).map(([k, v]) => <span key={k}><strong>{v}</strong> {ETATS[k]?.toLowerCase() ?? k}</span>)}</div>}
      {!lancee && peutLancer && (confirmer ? (
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          <span style={{ fontSize: 13 }}>Envoyer à {n ?? '…'} adhérent{(n ?? 0) > 1 ? 's' : ''} ? Une campagne ne part qu'une fois.</span>
          <Bouton variante="primaire" disabled={lancer.isPending} onClick={() => lancer.mutate(c.id, { onSuccess: () => setConfirmer(false) })}>Confirmer l'envoi</Bouton>
          <Bouton variante="discret" onClick={() => setConfirmer(false)}>Annuler</Bouton>
        </div>
      ) : <Bouton style={{ alignSelf: 'flex-start' }} onClick={() => setConfirmer(true)}>Envoyer…</Bouton>)}
      {lancer.error && <Alerte>{(lancer.error as Error).message}</Alerte>}
    </li>
  );
}

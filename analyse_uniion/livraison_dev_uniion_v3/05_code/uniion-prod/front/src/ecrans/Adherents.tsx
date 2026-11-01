import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { aRole, type Moi } from '../lib/supabase';
import { COTISATION, useAdherent, useAdherents, useAgregats, useEnregistrerAdherent, useEtablissements, useSupprimerAdherent, type Adherent, type StatutCotisation } from '../lib/gestion';
import { date } from '../lib/donnees';
import { EnTete } from '../ui/Coque';
import { Cotisations } from './Tresorerie';
import { Alerte, Bloc, Bouton, Champ, Chargement, Icone, I, Pastille, Vide, s } from '../ui/kit';

const PAS = 100;

export function Adherents({ moi }: { moi: Moi }) {
  const tresorier = aRole(moi, 'tresorier');
  const [saisie, setSaisie] = useState('');
  const [recherche, setRecherche] = useState('');
  const [statut, setStatut] = useState<StatutCotisation | ''>('');
  const [etab, setEtab] = useState('');
  const [limite, setLimite] = useState(PAS);
  const [ouvert, setOuvert] = useState<string | 'nouveau' | null>(null);
  // Chaque recherche est une lecture nominative journalisée : on attend que la frappe s'arrête.
  useEffect(() => { const t = setTimeout(() => { setRecherche(saisie.trim()); setLimite(PAS); }, 450); return () => clearTimeout(t); }, [saisie]);
  const filtres = { ...(recherche && { recherche }), ...(statut && { statut_cotisation: [statut] }), ...(etab && { etablissement_id: [etab] }) };
  const liste = useAdherents(filtres, limite, tresorier);
  const { data: etabs } = useEtablissements();
  const libEtab = (id: string | null) => etabs?.find((e) => e.id === id)?.libelle ?? '—';

  return (
    <>
      <EnTete titre="Adhérents" sous="L'appartenance syndicale est une donnée sensible : chaque consultation nominative est inscrite au journal d'audit."
        action={tresorier && <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <Link to="/adherents/import" style={{ textDecoration: 'none' }}><Bouton>Importer un fichier</Bouton></Link>
          <Bouton variante="primaire" onClick={() => setOuvert('nouveau')}><Icone d={I.plus} taille={16} />Nouvel adhérent</Bouton>
        </div>} />

      <Agregats libEtab={libEtab} />

      {!tresorier ? (
        <div style={{ marginTop: 18 }}><Alerte ton="info">La liste nominative est réservée aux trésoriers. En tant qu'administrateur, vous voyez uniquement les effectifs ; les groupes de moins de 5 personnes sont masqués.</Alerte></div>
      ) : (
        <section style={{ ...s.carte, marginTop: 18, padding: 0, overflow: 'hidden' }}>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, padding: 16, borderBottom: '1px solid var(--bd)' }}>
            <input type="search" value={saisie} onChange={(e) => setSaisie(e.target.value)} placeholder="Rechercher par nom" aria-label="Rechercher par nom" style={{ ...s.saisie, flex: '1 1 220px', maxWidth: 320, borderRadius: 99 }} />
            <select value={statut} onChange={(e) => setStatut(e.target.value as StatutCotisation | '')} aria-label="Cotisation" style={{ ...s.saisie, width: 'auto', borderRadius: 99 }}>
              <option value="">Toutes cotisations</option>
              {Object.entries(COTISATION).map(([k, v]) => <option key={k} value={k}>{v.libelle}</option>)}
            </select>
            <select value={etab} onChange={(e) => setEtab(e.target.value)} aria-label="Établissement" style={{ ...s.saisie, width: 'auto', maxWidth: 260, borderRadius: 99 }}>
              <option value="">Tous établissements</option>
              {(etabs ?? []).map((e) => <option key={e.id} value={e.id}>{e.libelle}</option>)}
            </select>
          </div>
          {liste.error && <div style={{ padding: 16 }}><Alerte>{(liste.error as Error).message}</Alerte></div>}
          {liste.isLoading ? <div style={{ padding: 16 }}><Chargement /></div> : !liste.data?.length ? <div style={{ padding: 16 }}><Vide>{recherche || statut || etab ? 'Aucun adhérent ne correspond.' : 'Aucun adhérent. Importez votre fichier ou créez une première fiche.'}</Vide></div> : (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13.5 }}>
                <thead><tr style={{ textAlign: 'left' }}>
                  {['Nom', 'Établissement', 'Section', 'Cotisation', 'Envois'].map((h) => <th key={h} scope="col" style={{ ...s.surtitre, padding: '10px 16px', borderBottom: '1px solid var(--bd)', whiteSpace: 'nowrap' }}>{h}</th>)}
                </tr></thead>
                <tbody>
                  {liste.data.map((a) => (
                    <tr key={a.id} onClick={() => setOuvert(a.id)} style={{ cursor: 'pointer', borderBottom: '1px solid var(--bd)', background: ouvert === a.id ? 'var(--acBg2)' : undefined }}>
                      <td style={{ padding: '11px 16px' }}><button type="button" onClick={() => setOuvert(a.id)} style={{ border: 'none', background: 'none', padding: 0, font: 'inherit', fontWeight: 600, color: 'var(--ink)', cursor: 'pointer', textAlign: 'left' }}>{a.nom.toUpperCase()} {a.prenom}</button>
                        {a.emploi && <div style={{ ...s.discret, fontSize: 12 }}>{a.emploi}</div>}</td>
                      <td style={{ padding: '11px 16px', color: 'var(--ink4)' }}>{libEtab(a.etablissement_id)}</td>
                      <td style={{ padding: '11px 16px', color: 'var(--ink4)' }}>{a.section ?? '—'}</td>
                      <td style={{ padding: '11px 16px' }}><Pastille ton={COTISATION[a.statut_cotisation].ton}>{COTISATION[a.statut_cotisation].libelle}</Pastille></td>
                      <td style={{ padding: '11px 16px', color: a.consentement_contact ? 'var(--okTx)' : 'var(--ink5)', fontSize: 12.5 }}>{a.consentement_contact ? 'Consentement' : 'Aucun envoi'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {liste.data.length >= limite && <div style={{ padding: 14, textAlign: 'center' }}><Bouton onClick={() => setLimite((l) => l + PAS)} disabled={liste.isFetching}>Afficher {PAS} de plus</Bouton></div>}
            </div>
          )}
        </section>
      )}

      {tresorier && ouvert && <Fiche id={ouvert === 'nouveau' ? null : ouvert} fermer={() => setOuvert(null)} />}
    </>
  );
}

function Agregats({ libEtab }: { libEtab: (id: string | null) => string }) {
  const { data, isLoading, error } = useAgregats();
  if (isLoading) return <Chargement />;
  if (error || !data) return <Alerte>{(error as Error)?.message ?? 'Effectifs indisponibles.'}</Alerte>;
  const n = (v: number | null | undefined) => (v == null ? '< 5' : v);
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16 }}>
      <section style={{ flex: '1 1 260px', background: 'var(--inkSurf)', color: '#FFFFFF', borderRadius: 22, padding: 22, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <span style={{ ...s.surtitre, color: '#9CA3AF' }}>Effectif</span>
        <span style={{ fontFamily: 'var(--fTitle)', fontSize: 40, lineHeight: 1 }}>{data.total}</span>
        <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap', fontSize: 13 }}>
          {Object.entries(COTISATION).map(([k, v]) => <span key={k}><strong style={{ color: 'var(--acMid)', fontSize: 15 }}>{n(data.par_statut?.[k])}</strong> {v.libelle.toLowerCase()}</span>)}
        </div>
      </section>
      <Bloc titre="Par établissement" style={{ flex: '2 1 360px' }}>
        {!data.par_etablissement ? <Vide>Aucun adhérent.</Vide> : (
          <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 8 }}>
            {Object.entries(data.par_etablissement).map(([id, v]) => (
              <li key={id} style={{ display: 'flex', justifyContent: 'space-between', gap: 10, background: 'var(--surf2)', borderRadius: 12, padding: '9px 12px', fontSize: 13 }}>
                <span style={{ color: 'var(--ink3)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{id === 'non renseigné' ? 'Non renseigné' : libEtab(id)}</span>
                <strong>{n(v)}</strong>
              </li>
            ))}
          </ul>
        )}
      </Bloc>
    </div>
  );
}

const VIDE: Partial<Adherent> = { prenom: '', nom: '', email: '', telephone: '', emploi: '', entreprise: '', section: '', direction: '', mode_reglement: '', statut_cotisation: 'a_jour', consentement_contact: false };

function Fiche({ id, fermer }: { id: string | null; fermer: () => void }) {
  const { data, isLoading, error, refetch } = useAdherent(id);
  const { data: etabs } = useEtablissements();
  const enregistrer = useEnregistrerAdherent();
  const supprimer = useSupprimerAdherent();
  const [f, setF] = useState<Partial<Adherent>>(VIDE);
  const [motif, setMotif] = useState<string | null>(null);
  useEffect(() => { setF(id ? (data ?? VIDE) : VIDE); setMotif(null); enregistrer.reset(); }, [id, data]);  // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { const k = (e: KeyboardEvent) => e.key === 'Escape' && fermer(); addEventListener('keydown', k); return () => removeEventListener('keydown', k); }, [fermer]);
  const champ = (k: keyof Adherent, libelle: string, type = 'text') => (
    <Champ libelle={libelle}><input type={type} value={(f[k] as string | number | null) ?? ''} onChange={(e) => setF({ ...f, [k]: e.target.value })} style={s.saisie} /></Champ>
  );
  const valider = () => {
    // Champs vides → null (une chaîne vide ne se convertit ni en date ni en montant côté serveur).
    const p = Object.fromEntries(Object.entries(f).map(([k, v]) => [k, v === '' ? null : v]));
    enregistrer.mutate(id ? { ...p, id, version: data!.version } : p, { onSuccess: (a) => { if (!id) fermer(); else setF(a); } });
  };

  return (
    <div role="dialog" aria-modal="true" aria-label={id ? 'Fiche adhérent' : 'Nouvel adhérent'} style={{ position: 'fixed', inset: 0, zIndex: 20, display: 'flex', justifyContent: 'flex-end' }}>
      <div onClick={fermer} style={{ position: 'absolute', inset: 0, background: 'rgba(17,24,39,.35)' }} />
      <aside style={{ position: 'relative', width: 'min(560px, 100%)', height: '100%', overflowY: 'auto', background: 'var(--surface)', boxSizing: 'border-box', padding: 24, display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <h2 style={{ ...s.titre, fontSize: 24, flex: 1 }}>{id ? (data ? `${data.prenom} ${data.nom}` : 'Fiche adhérent') : 'Nouvel adhérent'}</h2>
          <Bouton variante="discret" onClick={fermer} aria-label="Fermer">Fermer</Bouton>
        </div>
        {id && isLoading && <Chargement />}
        {error && <><Alerte>{(error as Error).message}</Alerte><Bouton onClick={() => refetch()}>Réessayer</Bouton></>}
        {(!id || data) && <>
          {data && <p style={{ ...s.discret, margin: 0 }}>{data.date_adhesion ? `Adhérent depuis le ${date(data.date_adhesion)}` : "Date d'adhésion non renseignée"}</p>}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12 }}>
            {champ('prenom', 'Prénom')}{champ('nom', 'Nom')}{champ('email', 'E-mail', 'email')}{champ('telephone', 'Téléphone', 'tel')}
            {champ('entreprise', 'Entreprise')}
            <Champ libelle="Établissement"><select value={f.etablissement_id ?? ''} onChange={(e) => setF({ ...f, etablissement_id: e.target.value || null })} style={s.saisie}>
              <option value="">—</option>{(etabs ?? []).map((e) => <option key={e.id} value={e.id}>{e.libelle}</option>)}</select></Champ>
            {champ('section', 'Section')}{champ('direction', 'Direction')}{champ('emploi', 'Emploi')}
            {!id && champ('date_adhesion', "Date d'adhésion", 'date')}
            {champ('mode_reglement', 'Mode de règlement')}{champ('montant_cotisation', 'Montant (€)', 'number')}
            <Champ libelle="Cotisation"><select value={f.statut_cotisation} onChange={(e) => setF({ ...f, statut_cotisation: e.target.value as StatutCotisation })} style={s.saisie}>
              {Object.entries(COTISATION).map(([k, v]) => <option key={k} value={k}>{v.libelle}</option>)}</select></Champ>
            {id && champ('date_fin_adhesion', "Fin d'adhésion", 'date')}
          </div>
          <label style={{ display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 13.5, color: 'var(--ink3)', lineHeight: 1.5 }}>
            <input type="checkbox" checked={!!f.consentement_contact} onChange={(e) => setF({ ...f, consentement_contact: e.target.checked })} style={{ width: 18, height: 18, marginTop: 2 }} />
            <span>A consenti à recevoir les envois de l'organisation (e-mail, SMS). Sans ce consentement, il est exclu de toutes les diffusions.</span>
          </label>
          {f.date_fin_adhesion && <Alerte ton="info">Fin d'adhésion renseignée : la fiche sera effacée automatiquement 3 ans après cette date.</Alerte>}
          {enregistrer.error && <Alerte>{(enregistrer.error as Error).message}</Alerte>}
          {enregistrer.isSuccess && id && <Alerte ton="ok">Fiche enregistrée.</Alerte>}
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <Bouton variante="primaire" onClick={valider} disabled={!f.prenom?.trim() || !f.nom?.trim() || enregistrer.isPending}>{id ? 'Enregistrer' : 'Créer la fiche'}</Bouton>
            {id && motif === null && <Bouton variante="discret" style={{ color: 'var(--dangerTx2)', marginLeft: 'auto' }} onClick={() => setMotif('')}>Supprimer la fiche</Bouton>}
          </div>
          {id && <Cotisations adherent={id} />}
          {id && motif !== null && (
            <section style={{ border: '1px solid var(--dangerBd)', background: 'var(--dangerBg)', borderRadius: 16, padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
              <Champ libelle="Motif de suppression (inscrit au journal)"><input value={motif} onChange={(e) => setMotif(e.target.value)} placeholder="Ex. : demande d'effacement de l'intéressé" style={s.saisie} /></Champ>
              {supprimer.error && <Alerte>{(supprimer.error as Error).message}</Alerte>}
              <div style={{ display: 'flex', gap: 8 }}>
                <Bouton variante="danger" disabled={!motif.trim() || supprimer.isPending} onClick={() => supprimer.mutate({ id, motif: motif.trim() }, { onSuccess: fermer })}>Confirmer la suppression</Bouton>
                <Bouton variante="discret" onClick={() => setMotif(null)}>Annuler</Bouton>
              </div>
            </section>
          )}
        </>}
      </aside>
    </div>
  );
}

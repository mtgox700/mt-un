import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import type { Moi } from '../lib/supabase';
import { TYPES_EVT, VISIBILITES, exporterIcs, typeEvt, useActionEvt, useEnregistrerEvt, useEvenements, type Evenement, type SaisieEvt } from '../lib/contenus';
import { useCollegues, useDossiers } from '../lib/donnees';
import { EnTete, useLarge } from '../ui/Coque';
import { Alerte, Bouton, Champ, Chargement, Icone, I, Pastille, Vide, s } from '../ui/kit';

const JOURS = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const jour = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const cle = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const hm = (iso: string) => new Date(iso).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
const local = (iso: string) => { const d = new Date(iso); return `${cle(d)}T${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };

export function Agenda({ moi }: { moi: Moi }) {
  const large = useLarge(760);
  const [mois, setMois] = useState(() => { const d = new Date(); return new Date(d.getFullYear(), d.getMonth(), 1); });
  const [ouvert, setOuvert] = useState<Evenement | 'nouveau' | null>(null);
  const [jourNouveau, setJourNouveau] = useState<Date | null>(null);
  const grille = useMemo(() => {
    const debut = new Date(mois); debut.setDate(1 - ((mois.getDay() + 6) % 7));
    return Array.from({ length: 42 }, (_, i) => new Date(debut.getFullYear(), debut.getMonth(), debut.getDate() + i));
  }, [mois]);
  const { data, isLoading, error } = useEvenements(grille[0]!, new Date(grille[41]!.getTime() + 864e5));
  const parJour = useMemo(() => {
    const m = new Map<string, Evenement[]>();
    (data ?? []).forEach((e) => {
      for (let d = jour(new Date(e.debut)); d <= new Date(e.fin); d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)) m.set(cle(d), [...(m.get(cle(d)) ?? []), e]);
    });
    return m;
  }, [data]);
  const aujourdhui = cle(new Date());
  const avenir = (data ?? []).filter((e) => new Date(e.fin) >= new Date()).slice(0, 8);
  const decaler = (n: number) => setMois(new Date(mois.getFullYear(), mois.getMonth() + n, 1));
  const ouvrirNouveau = (d?: Date) => { setJourNouveau(d ?? null); setOuvert('nouveau'); };

  return (
    <>
      <EnTete titre="Agenda" sous="Les événements réservés au bureau ou aux invités ne sont jamais transmis aux autres membres."
        action={<Bouton variante="primaire" onClick={() => ouvrirNouveau()}><Icone d={I.plus} taille={16} />Nouvel événement</Bouton>} />
      {error && <Alerte>{(error as Error).message}</Alerte>}

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 18, alignItems: 'flex-start' }}>
        <section style={{ ...s.carte, flex: '3 1 560px', minWidth: 0, padding: large ? 20 : 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
            <h2 style={{ ...s.titre, fontSize: 22, flex: 1, textTransform: 'capitalize' }}>{mois.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })}</h2>
            <Bouton variante="discret" onClick={() => setMois(new Date(new Date().getFullYear(), new Date().getMonth(), 1))}>Aujourd'hui</Bouton>
            <button type="button" aria-label="Mois précédent" onClick={() => decaler(-1)} style={fleche}><Icone d={I.gauche} taille={16} /></button>
            <button type="button" aria-label="Mois suivant" onClick={() => decaler(1)} style={fleche}><Icone d={I.droite} taille={16} /></button>
          </div>
          {isLoading && !data ? <Chargement /> : (
            <div role="grid" aria-label="Calendrier du mois" style={{ display: 'grid', gridTemplateColumns: 'repeat(7, minmax(0, 1fr))', gap: 1, background: 'var(--bd)', border: '1px solid var(--bd)', borderRadius: 14, overflow: 'hidden' }}>
              {JOURS.map((j) => <div key={j} role="columnheader" style={{ background: 'var(--surf2)', padding: '7px 6px', fontSize: 11, fontWeight: 700, color: 'var(--ink5)', textTransform: 'uppercase', letterSpacing: '.05em' }}>{large ? j : j[0]}</div>)}
              {grille.map((d) => {
                const evts = parJour.get(cle(d)) ?? [];
                const horsMois = d.getMonth() !== mois.getMonth();
                return (
                  <div key={cle(d)} role="gridcell" onDoubleClick={() => ouvrirNouveau(d)} style={{ background: horsMois ? 'var(--surf2)' : 'var(--surface)', minHeight: large ? 96 : 54, padding: 4, display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0 }}>
                    <span style={{ alignSelf: 'flex-end', fontSize: 12, fontWeight: 600, width: 24, height: 24, borderRadius: 99, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                      background: cle(d) === aujourdhui ? 'linear-gradient(135deg, var(--ac), var(--ac2))' : 'transparent', color: cle(d) === aujourdhui ? '#FFFFFF' : horsMois ? 'var(--ink6)' : 'var(--ink3)' }}>{d.getDate()}</span>
                    {large ? evts.slice(0, 3).map((e) => {
                      const t = typeEvt(e.type);
                      return <button key={e.id} type="button" onClick={() => setOuvert(e)} title={e.titre} style={{ cursor: 'pointer', border: 'none', textAlign: 'left', background: t.fond, color: t.texte, borderRadius: 6, padding: '3px 6px', fontSize: 11, fontWeight: 600, fontFamily: 'inherit', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {!e.journee_entiere && <span style={{ fontWeight: 700 }}>{hm(e.debut)} </span>}{e.titre}</button>;
                    }) : !!evts.length && <span style={{ display: 'flex', gap: 2, flexWrap: 'wrap', justifyContent: 'center' }}>{evts.slice(0, 4).map((e) => <span key={e.id} style={{ width: 6, height: 6, borderRadius: 99, background: typeEvt(e.type).point }} />)}</span>}
                    {large && evts.length > 3 && <span style={{ fontSize: 11, color: 'var(--ink5)', paddingLeft: 4 }}>+ {evts.length - 3}</span>}
                  </div>
                );
              })}
            </div>
          )}
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginTop: 12 }}>
            {TYPES_EVT.map((t) => <span key={t.id} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, color: 'var(--ink4)' }}><span style={{ width: 8, height: 8, borderRadius: 99, background: t.point }} />{t.libelle}</span>)}
          </div>
        </section>

        <section style={{ ...s.carte, flex: '1 1 280px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <h2 style={{ ...s.titre, fontSize: 18 }}>À venir</h2>
          {!avenir.length ? <Vide>Rien de prévu ce mois-ci.</Vide> : avenir.map((e) => {
            const t = typeEvt(e.type); const d = new Date(e.debut);
            return (
              <button key={e.id} type="button" onClick={() => setOuvert(e)} style={{ cursor: 'pointer', border: '1px solid var(--bd)', background: 'var(--surf2)', borderRadius: 14, padding: '10px 12px', display: 'flex', gap: 12, alignItems: 'center', textAlign: 'left', fontFamily: 'inherit' }}>
                <span style={{ width: 44, flex: '0 0 44px', textAlign: 'center', lineHeight: 1.1 }}>
                  <span style={{ display: 'block', fontFamily: 'var(--fTitle)', fontSize: 20, color: 'var(--ink)' }}>{d.getDate()}</span>
                  <span style={{ fontSize: 11, color: 'var(--ink5)' }}>{d.toLocaleDateString('fr-FR', { month: 'short' })}</span>
                </span>
                <span style={{ flex: 1, minWidth: 0 }}>
                  <span style={{ display: 'block', fontSize: 13.5, fontWeight: 600, color: 'var(--ink)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{e.titre}</span>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, color: 'var(--ink5)' }}><span style={{ width: 7, height: 7, borderRadius: 99, background: t.point }} />{e.journee_entiere ? 'Journée' : `${hm(e.debut)}–${hm(e.fin)}`}</span>
                </span>
              </button>
            );
          })}
        </section>
      </div>

      {ouvert && <Panneau e={ouvert === 'nouveau' ? null : ouvert} jour={jourNouveau} moi={moi} fermer={() => setOuvert(null)} />}
    </>
  );
}
const fleche = { cursor: 'pointer', border: '1px solid var(--bd2)', background: 'var(--surface)', borderRadius: 99, width: 40, height: 40, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink4)' } as const;

function Panneau({ e, jour: j, moi, fermer }: { e: Evenement | null; jour: Date | null; moi: Moi; fermer: () => void }) {
  const createur = !e || e.createur_id === moi.personne_id;
  const [edition, setEdition] = useState(!e);
  useEffect(() => { const k = (ev: KeyboardEvent) => ev.key === 'Escape' && fermer(); addEventListener('keydown', k); return () => removeEventListener('keydown', k); }, [fermer]);
  return (
    <div role="dialog" aria-modal="true" aria-label={e ? e.titre : 'Nouvel événement'} style={{ position: 'fixed', inset: 0, zIndex: 20, display: 'flex', justifyContent: 'flex-end' }}>
      <div onClick={fermer} style={{ position: 'absolute', inset: 0, background: 'rgba(17,24,39,.35)' }} />
      <aside style={{ position: 'relative', width: 'min(520px, 100%)', height: '100%', overflowY: 'auto', background: 'var(--surface)', boxSizing: 'border-box', padding: 24, display: 'flex', flexDirection: 'column', gap: 16 }}>
        {edition ? <Formulaire e={e} jour={j} fermer={fermer} annuler={e ? () => setEdition(false) : fermer} /> : <Detail e={e!} moi={moi} createur={createur} modifier={() => setEdition(true)} fermer={fermer} />}
      </aside>
    </div>
  );
}

function Detail({ e, moi, createur, modifier, fermer }: { e: Evenement; moi: Moi; createur: boolean; modifier: () => void; fermer: () => void }) {
  const action = useActionEvt();
  const t = typeEvt(e.type);
  const moiInvite = e.participants.find((p) => p.personne_id === moi.personne_id);
  const quand = e.journee_entiere
    ? new Date(e.debut).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })
    : `${new Date(e.debut).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}, ${hm(e.debut)}–${hm(e.fin)}`;
  const rep = { accepte: 'Présent', refuse: 'Absent', en_attente: 'Sans réponse' } as const;
  return <>
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <span style={{ background: t.fond, color: t.texte, fontSize: 11, fontWeight: 700, padding: '4px 10px', borderRadius: 99 }}>{t.libelle}</span>
      {e.visibilite !== 'section' && <Pastille>{VISIBILITES.find((v) => v.id === e.visibilite)?.libelle}</Pastille>}
      <Bouton variante="discret" onClick={fermer} style={{ marginLeft: 'auto' }}>Fermer</Bouton>
    </div>
    <h2 style={{ ...s.titre, fontSize: 26, lineHeight: 1.2 }}>{e.titre}</h2>
    <p style={{ ...s.texte, margin: 0, textTransform: 'capitalize' }}>{quand}</p>
    {e.lieu && <p style={{ ...s.texte, margin: 0 }}>{e.lieu}</p>}
    {e.description && <p style={{ ...s.texte, margin: 0, color: 'var(--ink4)', whiteSpace: 'pre-line' }}>{e.description}</p>}
    {e.dossier && e.dossier_id && <Link to={`/dossiers/${e.dossier_id}`} style={{ fontSize: 13.5, fontWeight: 600 }}>Dossier : {e.dossier.intitule}</Link>}
    <p style={{ ...s.discret, margin: 0 }}>Organisé par {e.createur ? `${e.createur.prenom} ${e.createur.nom}` : '—'}</p>
    {!!e.participants.length && (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        <span style={s.surtitre}>Invités</span>
        {e.participants.map((p) => <div key={p.personne_id} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13.5 }}><span>{p.personne ? `${p.personne.prenom} ${p.personne.nom}` : '—'}</span>
          <span style={{ color: p.reponse === 'accepte' ? 'var(--okTx)' : p.reponse === 'refuse' ? 'var(--dangerTx2)' : 'var(--ink5)', fontWeight: 600, fontSize: 12.5 }}>{rep[p.reponse]}</span></div>)}
      </div>
    )}
    {moiInvite && (
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <Bouton variante={moiInvite.reponse === 'accepte' ? 'primaire' : 'secondaire'} onClick={() => action.mutate({ repondre: e, personneId: moi.personne_id!, reponse: 'accepte' })}>Je serai présent</Bouton>
        <Bouton variante={moiInvite.reponse === 'refuse' ? 'danger' : 'secondaire'} onClick={() => action.mutate({ repondre: e, personneId: moi.personne_id!, reponse: 'refuse' })}>Je serai absent</Bouton>
      </div>
    )}
    {action.error && <Alerte>{(action.error as Error).message}</Alerte>}
    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', borderTop: '1px solid var(--bd)', paddingTop: 14 }}>
      <Bouton onClick={() => exporterIcs(e)}>Ajouter à mon calendrier</Bouton>
      {createur && <Bouton onClick={modifier}>Modifier</Bouton>}
      {createur && <Bouton variante="discret" style={{ color: 'var(--dangerTx2)' }} onClick={() => { if (confirm('Supprimer cet événement ?')) action.mutate({ supprimer: e }, { onSuccess: fermer }); }}>Supprimer</Bouton>}
    </div>
  </>;
}

function Formulaire({ e, jour: j, fermer, annuler }: { e: Evenement | null; jour: Date | null; fermer: () => void; annuler: () => void }) {
  const enregistrer = useEnregistrerEvt();
  const { data: collegues } = useCollegues(true);
  const { data: dossiers } = useDossiers();
  const base = j ?? new Date();
  const defaut = new Date(base.getFullYear(), base.getMonth(), base.getDate(), 9, 0);
  const [f, setF] = useState(() => ({
    titre: e?.titre ?? '', type: e?.type ?? 'cse', lieu: e?.lieu ?? '', description: e?.description ?? '', visibilite: e?.visibilite ?? 'section', dossier_id: e?.dossier_id ?? '',
    journee: e?.journee_entiere ?? false, debut: local(e?.debut ?? defaut.toISOString()), fin: local(e?.fin ?? new Date(defaut.getTime() + 2 * 36e5).toISOString()),
  }));
  const [invites, setInvites] = useState<string[]>(e?.participants.map((p) => p.personne_id) ?? []);
  const maj = (k: keyof typeof f) => (ev: { target: { value: string } }) => setF({ ...f, [k]: ev.target.value });
  const debut = f.journee ? new Date(f.debut.slice(0, 10) + 'T00:00') : new Date(f.debut);
  const fin = f.journee ? new Date(f.fin.slice(0, 10) + 'T23:59') : new Date(f.fin);
  const incoherent = fin < debut;
  const valider = () => {
    const saisie: SaisieEvt = { titre: f.titre.trim(), type: f.type, lieu: f.lieu.trim() || null, description: f.description.trim() || null, visibilite: f.visibilite as SaisieEvt['visibilite'],
      dossier_id: f.dossier_id || null, journee_entiere: f.journee, debut: debut.toISOString(), fin: fin.toISOString() };
    enregistrer.mutate({ e: saisie, avant: e ?? undefined, invites }, { onSuccess: fermer });
  };
  return <>
    <div style={{ display: 'flex', alignItems: 'center' }}><h2 style={{ ...s.titre, fontSize: 24, flex: 1 }}>{e ? "Modifier l'événement" : 'Nouvel événement'}</h2><Bouton variante="discret" onClick={annuler}>Annuler</Bouton></div>
    <Champ libelle="Titre" aide={f.visibilite === 'section' ? 'Visible de tous les membres : pas de nom de salarié dans le titre.' : undefined}><input value={f.titre} onChange={maj('titre')} maxLength={160} style={s.saisie} /></Champ>
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
      {TYPES_EVT.map((t) => <button key={t.id} type="button" aria-pressed={f.type === t.id} onClick={() => setF({ ...f, type: t.id })} style={{ cursor: 'pointer', border: f.type === t.id ? `1.5px solid ${t.point}` : '1px solid var(--bd2)', background: f.type === t.id ? t.fond : 'var(--surface)', color: f.type === t.id ? t.texte : 'var(--ink4)', borderRadius: 99, padding: '7px 12px', minHeight: 36, fontSize: 12.5, fontWeight: 600, fontFamily: 'inherit' }}>{t.libelle}</button>)}
    </div>
    <label style={{ display: 'flex', gap: 10, alignItems: 'center', fontSize: 13.5, minHeight: 36 }}><input type="checkbox" checked={f.journee} onChange={(ev) => setF({ ...f, journee: ev.target.checked })} style={{ width: 18, height: 18 }} />Toute la journée</label>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: 12 }}>
      <Champ libelle="Début"><input type={f.journee ? 'date' : 'datetime-local'} value={f.journee ? f.debut.slice(0, 10) : f.debut} onChange={(ev) => setF({ ...f, debut: f.journee ? ev.target.value + f.debut.slice(10) : ev.target.value })} style={s.saisie} /></Champ>
      <Champ libelle="Fin"><input type={f.journee ? 'date' : 'datetime-local'} value={f.journee ? f.fin.slice(0, 10) : f.fin} onChange={(ev) => setF({ ...f, fin: f.journee ? ev.target.value + f.fin.slice(10) : ev.target.value })} style={s.saisie} /></Champ>
    </div>
    {incoherent && <Alerte>La fin précède le début.</Alerte>}
    <Champ libelle="Lieu"><input value={f.lieu} onChange={maj('lieu')} style={s.saisie} /></Champ>
    <Champ libelle="Notes"><textarea value={f.description} onChange={maj('description')} rows={3} style={{ ...s.saisie, resize: 'vertical' }} /></Champ>
    <Champ libelle="Visibilité" aide={VISIBILITES.find((v) => v.id === f.visibilite)?.aide}>
      <select value={f.visibilite} onChange={maj('visibilite')} style={s.saisie}>{VISIBILITES.map((v) => <option key={v.id} value={v.id}>{v.libelle}</option>)}</select>
    </Champ>
    <Champ libelle="Dossier lié"><select value={f.dossier_id} onChange={maj('dossier_id')} style={s.saisie}><option value="">Aucun</option>{(dossiers ?? []).map((d) => <option key={d.id} value={d.id}>{d.intitule}</option>)}</select></Champ>
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <span style={s.surtitre}>Invités</span>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', maxHeight: 160, overflowY: 'auto' }}>
        {(collegues ?? []).map((p) => {
          const actif = invites.includes(p.id);
          return <button key={p.id} type="button" aria-pressed={actif} onClick={() => setInvites(actif ? invites.filter((x) => x !== p.id) : [...invites, p.id])}
            style={{ cursor: 'pointer', border: '1px solid var(--bd2)', background: actif ? 'var(--acBg)' : 'var(--surface)', color: actif ? 'var(--acTx2)' : 'var(--ink4)', borderRadius: 99, padding: '6px 12px', minHeight: 34, fontSize: 12.5, fontWeight: 600, fontFamily: 'inherit' }}>{p.prenom} {p.nom}</button>;
        })}
      </div>
    </div>
    {enregistrer.error && <Alerte>{(enregistrer.error as Error).message}</Alerte>}
    <Bouton variante="primaire" disabled={!f.titre.trim() || incoherent || enregistrer.isPending} onClick={valider} style={{ alignSelf: 'flex-start' }}>{enregistrer.isPending ? 'Enregistrement…' : e ? 'Enregistrer' : "Créer l'événement"}</Bouton>
  </>;
}

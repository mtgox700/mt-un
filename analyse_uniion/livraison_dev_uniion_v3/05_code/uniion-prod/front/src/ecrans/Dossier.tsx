import { useEffect, useRef, useState, type ChangeEvent, type DragEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import type { Moi } from '../lib/supabase';
import {
  CATEGORIES, Conflit, STATUTS, TYPES_ACCEPTES, date, echeance, heure, nomCourt, octets, ouvrirPiece,
  useAcces, useAjouterNote, useCollegues, useDeposerPiece, useDetail, useDossier, useEcrireDetail, useHistorique,
  useModifierAcces, useModifierDossier, useNotes, usePieces, useSupprimerPiece, type Dossier as TDossier, type Piece,
} from '../lib/donnees';
import { Conversation } from './Conversation';
import { Alerte, Avatar, Bloc, Bouton, Champ, Chargement, Icone, I, Pastille, Vide, s } from '../ui/kit';

export function Dossier({ moi }: { moi: Moi }) {
  const { id = '' } = useParams();
  const { data: d, isLoading } = useDossier(id);
  if (isLoading) return <Chargement />;
  // Hors périmètre ou inexistant : même message, on ne confirme pas l'existence d'un dossier.
  if (!d) return <div style={{ display: 'grid', gap: 14, maxWidth: 480 }}><Retour /><Alerte ton="info">Ce dossier n'existe pas ou ne vous a pas été partagé.</Alerte></div>;
  const referent = d.referent_id === moi.personne_id;
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 20, alignItems: 'flex-start' }}>
      <div style={{ flex: '1 1 540px', minWidth: 0, display: 'flex', flexDirection: 'column', gap: 18 }}>
        <Retour />
        <Entete d={d} referent={referent} />
        <Detail id={d.id} />
        <Pieces id={d.id} moi={moi} referent={referent} />
        <Notes id={d.id} />
        <Historique id={d.id} />
      </div>
      <div style={{ flex: '1 1 360px', minWidth: 0, display: 'flex', flexDirection: 'column', gap: 18, position: 'sticky', top: 20 }}>
        <section style={{ ...s.carte, padding: 0, overflow: 'hidden', borderColor: 'var(--acBd)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '14px 18px', background: 'linear-gradient(to right, var(--ac), var(--ac2))', color: '#FFFFFF' }}>
            <Icone d={I.unii} taille={16} /><h2 style={{ margin: 0, fontSize: 15, fontWeight: 700 }}>unii sur ce dossier</h2>
          </div>
          <Conversation surface="dossier" dossier={d} hauteur={420} suggestions={['Quels délais s\'appliquent ?', 'Quelles pièces réunir ?', 'Rédige un courrier à la direction']} />
        </section>
        <Perimetre d={d} referent={referent} />
      </div>
    </div>
  );
}

const Retour = () => <Link to="/dossiers" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600, color: 'var(--ink4)', textDecoration: 'none', minHeight: 32 }}><Icone d={I.gauche} taille={16} />Dossiers</Link>;

function Entete({ d, referent }: { d: TDossier; referent: boolean }) {
  const modifier = useModifierDossier();
  const aller = useNavigate();
  const [edition, setEdition] = useState(false);
  const [suppr, setSuppr] = useState(false);
  const [f, setF] = useState(d);
  const [erreur, setErreur] = useState('');
  useEffect(() => { if (!edition) setF(d); }, [d, edition]);
  const e = echeance(d.echeance);
  const appliquer = (modif: Parameters<typeof modifier.mutate>[0]['modif'], ok?: () => void) => {
    setErreur('');
    modifier.mutate({ d, modif }, { onSuccess: ok, onError: (x) => setErreur(x instanceof Conflit ? x.message : 'Enregistrement impossible.') });
  };

  return (
    <section style={{ ...s.carte, display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
        <Pastille>{d.categorie}</Pastille>
        {d.contentieux && <Pastille ton="alerte">Contentieux · conservation 10 ans</Pastille>}
        <span style={{ marginLeft: 'auto', fontSize: 12.5, fontWeight: 600, color: d.statut !== 'done' && e.urgent ? 'var(--dangerTx2)' : 'var(--ink5)' }}>
          {d.statut === 'done' ? `Clos le ${date(d.clos_le)}` : d.echeance ? `Échéance : ${date(d.echeance)} · ${e.texte}` : e.texte}
        </span>
      </div>

      {!edition ? <>
        <h1 style={{ ...s.titre, fontSize: 28, lineHeight: 1.2 }}>{d.intitule}</h1>
        {d.description && <p style={{ ...s.texte, margin: 0, color: 'var(--ink4)' }}>{d.description}</p>}
      </> : (
        <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))' }}>
          <div style={{ gridColumn: '1 / -1' }}><Champ libelle="Intitulé"><input value={f.intitule} maxLength={160} onChange={(x) => setF({ ...f, intitule: x.target.value })} style={s.saisie} /></Champ></div>
          <Champ libelle="Catégorie"><select value={f.categorie} onChange={(x) => setF({ ...f, categorie: x.target.value })} style={s.saisie}>{CATEGORIES.map((c) => <option key={c}>{c}</option>)}</select></Champ>
          <Champ libelle="Échéance"><input type="date" value={f.echeance ?? ''} onChange={(x) => setF({ ...f, echeance: x.target.value || null })} style={s.saisie} /></Champ>
          <div style={{ gridColumn: '1 / -1' }}><Champ libelle="Description"><textarea rows={3} maxLength={2000} value={f.description ?? ''} onChange={(x) => setF({ ...f, description: x.target.value })} style={{ ...s.saisie, resize: 'vertical' }} /></Champ></div>
          <label style={{ gridColumn: '1 / -1', display: 'flex', gap: 10, alignItems: 'center', fontSize: 13.5, color: 'var(--ink3)', minHeight: 44 }}>
            <input type="checkbox" checked={f.contentieux} onChange={(x) => setF({ ...f, contentieux: x.target.checked })} style={{ width: 18, height: 18 }} />
            Contentieux en cours — le dossier sera conservé 10 ans au lieu de 5
          </label>
        </div>
      )}

      <div role="group" aria-label="État du dossier" style={{ display: 'flex', gap: 4, background: 'var(--chip)', borderRadius: 99, padding: 4, alignSelf: 'flex-start', flexWrap: 'wrap' }}>
        {STATUTS.map((st) => (
          <button key={st.id} type="button" aria-pressed={d.statut === st.id} onClick={() => appliquer({ statut: st.id })} disabled={modifier.isPending}
            style={{ cursor: 'pointer', border: 'none', borderRadius: 99, padding: '8px 14px', minHeight: 36, fontSize: 12.5, fontWeight: 700, fontFamily: 'inherit', display: 'inline-flex', alignItems: 'center', gap: 7,
              background: d.statut === st.id ? 'var(--surface)' : 'transparent', color: d.statut === st.id ? 'var(--ink)' : 'var(--ink5)', boxShadow: d.statut === st.id ? '0 1px 3px rgba(17,24,39,.08)' : 'none' }}>
            <span style={{ width: 7, height: 7, borderRadius: 99, background: st.pastille }} />{st.libelle}
          </button>
        ))}
      </div>

      {erreur && <Alerte>{erreur}</Alerte>}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {edition ? <>
          <Bouton variante="primaire" disabled={!f.intitule.trim() || modifier.isPending} onClick={() => appliquer(
            { intitule: f.intitule.trim(), categorie: f.categorie, description: f.description?.trim() || null, echeance: f.echeance, contentieux: f.contentieux }, () => setEdition(false))}>Enregistrer</Bouton>
          <Bouton variante="discret" onClick={() => setEdition(false)}>Annuler</Bouton>
        </> : <Bouton onClick={() => setEdition(true)}>Modifier</Bouton>}
        {referent && !edition && (suppr
          ? <><Bouton variante="danger" onClick={() => appliquer({ supprime_le: new Date().toISOString() }, () => aller('/dossiers'))}>Confirmer la suppression</Bouton><Bouton variante="discret" onClick={() => setSuppr(false)}>Annuler</Bouton></>
          : <Bouton variante="discret" onClick={() => setSuppr(true)} style={{ color: 'var(--dangerTx2)' }}>Supprimer</Bouton>)}
      </div>
    </section>
  );
}

function Detail({ id }: { id: string }) {
  const { data, isLoading, error } = useDetail(id);
  const ecrire = useEcrireDetail(id);
  const [texte, setTexte] = useState<string | null>(null);
  const valeur = texte ?? data ?? '';
  const modifie = texte !== null && texte !== data;
  return (
    <Bloc titre="Détail confidentiel" action={<Pastille ton="ok"><Icone d={I.cadenas} taille={11} />Chiffré</Pastille>}>
      <p style={{ ...s.discret, margin: 0 }}>Santé, situation familiale, éléments disciplinaires : écrivez-les ici plutôt que dans la description. Ce texte est chiffré et n'est lu que par les personnes du dossier.</p>
      {isLoading ? <Chargement /> : error ? <Alerte>{(error as Error).message}</Alerte> : (
        <textarea value={valeur} onChange={(e) => setTexte(e.target.value)} rows={5} maxLength={50000} aria-label="Détail confidentiel" style={{ ...s.saisie, resize: 'vertical', lineHeight: 1.55 }} />
      )}
      {ecrire.error && <Alerte>{(ecrire.error as Error).message}</Alerte>}
      {modifie && <div style={{ display: 'flex', gap: 8 }}>
        <Bouton variante="primaire" disabled={ecrire.isPending} onClick={() => ecrire.mutate(valeur, { onSuccess: () => setTexte(null) })}>{ecrire.isPending ? 'Chiffrement…' : 'Enregistrer'}</Bouton>
        <Bouton variante="discret" onClick={() => setTexte(null)}>Annuler</Bouton>
      </div>}
    </Bloc>
  );
}

function Pieces({ id, moi, referent }: { id: string; moi: Moi; referent: boolean }) {
  const { data, isLoading } = usePieces(id);
  const deposer = useDeposerPiece(id);
  const supprimer = useSupprimerPiece(id);
  const champ = useRef<HTMLInputElement>(null);
  const [survol, setSurvol] = useState(false);
  const [erreurs, setErreurs] = useState<string[]>([]);
  const [enCours, setEnCours] = useState<string[]>([]);

  const envoyer = async (fichiers: File[]) => {
    setErreurs([]);
    for (const f of fichiers) {
      setEnCours((l) => [...l, f.name]);
      try {
        const r = await deposer.mutateAsync(f);
        if (r.antivirus === 'indisponible') setErreurs((l) => [...l, `« ${f.name} » est enregistré ; il sera disponible après l'analyse antivirus.`]);
      } catch (e) { setErreurs((l) => [...l, (e as Error).message]); }
      setEnCours((l) => l.filter((n) => n !== f.name));
    }
  };
  const choisir = (e: ChangeEvent<HTMLInputElement>) => { envoyer([...(e.target.files ?? [])]); e.target.value = ''; };
  const lacher = (e: DragEvent) => { e.preventDefault(); setSurvol(false); envoyer([...e.dataTransfer.files]); };
  const ouvrir = (p: Piece, mode: 'apercu' | 'telecharger') => ouvrirPiece(p, mode).catch((e) => setErreurs([(e as Error).message]));

  return (
    <Bloc titre="Pièces jointes" action={data && <Pastille ton="accent">{data.length}</Pastille>}>
      <button type="button" onClick={() => champ.current?.click()} onDragOver={(e) => { e.preventDefault(); setSurvol(true); }} onDragLeave={() => setSurvol(false)} onDrop={lacher}
        style={{ cursor: 'pointer', border: '1.5px dashed var(--acMid)', background: survol ? 'var(--acBg)' : 'var(--acBg2)', borderRadius: 18, padding: '20px 16px', display: 'flex', alignItems: 'center', gap: 14, textAlign: 'left', fontFamily: 'inherit', color: 'var(--ink3)' }}>
        <span style={{ width: 40, height: 40, flex: '0 0 40px', borderRadius: 99, background: 'linear-gradient(135deg, var(--ac), var(--ac2))', color: '#FFFFFF', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icone d={I.plus} /></span>
        <span><span style={{ display: 'block', fontSize: 14, fontWeight: 700 }}>Déposer des fichiers</span>
          <span style={{ ...s.discret, display: 'block' }}>PDF, images, documents bureautiques, e-mails, audio · 80 Mo au plus · analysés par antivirus puis chiffrés</span></span>
      </button>
      <input ref={champ} type="file" multiple accept={TYPES_ACCEPTES.join(',')} onChange={choisir} hidden />
      {enCours.map((n) => <p key={n} role="status" style={{ ...s.discret, margin: 0 }}>Analyse et chiffrement de « {n} »…</p>)}
      {erreurs.map((m, i) => <Alerte key={i} ton={m.includes('antivirus') && !m.includes('malveillant') ? 'info' : 'danger'}>{m}</Alerte>)}
      {isLoading ? <Chargement /> : !data?.length ? <Vide>Aucune pièce pour l'instant.</Vide> : (
        <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>
          {data.map((p) => (
            <li key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap', border: '1px solid var(--bd)', borderRadius: 14, padding: '10px 12px' }}>
              <span style={{ color: 'var(--ink5)' }}><Icone d={I.trombone} taille={16} /></span>
              <span style={{ flex: '1 1 200px', minWidth: 0 }}>
                <span style={{ display: 'block', fontSize: 13.5, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p.nom}</span>
                <span style={{ ...s.discret, fontSize: 11.5 }}>{octets(p.taille_octets)} · {heure(p.cree_le)}</span>
              </span>
              {!p.antivirus_ok ? <Pastille ton="alerte">Analyse antivirus en attente</Pastille> : (
                <span style={{ display: 'flex', gap: 6 }}>
                  {(p.type_mime === 'application/pdf' || p.type_mime.startsWith('image/')) && <Bouton style={{ padding: '7px 12px', minHeight: 36, fontSize: 12 }} onClick={() => ouvrir(p, 'apercu')}>Aperçu</Bouton>}
                  <Bouton style={{ padding: '7px 12px', minHeight: 36, fontSize: 12 }} onClick={() => ouvrir(p, 'telecharger')}>Télécharger</Bouton>
                </span>
              )}
              {(referent || p.depose_par === moi.personne_id) && (
                <Bouton variante="discret" style={{ padding: '7px 10px', minHeight: 36, fontSize: 12 }} disabled={supprimer.isPending}
                  onClick={() => { if (confirm(`Placer « ${p.nom} » dans la corbeille ? Elle sera supprimée définitivement dans 30 jours.`)) supprimer.mutate(p.id); }}>Supprimer</Bouton>
              )}
            </li>
          ))}
        </ul>
      )}
    </Bloc>
  );
}

function Notes({ id }: { id: string }) {
  const { data, isLoading, error } = useNotes(id);
  const ajouter = useAjouterNote(id);
  const [texte, setTexte] = useState('');
  return (
    <Bloc titre="Notes" action={<Pastille ton="ok"><Icone d={I.cadenas} taille={11} />Chiffrées</Pastille>}>
      <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
        <textarea value={texte} onChange={(e) => setTexte(e.target.value)} rows={2} maxLength={20000} placeholder="Compte rendu d'entretien, appel, démarche…" aria-label="Nouvelle note" style={{ ...s.saisie, resize: 'vertical', flex: 1 }} />
        <Bouton variante="primaire" disabled={!texte.trim() || ajouter.isPending} onClick={() => ajouter.mutate(texte.trim(), { onSuccess: () => setTexte('') })}>Ajouter</Bouton>
      </div>
      {(error || ajouter.error) && <Alerte>{((error || ajouter.error) as Error).message}</Alerte>}
      {isLoading ? <Chargement /> : !data?.length ? <Vide>Aucune note.</Vide> : (
        <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {[...data].reverse().map((n) => (
            <li key={n.id} style={{ background: 'var(--surf2)', borderRadius: 14, padding: '11px 14px' }}>
              <div style={{ ...s.discret, fontSize: 11.5, marginBottom: 4 }}>{heure(n.cree_le)}</div>
              <div style={{ ...s.texte, whiteSpace: 'pre-wrap' }}>{n.texte}</div>
            </li>
          ))}
        </ul>
      )}
    </Bloc>
  );
}

function Historique({ id }: { id: string }) {
  const { data, isLoading } = useHistorique(id);
  return (
    <Bloc titre="Historique">
      {isLoading ? <Chargement /> : !data?.length ? <Vide>Aucun événement.</Vide> : (
        <ol style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column' }}>
          {data.map((h, i) => (
            <li key={h.id} style={{ display: 'flex', gap: 12 }}>
              <span aria-hidden="true" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 5 }}>
                <span style={{ width: 9, height: 9, borderRadius: 99, background: i ? 'var(--bd2)' : 'var(--ac)' }} />
                {i < data.length - 1 && <span style={{ width: 1, flex: 1, background: 'var(--bd2)', margin: '4px 0' }} />}
              </span>
              <span style={{ paddingBottom: 14, minWidth: 0 }}>
                <span style={{ display: 'block', fontSize: 13.5, fontWeight: 600 }}>{h.titre}{h.corps && <span style={{ fontWeight: 400, color: 'var(--ink4)' }}> — {h.corps}</span>}</span>
                <span style={{ ...s.discret, fontSize: 11.5 }}>{heure(h.cree_le)} · {nomCourt(h.auteur)}</span>
              </span>
            </li>
          ))}
        </ol>
      )}
    </Bloc>
  );
}

function Perimetre({ d, referent }: { d: TDossier; referent: boolean }) {
  const { data } = useAcces(d.id);
  const [ajout, setAjout] = useState(false);
  const { data: collegues } = useCollegues(ajout);
  const modifier = useModifierAcces(d.id);
  const deja = new Set([d.referent_id, ...(data ?? []).map((p) => p.id)]);
  return (
    <Bloc titre="Accès au dossier" action={referent && !ajout && <Bouton style={{ padding: '7px 12px', minHeight: 36, fontSize: 12 }} onClick={() => setAjout(true)}>Ajouter</Bouton>}>
      <p style={{ ...s.discret, margin: 0 }}>Aucun rôle, même administrateur, ne voit un dossier sans y être ajouté.</p>
      <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <li style={{ display: 'flex', alignItems: 'center', gap: 10 }}><Avatar p={d.referent} taille={28} /><span style={{ flex: 1, fontSize: 13.5, fontWeight: 600 }}>{d.referent ? `${d.referent.prenom} ${d.referent.nom}` : '—'}</span><Pastille ton="accent">Référent</Pastille></li>
        {(data ?? []).map((p) => (
          <li key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <Avatar p={p} taille={28} />
            <span style={{ flex: 1, minWidth: 0 }}><span style={{ display: 'block', fontSize: 13.5, fontWeight: 600 }}>{p.prenom} {p.nom}</span>{p.mandat && <span style={{ ...s.discret, fontSize: 11.5 }}>{p.mandat}</span>}</span>
            {referent && <Bouton variante="discret" style={{ padding: '6px 10px', minHeight: 36, fontSize: 12 }} onClick={() => modifier.mutate({ personneId: p.id, ajouter: false })}>Retirer</Bouton>}
          </li>
        ))}
      </ul>
      {ajout && (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <select defaultValue="" aria-label="Personne à ajouter" onChange={(e) => { if (e.target.value) { modifier.mutate({ personneId: e.target.value, ajouter: true }); setAjout(false); } }} style={{ ...s.saisie, flex: 1 }}>
            <option value="" disabled>Choisir un membre…</option>
            {(collegues ?? []).filter((p) => !deja.has(p.id)).map((p) => <option key={p.id} value={p.id}>{p.prenom} {p.nom}{p.mandat ? ` — ${p.mandat}` : ''}</option>)}
          </select>
          <Bouton variante="discret" onClick={() => setAjout(false)}>Annuler</Bouton>
        </div>
      )}
      {modifier.error && <Alerte>{(modifier.error as Error).message}</Alerte>}
    </Bloc>
  );
}

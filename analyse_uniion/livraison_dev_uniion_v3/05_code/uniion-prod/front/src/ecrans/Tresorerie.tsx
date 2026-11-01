import { useState } from 'react';
import { Link } from 'react-router-dom';
import type { Moi } from '../lib/supabase';
import { COTISATION, euros, lireAttestation, rpc, useAdherents, useCotisations, useEnregistrerCotisation, useSupprimerCotisation, useSynthese, type Attestation } from '../lib/gestion';
import { date } from '../lib/donnees';
import { useQueryClient } from '@tanstack/react-query';
import { EnTete } from '../ui/Coque';
import { Impression, imprimer } from '../ui/Rendu';
import { Alerte, Bloc, Bouton, Champ, Chargement, Pastille, Vide, s } from '../ui/kit';

export function Tresorerie(_: { moi: Moi }) {
  const qc = useQueryClient();
  const an = new Date().getFullYear();
  const [annee, setAnnee] = useState(an);
  const { data, isLoading, error } = useSynthese(annee);
  const retards = useAdherents({ statut_cotisation: ['en_retard'] }, 200, true);
  const [gen, setGen] = useState<{ n?: number; erreur?: string; attente?: boolean }>({});
  const generer = async () => {
    setGen({ attente: true });
    try { const n = await rpc<number>('attestations_generer', { p_annee: an - 1 }); setGen({ n }); qc.invalidateQueries({ queryKey: ['tresorerie'] }); }
    catch (e) { setGen({ erreur: (e as Error).message }); }
  };
  return (
    <>
      <EnTete titre="Trésorerie" sous="Cotisations encaissées et attestations fiscales. Les versements se saisissent depuis la fiche de chaque adhérent."
        action={<select value={annee} onChange={(e) => setAnnee(Number(e.target.value))} aria-label="Année" style={{ ...s.saisie, width: 'auto', borderRadius: 99, background: 'var(--surface)' }}>
          {[an, an - 1, an - 2, an - 3].map((a) => <option key={a} value={a}>{a}</option>)}</select>} />
      {error && <Alerte>{(error as Error).message}</Alerte>}
      {isLoading ? <Chargement /> : data && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 14, marginBottom: 18 }}>
          {[['Encaissé en ' + annee, euros(data.encaisse)], ['Cotisants', String(data.cotisants)], ['En retard (aujourd\'hui)', String(data.en_retard)], ['Attestations ' + annee, String(data.attestations)]].map(([l, v]) => (
            <section key={l} style={{ ...s.carte, padding: 18 }}><div style={s.surtitre}>{l}</div><div style={{ fontFamily: 'var(--fTitle)', fontSize: 30, marginTop: 6 }}>{v}</div></section>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 18, alignItems: 'flex-start' }}>
        <Bloc titre="Cotisations en retard" style={{ flex: '2 1 420px' }}>
          {retards.isLoading ? <Chargement /> : !retards.data?.length ? <Vide>Aucun retard.</Vide> : (
            <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>
              {retards.data.map((a) => (
                <li key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 10, border: '1px solid var(--bd)', borderRadius: 12, padding: '9px 12px', fontSize: 13.5 }}>
                  <span style={{ flex: 1, fontWeight: 600 }}>{a.nom.toUpperCase()} {a.prenom}</span>
                  <span style={{ color: 'var(--ink5)', fontSize: 12.5 }}>{a.mode_reglement ?? ''}{a.montant_cotisation ? ` · ${euros(Number(a.montant_cotisation))}` : ''}</span>
                  <Pastille ton="danger">{COTISATION.en_retard.libelle}</Pastille>
                </li>
              ))}
            </ul>
          )}
          <p style={{ ...s.discret, margin: 0 }}>Pour relancer : créez une liste « cotisation en retard » dans <Link to="/diffusions">Diffusions</Link>. Seuls les adhérents ayant consenti aux envois la recevront.</p>
        </Bloc>
        <Bloc titre={`Attestations fiscales ${an - 1}`} style={{ flex: '1 1 300px' }}>
          <p style={{ ...s.texte, margin: 0 }}>Une attestation par adhérent, d'après les versements encaissés en {an - 1}. Elle ouvre droit à un crédit d'impôt de 66 % des cotisations, dans la limite de 1 % des salaires et pensions (art. 199 quater C du CGI).</p>
          <Bouton variante="primaire" onClick={generer} disabled={gen.attente} style={{ alignSelf: 'flex-start' }}>{gen.attente ? 'Calcul…' : 'Générer ou mettre à jour'}</Bouton>
          {gen.n !== undefined && <Alerte ton="ok">{gen.n} attestation{gen.n > 1 ? 's' : ''} à jour. Chacune s'imprime depuis la fiche de l'adhérent.</Alerte>}
          {gen.erreur && <Alerte>{gen.erreur}</Alerte>}
        </Bloc>
      </div>
    </>
  );
}

// Section « Cotisations » de la fiche adhérent.
export function Cotisations({ adherent }: { adherent: string }) {
  const { data, isLoading, error } = useCotisations(adherent);
  const enregistrer = useEnregistrerCotisation(adherent);
  const supprimer = useSupprimerCotisation(adherent);
  const an = new Date().getFullYear();
  const [f, setF] = useState({ periode: String(an), montant: '', mode: '', encaisse_le: new Date().toISOString().slice(0, 10) });
  const [att, setAtt] = useState<Attestation | null>(null);
  const [erreurAtt, setErreurAtt] = useState('');
  const ouvrirAttestation = async () => {
    setErreurAtt('');
    try { const a = await lireAttestation(adherent, an - 1); setAtt(a); setTimeout(() => imprimer('a4'), 50); }
    catch (e) { setErreurAtt((e as Error).message); }
  };
  return (
    <section style={{ borderTop: '1px solid var(--bd)', paddingTop: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
      <h3 style={{ ...s.titre, fontSize: 18 }}>Cotisations</h3>
      {error && <Alerte>{(error as Error).message}</Alerte>}
      {isLoading ? <Chargement /> : !data?.length ? <Vide>Aucun versement enregistré.</Vide> : (
        <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
          {data.map((c) => (
            <li key={c.id} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13.5, background: 'var(--surf2)', borderRadius: 10, padding: '8px 10px' }}>
              <strong style={{ minWidth: 70 }}>{c.periode}</strong>
              <span style={{ flex: 1 }}>{euros(Number(c.montant))}{c.mode ? ` · ${c.mode}` : ''}</span>
              <span style={{ color: 'var(--ink5)', fontSize: 12 }}>{c.encaisse_le ? `encaissé le ${date(c.encaisse_le)}` : 'non encaissé'}</span>
              <button type="button" aria-label={`Supprimer le versement ${c.periode}`} onClick={() => { const m = prompt('Motif de la suppression (inscrit au journal) :'); if (m?.trim()) supprimer.mutate({ id: c.id, motif: m.trim() }); }}
                style={{ border: 'none', background: 'none', color: 'var(--dangerTx2)', cursor: 'pointer', minWidth: 32, minHeight: 32, fontSize: 16 }}>×</button>
            </li>
          ))}
        </ul>
      )}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(110px, 1fr))', gap: 8, alignItems: 'end' }}>
        <Champ libelle="Période"><input value={f.periode} onChange={(e) => setF({ ...f, periode: e.target.value })} placeholder="2026-T3" style={s.saisie} /></Champ>
        <Champ libelle="Montant (€)"><input type="number" min="0" step="0.01" value={f.montant} onChange={(e) => setF({ ...f, montant: e.target.value })} style={s.saisie} /></Champ>
        <Champ libelle="Mode"><input value={f.mode} onChange={(e) => setF({ ...f, mode: e.target.value })} placeholder="Prélèvement" style={s.saisie} /></Champ>
        <Champ libelle="Encaissé le"><input type="date" value={f.encaisse_le} onChange={(e) => setF({ ...f, encaisse_le: e.target.value })} style={s.saisie} /></Champ>
      </div>
      <Bouton style={{ alignSelf: 'flex-start' }} disabled={!f.montant || enregistrer.isPending}
        onClick={() => enregistrer.mutate({ periode: f.periode.trim(), montant: Number(f.montant), mode: f.mode || null, encaisse_le: f.encaisse_le || null }, { onSuccess: () => setF({ ...f, montant: '' }) })}>Enregistrer le versement</Bouton>
      {(enregistrer.error || supprimer.error) && <Alerte>{((enregistrer.error || supprimer.error) as Error).message}</Alerte>}
      <Bouton variante="discret" style={{ alignSelf: 'flex-start' }} onClick={ouvrirAttestation}>Imprimer l'attestation fiscale {an - 1}</Bouton>
      {erreurAtt && <Alerte ton="info">{erreurAtt}. Générez d'abord les attestations depuis la Trésorerie.</Alerte>}
      {att && <Impression format="a4" contenus={[<PageAttestation key="a" a={att} />]} />}
    </section>
  );
}

function PageAttestation({ a }: { a: Attestation }) {
  const p = { fontSize: 12, lineHeight: 1.6, margin: '0 0 10px' } as const;
  return (
    <div style={{ width: '100%', height: '100%', boxSizing: 'border-box', padding: '56px 60px', background: '#FFFFFF', color: '#111827', fontFamily: 'system-ui, "Segoe UI", Helvetica, sans-serif' }}>
      <div style={{ borderBottom: '2px solid #111827', paddingBottom: 10, marginBottom: 28 }}>
        <div style={{ fontSize: 16, fontWeight: 700 }}>{a.organisation}</div>
        {a.adresse && <div style={{ fontSize: 11, color: '#4B5563', whiteSpace: 'pre-line' }}>{a.adresse}</div>}
      </div>
      <h1 style={{ fontSize: 18, margin: '0 0 24px' }}>Attestation de versement de cotisations syndicales — année {a.annee}</h1>
      <p style={p}>L'organisation syndicale {a.organisation} ({a.sigle}) atteste avoir reçu de <strong>{a.prenom} {a.nom}</strong>, au titre de l'année {a.annee}, des cotisations syndicales d'un montant total de <strong>{euros(Number(a.montant))}</strong>.</p>
      <p style={p}>Ces cotisations ouvrent droit au crédit d'impôt prévu à l'article 199 quater C du code général des impôts, égal à 66 % de leur montant, dans la limite de 1 % du montant des salaires et pensions. Le crédit d'impôt n'est pas cumulable avec la déduction des frais réels pour ces mêmes cotisations.</p>
      <p style={p}>Attestation à conserver : elle peut être demandée par l'administration fiscale.</p>
      <p style={{ ...p, marginTop: 40 }}>Établie le {date(a.emise_le)}, pour le trésorier.</p>
    </div>
  );
}

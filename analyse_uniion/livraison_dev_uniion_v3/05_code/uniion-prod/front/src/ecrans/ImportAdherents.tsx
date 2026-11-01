import { useRef, useState, type ChangeEvent } from 'react';
import { Link } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { COLONNES_CSV, importer, lireCsv, telechargerModele, type RapportImport } from '../lib/gestion';
import { EnTete } from '../ui/Coque';
import { Alerte, Bloc, Bouton, Icone, I, Pastille, s } from '../ui/kit';

type Lu = Awaited<ReturnType<typeof lireCsv>> & { nom: string };

// Étapes : choisir → vérification serveur (simulation) → import. Rien n'est écrit avant la dernière étape.
export function ImportAdherents() {
  const qc = useQueryClient();
  const champ = useRef<HTMLInputElement>(null);
  const [lu, setLu] = useState<Lu | null>(null);
  const [verif, setVerif] = useState<RapportImport | null>(null);
  const [fait, setFait] = useState<RapportImport | null>(null);
  const [attente, setAttente] = useState(false);
  const [erreur, setErreur] = useState('');

  const choisir = async (e: ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]; e.target.value = '';
    if (!f) return;
    setErreur(''); setVerif(null); setFait(null);
    if (f.size > 5 * 1024 * 1024) { setErreur('Fichier trop volumineux (5 Mo au plus).'); return; }
    const r = await lireCsv(f);
    if (!r.lignes.length) { setErreur('Aucune ligne de données trouvée sous l\'en-tête.'); return; }
    setLu({ ...r, nom: f.name });
  };
  const appeler = async (simuler: boolean) => {
    if (!lu) return;
    setErreur(''); setAttente(true);
    try {
      const r = await importer(lu.nom, lu.sep, lu.lignes, simuler);
      if (simuler) setVerif(r); else { setFait(r); qc.invalidateQueries({ queryKey: ['adherents'] }); qc.invalidateQueries({ queryKey: ['adherents-agregats'] }); qc.invalidateQueries({ queryKey: ['etablissements'] }); }
    } catch (e) { setErreur((e as Error).message); }
    setAttente(false);
  };
  const recommencer = () => { setLu(null); setVerif(null); setFait(null); setErreur(''); };
  const nomLigne = (n: number) => { const l = lu?.lignes[n - 1]; return l ? `${l.prenom ?? ''} ${l.nom ?? ''}`.trim() || '(sans nom)' : ''; };

  return (
    <>
      <EnTete titre="Importer des adhérents" sous="Fichier CSV exporté d'un tableur (séparateur point-virgule ou virgule). Le fichier est vérifié ligne à ligne sur nos serveurs avant tout enregistrement."
        retour={<Link to="/adherents" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600, color: 'var(--ink4)', textDecoration: 'none' }}><Icone d={I.gauche} taille={16} />Adhérents</Link>} />

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 18, alignItems: 'flex-start' }}>
        <div style={{ flex: '2 1 480px', minWidth: 0, display: 'flex', flexDirection: 'column', gap: 18 }}>
          {fait ? (
            <Bloc titre="Import terminé">
              <Alerte ton="ok">{fait.valides} adhérent{fait.valides > 1 ? 's' : ''} importé{fait.valides > 1 ? 's' : ''}{fait.rejetees ? ` · ${fait.rejetees} ligne${fait.rejetees > 1 ? 's' : ''} écartée${fait.rejetees > 1 ? 's' : ''}` : ''}. L'opération est inscrite au journal.</Alerte>
              <Rejets r={fait} nomLigne={nomLigne} />
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <Link to="/adherents" style={{ textDecoration: 'none' }}><Bouton variante="primaire">Voir les adhérents</Bouton></Link>
                <Bouton onClick={recommencer}>Importer un autre fichier</Bouton>
              </div>
            </Bloc>
          ) : <>
            <Bloc titre="1. Choisir le fichier">
              <button type="button" onClick={() => champ.current?.click()} style={{ cursor: 'pointer', border: '1.5px dashed var(--acMid)', background: 'var(--acBg2)', borderRadius: 18, padding: '20px 16px', display: 'flex', alignItems: 'center', gap: 14, textAlign: 'left', fontFamily: 'inherit', color: 'var(--ink3)' }}>
                <span style={{ width: 40, height: 40, flex: '0 0 40px', borderRadius: 99, background: 'linear-gradient(135deg, var(--ac), var(--ac2))', color: '#FFFFFF', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icone d={I.plus} /></span>
                <span><span style={{ display: 'block', fontSize: 14, fontWeight: 700 }}>{lu ? lu.nom : 'Choisir un fichier CSV'}</span>
                  <span style={{ ...s.discret, display: 'block' }}>{lu ? `${lu.lignes.length} lignes · ${lu.encodage} · séparateur ${lu.sep === ';' ? 'point-virgule' : 'virgule'}` : '5 000 lignes et 5 Mo au plus'}</span></span>
              </button>
              <input ref={champ} type="file" accept=".csv,text/csv" onChange={choisir} hidden />
              {lu && <>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>{lu.reconnues.map((c) => <Pastille key={c} ton="ok">{c}</Pastille>)}</div>
                {!!lu.manquantes.length && <Alerte>Colonnes obligatoires absentes : {lu.manquantes.join(', ')}. Toutes les lignes seraient refusées.</Alerte>}
                {!!lu.ignorees.length && <p style={{ ...s.discret, margin: 0 }}>Colonnes non reconnues, ignorées : {lu.ignorees.join(', ')}.</p>}
                {!lu.reconnues.some((c) => c.startsWith('Consentement')) && <Alerte ton="info">Pas de colonne « consentement » : les adhérents importés ne recevront aucun envoi tant que leur consentement n'est pas renseigné sur leur fiche.</Alerte>}
              </>}
            </Bloc>

            {lu && (
              <Bloc titre="2. Vérifier">
                {!verif ? <>
                  <p style={{ ...s.texte, margin: 0 }}>Le serveur contrôle chaque ligne (champs obligatoires, e-mail, dates, montants, doublons avec le fichier existant) sans rien enregistrer.</p>
                  <Bouton variante="primaire" onClick={() => appeler(true)} disabled={attente} style={{ alignSelf: 'flex-start' }}>{attente ? 'Vérification…' : 'Lancer la vérification'}</Bouton>
                </> : <>
                  <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <Pastille ton="ok">{verif.valides} prête{verif.valides > 1 ? 's' : ''} à importer</Pastille>
                    {!!verif.rejetees && <Pastille ton="danger">{verif.rejetees} à corriger</Pastille>}
                    {!!verif.doublons && <Pastille ton="alerte">{verif.doublons} doublon{verif.doublons > 1 ? 's' : ''}</Pastille>}
                  </div>
                  <Rejets r={verif} nomLigne={nomLigne} />
                </>}
              </Bloc>
            )}

            {verif && (
              <Bloc titre="3. Importer">
                <p style={{ ...s.texte, margin: 0 }}>{verif.rejetees ? 'Les lignes à corriger seront écartées ; vous pourrez les réimporter après correction. ' : ''}Les établissements inconnus seront créés.</p>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <Bouton variante="primaire" onClick={() => appeler(false)} disabled={attente || !verif.valides}>{attente ? 'Import…' : `Importer ${verif.valides} adhérent${verif.valides > 1 ? 's' : ''}`}</Bouton>
                  <Bouton variante="discret" onClick={recommencer}>Annuler</Bouton>
                </div>
              </Bloc>
            )}
          </>}
          {erreur && <Alerte>{erreur}</Alerte>}
        </div>

        <Bloc titre="Colonnes attendues" style={{ flex: '1 1 280px' }} action={<Bouton style={{ padding: '7px 12px', minHeight: 36, fontSize: 12 }} onClick={telechargerModele}>Modèle</Bouton>}>
          <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
            {COLONNES_CSV.map((c) => (
              <li key={c.k} style={{ display: 'flex', gap: 8, alignItems: 'baseline', fontSize: 13 }}>
                <code style={{ fontSize: 12, color: 'var(--ink3)', background: 'var(--chip)', borderRadius: 6, padding: '1px 6px' }}>{c.k}</code>
                <span style={{ flex: 1, color: 'var(--ink4)' }}>{c.libelle}</span>
                <span style={{ fontSize: 11, fontWeight: 700, color: c.requis ? 'var(--acTx2)' : 'var(--ink5)' }}>{c.requis ? 'obligatoire' : 'facultative'}</span>
              </li>
            ))}
          </ul>
        </Bloc>
      </div>
    </>
  );
}

function Rejets({ r, nomLigne }: { r: RapportImport; nomLigne: (n: number) => string }) {
  if (!r.rapport.length) return null;
  return (
    <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 320, overflowY: 'auto' }}>
      {r.rapport.map((x) => (
        <li key={x.ligne} style={{ display: 'flex', gap: 10, flexWrap: 'wrap', border: '1px solid var(--dangerBd2)', borderRadius: 12, padding: '8px 12px', fontSize: 13 }}>
          <strong style={{ color: 'var(--ink5)', minWidth: 52 }}>L{x.ligne + 1}</strong>
          <span style={{ flex: '1 1 140px', fontWeight: 600 }}>{nomLigne(x.ligne)}</span>
          <span style={{ color: 'var(--dangerTx2)' }}>{x.motifs.join(' · ')}</span>
        </li>
      ))}
    </ul>
  );
}

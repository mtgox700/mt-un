import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import type { Moi } from '../lib/supabase';
import { FORMATS, STATUTS_DOC, deposerMedia, nouvelIdBloc, useDocument, useEnregistrerDocument, useImages, useOrganisation, type Doc } from '../lib/contenus';
import { useExtensions, type Bloc } from '../lib/extensions';
import { demanderUnii, reidentifier } from '../lib/ia';
import { Apercu, Impression, imprimer, pages, rendrePage, type Identite } from '../ui/Rendu';
import { useLarge } from '../ui/Coque';
import { Alerte, Bouton, Champ, Chargement, Icone, I, Pastille, s } from '../ui/kit';

const COEUR: { type: string; label: string; rows: number }[] = [
  { type: 'tag', label: 'Badge', rows: 1 }, { type: 'h1', label: 'Titre', rows: 1 }, { type: 'h2', label: 'Intertitre', rows: 1 }, { type: 'h3', label: 'Sous-titre', rows: 1 },
  { type: 'p', label: 'Paragraphe', rows: 4 }, { type: 'ul', label: 'Liste', rows: 4 }, { type: 'quote', label: 'Encadré', rows: 3 }, { type: 'table', label: 'Tableau', rows: 4 },
  { type: 'pagebreak', label: 'Saut de page', rows: 0 },
];

export function Document({ moi }: { moi: Moi }) {
  const { id = '' } = useParams();
  const { data: d, isLoading } = useDocument(id);
  if (isLoading) return <Chargement />;
  if (!d) return <Alerte ton="info">Ce document n'existe pas ou ne vous est pas accessible.</Alerte>;
  return <Editeur key={d.id} d={d} moi={moi} />;
}

function Editeur({ d, moi }: { d: Doc; moi: Moi }) {
  const large = useLarge(1100);
  const aller = useNavigate();
  const ext = useExtensions();
  const { data: org } = useOrganisation(moi.org_id);
  const enregistrer = useEnregistrerDocument();
  const auteur = d.auteur_id === moi.personne_id;
  const fige = d.statut === 'signe' || !auteur;

  const [titre, setTitre] = useState(d.titre);
  const [blocs, setBlocs] = useState<Bloc[]>(d.blocs ?? []);
  const [gabarit, setGabarit] = useState(d.gabarit);
  const [format, setFormat] = useState(d.format);
  const [apparence, setApparence] = useState(d.apparence ?? {});
  const [onglet, setOnglet] = useState<'contenu' | 'style'>('contenu');
  const [erreursRendu, setErreursRendu] = useState<string[]>([]);
  const [etatSauve, setEtatSauve] = useState<'' | 'attente' | 'ok' | 'erreur'>('');

  // Enregistrement automatique 1,2 s après la dernière frappe ; la version suit la réponse du serveur.
  const dernier = useRef(d);
  dernier.current = (enregistrer.data && enregistrer.data.version > d.version ? enregistrer.data : d);
  const sauve = useRef(JSON.stringify([d.titre, d.blocs ?? [], d.gabarit, d.format, d.apparence ?? {}]));
  useEffect(() => {
    const instant = JSON.stringify([titre, blocs, gabarit, format, apparence]);
    if (fige || instant === sauve.current) return;
    setEtatSauve('attente');
    const t = setTimeout(() => enregistrer.mutate({ d: dernier.current, modif: { titre: titre.trim() || 'Sans titre', blocs, gabarit, format, apparence } },
      { onSuccess: () => { sauve.current = instant; setEtatSauve('ok'); }, onError: () => setEtatSauve('erreur') }), 1200);
    return () => clearTimeout(t);
  }, [titre, blocs, gabarit, format, apparence]);  // eslint-disable-line react-hooks/exhaustive-deps

  const style = gabarit === 'classique' ? null : ext.styles.find((x) => x.id === gabarit) ?? null;
  const styleManquant = gabarit !== 'classique' && !style && ext.pret;
  const images = useImages(blocs.filter((b) => b.media).map((b) => b.media!));
  const blocsRendus = useMemo(() => blocs.map((b) => (b.media && images[b.media] ? { ...b, img: images[b.media] } : b)), [blocs, images]);
  const identite: Identite = { emetteur: org?.sigle ?? '', section: org?.nom ?? '', contact: org?.email ?? '', logo: '' };
  const decoupe = pages(blocsRendus);
  const contenus = decoupe.map((p, i) => rendrePage({ blocs: p, index: i, count: decoupe.length, style, palette: apparence.palette, police: apparence.police, format, org: identite, extBlocs: ext.blocs,
    onErreur: (m) => setTimeout(() => setErreursRendu((l) => (l.includes(m) ? l : [...l.slice(-4), m]))) }));
  const slotsVides = (style?.slots ?? []).filter((sl) => !sl.optional && !blocsRendus.filter((b) => b.type === sl.type)[sl.index]?.img);

  const statut = (st: Doc['statut']) => enregistrer.mutate({ d: dernier.current, modif: { statut: st } });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div data-hors-impression="" style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <Link to="/documents" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600, color: 'var(--ink4)', textDecoration: 'none', minHeight: 36 }}><Icone d={I.gauche} taille={16} />Documents</Link>
        <Pastille ton={STATUTS_DOC[d.statut].ton}>{STATUTS_DOC[d.statut].libelle}</Pastille>
        <span role="status" style={{ ...s.discret, fontSize: 12 }}>{etatSauve === 'attente' ? 'Modifications non enregistrées…' : etatSauve === 'ok' ? 'Enregistré' : ''}</span>
        <span style={{ marginLeft: 'auto', display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {auteur && d.statut === 'brouillon' && <Bouton onClick={() => statut('relu')}>Marquer comme relu</Bouton>}
          {auteur && d.statut === 'relu' && <><Bouton variante="discret" onClick={() => statut('brouillon')}>Repasser en brouillon</Bouton><Bouton onClick={() => statut('diffuse')}>Marquer comme diffusé</Bouton></>}
          <Bouton variante="primaire" onClick={() => imprimer(format)}>Imprimer / PDF</Bouton>
        </span>
      </div>
      {etatSauve === 'erreur' && <Alerte>{(enregistrer.error as Error)?.message ?? 'Enregistrement impossible.'}</Alerte>}
      {!auteur && <Alerte ton="info">Document de {d.auteur ? `${d.auteur.prenom} ${d.auteur.nom}` : 'un autre membre'} : lecture seule.</Alerte>}
      {d.statut === 'signe' && <Alerte ton="info">Document signé : son contenu est figé.</Alerte>}
      {styleManquant && <Alerte ton="info">Le style « {gabarit} » vient d'une extension désactivée : le rendu classique est utilisé. Le contenu est intact.</Alerte>}
      {ext.erreurs.map((m) => <Alerte key={m}>{m}</Alerte>)}

      <div style={{ display: 'flex', gap: 20, alignItems: 'flex-start', flexDirection: large ? 'row' : 'column' }}>
        <div data-hors-impression="" style={{ flex: large ? '0 0 440px' : '1 1 auto', width: large ? 440 : '100%', minWidth: 0, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <input value={titre} onChange={(e) => setTitre(e.target.value)} disabled={fige} aria-label="Titre du document" maxLength={160}
            style={{ ...s.saisie, fontFamily: 'var(--fTitle)', fontSize: 22, background: 'var(--surface)' }} />
          <div role="tablist" style={{ display: 'flex', gap: 4, background: 'var(--chip)', borderRadius: 99, padding: 4, alignSelf: 'flex-start' }}>
            {(['contenu', 'style'] as const).map((o) => (
              <button key={o} type="button" role="tab" aria-selected={onglet === o} onClick={() => setOnglet(o)} style={{ cursor: 'pointer', border: 'none', borderRadius: 99, padding: '8px 16px', minHeight: 36, fontSize: 13, fontWeight: 700, fontFamily: 'inherit',
                background: onglet === o ? 'var(--surface)' : 'transparent', color: onglet === o ? 'var(--ink)' : 'var(--ink5)' }}>{o === 'contenu' ? 'Contenu' : 'Style'}</button>
            ))}
          </div>
          {slotsVides.length > 0 && <Alerte ton="info">Ce style attend une image : {slotsVides.map((x) => x.label).join(', ')}. Ajoutez un bloc Photo dans le contenu.</Alerte>}
          {onglet === 'contenu'
            ? <Contenu blocs={blocs} setBlocs={setBlocs} fige={fige} extBlocs={ext.blocs} images={images} moi={moi} docId={d.id} styleHint={style?.uniiHint} />
            : <Style gabarit={gabarit} setGabarit={setGabarit} format={format} setFormat={setFormat} apparence={apparence} setApparence={setApparence} styles={ext.styles} fige={fige} />}
          {erreursRendu.map((m) => <Alerte key={m}>{m}</Alerte>)}
          {auteur && d.statut !== 'signe' && (
            <Bouton variante="discret" style={{ alignSelf: 'flex-start', color: 'var(--dangerTx2)' }}
              onClick={() => { if (confirm('Supprimer ce document ?')) enregistrer.mutate({ d: dernier.current, modif: { supprime_le: new Date().toISOString() } }, { onSuccess: () => aller('/documents') }); }}>Supprimer le document</Bouton>
          )}
        </div>
        <div data-hors-impression="" style={{ flex: 1, minWidth: 0, width: '100%', background: 'var(--chip)', borderRadius: 22, padding: large ? 28 : 14, boxSizing: 'border-box', position: large ? 'sticky' : 'static', top: 20 }}>
          <Apercu contenus={contenus} format={format} />
        </div>
      </div>
      <Impression contenus={contenus} format={format} />
    </div>
  );
}

function Contenu({ blocs, setBlocs, fige, extBlocs, images, moi, docId, styleHint }: { blocs: Bloc[]; setBlocs: (f: (b: Bloc[]) => Bloc[]) => void; fige: boolean; extBlocs: ReturnType<typeof useExtensions>['blocs']; images: Record<string, string>; moi: Moi; docId: string; styleHint?: string }) {
  const [ajout, setAjout] = useState(false);
  const types = [...COEUR, ...extBlocs.map((b) => ({ type: b.type, label: b.label, rows: b.rows ?? 3 }))];
  const maj = (id: string, p: Partial<Bloc>) => setBlocs((l) => l.map((b) => (b.id === id ? { ...b, ...p } : b)));
  const deplacer = (i: number, dir: -1 | 1) => setBlocs((l) => { const c = [...l]; const [x] = c.splice(i, 1); c.splice(i + dir, 0, x!); return c; });
  const ajouter = (type: string) => { const e = extBlocs.find((b) => b.type === type); setBlocs((l) => [...l, { id: nouvelIdBloc(), type, text: e?.sample ?? '' }]); setAjout(false); };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      {!fige && <Redaction blocs={blocs} setBlocs={setBlocs} styleHint={styleHint} types={types.map((t) => t.type)} />}
      {blocs.map((b, i) => {
        const t = types.find((x) => x.type === b.type);
        const e = extBlocs.find((x) => x.type === b.type);
        return (
          <div key={b.id} style={{ background: 'var(--surface)', border: '1px solid var(--bd)', borderRadius: 16, padding: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ ...s.surtitre, flex: 1 }}>{t?.label ?? `${b.type} (extension inactive)`}</span>
              {!fige && <>
                <button type="button" aria-label="Monter" disabled={i === 0} onClick={() => deplacer(i, -1)} style={petit}>↑</button>
                <button type="button" aria-label="Descendre" disabled={i === blocs.length - 1} onClick={() => deplacer(i, 1)} style={petit}>↓</button>
                <button type="button" aria-label="Supprimer le bloc" onClick={() => setBlocs((l) => l.filter((x) => x.id !== b.id))} style={{ ...petit, color: 'var(--dangerTx2)' }}>×</button>
              </>}
            </div>
            {b.type !== 'pagebreak' && <textarea value={b.text} disabled={fige} onChange={(ev) => maj(b.id, { text: ev.target.value })} rows={Math.max(1, t?.rows ?? 3)} placeholder={e?.ph}
              aria-label={t?.label} style={{ ...s.saisie, resize: 'vertical', fontSize: b.type === 'h1' ? 17 : 14, fontWeight: b.type.startsWith('h') ? 700 : 400 }} />}
            {e?.hint && <span style={{ ...s.discret, fontSize: 11.5 }}>{e.hint}</span>}
            {e?.accepts === 'image' && !fige && <Photo bloc={b} url={b.media ? images[b.media] : undefined} moi={moi} docId={docId} onMedia={(m) => maj(b.id, { media: m })} />}
          </div>
        );
      })}
      {!fige && (ajout ? (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, background: 'var(--surface)', border: '1px solid var(--bd)', borderRadius: 16, padding: 12 }}>
          {types.map((t) => <button key={t.type} type="button" onClick={() => ajouter(t.type)} style={{ cursor: 'pointer', border: '1px solid var(--bd2)', background: 'var(--surface)', borderRadius: 99, padding: '7px 12px', minHeight: 36, fontSize: 12.5, fontWeight: 600, color: 'var(--ink3)', fontFamily: 'inherit' }}>{t.label}</button>)}
          <Bouton variante="discret" onClick={() => setAjout(false)} style={{ minHeight: 36, padding: '7px 12px' }}>Fermer</Bouton>
        </div>
      ) : <Bouton onClick={() => setAjout(true)} style={{ alignSelf: 'flex-start' }}><Icone d={I.plus} taille={16} />Ajouter un bloc</Bouton>)}
    </div>
  );
}
const petit = { cursor: 'pointer', border: '1px solid var(--bd)', background: 'var(--surface)', borderRadius: 8, width: 32, height: 32, fontSize: 15, color: 'var(--ink4)' } as const;

function Photo({ bloc, url, moi, docId, onMedia }: { bloc: Bloc; url?: string; moi: Moi; docId: string; onMedia: (id: string) => void }) {
  const champ = useRef<HTMLInputElement>(null);
  const [fichier, setFichier] = useState<File | null>(null);
  const [identifiable, setIdentifiable] = useState<boolean | null>(null);
  const [consentement, setConsentement] = useState(false);
  const [etat, setEtat] = useState<'' | 'envoi'>('');
  const [erreur, setErreur] = useState('');
  const envoyer = async () => {
    setErreur(''); setEtat('envoi');
    try { onMedia(await deposerMedia(fichier!, { orgId: moi.org_id!, personneId: moi.personne_id!, documentId: docId, identifiable: !!identifiable, consentement })); setFichier(null); setIdentifiable(null); setConsentement(false); }
    catch (e) { setErreur((e as Error).message); }
    setEtat('');
  };
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {url && <img src={url} alt="" style={{ maxWidth: '100%', maxHeight: 140, objectFit: 'contain', alignSelf: 'flex-start', borderRadius: 8 }} />}
      {!fichier ? <Bouton onClick={() => champ.current?.click()} style={{ alignSelf: 'flex-start', minHeight: 36, padding: '7px 12px', fontSize: 12.5 }}>{bloc.media ? "Remplacer l'image" : 'Déposer une image'}</Bouton> : (
        <div style={{ border: '1px solid var(--bd2)', borderRadius: 12, padding: 10, display: 'flex', flexDirection: 'column', gap: 8, fontSize: 13 }}>
          <strong>{fichier.name}</strong>
          <span>Une personne est-elle reconnaissable sur cette image ?</span>
          <div style={{ display: 'flex', gap: 8 }}>
            {[true, false].map((v) => <Bouton key={String(v)} variante={identifiable === v ? 'primaire' : 'secondaire'} style={{ minHeight: 36, padding: '7px 14px' }} onClick={() => setIdentifiable(v)}>{v ? 'Oui' : 'Non'}</Bouton>)}
          </div>
          {identifiable && <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', lineHeight: 1.5 }}><input type="checkbox" checked={consentement} onChange={(e) => setConsentement(e.target.checked)} style={{ width: 18, height: 18, marginTop: 2 }} />J'ai l'accord écrit de chaque personne reconnaissable pour cette diffusion.</label>}
          <div style={{ display: 'flex', gap: 8 }}>
            <Bouton variante="primaire" disabled={identifiable === null || (identifiable && !consentement) || etat === 'envoi'} onClick={envoyer} style={{ minHeight: 36, padding: '7px 14px' }}>{etat === 'envoi' ? 'Envoi…' : 'Ajouter'}</Bouton>
            <Bouton variante="discret" onClick={() => setFichier(null)} style={{ minHeight: 36, padding: '7px 14px' }}>Annuler</Bouton>
          </div>
        </div>
      )}
      <input ref={champ} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={(e) => { setFichier(e.target.files?.[0] ?? null); e.target.value = ''; }} />
      {erreur && <Alerte>{erreur}</Alerte>}
      <span style={{ ...s.discret, fontSize: 11.5 }}>L'image est réduite et ses métadonnées (lieu, appareil) supprimées. Elle n'est jamais envoyée à unii.</span>
    </div>
  );
}

// Rédaction assistée : unii propose un contenu complet en blocs, que l'utilisateur accepte ou non.
function Redaction({ blocs, setBlocs, styleHint, types }: { blocs: Bloc[]; setBlocs: (f: (b: Bloc[]) => Bloc[]) => void; styleHint?: string; types: string[] }) {
  const [ouvert, setOuvert] = useState(false);
  const [consigne, setConsigne] = useState('');
  const [attente, setAttente] = useState(false);
  const [erreur, setErreur] = useState('');
  const [proposition, setProposition] = useState<Bloc[] | null>(null);
  const demander = async () => {
    setErreur(''); setAttente(true); setProposition(null);
    const actuel = blocs.filter((b) => b.type !== 'pagebreak').map((b) => `${b.type}: ${b.text}`).join('\n');  // jamais d'image
    const texte = `${consigne.trim()}\n\n${styleHint ? `Consigne de mise en page : ${styleHint}\n` : ''}Types de blocs autorisés : ${types.filter((t) => t !== 'pagebreak').join(', ')}.\nContenu actuel :\n${actuel || '(vide)'}\n\nRéponds uniquement par un tableau JSON [{"type": "...", "text": "..."}].`;
    const r = await demanderUnii('document', texte, {});
    setAttente(false);
    if (r.refus === 'masquage_incomplet') { setErreur("Rien n'a été envoyé : un nom propre n'a pas pu être masqué. Reformulez sans nom de personne."); return; }
    if (r.erreur || !r.reponse) { setErreur(r.erreur ?? 'unii est indisponible.'); return; }
    const rep = r.apercu_masque ? reidentifier(r.reponse, r.apercu_masque, texte) : r.reponse;
    try {
      const json = JSON.parse(rep.slice(rep.indexOf('['), rep.lastIndexOf(']') + 1)) as { type: string; text: string }[];
      const ok = json.filter((b) => types.includes(b.type) && typeof b.text === 'string').map((b) => ({ id: nouvelIdBloc(), type: b.type, text: b.text }));
      if (!ok.length) throw new Error();
      setProposition(ok);
    } catch { setErreur("La proposition d'unii n'a pas pu être lue. Réessayez en précisant la consigne."); }
  };
  if (!ouvert) return <Bouton variante="primaire" onClick={() => setOuvert(true)} style={{ alignSelf: 'flex-start' }}><Icone d={I.unii} taille={16} />Rédiger avec unii</Bouton>;
  return (
    <div style={{ border: '1px solid var(--acBd)', background: 'var(--acBg2)', borderRadius: 16, padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
      <Champ libelle="Que doit dire ce document ?" aide="Pas de nom de salarié : unii n'en a pas besoin pour rédiger.">
        <textarea value={consigne} onChange={(e) => setConsigne(e.target.value)} rows={3} placeholder="Ex. : tract d'appel à l'assemblée du 4 novembre sur la NAO, ton combatif, 3 revendications" style={{ ...s.saisie, resize: 'vertical', background: 'var(--surface)' }} />
      </Champ>
      {erreur && <Alerte>{erreur}</Alerte>}
      {proposition && (
        <div style={{ background: 'var(--surface)', borderRadius: 12, padding: 12, display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 260, overflowY: 'auto' }}>
          {proposition.map((b) => <div key={b.id} style={{ fontSize: 13, lineHeight: 1.5 }}><span style={{ ...s.surtitre, marginRight: 6 }}>{b.type}</span><span style={{ whiteSpace: 'pre-line' }}>{b.text}</span></div>)}
        </div>
      )}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {proposition
          ? <><Bouton variante="primaire" onClick={() => { const imgs = blocs.filter((b) => b.media); setBlocs(() => [...proposition, ...imgs]); setProposition(null); setOuvert(false); setConsigne(''); }}>Remplacer le contenu</Bouton>
              <Bouton onClick={demander} disabled={attente}>Autre proposition</Bouton></>
          : <Bouton variante="primaire" onClick={demander} disabled={!consigne.trim() || attente}>{attente ? 'unii rédige…' : 'Proposer'}</Bouton>}
        <Bouton variante="discret" onClick={() => { setOuvert(false); setProposition(null); }}>Fermer</Bouton>
      </div>
    </div>
  );
}

function Style({ gabarit, setGabarit, format, setFormat, apparence, setApparence, styles, fige }: {
  gabarit: string; setGabarit: (v: string) => void; format: string; setFormat: (v: string) => void;
  apparence: Doc['apparence']; setApparence: (v: Doc['apparence']) => void; styles: ReturnType<typeof useExtensions>['styles']; fige: boolean }) {
  const st = styles.find((x) => x.id === gabarit);
  const carte = (actif: boolean) => ({ cursor: fige ? 'default' : 'pointer', textAlign: 'left', border: actif ? '1.5px solid var(--ac)' : '1px solid var(--bd2)', background: actif ? 'var(--acBg)' : 'var(--surface)', borderRadius: 14, padding: '10px 12px', fontFamily: 'inherit', display: 'flex', flexDirection: 'column', gap: 3 } as const);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <Champ libelle="Format"><select value={format} disabled={fige} onChange={(e) => setFormat(e.target.value)} style={s.saisie}>
        {Object.entries(FORMATS).filter(([k]) => !st || st.formats.includes(k)).map(([k, v]) => <option key={k} value={k}>{v.libelle}</option>)}</select></Champ>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 8 }}>
        <button type="button" disabled={fige} onClick={() => setGabarit('classique')} style={carte(gabarit === 'classique')}><strong style={{ fontSize: 13.5 }}>Classique</strong><span style={{ ...s.discret, fontSize: 11.5 }}>La charte de l'organisation.</span></button>
        {styles.map((x) => (
          <button key={x.id} type="button" disabled={fige} onClick={() => { setGabarit(x.id); setApparence({}); if (!x.formats.includes(format)) setFormat(x.formats[0]!); }} style={carte(gabarit === x.id)}>
            <strong style={{ fontSize: 13.5 }}>{x.label}</strong><span style={{ ...s.discret, fontSize: 11.5 }}>{x.desc}</span>
          </button>
        ))}
      </div>
      {!styles.length && <p style={{ ...s.discret, margin: 0 }}>Les styles graphiques d'uniion Studio apparaissent ici quand un administrateur active l'extension.</p>}
      {st && <>
        {st.notice && <Alerte ton="info">{st.notice}</Alerte>}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <span style={s.surtitre}>Couleurs</span>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {st.palettes.map((p) => {
              const actif = (apparence.palette ?? st.palettes[0]!.id) === p.id;
              return <button key={p.id} type="button" disabled={fige} onClick={() => setApparence({ ...apparence, palette: p.id })} aria-pressed={actif} style={{ cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 8, border: actif ? '1.5px solid var(--ac)' : '1px solid var(--bd2)', background: 'var(--surface)', borderRadius: 99, padding: '6px 12px 6px 6px', minHeight: 36, fontFamily: 'inherit', fontSize: 12.5, fontWeight: 600, color: 'var(--ink3)' }}>
                <span style={{ display: 'flex' }}>{Object.values(p.colors).map((c, i) => <span key={i} style={{ width: 16, height: 16, borderRadius: 99, background: c, marginLeft: i ? -5 : 0, border: '1.5px solid var(--surface)' }} />)}</span>{p.label}</button>;
            })}
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <span style={s.surtitre}>Polices</span>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {st.fonts.map((p) => {
              const actif = (apparence.police ?? st.fonts[0]!.id) === p.id;
              return <button key={p.id} type="button" disabled={fige} onClick={() => setApparence({ ...apparence, police: p.id })} aria-pressed={actif} style={{ cursor: 'pointer', border: actif ? '1.5px solid var(--ac)' : '1px solid var(--bd2)', background: 'var(--surface)', borderRadius: 99, padding: '7px 14px', minHeight: 36, fontFamily: p.head, fontSize: 14, color: 'var(--ink2)' }}>{p.label}</button>;
            })}
          </div>
        </div>
      </>}
    </div>
  );
}

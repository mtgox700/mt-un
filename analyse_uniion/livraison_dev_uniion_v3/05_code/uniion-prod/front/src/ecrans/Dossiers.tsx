import { useMemo, useState, type DragEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { CATEGORIES, Conflit, STATUTS, echeance, nomCourt, useCreerDossier, useDossiers, useModifierDossier, type Dossier, type Statut } from '../lib/donnees';
import { EnTete } from '../ui/Coque';
import { Alerte, Avatar, Bouton, Champ, Chargement, Icone, I, Pastille, Vide, s } from '../ui/kit';

export function Dossiers() {
  const { data, isLoading, error } = useDossiers();
  const modifier = useModifierDossier();
  const [params, setParams] = useSearchParams();
  const nouveau = params.has('nouveau');
  const [cherche, setCherche] = useState('');
  const [categorie, setCategorie] = useState('');
  const [survol, setSurvol] = useState<Statut | null>(null);
  const [avis, setAvis] = useState('');

  const visibles = useMemo(() => (data ?? []).filter((d) =>
    (!categorie || d.categorie === categorie) &&
    (!cherche || (d.intitule + ' ' + (d.description ?? '')).toLowerCase().includes(cherche.toLowerCase()))), [data, cherche, categorie]);

  const deplacer = (d: Dossier, statut: Statut) => {
    if (d.statut === statut) return;
    setAvis('');
    modifier.mutate({ d, modif: { statut } }, { onError: (e) => setAvis(e instanceof Conflit ? e.message : 'Changement d\'état impossible.') });
  };
  const deposer = (e: DragEvent, statut: Statut) => {
    e.preventDefault(); setSurvol(null);
    const d = data?.find((x) => x.id === e.dataTransfer.getData('text/x-dossier'));
    if (d) deplacer(d, statut);
  };

  return (
    <>
      <EnTete titre="Dossiers" sous="Seuls les dossiers dont vous êtes référent ou auxquels vous avez été ajouté apparaissent ici."
        action={!nouveau && <Bouton variante="primaire" onClick={() => setParams({ nouveau: '' })}><Icone d={I.plus} taille={16} />Nouveau dossier</Bouton>} />

      {nouveau && <NouveauDossier fermer={() => setParams({})} />}

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginBottom: 18 }}>
        <input type="search" value={cherche} onChange={(e) => setCherche(e.target.value)} placeholder="Rechercher un dossier" aria-label="Rechercher un dossier" style={{ ...s.saisie, background: 'var(--surface)', flex: '1 1 240px', maxWidth: 360, borderRadius: 99 }} />
        <select value={categorie} onChange={(e) => setCategorie(e.target.value)} aria-label="Catégorie" style={{ ...s.saisie, background: 'var(--surface)', width: 'auto', borderRadius: 99, paddingRight: 32 }}>
          <option value="">Toutes catégories</option>
          {CATEGORIES.map((c) => <option key={c}>{c}</option>)}
        </select>
      </div>

      {avis && <div style={{ marginBottom: 14 }}><Alerte>{avis}</Alerte></div>}
      {error && <Alerte>Impossible de charger les dossiers.</Alerte>}
      {isLoading && <Chargement />}

      {data && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16, alignItems: 'start' }}>
          {STATUTS.map((col, ci) => {
            const cartes = visibles.filter((d) => d.statut === col.id);
            return (
              <section key={col.id} aria-label={col.libelle}
                onDragOver={(e) => { e.preventDefault(); setSurvol(col.id); }} onDragLeave={() => setSurvol(null)} onDrop={(e) => deposer(e, col.id)}
                style={{ background: survol === col.id ? 'var(--acBg2)' : 'var(--chip)', outline: survol === col.id ? '2px dashed var(--acMid)' : 'none', borderRadius: 22, padding: 12, display: 'flex', flexDirection: 'column', gap: 10, minHeight: 160, transition: 'background .15s' }}>
                <h2 style={{ margin: 0, padding: '4px 6px', display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, fontWeight: 700, color: 'var(--ink3)' }}>
                  <span style={{ width: 8, height: 8, borderRadius: 99, background: col.pastille }} />{col.libelle}
                  <span style={{ marginLeft: 'auto', color: 'var(--ink5)', fontWeight: 600 }}>{cartes.length}</span>
                </h2>
                {!cartes.length && <Vide>{data.length ? 'Aucun dossier' : col.id === 'todo' ? 'Créez votre premier dossier.' : 'Aucun dossier'}</Vide>}
                {cartes.map((d) => <Carte key={d.id} d={d}
                  gauche={ci > 0 ? () => deplacer(d, STATUTS[ci - 1]!.id) : undefined}
                  droite={ci < 2 ? () => deplacer(d, STATUTS[ci + 1]!.id) : undefined}
                  libG={ci > 0 ? STATUTS[ci - 1]!.libelle : ''} libD={ci < 2 ? STATUTS[ci + 1]!.libelle : ''} />)}
              </section>
            );
          })}
        </div>
      )}
    </>
  );
}

function Carte({ d, gauche, droite, libG, libD }: { d: Dossier; gauche?: () => void; droite?: () => void; libG: string; libD: string }) {
  const e = echeance(d.echeance);
  const fleche = { cursor: 'pointer', border: '1px solid var(--bd)', background: 'var(--surface)', borderRadius: 10, width: 36, height: 36, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink4)' } as const;
  return (
    <article draggable onDragStart={(ev) => { ev.dataTransfer.setData('text/x-dossier', d.id); ev.dataTransfer.effectAllowed = 'move'; }}
      style={{ background: 'var(--surface)', border: '1px solid var(--bd)', borderRadius: 16, boxShadow: '0 1px 2px rgba(17,24,39,.04)', cursor: 'grab' }}>
      <Link to={`/dossiers/${d.id}`} draggable={false} style={{ display: 'flex', flexDirection: 'column', gap: 8, padding: '13px 14px 10px', textDecoration: 'none', color: 'inherit' }}>
        <span style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          <Pastille>{d.categorie}</Pastille>
          {d.contentieux && <Pastille ton="alerte">Contentieux</Pastille>}
        </span>
        <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)', lineHeight: 1.35 }}>{d.intitule}</span>
        {d.description && <span style={{ ...s.discret, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{d.description}</span>}
        <span style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: 'var(--ink5)' }}>
          <Avatar p={d.referent} taille={22} />{nomCourt(d.referent)}
          <span style={{ marginLeft: 'auto', fontWeight: 600, color: d.statut !== 'done' && e.urgent ? 'var(--dangerTx2)' : 'var(--ink5)' }}>{d.statut === 'done' ? 'Clos' : e.texte}</span>
        </span>
      </Link>
      <div style={{ display: 'flex', gap: 6, borderTop: '1px solid var(--surf2)', padding: '6px 9px' }}>
        {gauche && <button type="button" onClick={gauche} aria-label={`Passer « ${d.intitule} » en ${libG}`} title={`→ ${libG}`} style={fleche}><Icone d={I.gauche} taille={16} /></button>}
        {droite && <button type="button" onClick={droite} aria-label={`Passer « ${d.intitule} » en ${libD}`} title={`→ ${libD}`} style={{ ...fleche, marginLeft: 'auto' }}><Icone d={I.droite} taille={16} /></button>}
      </div>
    </article>
  );
}

function NouveauDossier({ fermer }: { fermer: () => void }) {
  const creer = useCreerDossier();
  const aller = useNavigate();
  const [f, setF] = useState({ intitule: '', categorie: 'Juridique', description: '', echeance: '' });
  const maj = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const valider = () => creer.mutate({ intitule: f.intitule.trim(), categorie: f.categorie, description: f.description.trim() || null, echeance: f.echeance || null },
    { onSuccess: (d) => aller(`/dossiers/${d.id}`) });
  return (
    <section style={{ ...s.carte, marginBottom: 22, display: 'grid', gap: 14, gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
      <h2 style={{ ...s.titre, fontSize: 20, gridColumn: '1 / -1' }}>Nouveau dossier</h2>
      <div style={{ gridColumn: '1 / -1' }}><Champ libelle="Intitulé"><input autoFocus value={f.intitule} onChange={maj('intitule')} maxLength={160} placeholder="Ex. : Signalement — service logistique" style={s.saisie} /></Champ></div>
      <Champ libelle="Catégorie"><select value={f.categorie} onChange={maj('categorie')} style={s.saisie}>{CATEGORIES.map((c) => <option key={c}>{c}</option>)}</select></Champ>
      <Champ libelle="Échéance"><input type="date" value={f.echeance} onChange={maj('echeance')} style={s.saisie} /></Champ>
      <div style={{ gridColumn: '1 / -1' }}>
        <Champ libelle="Description" aide="Restez factuel. Les éléments de santé ou de vie privée vont dans le détail confidentiel, sur la page du dossier.">
          <textarea value={f.description} onChange={maj('description')} rows={3} maxLength={2000} placeholder="Faits, date, service concerné, demande du salarié…" style={{ ...s.saisie, resize: 'vertical' }} />
        </Champ>
      </div>
      {creer.error && <div style={{ gridColumn: '1 / -1' }}><Alerte>Création impossible. Vérifiez votre connexion.</Alerte></div>}
      <div style={{ gridColumn: '1 / -1', display: 'flex', gap: 10, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
        <Bouton variante="discret" onClick={fermer}>Annuler</Bouton>
        <Bouton variante="primaire" onClick={valider} disabled={!f.intitule.trim() || creer.isPending}>{creer.isPending ? 'Création…' : 'Créer le dossier'}</Bouton>
      </div>
    </section>
  );
}

import { Link } from 'react-router-dom';
import type { Moi } from '../lib/supabase';
import { STATUTS, echeance, usePersonne, useDossiers } from '../lib/donnees';
import { Bloc, Chargement, Icone, I, Pastille, Vide, s } from '../ui/kit';

export function Accueil({ moi }: { moi: Moi }) {
  const { data: p } = usePersonne(moi.personne_id);
  const { data, isLoading } = useDossiers();
  const ouverts = (data ?? []).filter((d) => d.statut !== 'done');
  const mesEcheances = ouverts.filter((d) => d.referent_id === moi.personne_id).slice(0, 6);
  const moment = new Date().getHours() < 18 ? 'Bonjour' : 'Bonsoir';
  const action = { display: 'flex', flexDirection: 'column', gap: 10, padding: '18px 16px', background: 'var(--surface)', border: '1px solid var(--bd)', borderRadius: 18, textDecoration: 'none', color: 'var(--ink3)', fontSize: 13.5, fontWeight: 600 } as const;

  return (
    <>
      <header style={{ marginBottom: 24 }}>
        <p style={{ ...s.discret, margin: '0 0 4px', fontSize: 14, textTransform: 'capitalize' }}>{new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}</p>
        <h1 style={{ ...s.titre, fontSize: 32 }}>{moment}{p ? `, ${p.prenom}` : ''}</h1>
      </header>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 14, marginBottom: 24 }}>
        <Link to="/dossiers?nouveau" style={action}><span style={{ color: 'var(--acTx)' }}><Icone d={I.plus} taille={22} /></span>Nouveau dossier</Link>
        <Link to="/assistant" style={action}><span style={{ color: 'var(--acTx)' }}><Icone d={I.unii} taille={22} /></span>Demander à unii</Link>
        <Link to="/dossiers" style={action}><span style={{ color: 'var(--acTx)' }}><Icone d={I.dossiers} taille={22} /></span>Tous les dossiers</Link>
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 18, alignItems: 'flex-start' }}>
        <Bloc titre="Mes prochaines échéances" style={{ flex: '2 1 440px' }} action={<Link to="/dossiers" style={{ fontSize: 13, fontWeight: 600 }}>Voir tout</Link>}>
          {isLoading ? <Chargement /> : !mesEcheances.length ? <Vide>Aucun dossier ouvert dont vous êtes référent.</Vide> : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {mesEcheances.map((d) => {
                const e = echeance(d.echeance);
                const st = STATUTS.find((x) => x.id === d.statut)!;
                return (
                  <Link key={d.id} to={`/dossiers/${d.id}`} style={{ display: 'flex', alignItems: 'center', gap: 12, background: 'var(--surf2)', border: '1px solid var(--bd)', borderRadius: 14, padding: '13px 14px', textDecoration: 'none', color: 'inherit' }}>
                    <span title={st.libelle} style={{ width: 8, height: 8, flex: '0 0 8px', borderRadius: 99, background: st.pastille }} />
                    <span style={{ flex: 1, minWidth: 0 }}>
                      <span style={{ display: 'block', fontSize: 14, fontWeight: 600, color: 'var(--ink)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{d.intitule}</span>
                      <span style={{ ...s.discret, fontSize: 12 }}>{d.categorie} · {st.libelle}</span>
                    </span>
                    <Pastille ton={e.urgent ? 'danger' : 'neutre'}>{e.texte}</Pastille>
                  </Link>
                );
              })}
            </div>
          )}
        </Bloc>
        <section style={{ flex: '1 1 260px', background: 'var(--inkSurf)', color: '#FFFFFF', borderRadius: 22, padding: 22, display: 'flex', flexDirection: 'column', gap: 10 }}>
          <span style={{ ...s.surtitre, color: '#9CA3AF' }}>Dossiers ouverts</span>
          {STATUTS.slice(0, 2).map((st) => (
            <Link key={st.id} to="/dossiers" style={{ display: 'flex', alignItems: 'baseline', gap: 10, color: '#FFFFFF', textDecoration: 'none', borderTop: '1px solid rgba(255,255,255,.1)', paddingTop: 10 }}>
              <span style={{ fontFamily: 'var(--fTitle)', fontSize: 28, color: 'var(--acMid)', minWidth: 40 }}>{ouverts.filter((d) => d.statut === st.id).length}</span>
              <span style={{ fontSize: 14, fontWeight: 600 }}>{st.libelle}</span>
            </Link>
          ))}
        </section>
      </div>
    </>
  );
}

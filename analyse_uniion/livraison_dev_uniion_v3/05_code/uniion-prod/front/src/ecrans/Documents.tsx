import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { MODELES, STATUTS_DOC, useCreerDocument, useDocuments } from '../lib/contenus';
import { useExtensions } from '../lib/extensions';
import { heure, nomCourt } from '../lib/donnees';
import { EnTete } from '../ui/Coque';
import { Alerte, Bouton, Chargement, Icone, I, Pastille, Vide, s } from '../ui/kit';

export function Documents() {
  const { data, isLoading, error } = useDocuments();
  const { styles } = useExtensions();
  const creer = useCreerDocument();
  const aller = useNavigate();
  const [choix, setChoix] = useState(false);
  const libStyle = (id: string) => (id === 'classique' ? 'Classique' : styles.find((x) => x.id === id)?.label ?? id);

  return (
    <>
      <EnTete titre="Documents" sous="Tracts, comptes rendus, courriers. Vos brouillons ne sont visibles que de vous ; un document relu est visible de toute l'organisation."
        action={!choix && <Bouton variante="primaire" onClick={() => setChoix(true)}><Icone d={I.plus} taille={16} />Nouveau document</Bouton>} />

      {choix && (
        <section style={{ ...s.carte, marginBottom: 22, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center' }}><h2 style={{ ...s.titre, fontSize: 20, flex: 1 }}>Partir de…</h2><Bouton variante="discret" onClick={() => setChoix(false)}>Annuler</Bouton></div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 12 }}>
            {MODELES.map((m) => (
              <button key={m.id} type="button" disabled={creer.isPending}
                onClick={() => creer.mutate({ ...m, styleDispo: m.style === 'classique' || styles.some((x) => x.id === m.style) }, { onSuccess: (id) => aller(`/documents/${id}`) })}
                style={{ cursor: 'pointer', textAlign: 'left', border: '1px solid var(--bd2)', background: 'var(--surface)', borderRadius: 16, padding: 16, fontFamily: 'inherit', display: 'flex', flexDirection: 'column', gap: 6, minHeight: 96 }}>
                <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{m.libelle}</span>
                <span style={s.discret}>{m.desc}</span>
              </button>
            ))}
          </div>
          {creer.error && <Alerte>{(creer.error as Error).message}</Alerte>}
        </section>
      )}

      {error && <Alerte>{(error as Error).message}</Alerte>}
      {isLoading ? <Chargement /> : !data?.length ? <Vide>Aucun document pour l'instant.</Vide> : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 14 }}>
          {data.map((d) => (
            <Link key={d.id} to={`/documents/${d.id}`} style={{ ...s.carte, padding: 18, textDecoration: 'none', color: 'inherit', display: 'flex', flexDirection: 'column', gap: 10 }}>
              <span style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}><Pastille ton={STATUTS_DOC[d.statut].ton}>{STATUTS_DOC[d.statut].libelle}</Pastille><Pastille>{libStyle(d.gabarit)}</Pastille></span>
              <span style={{ fontFamily: 'var(--fTitle)', fontSize: 19, lineHeight: 1.25, color: 'var(--ink)' }}>{d.titre}</span>
              <span style={{ ...s.discret, fontSize: 12, marginTop: 'auto' }}>{nomCourt(d.auteur)} · modifié {heure(d.modifie_le)}</span>
            </Link>
          ))}
        </div>
      )}
    </>
  );
}

import type { ButtonHTMLAttributes, CSSProperties, ReactNode } from 'react';
import { initiales, type Personne } from '../lib/donnees';

// Vocabulaire visuel de « uniion App v3 » : cartes 20–22 px, pilules, titres Philosopher, accent en dégradé.
export const s = {
  titre: { fontFamily: 'var(--fTitle)', fontWeight: 400, margin: 0, letterSpacing: '-.01em', color: 'var(--ink)' } as CSSProperties,
  carte: { background: 'var(--surface)', border: '1px solid var(--bd)', borderRadius: 22, padding: 22 } as CSSProperties,
  surtitre: { fontSize: 10.5, fontWeight: 700, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink5)' } as CSSProperties,
  texte: { fontSize: 14, lineHeight: 1.6, color: 'var(--ink3)', textWrap: 'pretty' } as CSSProperties,
  discret: { fontSize: 12.5, color: 'var(--ink5)', lineHeight: 1.5 } as CSSProperties,
  saisie: { width: '100%', boxSizing: 'border-box', background: 'var(--surf2)', border: '1px solid var(--bd2)', borderRadius: 13, padding: '11px 13px',
    fontSize: 15, fontFamily: 'inherit', color: 'var(--ink)', minHeight: 44 } as CSSProperties,
};

const VARIANTES: Record<string, CSSProperties> = {
  primaire: { border: 'none', background: 'linear-gradient(to right, var(--ac), var(--ac2))', color: '#FFFFFF' },
  secondaire: { border: '1px solid var(--bd2)', background: 'var(--surface)', color: 'var(--ink3)' },
  discret: { border: 'none', background: 'transparent', color: 'var(--ink4)' },
  danger: { border: '1px solid var(--dangerBd)', background: 'var(--dangerBg)', color: 'var(--dangerTx2)' },
};
export function Bouton({ variante = 'secondaire', style, ...p }: ButtonHTMLAttributes<HTMLButtonElement> & { variante?: keyof typeof VARIANTES }) {
  return <button type="button" {...p} style={{ cursor: p.disabled ? 'default' : 'pointer', opacity: p.disabled ? 0.55 : 1, borderRadius: 99, padding: '11px 18px',
    minHeight: 44, fontSize: 13.5, fontWeight: 700, fontFamily: 'inherit', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    ...VARIANTES[variante], ...style }} />;
}

export function Champ({ libelle, aide, children }: { libelle: string; aide?: string; children: ReactNode }) {
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <span style={{ ...s.surtitre, color: 'var(--ink5)' }}>{libelle}</span>
      {children}
      {aide && <span style={s.discret}>{aide}</span>}
    </label>
  );
}

export const Pastille = ({ children, ton = 'neutre' }: { children: ReactNode; ton?: 'neutre' | 'accent' | 'ok' | 'alerte' | 'danger' }) => {
  const t = { neutre: ['var(--chip)', 'var(--ink4)'], accent: ['var(--acBg)', 'var(--acTx2)'], ok: ['var(--okBg)', 'var(--okTx)'],
    alerte: ['var(--warnBg)', 'var(--warnTx)'], danger: ['var(--dangerBg)', 'var(--dangerTx2)'] }[ton];
  return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, background: t[0], color: t[1], fontSize: 11, fontWeight: 700, padding: '4px 10px', borderRadius: 99, whiteSpace: 'nowrap' }}>{children}</span>;
};

export const Avatar = ({ p, taille = 30 }: { p?: Pick<Personne, 'prenom' | 'nom'> | null; taille?: number }) => (
  <span aria-hidden="true" style={{ width: taille, height: taille, flex: `0 0 ${taille}px`, borderRadius: 99, background: 'linear-gradient(135deg, var(--ac), var(--ac2))',
    color: '#FFFFFF', fontSize: taille * 0.36, fontWeight: 700, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>{initiales(p)}</span>
);

export function Bloc({ titre, action, children, style }: { titre: string; action?: ReactNode; children: ReactNode; style?: CSSProperties }) {
  return (
    <section style={{ ...s.carte, display: 'flex', flexDirection: 'column', gap: 14, ...style }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <h2 style={{ ...s.titre, fontSize: 18, flex: 1 }}>{titre}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

export const Alerte = ({ children, ton = 'danger' }: { children: ReactNode; ton?: 'danger' | 'info' | 'ok' }) => {
  const t = { danger: ['var(--dangerBg)', 'var(--dangerBd2)', 'var(--dangerTx2)'], info: ['var(--infoBg)', 'var(--infoBd)', 'var(--infoTx2)'], ok: ['var(--okBg)', 'var(--okBd)', 'var(--okTx2)'] }[ton];
  return <p role={ton === 'danger' ? 'alert' : 'status'} style={{ margin: 0, background: t[0], border: `1px solid ${t[1]}`, color: t[2], borderRadius: 12, padding: '11px 13px', fontSize: 13, lineHeight: 1.5 }}>{children}</p>;
};

export const Vide = ({ children }: { children: ReactNode }) => (
  <p style={{ margin: 0, padding: '18px 14px', textAlign: 'center', border: '1px dashed var(--bd2)', borderRadius: 14, ...s.discret }}>{children}</p>
);
export const Chargement = () => <p role="status" style={{ ...s.discret, margin: 0 }}>Chargement…</p>;

export const Icone = ({ d, taille = 18 }: { d: string; taille?: number }) => (
  <svg width={taille} height={taille} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style={{ flex: `0 0 ${taille}px` }}>
    {d.split('|').map((x, i) => <path key={i} d={x} />)}
  </svg>
);
export const I = {
  accueil: 'M3 10.5 12 3l9 7.5|M5 9v11h14V9',
  dossiers: 'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
  unii: 'm12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3z',
  trombone: 'm21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48',
  plus: 'M12 5v14|M5 12h14',
  cadenas: 'M5 11h14v10H5z|M8 11V7a4 4 0 0 1 8 0v4',
  gauche: 'm15 18-6-6 6-6', droite: 'm9 18 6-6-6-6',
  sortie: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4|m16 17 5-5-5-5|M21 12H9',
  envoi: 'm22 2-7 20-4-9-9-4z|M22 2 11 13',
  adherents: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2|M9 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z|M22 21v-2a4 4 0 0 0-3-3.87|M16 3.13a4 4 0 0 1 0 7.75',
  membres: 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z|m9 12 2 2 4-4',
  agenda: 'M3 6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z|M16 2v4|M8 2v4|M3 10h18',
  documents: 'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z|M14 2v6h6|M8 13h8|M8 17h5',
  tresorerie: 'M3 7h18v12H3z|M3 11h18|M7 15h3',
  diffusions: 'M4 5h16v12H4z|m4 6 8 6 8-6',
  reglages: 'M4 21v-7|M4 10V3|M12 21v-9|M12 8V3|M20 21v-5|M20 12V3|M1 14h6|M9 8h6|M17 16h6',
};

import { useEffect, useState, type ReactNode } from 'react';
import { NavLink } from 'react-router-dom';
import { supabase, aRole, type Moi } from '../lib/supabase';
import { usePersonne } from '../lib/donnees';
import { Avatar, Icone, I, s } from './kit';

export function useLarge(min = 900) {
  const q = `(min-width: ${min}px)`;
  const [l, setL] = useState(() => matchMedia(q).matches);
  useEffect(() => { const m = matchMedia(q); const f = () => setL(m.matches); m.addEventListener('change', f); return () => m.removeEventListener('change', f); }, [q]);
  return l;
}

const NAV_TOUS = [
  { a: '/', libelle: 'Accueil', icone: I.accueil },
  { a: '/dossiers', libelle: 'Dossiers', icone: I.dossiers },
  { a: '/assistant', libelle: 'Assistant', icone: I.unii },
  { a: '/agenda', libelle: 'Agenda', icone: I.agenda },
  { a: '/documents', libelle: 'Documents', icone: I.documents },
  { a: '/adherents', libelle: 'Adhérents', icone: I.adherents, roles: ['tresorier', 'admin'] },
  { a: '/tresorerie', libelle: 'Trésorerie', icone: I.tresorerie, roles: ['tresorier'] },
  { a: '/diffusions', libelle: 'Diffusions', icone: I.diffusions, roles: ['tresorier', 'admin', 'communication'] },
  { a: '/membres', libelle: 'Membres', icone: I.membres, roles: ['admin'] },
  { a: '/reglages', libelle: 'Réglages', icone: I.reglages },
];
const SECONDAIRES = ['/adherents', '/tresorerie', '/diffusions', '/membres', '/reglages'];
const ROLES: Record<string, string> = { admin: 'Administration', tresorier: 'Trésorerie', communication: 'Communication', militant: 'Militant' };

function useEnLigne() {
  const [l, setL] = useState(() => navigator.onLine);
  useEffect(() => { const f = () => setL(navigator.onLine); addEventListener('online', f); addEventListener('offline', f); return () => { removeEventListener('online', f); removeEventListener('offline', f); }; }, []);
  return l;
}
const HorsLigne = () => (
  <div role="status" data-hors-impression="" style={{ background: 'var(--warnBg)', color: 'var(--warnTx)', borderBottom: '1px solid var(--warnBd)', padding: '9px 16px', fontSize: 13, fontWeight: 600, textAlign: 'center' }}>
    Hors ligne. Aucune donnée n'est conservée sur cet appareil : reconnectez-vous au réseau pour continuer.
  </div>
);

export function Coque({ moi, children }: { moi: Moi; children: ReactNode }) {
  const large = useLarge();
  const enLigne = useEnLigne();
  const { data: p } = usePersonne(moi.personne_id);
  const NAV = NAV_TOUS.filter((n) => !n.roles || n.roles.some((r) => aRole(moi, r)));
  const lien = (n: (typeof NAV_TOUS)[number], compact = false) => (
    <NavLink key={n.a} to={n.a} end={n.a === '/'} style={({ isActive }) => ({
      display: 'flex', alignItems: 'center', gap: compact ? 4 : 12, flexDirection: compact ? 'column' : 'row', padding: compact ? '8px 4px' : '11px 14px',
      borderRadius: 14, textDecoration: 'none', fontSize: compact ? 11 : 14, fontWeight: 600, minHeight: 44, flex: compact ? 1 : undefined, justifyContent: 'center',
      background: isActive ? 'var(--acBg)' : 'transparent', color: isActive ? 'var(--acTx2)' : 'var(--ink4)' })}>
      <Icone d={n.icone} taille={compact ? 20 : 19} />
      <span style={{ flex: compact ? undefined : 1 }}>{n.libelle}</span>
    </NavLink>
  );

  if (!large) return (
    <div style={{ minHeight: '100dvh', display: 'flex', flexDirection: 'column', background: 'var(--surf2)' }}>
      <header data-hors-impression="" style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '8px 10px 8px 16px', background: 'var(--surface)', borderBottom: '1px solid var(--bd)', position: 'sticky', top: 0, zIndex: 5 }}>
        <span style={{ ...s.titre, fontSize: 21, flex: 1 }}>uniion</span>
        {NAV.filter((n) => SECONDAIRES.includes(n.a)).map((n) => <NavLink key={n.a} to={n.a} aria-label={n.libelle} title={n.libelle} style={({ isActive }) => ({ color: isActive ? 'var(--acTx)' : 'var(--ink5)', minWidth: 44, minHeight: 44, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' })}><Icone d={n.icone} /></NavLink>)}
        <button type="button" onClick={() => supabase.auth.signOut()} aria-label="Se déconnecter" style={{ border: 'none', background: 'transparent', color: 'var(--ink5)', minWidth: 44, minHeight: 44, cursor: 'pointer' }}><Icone d={I.sortie} /></button>
      </header>
      {!enLigne && <HorsLigne />}
      <main style={{ flex: 1, padding: '18px 14px 96px', minWidth: 0 }}>{children}</main>
      <nav data-hors-impression="" aria-label="Navigation" style={{ position: 'fixed', insetInline: 0, bottom: 0, display: 'flex', gap: 4, padding: '6px 8px calc(6px + env(safe-area-inset-bottom))', background: 'var(--surface)', borderTop: '1px solid var(--bd)', zIndex: 5 }}>
        {NAV.filter((n) => !SECONDAIRES.includes(n.a)).map((n) => lien(n, true))}
      </nav>
    </div>
  );

  return (
    <div style={{ minHeight: '100dvh', display: 'flex', background: 'var(--surf2)' }}>
      <aside data-hors-impression="" style={{ width: 248, flex: '0 0 248px', boxSizing: 'border-box', background: 'var(--surface)', borderRight: '1px solid var(--bd)', padding: '22px 14px', display: 'flex', flexDirection: 'column', gap: 6, position: 'sticky', top: 0, height: '100dvh' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '0 8px 20px' }}>
          <img src="/uniion-logo.png" alt="" style={{ width: 34, height: 34, borderRadius: 10 }} />
          <span style={{ ...s.titre, fontSize: 23 }}>uniion</span>
        </div>
        <nav aria-label="Navigation" style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>{NAV.map((n) => lien(n))}</nav>
        <div style={{ marginTop: 'auto', display: 'flex', alignItems: 'center', gap: 10, padding: '12px 6px 0', borderTop: '1px solid var(--bd)' }}>
          <Avatar p={p} taille={34} />
          <span style={{ flex: 1, minWidth: 0, lineHeight: 1.3 }}>
            <span style={{ display: 'block', fontSize: 13, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p ? `${p.prenom} ${p.nom}` : ' '}</span>
            <span style={{ display: 'block', fontSize: 11.5, color: 'var(--ink5)' }}>{moi.roles.map((r) => ROLES[r] ?? r).join(' · ')}</span>
          </span>
          <button type="button" onClick={() => supabase.auth.signOut()} title="Se déconnecter" aria-label="Se déconnecter" style={{ border: 'none', background: 'transparent', color: 'var(--ink5)', width: 40, height: 40, borderRadius: 99, cursor: 'pointer' }}><Icone d={I.sortie} /></button>
        </div>
      </aside>
      <main style={{ flex: 1, minWidth: 0, padding: '30px 34px 48px' }}>
        {!enLigne && <div style={{ margin: '-30px -34px 24px' }}><HorsLigne /></div>}
        <div style={{ maxWidth: 1240, margin: '0 auto' }}>{children}</div>
      </main>
    </div>
  );
}

export function EnTete({ titre, sous, action, retour }: { titre: string; sous?: string; action?: ReactNode; retour?: ReactNode }) {
  return (
    <header style={{ display: 'flex', alignItems: 'flex-end', gap: 14, flexWrap: 'wrap', marginBottom: 22 }}>
      <div style={{ flex: '1 1 280px', minWidth: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
        {retour}
        <h1 style={{ ...s.titre, fontSize: 30 }}>{titre}</h1>
        {sous && <p style={{ ...s.discret, margin: 0, fontSize: 14 }}>{sous}</p>}
      </div>
      {action}
    </header>
  );
}

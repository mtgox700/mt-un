import { useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase, moi, mfaRequise, type Moi } from '../lib/supabase';
import { Connexion } from './Connexion';
import { DoubleAuth } from './DoubleAuth';

// Garde unique : session → organisation active → double authentification si le rôle l'exige.
export function Garde({ children }: { children: (m: Moi) => ReactNode }) {
  const [session, setSession] = useState<Session | null | undefined>(undefined);
  const [m, setM] = useState<Moi | null>(null);
  const [aal, setAal] = useState<{ courant: string; suivant: string } | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) { setM(null); setAal(null); return; }
    (async () => {
      setM(await moi());
      const { data } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      setAal(data ? { courant: data.currentLevel ?? 'aal1', suivant: data.nextLevel ?? 'aal1' } : null);
    })();
  }, [session]);

  if (session === undefined) return null;
  if (!session) return <Connexion />;
  if (!m || !aal) return null;
  if (!m.org_id) return <Message titre="Compte sans organisation active" texte="Votre mandat est terminé ou votre accès a été désactivé. Contactez un administrateur de votre organisation." />;
  if (mfaRequise(m) && aal.courant !== 'aal2') return <DoubleAuth inscrit={aal.suivant === 'aal2'} onOk={async () => { await supabase.auth.refreshSession(); setM(await moi()); setAal({ courant: 'aal2', suivant: 'aal2' }); }} />;
  return <>{children(m)}</>;
}

export function Message({ titre, texte }: { titre: string; texte: string }) {
  return (
    <main style={{ minHeight: '100dvh', display: 'grid', placeItems: 'center', padding: 24, fontFamily: 'var(--font-sans, system-ui)' }}>
      <div style={{ maxWidth: 420, display: 'grid', gap: 12 }}>
        <h1 style={{ margin: 0, fontSize: 22 }}>{titre}</h1>
        <p style={{ margin: 0, lineHeight: 1.5 }}>{texte}</p>
        <button onClick={() => supabase.auth.signOut()} style={{ justifySelf: 'start', padding: '10px 16px', minHeight: 44 }}>Se déconnecter</button>
      </div>
    </main>
  );
}

import { useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';

// Connexion par e-mail + mot de passe. Pas d'inscription : les comptes sont créés par invitation.
export function Connexion() {
  const [email, setEmail] = useState('');
  const [mdp, setMdp] = useState('');
  const [etat, setEtat] = useState<'' | 'envoi' | 'lien'>('');
  const [erreur, setErreur] = useState('');

  const connecter = async (e: FormEvent) => {
    e.preventDefault(); setErreur(''); setEtat('envoi');
    const { error } = await supabase.auth.signInWithPassword({ email, password: mdp });
    setEtat('');
    if (error) setErreur('Identifiants incorrects ou compte non activé.');  // message volontairement indistinct
  };
  const oubli = async () => {
    if (!email) { setErreur('Saisissez votre e-mail.'); return; }
    await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${location.origin}/reinitialiser` });
    setEtat('lien');
  };

  const champ = { padding: '12px 14px', minHeight: 44, borderRadius: 10, border: '1px solid var(--color-border, #cfd4dc)', fontSize: 16 } as const;
  return (
    <main style={{ minHeight: '100dvh', display: 'grid', placeItems: 'center', padding: 24, fontFamily: 'var(--font-sans, system-ui)' }}>
      <form onSubmit={connecter} style={{ width: '100%', maxWidth: 380, display: 'grid', gap: 14 }}>
        <img src="/uniion-logo.png" alt="uniion" style={{ height: 40, justifySelf: 'start' }} />
        <h1 style={{ margin: 0, fontSize: 24 }}>Connexion</h1>
        <label style={{ display: 'grid', gap: 6 }}>E-mail
          <input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} style={champ} />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>Mot de passe
          <input type="password" autoComplete="current-password" required value={mdp} onChange={(e) => setMdp(e.target.value)} style={champ} />
        </label>
        {erreur && <p role="alert" style={{ margin: 0, color: 'var(--color-danger, #b42318)' }}>{erreur}</p>}
        {etat === 'lien' && <p role="status" style={{ margin: 0 }}>Si un compte existe, un lien de réinitialisation vient d'être envoyé.</p>}
        <button type="submit" disabled={etat === 'envoi'} style={{ ...champ, cursor: 'pointer', fontWeight: 600 }}>{etat === 'envoi' ? 'Connexion…' : 'Se connecter'}</button>
        <button type="button" onClick={oubli} style={{ background: 'none', border: 0, padding: 8, minHeight: 44, cursor: 'pointer', justifySelf: 'start', textDecoration: 'underline' }}>Mot de passe oublié</button>
      </form>
    </main>
  );
}

import { useEffect, useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';

// Double authentification TOTP : enrôlement au premier passage, vérification ensuite.
export function DoubleAuth({ inscrit, onOk }: { inscrit: boolean; onOk: () => void }) {
  const [facteur, setFacteur] = useState<string>('');
  const [qr, setQr] = useState('');
  const [secret, setSecret] = useState('');
  const [code, setCode] = useState('');
  const [erreur, setErreur] = useState('');

  useEffect(() => {
    (async () => {
      if (inscrit) {
        const { data } = await supabase.auth.mfa.listFactors();
        setFacteur(data?.totp.find((f) => f.status === 'verified')?.id ?? '');
      } else {
        const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName: 'uniion' });
        if (error || !data) { setErreur("Impossible de préparer l'enrôlement."); return; }
        setFacteur(data.id); setQr(data.totp.qr_code); setSecret(data.totp.secret);
      }
    })();
  }, [inscrit]);

  const verifier = async (e: FormEvent) => {
    e.preventDefault(); setErreur('');
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: facteur, code: code.replace(/\s/g, '') });
    if (error) { setErreur('Code incorrect ou expiré.'); return; }
    onOk();
  };

  return (
    <main style={{ minHeight: '100dvh', display: 'grid', placeItems: 'center', padding: 24, fontFamily: 'var(--font-sans, system-ui)' }}>
      <form onSubmit={verifier} style={{ width: '100%', maxWidth: 380, display: 'grid', gap: 14 }}>
        <h1 style={{ margin: 0, fontSize: 22 }}>{inscrit ? 'Code de vérification' : 'Activer la double authentification'}</h1>
        <p style={{ margin: 0, lineHeight: 1.5 }}>
          {inscrit ? "Saisissez le code à 6 chiffres affiché par votre application d'authentification."
                   : "Votre rôle donne accès à des données protégées (fichier adhérents ou administration). Scannez ce code avec une application d'authentification, puis saisissez le code affiché."}
        </p>
        {qr && <img src={qr} alt="QR code d'enrôlement" style={{ width: 200, height: 200, justifySelf: 'center' }} />}
        {secret && <code style={{ wordBreak: 'break-all', fontSize: 13 }}>Clé manuelle : {secret}</code>}
        <input inputMode="numeric" autoComplete="one-time-code" pattern="[0-9 ]{6,7}" required aria-label="Code à 6 chiffres"
          value={code} onChange={(e) => setCode(e.target.value)} style={{ padding: '12px 14px', minHeight: 44, fontSize: 20, letterSpacing: 4, textAlign: 'center' }} />
        {erreur && <p role="alert" style={{ margin: 0, color: 'var(--color-danger, #b42318)' }}>{erreur}</p>}
        <button type="submit" style={{ minHeight: 44, fontWeight: 600 }}>Valider</button>
        <button type="button" onClick={() => supabase.auth.signOut()} style={{ minHeight: 44, background: 'none', border: 0, textDecoration: 'underline' }}>Se déconnecter</button>
      </form>
    </main>
  );
}

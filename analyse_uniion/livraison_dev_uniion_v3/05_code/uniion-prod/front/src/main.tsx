import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Navigate, Routes, Route } from 'react-router-dom';
import { Garde } from './auth/Garde';
import { Coque } from './ui/Coque';
import { Accueil } from './ecrans/Accueil';
import { Dossiers } from './ecrans/Dossiers';
import { Dossier } from './ecrans/Dossier';
import { Assistant } from './ecrans/Assistant';
import { Adherents } from './ecrans/Adherents';
import { ImportAdherents } from './ecrans/ImportAdherents';
import { Membres } from './ecrans/Membres';
import { Reglages } from './ecrans/Reglages';
import { Agenda } from './ecrans/Agenda';
import { Tresorerie } from './ecrans/Tresorerie';
import { Diffusions } from './ecrans/Diffusions';
import { Documents } from './ecrans/Documents';
import { Document } from './ecrans/Document';
import { aRole, supabase } from './lib/supabase';
import { appliquerTheme } from './lib/gestion';

// Lot 3 : écrans cœur portés depuis « uniion App v3 ».
const requetes = new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, retry: 1, refetchOnWindowFocus: true } } });
appliquerTheme();
if (import.meta.env.PROD && 'serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js');
// Déconnexion : plus rien ne reste en mémoire ni dans le cache de l'application.
supabase.auth.onAuthStateChange((evt) => {
  if (evt !== 'SIGNED_OUT') return;
  requetes.clear();
  navigator.serviceWorker?.controller?.postMessage('purger');
  sessionStorage.clear();
});
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => appliquerTheme());

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={requetes}>
      <BrowserRouter>
        <Garde>
          {(m) => (
            <Coque moi={m}>
              <Routes>
                <Route path="/" element={<Accueil moi={m} />} />
                <Route path="/dossiers" element={<Dossiers />} />
                <Route path="/dossiers/:id" element={<Dossier moi={m} />} />
                <Route path="/assistant" element={<Assistant />} />
                <Route path="/agenda" element={<Agenda moi={m} />} />
                <Route path="/documents" element={<Documents />} />
                <Route path="/documents/:id" element={<Document moi={m} />} />
                {(aRole(m, 'tresorier') || aRole(m, 'admin')) && <Route path="/adherents" element={<Adherents moi={m} />} />}
                {aRole(m, 'tresorier') && <Route path="/adherents/import" element={<ImportAdherents />} />}
                {aRole(m, 'tresorier') && <Route path="/tresorerie" element={<Tresorerie moi={m} />} />}
                {(aRole(m, 'tresorier') || aRole(m, 'admin') || aRole(m, 'communication')) && <Route path="/diffusions" element={<Diffusions moi={m} />} />}
                {aRole(m, 'admin') && <Route path="/membres" element={<Membres moi={m} />} />}
                <Route path="/reglages" element={<Reglages moi={m} />} />
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </Coque>
          )}
        </Garde>
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
);

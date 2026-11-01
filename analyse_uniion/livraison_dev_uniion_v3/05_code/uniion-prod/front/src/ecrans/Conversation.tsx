import { useEffect, useRef, useState, type KeyboardEvent } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { demanderUnii, reidentifier, type Surface } from '../lib/ia';
import { useConversation, verserConversation, type Dossier } from '../lib/donnees';
import { Alerte, Bouton, Chargement, Icone, I, s } from '../ui/kit';

interface Bulle { id: string; role: 'user' | 'assistant'; texte: string; masques?: number; envoye?: string }
const TYPES: Record<string, string> = { NOM: 'un nom', PRENOM: 'un prénom', EMAIL: 'un e-mail', TEL: 'un téléphone', NIR: 'un numéro de sécurité sociale', ADRESSE: 'une adresse', MATRICULE: 'un matricule', NUMERO: 'un numéro' };

// Conversation avec unii. Avec un dossier : historique chiffré côté serveur (2 ans). Sans dossier : rien n'est conservé.
export function Conversation({ surface, dossier, suggestions, hauteur = 460 }: { surface: Surface; dossier?: Dossier; suggestions: string[]; hauteur?: number }) {
  const qc = useQueryClient();
  const stocke = useConversation(dossier?.id ?? '');
  const [locales, setLocales] = useState<Bulle[]>([]);
  const [question, setQuestion] = useState('');
  const [attente, setAttente] = useState(false);
  const [erreur, setErreur] = useState('');
  const [vu, setVu] = useState<string | null>(null);
  const fil = useRef<HTMLDivElement>(null);

  const bulles: Bulle[] = dossier ? [...(stocke.data ?? []).map((t) => ({ id: t.id, role: t.role, texte: t.texte })), ...locales] : locales;
  useEffect(() => { fil.current?.scrollTo({ top: fil.current.scrollHeight, behavior: 'smooth' }); }, [bulles.length, attente]);

  const envoyer = async (q = question) => {
    q = q.trim(); if (!q || attente) return;
    setErreur(''); setAttente(true); setQuestion('');
    const texte = dossier ? `Dossier « ${dossier.intitule} » (${dossier.categorie}). ${dossier.description ?? ''}\n\nQuestion : ${q}` : q;
    const historique = bulles.slice(-6).map((b) => ({ role: b.role, texte: b.texte }));
    const r = await demanderUnii(surface, texte, { dossierId: dossier?.id, historique });
    setAttente(false);
    if (r.refus === 'masquage_incomplet') {
      const quoi = [...new Set(r.residuel ?? [])].map((t) => TYPES[t] ?? t).join(', ');
      setErreur(`Rien n'a été envoyé : ${quoi || 'un identifiant'} n'a pas pu être masqué. Reformulez sans nom propre (« la salariée », « son manager »).`);
      setQuestion(q); return;
    }
    if (r.erreur || !r.reponse) { setErreur(r.erreur ?? "L'assistant est indisponible."); setQuestion(q); return; }
    const reponse = r.apercus ? reidentifier(r.reponse, r.apercus, [...historique.map((h) => h.texte), texte])
      : r.apercu_masque ? reidentifier(r.reponse, r.apercu_masque, texte) : r.reponse;
    const user: Bulle = { id: r.id + ':q', role: 'user', texte: q, masques: r.correspondances.length, envoye: r.apercu_masque };
    const rep: Bulle = { id: r.id + ':r', role: 'assistant', texte: reponse };
    setLocales((l) => [...l, user, rep]);
    if (dossier) {
      try {
        await verserConversation(dossier.id, [{ role: 'user', texte: q }, { role: 'assistant', texte: reponse }], r.id);
        await qc.invalidateQueries({ queryKey: ['conversation', dossier.id] });
        setLocales((l) => l.filter((b) => b !== user && b !== rep));  // désormais servies par l'historique stocké
      } catch { setErreur("La réponse s'affiche mais n'a pas pu être enregistrée dans le dossier."); }
    }
  };
  const touche = (e: KeyboardEvent<HTMLTextAreaElement>) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); envoyer(); } };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      <div ref={fil} aria-live="polite" style={{ display: 'flex', flexDirection: 'column', gap: 12, padding: '16px 18px', overflowY: 'auto', maxHeight: hauteur, minHeight: 160 }}>
        {dossier && stocke.isLoading && <Chargement />}
        {!bulles.length && !stocke.isLoading && (
          <p style={{ ...s.discret, margin: 0 }}>{dossier ? 'Posez une question sur ce dossier. Les échanges sont conservés, chiffrés, avec le dossier.' : 'Posez une question de droit du travail, de procédure ou de rédaction. Cette conversation n\'est pas conservée.'}</p>
        )}
        {bulles.map((b) => b.role === 'user' ? (
          <div key={b.id} style={{ alignSelf: 'flex-end', maxWidth: '85%', display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
            <div style={{ background: 'var(--ink)', color: 'var(--surface)', borderRadius: '18px 18px 4px 18px', padding: '10px 14px', fontSize: 14, lineHeight: 1.55, whiteSpace: 'pre-wrap' }}>{b.texte}</div>
            {!!b.masques && (
              <button type="button" onClick={() => setVu(vu === b.id ? null : b.id)} style={{ border: 'none', background: 'transparent', color: 'var(--okTx)', fontSize: 11.5, fontWeight: 600, cursor: 'pointer', padding: '4px 2px', display: 'inline-flex', gap: 5, alignItems: 'center' }}>
                <Icone d={I.cadenas} taille={12} />{b.masques} élément{b.masques > 1 ? 's' : ''} masqué{b.masques > 1 ? 's' : ''} avant envoi
              </button>
            )}
            {vu === b.id && b.envoye && <div style={{ background: 'var(--okBg)', border: '1px solid var(--okBd)', borderRadius: 12, padding: '9px 12px', fontSize: 12, lineHeight: 1.5, color: 'var(--okTx2)', whiteSpace: 'pre-wrap' }}><strong>Texte réellement envoyé :</strong>{'\n'}{b.envoye}</div>}
          </div>
        ) : (
          <div key={b.id} style={{ alignSelf: 'flex-start', maxWidth: '92%', background: 'var(--surf2)', border: '1px solid var(--bd)', borderRadius: '18px 18px 18px 4px', padding: '11px 14px', fontSize: 14, lineHeight: 1.6, color: 'var(--ink2)', whiteSpace: 'pre-wrap' }}>{b.texte}</div>
        ))}
        {attente && <div role="status" style={{ alignSelf: 'flex-start', ...s.discret }}>unii rédige…</div>}
      </div>

      {!bulles.length && (
        <div style={{ padding: '0 18px 12px', display: 'flex', flexWrap: 'wrap', gap: 7 }}>
          {suggestions.map((q) => <button key={q} type="button" onClick={() => envoyer(q)} style={{ cursor: 'pointer', border: '1px solid var(--bd2)', background: 'var(--surface)', borderRadius: 99, padding: '8px 13px', minHeight: 36, fontSize: 12.5, fontWeight: 600, color: 'var(--ink4)', fontFamily: 'inherit' }}>{q}</button>)}
        </div>
      )}
      {erreur && <div style={{ padding: '0 18px 12px' }}><Alerte>{erreur}</Alerte></div>}

      <div style={{ borderTop: '1px solid var(--bd)', padding: 12, display: 'flex', gap: 8, alignItems: 'flex-end' }}>
        <textarea value={question} onChange={(e) => setQuestion(e.target.value)} onKeyDown={touche} rows={2} maxLength={8000}
          aria-label="Votre question" placeholder="Votre question…" style={{ ...s.saisie, resize: 'none', flex: 1, borderRadius: 16 }} />
        <Bouton variante="primaire" onClick={() => envoyer()} disabled={attente || !question.trim()} aria-label="Envoyer" style={{ width: 46, padding: 0 }}><Icone d={I.envoi} /></Bouton>
      </div>
      <p style={{ ...s.discret, fontSize: 11.5, margin: 0, padding: '0 14px 12px' }}>Noms, coordonnées et numéros sont masqués sur nos serveurs avant l'envoi au modèle (Mistral AI, hébergé dans l'UE, sans conservation). La réponse est rétablie avec les vrais noms sur votre appareil.</p>
    </div>
  );
}

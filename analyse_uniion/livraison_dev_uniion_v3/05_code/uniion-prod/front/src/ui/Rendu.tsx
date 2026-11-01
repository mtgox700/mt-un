import { Component, createElement, useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import type { Bloc, DocBlock, DocStyle } from '../lib/extensions';
import { FORMATS } from '../lib/contenus';

export interface Identite { emetteur: string; section: string; contact: string; logo: string }
export const lignes = (s: string) => String(s || '').split('\n').map((l) => l.trim()).filter(Boolean);
export const cellules = (l: string) => String(l || '').split('|').map((c) => c.trim());

const CLASSIQUE = { accent: '#DC2626', accent2: '#F97316', ink: '#111827', paper: '#FFFFFF', head: 'Philosopher, Georgia, serif', body: 'system-ui, "Segoe UI", Helvetica, sans-serif' };

// Découpe en pages (bloc « pagebreak ») puis rend chaque page avec le style choisi.
export function pages(blocs: Bloc[]) {
  const p: Bloc[][] = [[]];
  blocs.forEach((b) => (b.type === 'pagebreak' ? p.push([]) : p[p.length - 1]!.push(b)));
  return p;
}

export function rendrePage(o: { blocs: Bloc[]; index: number; count: number; style: DocStyle | null; palette?: string; police?: string; format: string; org: Identite; extBlocs: DocBlock[]; onErreur?: (m: string) => void }): ReactNode {
  const f = FORMATS[o.format] ?? FORMATS.a4!;
  const u = f.w / 420;
  const bloc = (b: Bloc, k: unknown) => {
    const d = o.extBlocs.find((x) => x.type === b.type);
    if (!d) return null;
    try { return d.render(b, k) as ReactNode; } catch (e) { o.onErreur?.(`Bloc « ${d.label} » : ${(e as Error).message}`); return null; }
  };
  if (o.style) {
    const pal = o.style.palettes.find((p) => p.id === o.palette) ?? o.style.palettes[0]!;
    const pol = o.style.fonts.find((p) => p.id === o.police) ?? o.style.fonts[0]!;
    const ctx = {
      h: createElement, blocks: o.blocs, first: (t: string) => o.blocs.find((b) => b.type === t), all: (t: string) => o.blocs.filter((b) => b.type === t),
      block: bloc, lines: lignes, cells: cellules, colors: pal.colors, fonts: pol, format: { id: o.format, w: f.w, h: f.h }, u, page: { index: o.index, count: o.count }, org: o.org,
    };
    try { return o.style.render(ctx) as ReactNode; } catch (e) { o.onErreur?.(`Style « ${o.style.label} » : ${(e as Error).message}. Rendu classique utilisé.`); }
  }
  const k = { h: createElement, u, ...CLASSIQUE, lines: lignes };
  const px = (n: number) => n * u + 'px';
  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden', background: '#FFFFFF', color: CLASSIQUE.ink, fontFamily: CLASSIQUE.body, padding: px(30), boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      {o.index === 0 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: px(10), borderBottom: `${px(2)} solid ${CLASSIQUE.accent}`, paddingBottom: px(8), marginBottom: px(16) }}>
          {o.org.logo && <img src={o.org.logo} alt="" style={{ height: px(26) }} />}
          <span style={{ fontFamily: CLASSIQUE.head, fontSize: px(15), fontWeight: 700 }}>{o.org.emetteur}</span>
          <span style={{ marginLeft: 'auto', fontSize: px(9), color: '#4B5563' }}>{o.org.section}</span>
        </div>
      )}
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}>
        {o.blocs.map((b) => {
          const t = b.text ?? '';
          switch (b.type) {
            case 'tag': return <span key={b.id} style={{ display: 'inline-block', background: CLASSIQUE.accent, color: '#FFFFFF', fontSize: px(8.5), fontWeight: 700, letterSpacing: '.08em', textTransform: 'uppercase', padding: `${px(3)} ${px(8)}`, borderRadius: px(99), marginBottom: px(8), WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' } as CSSProperties}>{t}</span>;
            case 'h1': return <h1 key={b.id} style={{ fontFamily: CLASSIQUE.head, fontSize: px(26), lineHeight: 1.1, margin: `0 0 ${px(10)}` }}>{t}</h1>;
            case 'h2': return <h2 key={b.id} style={{ fontFamily: CLASSIQUE.head, fontSize: px(16), margin: `${px(12)} 0 ${px(6)}`, color: CLASSIQUE.accent }}>{t}</h2>;
            case 'h3': return <h3 key={b.id} style={{ fontSize: px(12), margin: `${px(10)} 0 ${px(4)}` }}>{t}</h3>;
            case 'ul': return <ul key={b.id} style={{ margin: `0 0 ${px(10)}`, paddingLeft: px(16), fontSize: px(10.5), lineHeight: 1.5 }}>{lignes(t).map((l, i) => <li key={i}>{l}</li>)}</ul>;
            case 'quote': return <blockquote key={b.id} style={{ margin: `0 0 ${px(10)}`, borderLeft: `${px(3)} solid ${CLASSIQUE.accent}`, background: '#FEF2F2', padding: `${px(8)} ${px(12)}`, fontSize: px(10.5), lineHeight: 1.5, whiteSpace: 'pre-line', WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' } as CSSProperties}>{t}</blockquote>;
            case 'table': return (
              <table key={b.id} style={{ width: '100%', borderCollapse: 'collapse', fontSize: px(9.5), margin: `0 0 ${px(10)}` }}><tbody>
                {lignes(t).map((l, i) => <tr key={i}>{cellules(l).map((c, j) => <td key={j} style={{ border: '1px solid #D1D5DB', padding: `${px(4)} ${px(6)}`, fontWeight: i === 0 ? 700 : 400 }}>{c}</td>)}</tr>)}
              </tbody></table>);
            case 'p': return t ? <p key={b.id} style={{ fontSize: px(10.5), lineHeight: 1.55, margin: `0 0 ${px(8)}`, whiteSpace: 'pre-line' }}>{t}</p> : null;
            default: return <div key={b.id}>{bloc(b, k) ?? (t ? <p style={{ fontSize: px(10.5), margin: `0 0 ${px(8)}` }}>{t}</p> : null)}</div>;
          }
        })}
      </div>
      {o.org.contact && <div style={{ borderTop: '1px solid #E5E7EB', paddingTop: px(6), fontSize: px(8), color: '#4B5563', display: 'flex', justifyContent: 'space-between' }}><span>{o.org.contact}</span>{o.count > 1 && <span>{o.index + 1} / {o.count}</span>}</div>}
    </div>
  );
}

// Une page en erreur ne doit pas faire tomber l'éditeur.
class Garde extends Component<{ children: ReactNode }, { e: boolean }> {
  state = { e: false };
  static getDerivedStateFromError() { return { e: true }; }
  render() { return this.state.e ? <div style={{ padding: 20, fontSize: 13, color: '#B91C1C' }}>Cette page n'a pas pu être affichée.</div> : this.props.children; }
}

export function Apercu({ contenus, format, largeurMax = 640 }: { contenus: ReactNode[]; format: string; largeurMax?: number }) {
  const f = FORMATS[format] ?? FORMATS.a4!;
  const boite = useRef<HTMLDivElement>(null);
  const [l, setL] = useState(largeurMax);
  useLayoutEffect(() => {
    const el = boite.current; if (!el) return;
    const o = new ResizeObserver(([e]) => setL(Math.min(largeurMax, e!.contentRect.width)));
    o.observe(el); return () => o.disconnect();
  }, [largeurMax]);
  const k = l / f.w;
  return (
    <div ref={boite} style={{ display: 'flex', flexDirection: 'column', gap: 18, alignItems: 'center', width: '100%' }}>
      {contenus.map((c, i) => (
        <div key={i} style={{ width: f.w * k, height: f.h * k, boxShadow: '0 1px 3px rgba(17,24,39,.12), 0 8px 24px rgba(17,24,39,.08)', background: '#FFFFFF', overflow: 'hidden', flex: '0 0 auto' }}>
          <div style={{ width: f.w, height: f.h, transform: `scale(${k})`, transformOrigin: '0 0' }}><Garde>{c}</Garde></div>
        </div>
      ))}
    </div>
  );
}

// Version d'impression : pages à taille réelle, masquées à l'écran, seules visibles à l'impression.
export function Impression({ contenus, format }: { contenus: ReactNode[]; format: string }) {
  const f = FORMATS[format] ?? FORMATS.a4!;
  return (
    <div data-impression="" style={{ display: 'none' }}>
      {contenus.map((c, i) => <div key={i} style={{ width: f.w, height: f.h, overflow: 'hidden', position: 'relative' }}><Garde>{c}</Garde></div>)}
    </div>
  );
}
export function imprimer(format: string) {
  const f = FORMATS[format] ?? FORMATS.a4!;
  let s = document.getElementById('uniion-page') as HTMLStyleElement | null;
  if (!s) { s = document.createElement('style'); s.id = 'uniion-page'; document.head.append(s); }
  // 1 px CSS = 0,75 pt : la page imprimée a exactement la taille du format.
  s.textContent = `@page { size: ${f.w * 0.75}pt ${f.h * 0.75}pt; margin: 0 }`;
  window.print();
}

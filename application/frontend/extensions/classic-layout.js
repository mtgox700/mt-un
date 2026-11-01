import React from 'react';
const CORE_DOC_TYPES=['tag','h1','h2','h3','p','ul','quote','table','pagebreak'];
const pxv=v=>(Math.round(v*10)/10)+'px';
const rgba=(hex,a)=>{const n=parseInt(hex.slice(1),16);return 'rgba('+((n>>16)&255)+','+((n>>8)&255)+','+(n&255)+','+a+')';};
export function prepareClassicBlock(b, {chr,ts,tfont,bfont,ac,self}) {
 const xstd={accent:ac,accent2:ac,ink:chr.ink,paper:"#FFFFFF",head:tfont,body:bfont,hand:tfont,u:ts};
      let type = b.type;
      if (CORE_DOC_TYPES.indexOf(type) < 0) {
        const xb = self.extDocBlock(type);
        const xel = xb ? self.extSafe(xb.extId, 'bloc ' + type, () => xb.render(b, Object.assign({ h: React.createElement, lines: (s) => self.extLines(s) }, xstd)), null) : null;
        if (xel) return { id: b.id, isExt: true, el: xel, text: '' };
        type = 'p';
      }
      const text = b.text || '';
      const out = {
        id: b.id,
        isTag: type === 'tag', isH1: type === 'h1', isH2: type === 'h2', isH3: type === 'h3',
        isP: type === 'p', isUl: type === 'ul', isQuote: type === 'quote', isTable: type === 'table',
        text: text
      };
      if (type === 'tag') {
        out.st = { display: 'inline-block', fontFamily: bfont, background: rgba(ac, .1), color: ac, border: '1px solid ' + ac, fontSize: pxv(9.5 * ts), fontWeight: 800, letterSpacing: '.09em', textTransform: 'uppercase', padding: pxv(3 * ts) + ' ' + pxv(8 * ts), borderRadius: '2px', marginBottom: pxv(9 * ts) };
      } else if (type === 'h1') {
        out.st = { fontFamily: tfont, color: ac, fontWeight: 700, fontSize: pxv(26 * ts), lineHeight: 1.18, margin: '0 0 ' + pxv(11 * ts), borderBottom: '2px solid ' + ac, paddingBottom: pxv(6 * ts), textTransform: chr.caps ? 'uppercase' : 'none', textWrap: 'pretty' };
      } else if (type === 'h2') {
        out.st = { fontFamily: tfont, color: chr.ink, fontWeight: 700, fontSize: pxv(18.5 * ts), lineHeight: 1.3, margin: pxv(13 * ts) + ' 0 ' + pxv(6 * ts) };
      } else if (type === 'h3') {
        out.st = { fontFamily: tfont, color: ac, fontWeight: 700, fontSize: pxv(15 * ts), lineHeight: 1.35, margin: pxv(10 * ts) + ' 0 ' + pxv(5 * ts) };
      } else if (type === 'p') {
        out.st = { fontFamily: bfont, fontSize: pxv(13 * ts), lineHeight: 1.62, color: chr.ink, margin: '0 0 ' + pxv(9 * ts), textWrap: 'pretty' };
      } else if (type === 'ul') {
        out.items = text.split('\n').filter(function (l) { return l.trim(); }).map(function (l, i) { return { key: i, text: l.trim() }; });
        out.st = { display: 'flex', flexDirection: 'column', gap: pxv(5 * ts), margin: '0 0 ' + pxv(11 * ts) };
        out.itemSt = { display: 'flex', gap: pxv(8 * ts), fontFamily: bfont, fontSize: pxv(13 * ts), lineHeight: 1.55, color: chr.ink };
        out.bulletSt = { color: ac, fontSize: pxv(7 * ts), lineHeight: pxv(20 * ts), flex: '0 0 auto' };
      } else if (type === 'quote') {
        out.st = { fontFamily: bfont, borderLeft: '3px solid ' + ac, background: rgba(ac, .07), padding: pxv(11 * ts) + ' ' + pxv(14 * ts), borderRadius: '0 10px 10px 0', fontSize: pxv(12.5 * ts), lineHeight: 1.6, fontStyle: 'italic', color: chr.ink, margin: '0 0 ' + pxv(12 * ts), whiteSpace: 'pre-line' };
      } else if (type === 'table') {
        const rows = text.split('\n').filter(function (l) { return l.trim(); }).map(function (l) { return l.split('|').map(function (c) { return c.trim(); }); });
        const ncol = rows.length ? rows[0].length : 1;
        out.st = { display: 'grid', gridTemplateColumns: 'repeat(' + ncol + ', minmax(0, 1fr))', border: '1px solid var(--bd2)', borderRadius: '4px', overflow: 'hidden', margin: '0 0 ' + pxv(12 * ts) };
        out.cells = [];
        rows.forEach(function (row, ri) {
          for (let ci = 0; ci < ncol; ci++) {
            const val = row[ci] === undefined ? '' : row[ci];
            out.cells.push({
              key: ri + '-' + ci, text: val,
              st: ri === 0
                ? { background: ac, color: '#FFFFFF', fontFamily: bfont, fontWeight: 700, fontSize: pxv(10 * ts), letterSpacing: '.05em', textTransform: 'uppercase', padding: pxv(7 * ts) + ' ' + pxv(9 * ts) }
                : { background: ri % 2 === 0 ? 'var(--surf2)' : '#FFFFFF', color: chr.ink, fontFamily: bfont, fontSize: pxv(11.5 * ts), lineHeight: 1.45, padding: pxv(7 * ts) + ' ' + pxv(9 * ts), borderTop: '1px solid var(--bd2)' }
            });
          }
        });
      }
      return out;
    }
export function prepareClassicPage({dfmt,dz,chr,ts,tfont,bfont,ac,grp,blockView,i,count}) { return {
        key: 'pg' + i,
        wrapW: pxv(dfmt.w * dz), wrapH: pxv(dfmt.h * dz),
        st: {
          position: 'absolute', top: 0, left: 0, width: pxv(dfmt.w), height: pxv(dfmt.h),
          transform: 'scale(' + dz + ')', transformOrigin: 'top left',
          background: '#FFFFFF', boxSizing: 'border-box', padding: pxv(dfmt.pad),
          display: 'flex', flexDirection: 'column', overflow: 'hidden',
          borderRadius: '3px', boxShadow: '0 18px 44px -26px hsl(var(--shC) / .55)',
          WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact'
        },
        showHeader: !!chr.header, showFooter: !!chr.footer,
        headerSt: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: pxv(14 * ts), borderBottom: '2px solid ' + ac, paddingBottom: pxv(9 * ts), marginBottom: pxv(18 * ts), flex: '0 0 auto' },
        emetteurSt: { display: 'block', fontFamily: tfont, fontSize: pxv(12.5 * ts), fontWeight: 700, letterSpacing: '.06em', textTransform: 'uppercase', color: chr.ink },
        sectionSt: { display: 'block', fontFamily: bfont, fontSize: pxv(10.5 * ts), color: 'var(--ink4)', marginTop: pxv(2 * ts) },
        emetteur: chr.emetteur, section: chr.section,
        hasLogo: !!chr.logo, logo: chr.logo,
        logoSt: { display: 'block', flex: '0 0 auto', width: pxv(140 * ts), height: pxv(38 * ts), backgroundImage: chr.logo ? 'url("' + chr.logo + '")' : 'none', backgroundSize: 'contain', backgroundRepeat: 'no-repeat', backgroundPosition: 'right center', WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' },
        bodySt: { flex: '1 1 auto', minHeight: 0 },
        footerSt: { flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: pxv(12 * ts), borderTop: '1px solid var(--bd2)', paddingTop: pxv(9 * ts), marginTop: pxv(14 * ts), fontFamily: bfont, fontSize: pxv(9.5 * ts), color: 'var(--ink4)' },
        pageNoSt: { fontWeight: 700, color: ac, flex: '0 0 auto' },
        contact: chr.email + ' — ' + chr.phone,
        pageNo: 'Page ' + (i + 1) + ' / ' + count,
        blocks: grp.map(blockView)
      };
}
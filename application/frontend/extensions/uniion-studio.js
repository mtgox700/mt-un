/*
 * uniion Studio — extension officielle (API d'extensions uniion v1)
 * Styles de documents et tracts, blocs visuels, thèmes et sections de pages web.
 * Voir « Guide extensions uniion.md » pour le contrat complet.
 */
(function () {
  'use strict';

  var FONTS = './fonts/studio/fonts.css';

  /* ---------- utilitaires ---------- */
  var F = function (n, fb) { return "'" + n + "', " + (fb || 'sans-serif'); };
  var lines = function (s) { return String(s || '').split('\n').map(function (l) { return l.trim(); }).filter(Boolean); };
  var cells = function (l) { return String(l || '').split('|').map(function (c) { return c.trim(); }); };
  var lum = function (hex) {
    if (!/^#[0-9a-f]{6}$/i.test(hex)) return 0;
    var n = parseInt(hex.slice(1), 16);
    var c = [n >> 16, (n >> 8) & 255, n & 255].map(function (v) { v /= 255; return v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); });
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2];
  };
  var onC = function (hex) { return lum(hex) > .45 ? '#111111' : '#FFFFFF'; };
  var ph = function (dark) { return dark ? 'repeating-linear-gradient(135deg,#3A3B40 0 14px,#34353A 14px 28px)' : 'repeating-linear-gradient(135deg,rgba(0,0,0,.07) 0 8px,rgba(0,0,0,.02) 8px 16px)'; };
  var isImg = function (s) { return /^(https?:|data:image)/.test(String(s || '')); };
  var fit = function (t, max, min, k) { var n = Math.max(1, String(t || '').length); return Math.max(min, Math.min(max, k / Math.sqrt(n))); };
  var P = function (k) { return function (n) { return (Math.round(n * (k.u || 1) * 10) / 10) + 'px'; }; };
  var mono = 'ui-monospace, SFMono-Regular, monospace';
  var shadow = 'none';
  /* source d'image d'un bloc Photo : image déposée (b.img) ou adresse collée en 1re ligne */
  var srcOf = function (b) { if (!b) return null; if (b.img) return b.img; var l = lines(b.text)[0]; return isImg(l) ? l : null; };

  /* ---------- encodeur QR (octets, correction M, versions 1 à 10 — jusqu'à 213 caractères) ---------- */
  var QR = (function () {
    var ECC = [0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26], BLK = [0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5];
    function raw(v) { var r = (16 * v + 128) * v + 64; if (v >= 2) { var n = Math.floor(v / 7) + 2; r -= (25 * n - 10) * n - 55; if (v >= 7) r -= 36; } return r; }
    function dataCw(v) { return Math.floor(raw(v) / 8) - ECC[v] * BLK[v]; }
    function mul(x, y) { var z = 0; for (var i = 7; i >= 0; i--) { z = (z << 1) ^ ((z >>> 7) * 0x11D); z ^= ((y >>> i) & 1) * x; } return z; }
    function divisor(d) { var r = [], i, j, root = 1; for (i = 0; i < d - 1; i++) r.push(0); r.push(1); for (i = 0; i < d; i++) { for (j = 0; j < r.length; j++) { r[j] = mul(r[j], root); if (j + 1 < r.length) r[j] ^= r[j + 1]; } root = mul(root, 2); } return r; }
    function remainder(data, div) { var r = div.map(function () { return 0; }); data.forEach(function (b) { var f = b ^ r.shift(); r.push(0); div.forEach(function (c, i) { r[i] ^= mul(c, f); }); }); return r; }
    function utf8(s) { var e = unescape(encodeURIComponent(s)), o = []; for (var i = 0; i < e.length; i++) o.push(e.charCodeAt(i)); return o; }
    function encode(text) {
      var bytes = utf8(String(text || '')), v, i, j;
      for (v = 1; v <= 10; v++) if (4 + (v < 10 ? 8 : 16) + bytes.length * 8 <= dataCw(v) * 8) break;
      if (v > 10) return null;
      var bits = [], put = function (val, n) { for (var k = n - 1; k >= 0; k--) bits.push((val >>> k) & 1); };
      put(4, 4); put(bytes.length, v < 10 ? 8 : 16); bytes.forEach(function (b) { put(b, 8); });
      var cap = dataCw(v) * 8;
      put(0, Math.min(4, cap - bits.length)); put(0, (8 - bits.length % 8) % 8);
      for (var pad = 0xEC; bits.length < cap; pad ^= 0xEC ^ 0x11) put(pad, 8);
      var data = []; for (i = 0; i < bits.length; i += 8) { var x = 0; for (j = 0; j < 8; j++) x = (x << 1) | bits[i + j]; data.push(x); }
      var nb = BLK[v], el = ECC[v], rawCw = Math.floor(raw(v) / 8), nShort = nb - rawCw % nb, shortLen = Math.floor(rawCw / nb), div = divisor(el), blocks = [], off = 0;
      for (i = 0; i < nb; i++) { var dat = data.slice(off, off + shortLen - el + (i < nShort ? 0 : 1)); off += dat.length; var ec = remainder(dat, div); if (i < nShort) dat.push(0); blocks.push(dat.concat(ec)); }
      var cw = []; for (i = 0; i < blocks[0].length; i++) for (j = 0; j < blocks.length; j++) if (i !== shortLen - el || j >= nShort) cw.push(blocks[j][i]);
      var size = v * 4 + 17, M = [], F = [];
      for (i = 0; i < size; i++) { M.push([]); F.push([]); for (j = 0; j < size; j++) { M[i].push(false); F[i].push(false); } }
      var set = function (px, py, d) { M[py][px] = d; F[py][px] = true; };
      for (i = 0; i < size; i++) { set(6, i, i % 2 === 0); set(i, 6, i % 2 === 0); }
      [[3, 3], [size - 4, 3], [3, size - 4]].forEach(function (p) { for (var dy = -4; dy <= 4; dy++) for (var dx = -4; dx <= 4; dx++) { var d = Math.max(Math.abs(dx), Math.abs(dy)), xx = p[0] + dx, yy = p[1] + dy; if (xx >= 0 && xx < size && yy >= 0 && yy < size) set(xx, yy, d !== 2 && d !== 4); } });
      var al = [];
      if (v > 1) { var na = Math.floor(v / 7) + 2, step = Math.ceil((v * 4 + 4) / (na * 2 - 2)) * 2; al = [6]; for (var pos = size - 7; al.length < na; pos -= step) al.splice(1, 0, pos); }
      al.forEach(function (ax, ai) { al.forEach(function (ay, aj) { if ((ai === 0 && aj === 0) || (ai === 0 && aj === al.length - 1) || (ai === al.length - 1 && aj === 0)) return; for (var dy = -2; dy <= 2; dy++) for (var dx = -2; dx <= 2; dx++) set(ax + dx, ay + dy, Math.max(Math.abs(dx), Math.abs(dy)) !== 1); }); });
      var fmt = function (mask) {
        var d = mask, rem = d, k; for (k = 0; k < 10; k++) rem = (rem << 1) ^ ((rem >>> 9) * 0x537);
        var b = ((d << 10) | rem) ^ 0x5412, g = function (n) { return ((b >>> n) & 1) !== 0; };
        for (k = 0; k <= 5; k++) set(8, k, g(k)); set(8, 7, g(6)); set(8, 8, g(7)); set(7, 8, g(8)); for (k = 9; k < 15; k++) set(14 - k, 8, g(k));
        for (k = 0; k < 8; k++) set(size - 1 - k, 8, g(k)); for (k = 8; k < 15; k++) set(8, size - 15 + k, g(k)); set(8, size - 8, true);
      };
      fmt(0);
      if (v >= 7) { var vr = v; for (i = 0; i < 12; i++) vr = (vr << 1) ^ ((vr >>> 11) * 0x1F25); var vb = (v << 12) | vr; for (i = 0; i < 18; i++) { var bt = ((vb >>> i) & 1) !== 0, a = size - 11 + i % 3, c = Math.floor(i / 3); set(a, c, bt); set(c, a, bt); } }
      var bi = 0;
      for (var right = size - 1; right >= 1; right -= 2) { if (right === 6) right = 5; for (var vert = 0; vert < size; vert++) for (j = 0; j < 2; j++) { var cx = right - j, up = ((right + 1) & 2) === 0, cy = up ? size - 1 - vert : vert; if (!F[cy][cx] && bi < cw.length * 8) { M[cy][cx] = ((cw[bi >>> 3] >>> (7 - (bi & 7))) & 1) !== 0; bi++; } } }
      var inv = function (m, x2, y2) { switch (m) { case 0: return (x2 + y2) % 2 === 0; case 1: return y2 % 2 === 0; case 2: return x2 % 3 === 0; case 3: return (x2 + y2) % 3 === 0; case 4: return (Math.floor(x2 / 3) + Math.floor(y2 / 2)) % 2 === 0; case 5: return x2 * y2 % 2 + x2 * y2 % 3 === 0; case 6: return (x2 * y2 % 2 + x2 * y2 % 3) % 2 === 0; default: return ((x2 + y2) % 2 + x2 * y2 % 3) % 2 === 0; } };
      var apply = function (m) { for (var y2 = 0; y2 < size; y2++) for (var x2 = 0; x2 < size; x2++) if (!F[y2][x2] && inv(m, x2, y2)) M[y2][x2] = !M[y2][x2]; };
      var penalty = function () {
        var p = 0, dark = 0, x2, y2, run, c2;
        for (y2 = 0; y2 < size; y2++) { run = 1; for (x2 = 1; x2 < size; x2++) { if (M[y2][x2] === M[y2][x2 - 1]) { run++; if (run === 5) p += 3; else if (run > 5) p++; } else run = 1; } }
        for (x2 = 0; x2 < size; x2++) { run = 1; for (y2 = 1; y2 < size; y2++) { if (M[y2][x2] === M[y2 - 1][x2]) { run++; if (run === 5) p += 3; else if (run > 5) p++; } else run = 1; } }
        for (y2 = 0; y2 < size - 1; y2++) for (x2 = 0; x2 < size - 1; x2++) { c2 = M[y2][x2]; if (c2 === M[y2][x2 + 1] && c2 === M[y2 + 1][x2] && c2 === M[y2 + 1][x2 + 1]) p += 3; }
        for (y2 = 0; y2 < size; y2++) for (x2 = 0; x2 < size; x2++) if (M[y2][x2]) dark++;
        return p + Math.max(0, Math.ceil(Math.abs(dark * 20 - size * size * 10) / (size * size)) - 1) * 10;
      };
      var best = 0, bestP = Infinity;
      for (var mk = 0; mk < 8; mk++) { apply(mk); fmt(mk); var pp = penalty(); if (pp < bestP) { bestP = pp; best = mk; } apply(mk); }
      apply(best); fmt(best);
      return M;
    }
    var cache = {};
    return { matrix: function (text) { if (!(text in cache)) { cache[text] = encode(text); } return cache[text]; } };
  })();
  function qrSvg(h, text, px) {
    var M = QR.matrix(text);
    if (!M) return null;
    var n = M.length, q = 4, d = '';
    for (var y = 0; y < n; y++) for (var x = 0; x < n; x++) if (M[y][x]) d += 'M' + (x + q) + ' ' + (y + q) + 'h1v1h-1z';
    return h('svg', { viewBox: '0 0 ' + (n + 2 * q) + ' ' + (n + 2 * q), width: px, height: px, role: 'img', 'aria-label': 'QR code : ' + text, shapeRendering: 'crispEdges', style: { display: 'block', flex: '0 0 auto' } },
      h('rect', { width: n + 2 * q, height: n + 2 * q, fill: '#FFFFFF' }), h('path', { d: d, fill: '#111111' }));
  }

  /* ---------- blocs visuels (documents) ----------
     render(block, k) — k : { h, u, accent, accent2, ink, paper, head, body, hand } */
  var DOC_BLOCKS = [
    {
      type: 'studio.chiffre', label: 'Chiffre clé', rows: 2, ph: '68 %\nLégende du chiffre',
      sample: '68 %\ndes salariés placent les salaires en priorité', hint: '1re ligne : le chiffre. 2e ligne : la légende.',
      estimateHeight: function () { return 120; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text);
        return h('div', { style: { margin: '0 0 ' + u(12) } },
          h('div', { style: { fontFamily: k.head, fontWeight: 700, fontSize: u(64), lineHeight: .9, color: k.accent } }, L[0] || ''),
          L[1] ? h('div', { style: { fontFamily: k.body, fontWeight: 600, fontSize: u(13), lineHeight: 1.35, color: k.ink, marginTop: u(4) } }, L[1]) : null);
      }
    },
    {
      type: 'studio.compare', label: 'Comparatif', rows: 3, ph: 'La direction propose | 0,8 %\nNous demandons | 4,5 %',
      sample: 'La direction propose | 0,8 %\nNous demandons | 4,5 %', hint: 'Une ligne par colonne : libellé | valeur. La dernière colonne est mise en avant.',
      estimateHeight: function () { return 110; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text);
        return h('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(' + Math.max(1, L.length) + ', minmax(0,1fr))', margin: '0 0 ' + u(12) } },
          L.map(function (l, i) {
            var c = cells(l), last = i === L.length - 1;
            return h('div', { key: i, style: { background: last ? k.accent : 'rgba(128,128,128,.14)', color: last ? onC(k.accent) : k.ink, padding: u(12), display: 'flex', flexDirection: 'column', gap: u(3) } },
              h('span', { style: { fontFamily: k.body, fontWeight: 600, fontSize: u(10), textTransform: 'uppercase', letterSpacing: '.04em' } }, c[0]),
              h('span', { style: { fontFamily: k.head, fontWeight: 700, fontSize: u(34), lineHeight: 1 } }, c[1] || ''));
          }));
      }
    },
    {
      type: 'studio.frise', label: 'Frise de dates', rows: 4, ph: '2 oct. | 1re séance | fait\n4 nov. | Assemblée',
      sample: '2 oct. | 1re séance | fait\n16 oct. | 2e séance | fait\n4 nov. | Assemblée\n13 nov. | 3e séance', hint: 'Une ligne par étape : date | libellé | « fait » si l\'étape est passée.',
      estimateHeight: function () { return 90; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text).map(cells);
        return h('div', { style: { position: 'relative', display: 'grid', gridTemplateColumns: 'repeat(' + Math.max(1, L.length) + ', minmax(0,1fr))', margin: u(4) + ' 0 ' + u(14) } },
          h('div', { style: { position: 'absolute', top: u(7), left: u(8), right: u(8), height: u(2), background: 'rgba(128,128,128,.35)' } }),
          L.map(function (c, i) {
            var done = /^fait|^ok|^x$/i.test(c[2] || '');
            return h('div', { key: i, style: { position: 'relative', display: 'flex', flexDirection: 'column', gap: u(4), paddingRight: u(6) } },
              h('span', { style: { width: u(16), height: u(16), borderRadius: '50%', boxSizing: 'border-box', background: done ? k.accent : (k.paper || '#FFFFFF'), border: u(3) + ' solid ' + k.accent } }),
              h('span', { style: { fontFamily: k.body, fontWeight: 800, fontSize: u(11), color: k.ink } }, c[0]),
              h('span', { style: { fontFamily: k.body, fontSize: u(10.5), lineHeight: 1.3, color: k.ink } }, c[1] || ''));
          }));
      }
    },
    {
      type: 'studio.photo', label: 'Photo', rows: 2, accepts: 'image', ph: 'Description de l\'image (ou adresse https://…)\nLégende',
      sample: 'Photo de l\'équipe FO devant le site\nLa délégation à la sortie de la séance', hint: 'Déposez une image avec le bouton ci-dessous, ou collez son adresse en 1re ligne. Sans image, un emplacement est réservé.',
      estimateHeight: function () { return 200; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text), src = srcOf(b);
        return h('figure', { style: { margin: '0 0 ' + u(12) } },
          h('div', { style: { height: u(k.photoH || 150), background: src ? 'url("' + src + '") center / cover' : ph(), border: src ? 'none' : '1.5px dashed rgba(0,0,0,.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontFamily: mono, fontSize: u(9.5), color: 'rgba(0,0,0,.55)', padding: u(8), WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' } }, src ? null : 'Emplacement photo — ' + (L[0] || '')),
          L[1] ? h('figcaption', { style: { fontFamily: k.body, fontStyle: 'italic', fontSize: u(9.5), color: k.ink, marginTop: u(4) } }, L[1]) : null);
      }
    },
    {
      type: 'studio.qr', label: 'QR code', rows: 2, ph: 'https://adresse-du-lien\nScannez pour…',
      sample: 'https://www.force-ouvriere.fr\nScannez pour adhérer', hint: '1re ligne : l\'adresse (213 caractères au plus). 2e ligne : le libellé. Le QR code est généré et imprimable.',
      estimateHeight: function () { return 100; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text);
        var svg = L[0] ? qrSvg(h, L[0], u(86)) : null;
        return h('div', { style: { display: 'flex', gap: u(12), alignItems: 'center', margin: '0 0 ' + u(12) } },
          svg || h('div', { style: { flex: '0 0 auto', width: u(86), height: u(86), border: '1.5px dashed #999', display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontFamily: mono, fontSize: u(8), color: '#666', padding: u(4), boxSizing: 'border-box' } }, L[0] ? 'Adresse trop longue' : 'Ajoutez une adresse'),
          h('div', { style: { fontFamily: k.body, fontSize: u(12), lineHeight: 1.4, color: k.ink } }, h('strong', null, L[1] || 'Scannez'), h('br'), h('span', { style: { fontFamily: mono, fontSize: u(9.5), wordBreak: 'break-all' } }, L[0] || '')));
      }
    },
    {
      type: 'studio.coupon', label: 'Coupon d\'adhésion', rows: 2, ph: 'Titre du coupon\nChamp 1 | Champ 2 | Champ 3',
      sample: 'Je rejoins FO\nNom | Prénom | Service | Téléphone', hint: '1re ligne : titre. 2e ligne : les champs séparés par « | ».',
      estimateHeight: function () { return 150; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text), fields = cells(L[1] || 'Nom | Prénom | Service');
        return h('div', { style: { position: 'relative', border: u(2) + ' dashed ' + k.ink, padding: u(12), margin: u(8) + ' 0 ' + u(12), display: 'flex', flexDirection: 'column', gap: u(7), fontFamily: k.body, fontSize: u(11), color: k.ink } },
          h('span', { style: { position: 'absolute', top: u(-11), left: u(10), background: k.paper || '#FFFFFF', padding: '0 ' + u(4), fontSize: u(14) } }, '✂'),
          h('strong', { style: { fontSize: u(13), textTransform: 'uppercase' } }, L[0] || 'Je rejoins FO'),
          h('div', { style: { display: 'grid', gridTemplateColumns: u(70) + ' 1fr', gap: u(6) + ' ' + u(8), alignItems: 'end' } },
            fields.map(function (f, i) { return [h('span', { key: 'l' + i }, f), h('span', { key: 's' + i, style: { borderBottom: '1px solid ' + k.ink, height: u(13) } })]; })),
          h('div', { style: { display: 'flex', gap: u(14), flexWrap: 'wrap' } }, h('span', null, '☐ J\'adhère'), h('span', null, '☐ Je souhaite être contacté·e')));
      }
    },
    {
      type: 'studio.trombi', label: 'Trombinoscope', rows: 4, ph: 'Prénom N. | Mandat',
      sample: 'Sophie M. | Déléguée syndicale\nLéa T. | Référente SSCT\nJean-Paul D. | Trésorier\nMarc A. | Représentant de proximité', hint: 'Une ligne par personne : prénom | mandat. Ajoutez « | https://photo » pour la photo.',
      estimateHeight: function (b) { return 60 + Math.ceil(lines(b.text).length / 5) * 110; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text).map(cells);
        return h('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(' + Math.min(5, Math.max(3, L.length)) + ', minmax(0,1fr))', gap: u(7), margin: '0 0 ' + u(12) } },
          L.map(function (c, i) {
            return h('div', { key: i, style: { display: 'flex', flexDirection: 'column', gap: u(3) } },
              h('div', { style: { aspectRatio: '3 / 4', background: isImg(c[2]) ? 'url("' + c[2] + '") center / cover' : ph() } }),
              h('span', { style: { fontFamily: k.body, fontWeight: 700, fontSize: u(10.5), color: k.ink } }, c[0]),
              c[1] ? h('span', { style: { fontFamily: k.body, fontSize: u(9), color: k.ink, opacity: .75 } }, c[1]) : null);
          }));
      }
    },
    {
      type: 'studio.tampon', label: 'Tampon', rows: 2, ph: 'Texte central\nTexte du pourtour',
      sample: 'Je vote FO\nDéfendre · négocier · revendiquer', hint: '1re ligne : texte central. 2e ligne : texte du pourtour.',
      estimateHeight: function () { return 170; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text), col = k.stamp || k.accent;
        return h('div', { style: { display: 'flex', justifyContent: k.align || 'center', margin: u(6) + ' 0 ' + u(12) } },
          h('div', { style: { width: u(k.stampSize || 140), height: u(k.stampSize || 140), borderRadius: '50%', border: u(4) + ' solid ' + col, color: col, transform: 'rotate(-10deg)', padding: u(5), boxSizing: 'border-box', display: 'flex' } },
            h('div', { style: { flex: 1, borderRadius: '50%', border: u(2) + ' solid ' + col, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontFamily: F('Anton'), textTransform: 'uppercase', lineHeight: 1, padding: u(6) } },
              h('span', { style: { fontSize: u(8.5), letterSpacing: '.1em' } }, L[1] || ''),
              h('span', { style: { fontSize: u(fit(L[0], 32, 16, 80)), marginTop: u(3) } }, L[0] || ''))));
      }
    },
    {
      type: 'studio.surligne', label: 'Bandeau surligné', rows: 3, ph: 'Une ligne par bandeau',
      sample: 'Hennebont : 10 h 30 — place Foch\nPontivy : 10 h 30 — la Plaine', hint: 'Une ligne = un bandeau surligné.',
      estimateHeight: function (b) { return 14 + lines(b.text).length * 24; },
      render: function (b, k) {
        var h = k.h, u = P(k);
        return h('div', { style: { display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: u(4), margin: '0 0 ' + u(12) } },
          lines(b.text).map(function (l, i) { return h('span', { key: i, style: { background: k.mark || '#FFE14D', color: '#111111', fontFamily: k.body, fontWeight: 800, fontSize: u(12), textTransform: 'uppercase', padding: u(3) + ' ' + u(8), WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' } }, l); }));
      }
    },
    {
      type: 'studio.signature', label: 'Signature', rows: 3, ph: 'Prénom N.\nMandat\nContact',
      sample: 'Sophie M.\nDéléguée syndicale FO\nposte 4412 · bâtiment B', hint: 'Prénom, mandat, contact professionnel. Pas de numéro personnel.',
      estimateHeight: function () { return 80; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text);
        return h('div', { style: { display: 'flex', flexDirection: 'column', gap: u(2), margin: u(6) + ' 0 ' + u(10), color: k.ink } },
          h('span', { style: { fontFamily: F('Permanent Marker', 'cursive'), fontSize: u(20) } }, L[0] || ''),
          L[1] ? h('span', { style: { fontFamily: k.body, fontWeight: 700, fontSize: u(11.5) } }, L[1]) : null,
          L[2] ? h('span', { style: { fontFamily: k.body, fontSize: u(10.5), opacity: .8 } }, L[2]) : null);
      }
    },
    {
      type: 'studio.bulles', label: 'Bulles de dialogue', rows: 3, ph: 'Personnage : réplique',
      sample: 'La direction : Quel bonheur, il travaille 24 h/24 et ne fait jamais grève !\nLe délégué FO : Sûr ! Mais il ne cotise pas pour nos retraites.', hint: 'Une ligne par réplique : « Personnage : texte ». Jamais le nom d\'une personne réelle.',
      estimateHeight: function (b) { return 20 + lines(b.text).length * 52; },
      render: function (b, k) {
        var h = k.h, u = P(k);
        return h('div', { style: { display: 'flex', flexDirection: 'column', gap: u(8), margin: '0 0 ' + u(12) } },
          lines(b.text).map(function (l, i) {
            var m = l.match(/^([^:]{1,30})\s:\s?(.*)$/), who = m ? m[1] : '', txt = m ? m[2] : l;
            return h('div', { key: i, style: { alignSelf: i % 2 ? 'flex-end' : 'flex-start', maxWidth: '78%', display: 'flex', flexDirection: 'column', alignItems: i % 2 ? 'flex-end' : 'flex-start', gap: u(2) } },
              who ? h('span', { style: { fontFamily: k.body, fontSize: u(8.5), fontWeight: 700, textTransform: 'uppercase', letterSpacing: '.06em', color: k.ink, opacity: .7 } }, who) : null,
              h('span', { style: { background: '#FFFFFF', color: '#151515', border: u(2) + ' solid #151515', borderRadius: u(16), padding: u(7) + ' ' + u(11), fontFamily: F('Comic Neue', 'cursive'), fontWeight: 700, fontSize: u(11.5), lineHeight: 1.25 } }, txt));
          }));
      }
    },
    {
      type: 'studio.exige', label: 'Encadré « FO exige »', rows: 4, ph: 'Titre de l\'encadré\nRevendication 1\nRevendication 2',
      sample: 'FO exige !\nL\'humain dans tous nos métiers\nLa formation pour toutes et tous\nZéro suppression de poste sous couvert d\'IA', hint: '1re ligne : titre. Puis une revendication par ligne.',
      estimateHeight: function (b) { return 50 + lines(b.text).length * 22; },
      render: function (b, k) {
        var h = k.h, u = P(k), L = lines(b.text);
        return h('div', { style: { border: u(2.5) + ' solid ' + k.accent, background: '#FFFFFF', margin: '0 0 ' + u(12), WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' } },
          h('div', { style: { background: k.accent, color: onC(k.accent), fontFamily: k.head, fontWeight: 700, fontSize: u(22), textAlign: 'center', textTransform: 'uppercase', padding: u(3) + ' 0' } }, L[0] || 'FO exige !'),
          h('div', { style: { padding: u(9) + ' ' + u(10), display: 'flex', flexDirection: 'column', gap: u(5), fontFamily: k.body, fontWeight: 700, fontSize: u(11.5), lineHeight: 1.2, color: '#151515' } },
            L.slice(1).map(function (l, i) { return h('span', { key: i }, h('span', { style: { color: k.accent } }, '• '), l); })));
      }
    }
  ];

  /* ---------- moteur de rendu partagé par les styles ---------- */
  function kit(ctx, o) {
    var c = ctx.colors, f = ctx.fonts;
    return Object.assign({ h: ctx.h, u: ctx.u, accent: c.a, accent2: c.b, ink: c.c, paper: c.d, head: f.head, body: f.body, hand: f.hand || f.head }, o || {});
  }
  /* rend un bloc avec la « peau » d'un style. skin[type](b, i) peut surcharger n'importe quel type. */
  function flow(ctx, list, k, skin) {
    var h = ctx.h, u = P(k);
    skin = skin || {};
    return list.map(function (b, i) {
      if (skin[b.type]) return skin[b.type](b, i);
      var t = b.text || '';
      switch (b.type) {
        case 'tag': return h('div', { key: b.id || i, style: { fontFamily: k.body, fontWeight: 800, fontSize: u(10.5), letterSpacing: '.14em', textTransform: 'uppercase', color: k.accent, margin: '0 0 ' + u(6) } }, t);
        case 'h1': return h('div', { key: b.id || i, style: { fontFamily: k.head, fontWeight: 700, fontSize: u(fit(t, 30, 18, 150)), lineHeight: 1.08, color: k.ink, margin: '0 0 ' + u(10), textWrap: 'balance' } }, t);
        case 'h2': return h('div', { key: b.id || i, style: { fontFamily: k.head, fontWeight: 700, fontSize: u(16), lineHeight: 1.2, color: k.ink, margin: u(10) + ' 0 ' + u(5) } }, t);
        case 'h3': return h('div', { key: b.id || i, style: { fontFamily: k.head, fontWeight: 700, fontSize: u(13.5), lineHeight: 1.25, color: k.accent, margin: u(8) + ' 0 ' + u(4) } }, t);
        case 'p': return h('p', { key: b.id || i, style: { fontFamily: k.body, fontSize: u(11), lineHeight: 1.5, color: k.ink, margin: '0 0 ' + u(8), textWrap: 'pretty' } }, t);
        case 'ul': return h('div', { key: b.id || i, style: { display: 'flex', flexDirection: 'column', gap: u(4), margin: '0 0 ' + u(10) } }, lines(t).map(function (l, j) { return h('div', { key: j, style: { display: 'flex', gap: u(7), fontFamily: k.body, fontSize: u(11), lineHeight: 1.4, color: k.ink } }, h('span', { style: { color: k.accent } }, '■'), h('span', null, l)); }));
        case 'quote': return h('div', { key: b.id || i, style: { fontFamily: k.body, fontSize: u(11), lineHeight: 1.5, color: k.ink, background: 'rgba(128,128,128,.12)', padding: u(9) + ' ' + u(12), margin: '0 0 ' + u(10), whiteSpace: 'pre-line' } }, t);
        case 'table': {
          var rows = lines(t).map(cells), n = rows.length ? rows[0].length : 1;
          return h('div', { key: b.id || i, style: { display: 'grid', gridTemplateColumns: 'repeat(' + n + ', minmax(0,1fr))', margin: '0 0 ' + u(10), fontFamily: k.body, fontSize: u(10), color: k.ink } },
            rows.map(function (r, ri) { var o = []; for (var ci = 0; ci < n; ci++) o.push(h('div', { key: ri + '-' + ci, style: { padding: u(5) + ' ' + u(6), fontWeight: ri ? 400 : 700, borderBottom: '1px solid rgba(128,128,128,.35)', background: ri ? 'transparent' : 'rgba(128,128,128,.12)' } }, r[ci] || '')); return o; }));
        }
        default: {
          var el = ctx.block(b, k);
          return el ? h('div', { key: b.id || i }, el) : (t ? h('p', { key: b.id || i, style: { fontFamily: k.body, fontSize: u(11), color: k.ink, margin: '0 0 ' + u(8) } }, t) : null);
        }
      }
    });
  }
  function frame(ctx, style, kids) {
    if (ctx.landscapeKind === 'choc') {
      var h = ctx.h, take = function (key) { return kids.find(function (k) { return k && k.key === key; }); };
      var top = take('t'), bottom = take('b');
      kids = [top && h('div', { key: 'top', style: { gridColumn: '1 / -1' } }, top),
        h('div', { key: 'number', style: { display: 'flex', alignItems: 'center', minWidth: 0 } }, take('n')),
        h('div', { key: 'message', style: { display: 'flex', flexDirection: 'column', justifyContent: 'center', minWidth: 0 } }, take('h'), take('p'), take('u'), take('x')),
        bottom && h('div', { key: 'bottom', style: { gridColumn: '1 / -1' } }, bottom)];
      style = Object.assign({}, style, { display: 'grid', gridTemplateColumns: '.9fr 1.1fr', gridTemplateRows: 'auto minmax(0,1fr) auto', gap: '18px' });
    }
    return ctx.h('div', { style: Object.assign({ position: 'relative', width: '100%', height: '100%', overflow: 'hidden', boxSizing: 'border-box', WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' }, style) }, kids); }
  function logo(ctx, size, bg) {
    var h = ctx.h, u = P({ u: ctx.u });
    if (ctx.org.logo) return h('span', { style: { display: 'block', width: u(size * 1.8), height: u(size), background: 'url("' + ctx.org.logo + '") left center / contain no-repeat' } });
    return h('span', { style: { width: u(size), height: u(size), borderRadius: '50%', background: bg || '#FFFFFF', color: '#8A8A8A', fontFamily: mono, fontSize: u(8.5), display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' } }, 'Logo');
  }
  function except(ctx, used) { return ctx.blocks.filter(function (b) { return used.indexOf(b) < 0; }); }

  /* ---------- styles de documents ---------- */
  var DOC_STYLES = [
    {
      id: 'choc', label: 'Affiche choc', desc: 'Un chiffre géant, un refus, des revendications surlignées.', formats: ['a5', 'a4', 'wide'],
      suits: ['tract', 'mobilisation', 'nao', 'grève', 'salaire', '%'],
      uniiHint: 'Affiche de mobilisation : un chiffre clé, un titre de 5 mots maximum, 3 revendications courtes en liste, une ligne pratique (date, heure, lieu) en encadré.',
      palettes: [{ id: 'rouge', label: 'Rouge FO', colors: { a: '#E3051B', b: '#FFE14D', c: '#5BC4C4', d: '#FFFFFF' } }, { id: 'nuit', label: 'Nuit', colors: { a: '#151515', b: '#FF3B2F', c: '#FFE14D', d: '#FFFFFF' } }, { id: 'bleu', label: 'Bleu ouvrier', colors: { a: '#2433A8', b: '#FFD23F', c: '#FF8A8A', d: '#FFFFFF' } }, { id: 'vert', label: 'Vert', colors: { a: '#0E7A55', b: '#FFE14D', c: '#FFFFFF', d: '#FFFFFF' } }],
      fonts: [{ id: 'anton', label: 'Anton', head: F('Anton'), body: F('Archivo') }, { id: 'bebas', label: 'Bebas', head: F('Bebas Neue'), body: F('Barlow') }, { id: 'archivo', label: 'Archivo Black', head: F('Archivo Black'), body: F('Archivo') }],
      render: function (ctx) {
        if (ctx.format.id === 'wide') ctx = Object.assign({}, ctx, { u: ctx.format.h / 420, landscapeKind: 'choc' });
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), used = [];
        var take = function (t) { var b = ctx.first(t); if (b) used.push(b); return b; };
        var tag = take('tag'), h1 = take('h1'), num = take('studio.chiffre'), ul = take('ul'), q = take('quote'), p = take('p');
        var big = num ? lines(num.text)[0] : null; if (ctx.landscapeKind && !big) ctx = Object.assign({}, ctx, { landscapeKind: 'choc-simple' }); var k = kit(ctx, { ink: c.d, mark: c.c });
        return frame(ctx, { background: 'radial-gradient(rgba(255,255,255,.07) 1px, transparent 1.4px) 0 0 / 6px 6px, ' + c.a, color: c.d, padding: u(26) + ' ' + u(28), display: 'flex', flexDirection: 'column' }, [
          h('div', { key: 't', style: { display: 'flex', justifyContent: 'space-between', alignItems: 'center' } }, logo(ctx, 50), h('span', { style: { fontFamily: f.body, fontWeight: 800, fontSize: u(12), letterSpacing: '.16em', textTransform: 'uppercase' } }, tag ? tag.text : ctx.org.emetteur)),
          big ? h('div', { key: 'n', style: { fontFamily: f.head, fontSize: u(fit(big, ctx.landscapeKind ? 120 : 210, 90, 420)), lineHeight: .82, whiteSpace: ctx.landscapeKind ? 'nowrap' : undefined, marginTop: u(20) } }, big) : null,
          h1 ? h('div', { key: 'h', style: { fontFamily: f.head, fontSize: u(ctx.landscapeKind ? fit(h1.text, 44, 30, 220) : big ? fit(h1.text, 64, 30, 220) : fit(h1.text, 110, 40, 420)), lineHeight: .95, textTransform: 'uppercase', color: c.b, marginTop: u(big ? 6 : 34) } }, h1.text) : null,
          p && !ul ? h('p', { key: 'p', style: { fontFamily: f.body, fontSize: u(13), lineHeight: 1.45, margin: u(14) + ' 0 0', maxWidth: '92%' } }, p.text) : null,
          ul ? h('div', { key: 'u', style: { display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: u(4), marginTop: u(20) } }, lines(ul.text).map(function (l, i) { return h('span', { key: i, style: { background: c.c, color: '#111111', fontFamily: f.body, fontWeight: 800, fontSize: u(12.5), textTransform: 'uppercase', padding: u(3) + ' ' + u(8) } }, l); })) : null,
          h('div', { key: 'x', style: { marginTop: u(14) } }, flow(ctx, except(ctx, used).filter(function (b) { return b.type.indexOf('studio.') === 0; }), k)),
          h('div', { key: 'b', style: { marginTop: 'auto', fontFamily: f.body, fontWeight: 800, fontSize: u(13), lineHeight: 1.3, textTransform: 'uppercase', whiteSpace: 'pre-line' } }, q ? q.text : ctx.org.contact)
        ]);
      }
    },
    {
      id: 'journal', label: 'Journal syndical', desc: 'Bandeau-titre, colonnes, lettrine, citation.', formats: ['a4', 'a5'],
      slots: [{ id: 'img0', label: 'Photo de l\'article', type: 'studio.photo', index: 0, optional: true }],
      suits: ['cr', 'compte rendu', 'journal', 'séance', 'bilan', 'négociation'],
      uniiHint: 'Article de journal de section : un surtitre (rubrique), un titre informatif, un chapô d\'une phrase, 3 à 4 paragraphes courts, une citation forte.',
      palettes: [{ id: 'papier', label: 'Papier', colors: { a: '#C8102E', b: '#E9E1D0', c: '#1B1A17', d: '#F6F1E6' } }, { id: 'presse', label: 'Bleu presse', colors: { a: '#1F4E9C', b: '#DDE3EC', c: '#111827', d: '#F7F8FA' } }, { id: 'soir', label: 'Édition du soir', colors: { a: '#E8553D', b: '#3A3A3A', c: '#F2EEE6', d: '#161616' } }, { id: 'nb', label: 'Noir et blanc', colors: { a: '#111111', b: '#DADADA', c: '#111111', d: '#FFFFFF' } }],
      fonts: [{ id: 'playfair', label: 'Playfair', head: F('Playfair Display', 'serif'), body: F('Source Serif 4', 'serif') }, { id: 'dm', label: 'DM Serif', head: F('DM Serif Display', 'serif'), body: F('Libre Franklin') }, { id: 'news', label: 'Newsreader', head: F('Newsreader', 'serif'), body: F('Newsreader', 'serif') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), used = [], k = kit(ctx);
        var take = function (t) { var b = ctx.first(t); if (b) used.push(b); return b; };
        var tag = take('tag'), h1 = take('h1'), chapo = take('p'), q = take('quote');
        var rest = except(ctx, used);
        var dropped = false;
        var skin = { p: function (b, i) {
          var t = b.text || '', first = !dropped; dropped = true;
          return h('p', { key: b.id || i, style: { fontFamily: f.body, fontSize: u(10.5), lineHeight: 1.5, color: c.c, margin: '0 0 ' + u(6), textAlign: 'justify', hyphens: 'auto' } },
            first ? h('span', { style: { float: 'left', fontFamily: f.head, fontSize: u(38), lineHeight: .8, padding: u(3) + ' ' + u(5) + ' 0 0', color: c.a } }, t.charAt(0)) : null, first ? t.slice(1) : t);
        } };
        return frame(ctx, { background: c.d, color: c.c, padding: u(22) + ' ' + u(24), display: 'flex', flexDirection: 'column', gap: u(8) }, [
          h('div', { key: 'm', style: { borderTop: u(4) + ' solid ' + c.c, paddingTop: u(6), textAlign: 'center', fontFamily: f.head, fontWeight: 900, fontSize: u(fit(ctx.org.emetteur, 40, 24, 140)), lineHeight: 1 } }, 'La Voix ' + (ctx.org.emetteur ? '— ' + ctx.org.emetteur : 'de la section')),
          h('div', { key: 'l', style: { display: 'flex', justifyContent: 'space-between', gap: u(8), borderTop: '1px solid ' + c.c, borderBottom: '1px solid ' + c.c, padding: u(3) + ' 0', fontFamily: f.body, fontSize: u(9), letterSpacing: '.08em', textTransform: 'uppercase' } }, h('span', null, ctx.org.section || ''), h('span', null, 'Page ' + (ctx.page.index + 1) + ' / ' + ctx.page.count)),
          tag ? h('span', { key: 'k', style: { fontFamily: f.body, fontWeight: 600, fontSize: u(10), letterSpacing: '.16em', textTransform: 'uppercase', color: c.a, marginTop: u(4) } }, tag.text) : null,
          h1 ? h('div', { key: 'h', style: { fontFamily: f.head, fontWeight: 700, fontSize: u(fit(h1.text, 30, 18, 170)), lineHeight: 1.08, textWrap: 'balance' } }, h1.text) : null,
          chapo ? h('div', { key: 'c', style: { fontFamily: f.body, fontStyle: 'italic', fontSize: u(12), lineHeight: 1.45 } }, chapo.text) : null,
          h('div', { key: 'b', style: { columnCount: 2, columnGap: u(16), flex: '1 1 auto', minHeight: 0, overflow: 'hidden' } }, flow(ctx, rest, Object.assign({}, k, { u: ctx.u * .92 }), skin)),
          q ? h('div', { key: 'q', style: { borderTop: u(2) + ' solid ' + c.a, paddingTop: u(7), fontFamily: f.head, fontStyle: 'italic', fontSize: u(15), lineHeight: 1.25, whiteSpace: 'pre-line' } }, '« ' + q.text + ' »') : null
        ]);
      }
    },
    {
      id: 'infographie', label: 'Infographie', desc: 'Chiffres clés, comparatifs et jauges en grand.', formats: ['a4', 'a5', 'wide'],
      suits: ['chiffre', 'bdese', 'rapport', 'enquête', 'sondage', 'résultat', '%'],
      uniiHint: 'Infographie : chiffres issus du dossier uniquement (aucun inventé), un comparatif direction / nous, 3 chiffres clés avec légende courte, source citée en pied.',
      palettes: [{ id: 'rouge', label: 'Rouge', colors: { a: '#E3051B', b: '#C9CDD6', c: '#14161B', d: '#FFFFFF' } }, { id: 'sombre', label: 'Sombre', colors: { a: '#FF5A36', b: '#3A3F4D', c: '#FFFFFF', d: '#14161B' } }, { id: 'bleu', label: 'Bleu et jaune', colors: { a: '#2D6BFF', b: '#FFC93C', c: '#0E1A33', d: '#F3F6FF' } }, { id: 'vert', label: 'Vert', colors: { a: '#0FA37F', b: '#E1E4E8', c: '#102A22', d: '#FFFFFF' } }],
      fonts: [{ id: 'space', label: 'Space Grotesk', head: F('Space Grotesk'), body: F('Space Grotesk') }, { id: 'barlow', label: 'Barlow', head: F('Barlow Condensed'), body: F('Barlow') }, { id: 'archivo', label: 'Archivo', head: F('Archivo Black'), body: F('Archivo') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), k = kit(ctx);
        var skin = {
          ul: function (b, i) { var L = lines(b.text); return h('div', { key: b.id || i, style: { display: 'grid', gridTemplateColumns: 'repeat(' + Math.min(3, Math.max(1, L.length)) + ', minmax(0,1fr))', gap: u(8), margin: '0 0 ' + u(12) } }, L.map(function (l, j) { var m = l.match(/^([\d.,]+\s?(%|€|j|h)?)\s+(.*)$/); return h('div', { key: j, style: { borderTop: u(3) + ' solid ' + c.a, paddingTop: u(6) } }, m ? h('div', { style: { fontFamily: f.head, fontWeight: 700, fontSize: u(24) } }, m[1]) : null, h('div', { style: { fontFamily: f.body, fontSize: u(10.5), lineHeight: 1.3 } }, m ? m[3] : l)); })); },
          tag: function (b, i) { return h('span', { key: b.id || i, style: { display: 'block', fontFamily: f.body, fontWeight: 700, fontSize: u(10.5), letterSpacing: '.16em', textTransform: 'uppercase', color: c.a, margin: '0 0 ' + u(6) } }, b.text); },
          h1: function (b, i) { return h('div', { key: b.id || i, style: { fontFamily: f.head, fontWeight: 700, fontSize: u(fit(b.text, 34, 20, 160)), lineHeight: 1.02, margin: '0 0 ' + u(14) } }, b.text); },
          'studio.chiffre': function (b, i) { var L = lines(b.text), v = parseFloat(String(L[0]).replace(',', '.')); var pct = /%/.test(L[0]) && v >= 0 && v <= 100 ? v : null;
            return h('div', { key: b.id || i, style: { display: 'flex', gap: u(16), alignItems: 'center', margin: '0 0 ' + u(14) } },
              h('div', { style: { flex: '0 0 auto', width: u(120), height: u(120), borderRadius: '50%', background: pct !== null ? 'conic-gradient(' + c.a + ' 0 ' + pct + '%, ' + c.b + ' 0)' : c.a, display: 'flex', alignItems: 'center', justifyContent: 'center' } }, h('div', { style: { width: u(84), height: u(84), borderRadius: '50%', background: c.d, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: f.head, fontWeight: 700, fontSize: u(fit(L[0], 28, 16, 60)), color: c.c } }, L[0])),
              h('div', { style: { fontFamily: f.body, fontWeight: 600, fontSize: u(14), lineHeight: 1.35 } }, L[1] || '')); },
          'studio.compare': function (b, i) { var L = lines(b.text).map(cells), vals = L.map(function (x) { return parseFloat(String(x[1]).replace(',', '.')) || 0; }), mx = Math.max.apply(null, vals.concat([1]));
            return h('div', { key: b.id || i, style: { display: 'flex', flexDirection: 'column', gap: u(9), margin: '0 0 ' + u(14) } }, L.map(function (x, j) { return h('div', { key: j, style: { display: 'flex', flexDirection: 'column', gap: u(3) } }, h('div', { style: { display: 'flex', justifyContent: 'space-between', fontFamily: f.body, fontSize: u(11.5), fontWeight: 600 } }, h('span', null, x[0]), h('span', null, x[1])), h('div', { style: { height: u(22), width: Math.max(6, vals[j] / mx * 100) + '%', background: j === L.length - 1 ? c.a : c.b } })); })); }
        };
        return frame(ctx, { background: c.d, color: c.c, padding: u(28), display: 'flex', flexDirection: 'column' }, [
          h('div', { key: 'f', style: { flex: '1 1 auto', minHeight: 0, overflow: 'hidden' } }, flow(ctx, ctx.blocks, k, skin)),
          h('div', { key: 's', style: { fontFamily: f.body, fontSize: u(9), opacity: .75, marginTop: u(8) } }, ctx.org.emetteur + (ctx.org.section ? ' · ' + ctx.org.section : ''))
        ]);
      }
    },
    {
      id: 'institutionnel', label: 'Institutionnel sobre', desc: 'Structuré, factuel, daté. Pour l\'information officielle.', formats: ['a4'],
      suits: ['courrier', 'note', 'information', 'officiel', 'employeur', 'saisine'],
      uniiHint: 'Note d\'information officielle : titre factuel, date, encadré « où en sommes-nous », points numérotés, prochaines étapes en tableau, contact.',
      palettes: [{ id: 'rouge', label: 'Rouge', colors: { a: '#C8102E', b: '#FBECEE', c: '#1C1E24', d: '#FFFFFF' } }, { id: 'marine', label: 'Marine', colors: { a: '#1E3A6E', b: '#E8EEF7', c: '#141A26', d: '#FFFFFF' } }, { id: 'olive', label: 'Olive', colors: { a: '#3F4A3C', b: '#EEF0EA', c: '#1D211B', d: '#FFFFFF' } }, { id: 'prune', label: 'Prune', colors: { a: '#5B2A86', b: '#F1EAF7', c: '#1E1626', d: '#FFFFFF' } }],
      fonts: [{ id: 'plex', label: 'IBM Plex', head: F('IBM Plex Sans'), body: F('IBM Plex Sans') }, { id: 'serif', label: 'Serif + Franklin', head: F('Source Serif 4', 'serif'), body: F('Libre Franklin') }, { id: 'barlow', label: 'Barlow', head: F('Barlow'), body: F('Barlow') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), k = kit(ctx), n = 0;
        var skin = {
          h1: function (b, i) { return h('div', { key: b.id || i, style: { fontFamily: f.head, fontWeight: 600, fontSize: u(fit(b.text, 24, 16, 120)), lineHeight: 1.2, margin: '0 0 ' + u(10), textWrap: 'balance' } }, b.text); },
          quote: function (b, i) { return h('div', { key: b.id || i, style: { background: c.b, padding: u(10) + ' ' + u(13), fontFamily: f.body, fontSize: u(11), lineHeight: 1.5, margin: '0 0 ' + u(10), whiteSpace: 'pre-line' } }, b.text); },
          ul: function (b, i) { return h('div', { key: b.id || i, style: { display: 'flex', flexDirection: 'column', gap: u(5), margin: '0 0 ' + u(10) } }, lines(b.text).map(function (l, j) { n++; return h('div', { key: j, style: { display: 'flex', gap: u(10), fontFamily: f.body, fontSize: u(11), lineHeight: 1.4 } }, h('span', { style: { fontWeight: 600, color: c.a } }, (n < 10 ? '0' : '') + n), h('span', null, l)); })); }
        };
        return frame(ctx, { background: c.d, color: c.c, padding: u(28) + ' ' + u(28) + ' ' + u(24) + ' ' + u(42), display: 'flex', flexDirection: 'column' }, [
          h('div', { key: 'band', style: { position: 'absolute', left: 0, top: 0, bottom: 0, width: u(12), background: c.a } }),
          h('div', { key: 'hd', style: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: u(16) } }, logo(ctx, 38, '#F1F1F3'), h('div', { style: { textAlign: 'right', fontFamily: f.body, fontSize: u(9.5), lineHeight: 1.4 } }, ctx.org.emetteur, h('br'), ctx.org.section)),
          h('div', { key: 'f', style: { flex: '1 1 auto', minHeight: 0, overflow: 'hidden' } }, flow(ctx, ctx.blocks, k, skin)),
          h('div', { key: 'ft', style: { borderTop: '1px solid #D9DBE0', paddingTop: u(6), display: 'flex', justifyContent: 'space-between', fontFamily: f.body, fontSize: u(9), opacity: .8 } }, h('span', null, ctx.org.contact), h('span', null, (ctx.page.index + 1) + ' / ' + ctx.page.count))
        ]);
      }
    },
    {
      id: 'photo', label: 'Photo pleine page', desc: 'La photo porte le message, le texte se pose en bas.', formats: ['a5', 'a4'],
      slots: [{ id: 'img0', label: 'Photo de fond', type: 'studio.photo', index: 0 }],
      suits: ['élection', 'campagne', 'adhésion', 'candidat', 'cse'],
      uniiHint: 'Affiche photo : un titre court et humain, une phrase d\'accroche, une bande pratique (scrutin, date). Prévoir un bloc Photo en premier.',
      palettes: [{ id: 'rouge', label: 'Rouge', colors: { a: '#E3051B', b: '#FFFFFF', c: '#0B0B0D', d: '#FFFFFF' } }, { id: 'jaune', label: 'Jaune', colors: { a: '#FFD23F', b: '#FFD23F', c: '#14110A', d: '#FFFFFF' } }, { id: 'bleu', label: 'Bleu', colors: { a: '#2D6BFF', b: '#FFFFFF', c: '#071330', d: '#FFFFFF' } }],
      fonts: [{ id: 'bebas', label: 'Bebas', head: F('Bebas Neue'), body: F('Barlow') }, { id: 'anton', label: 'Anton', head: F('Anton'), body: F('Archivo') }, { id: 'archivo', label: 'Archivo Black', head: F('Archivo Black'), body: F('Archivo') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), used = [];
        var take = function (t) { var b = ctx.first(t); if (b) used.push(b); return b; };
        var ph0 = take('studio.photo'), tag = take('tag'), h1 = take('h1'), p = take('p'), q = take('quote');
        var src = srcOf(ph0);
        return frame(ctx, { background: src ? 'url("' + src + '") center / cover' : ph(true), color: c.d }, [
          src ? null : h('div', { key: 'l', style: { position: 'absolute', top: '26%', left: 0, right: 0, textAlign: 'center', fontFamily: mono, fontSize: u(10), color: '#B9BBC2' } }, 'Emplacement photo' + (ph0 ? ' — ' + lines(ph0.text)[0] : ' : ajoutez un bloc Photo')),
          h('div', { key: 'g', style: { position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, transparent 30%, ' + c.c + ' 80%)' } }),
          h('div', { key: 'lg', style: { position: 'absolute', top: u(22), left: u(24) } }, logo(ctx, 50)),
          h('div', { key: 'b', style: { position: 'absolute', left: u(24), right: u(24), bottom: u(24), display: 'flex', flexDirection: 'column', gap: u(11) } },
            tag ? h('span', { style: { fontFamily: f.body, fontWeight: 800, fontSize: u(11), letterSpacing: '.16em', textTransform: 'uppercase' } }, tag.text) : null,
            h1 ? h('div', { style: { fontFamily: f.head, fontSize: u(fit(h1.text, 80, 38, 330)), lineHeight: .92, textTransform: 'uppercase' } }, h1.text) : null,
            p ? h('div', { style: { fontFamily: f.body, fontSize: u(13), lineHeight: 1.4 } }, p.text) : null,
            h('div', { style: { background: c.a, color: onC(c.a), fontFamily: f.body, fontWeight: 800, fontSize: u(12), textTransform: 'uppercase', letterSpacing: '.04em', padding: u(9) + ' ' + u(12), whiteSpace: 'pre-line' } }, q ? q.text : ctx.org.emetteur))
        ]);
      }
    },
    {
      id: 'serigraphie', label: 'Sérigraphie militante', desc: 'Deux encres, trame, tampon, écriture au feutre.', formats: ['a5', 'a4'],
      suits: ['grève', 'rassemblement', 'manifestation', 'mobilisation', '1er mai'],
      uniiHint: 'Affiche de rassemblement : un mot d\'ordre en 2 à 3 mots, une date manuscrite, un tampon (heure, lieu), une ligne de revendications.',
      palettes: [{ id: 'rb', label: 'Rouge et bleu', colors: { a: '#E3051B', b: '#1A1A5E', c: '#E3051B', d: '#F3EADB' } }, { id: 'on', label: 'Orange et noir', colors: { a: '#FF4F1F', b: '#111111', c: '#FF4F1F', d: '#F1E9D6' } }, { id: 'rv', label: 'Rouge et vert', colors: { a: '#D7263D', b: '#0B6E4F', c: '#D7263D', d: '#F4EEE1' } }, { id: 'nr', label: 'Noir et rouge', colors: { a: '#1A1A1A', b: '#E3051B', c: '#1A1A1A', d: '#FFFFFF' } }],
      fonts: [{ id: 'anton', label: 'Anton + feutre', head: F('Anton'), body: F('Archivo'), hand: F('Permanent Marker', 'cursive') }, { id: 'bebas', label: 'Bebas + feutre', head: F('Bebas Neue'), body: F('Barlow'), hand: F('Permanent Marker', 'cursive') }, { id: 'archivo', label: 'Archivo seul', head: F('Archivo Black'), body: F('Archivo'), hand: F('Archivo Black') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), used = [];
        var take = function (t) { var b = ctx.first(t); if (b) used.push(b); return b; };
        var h1 = take('h1'), tag = take('tag'), q = take('quote'), ul = take('ul'), st = take('studio.tampon');
        var w = String(h1 ? h1.text : '').split(/\s+/), w1 = w.shift() || '', w2 = w.join(' ');
        var ql = q ? lines(q.text) : [];
        return frame(ctx, { background: c.d, color: c.b, padding: u(26), display: 'flex', flexDirection: 'column' }, [
          h('div', { key: 'dots', style: { position: 'absolute', right: u(-120), top: u(-90), width: u(400), height: u(400), borderRadius: '50%', background: 'radial-gradient(' + c.a + ' 1.6px, transparent 2.2px) 0 0 / 10px 10px', opacity: .55 } }),
          h('div', { key: 'w1', style: { position: 'relative', fontFamily: f.head, fontSize: u(Math.min(fit(w1, 150, 70, 300), 340 / (Math.max(1,w1.length) * .65))), lineHeight: .82, textTransform: 'uppercase', transform: 'rotate(-4deg)', transformOrigin: 'left', marginTop: u(28), textShadow: u(4) + ' ' + u(4) + ' 0 ' + c.a } }, w1),
          w2 ? h('div', { key: 'w2', style: { position: 'relative', fontFamily: f.head, fontSize: u(fit(w2, 92, 34, 300)), lineHeight: .9, textTransform: 'uppercase', color: c.a, transform: 'rotate(-4deg)', transformOrigin: 'left', marginTop: u(4) } }, w2) : null,
          tag ? h('div', { key: 'tg', style: { position: 'relative', fontFamily: f.hand, fontSize: u(fit(tag.text, 40, 22, 120)), transform: 'rotate(-3deg)', marginTop: u(16) } }, tag.text) : null,
          (st || ql.length) ? h('div', { key: 'st', style: { position: 'absolute', right: u(22), top: '56%', width: u(150), height: u(150), borderRadius: '50%', border: u(4) + ' solid ' + c.a, color: c.a, transform: 'rotate(12deg)', padding: u(6), boxSizing: 'border-box', display: 'flex' } },
            h('div', { style: { flex: 1, borderRadius: '50%', border: u(2) + ' solid ' + c.a, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontFamily: f.head, textTransform: 'uppercase', lineHeight: 1, padding: u(6) } },
              (st ? lines(st.text) : ql).map(function (l, i) { return h('span', { key: i, style: { fontSize: u(i === 0 ? fit(l, 40, 14, 80) : 10), letterSpacing: i ? '.12em' : 0, marginTop: i ? u(3) : 0 } }, l); }))) : null,
          h('div', { key: 'bt', style: { marginTop: 'auto', position: 'relative', fontFamily: f.body, fontWeight: 800, fontSize: u(13), lineHeight: 1.35, textTransform: 'uppercase', maxWidth: '58%' } }, ul ? lines(ul.text).join(' · ') : '', h('br'), h('span', { style: { color: c.a } }, ctx.org.emetteur))
        ]);
      }
    },
    {
      id: 'bulletin', label: 'Bulletin d\'information', desc: 'Brèves, agenda et contacts en colonne.', formats: ['a4', 'a5'],
      slots: [{ id: 'img0', label: 'Photo d\'illustration', type: 'studio.photo', index: 0, optional: true }],
      suits: ['bulletin', 'lettre', 'actualité', 'mensuel', 'info'],
      uniiHint: 'Bulletin : 3 brèves (intertitre + 2 phrases chacune), un agenda en liste « date — événement », les contacts des élus.',
      palettes: [{ id: 'rouge', label: 'Rouge', colors: { a: '#C8102E', b: '#FDE8EA', c: '#1A1B20', d: '#FFFFFF' } }, { id: 'bleu', label: 'Bleu', colors: { a: '#0F5E9C', b: '#E3F0FA', c: '#122033', d: '#FFFFFF' } }, { id: 'orange', label: 'Orange', colors: { a: '#E76F00', b: '#FFF0E0', c: '#2A1A08', d: '#FFFDF9' } }, { id: 'graph', label: 'Graphite', colors: { a: '#26262B', b: '#EDEDF0', c: '#16161A', d: '#FFFFFF' } }],
      fonts: [{ id: 'franklin', label: 'Libre Franklin', head: F('Libre Franklin'), body: F('Libre Franklin') }, { id: 'space', label: 'Space Grotesk', head: F('Space Grotesk'), body: F('IBM Plex Sans') }, { id: 'barlow', label: 'Barlow', head: F('Barlow Condensed'), body: F('Barlow') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), k = kit(ctx);
        var side = ctx.blocks.filter(function (b) { return b.type === 'ul' || b.type === 'quote' || b.type === 'studio.signature' || b.type === 'studio.qr'; });
        var main = ctx.blocks.filter(function (b) { return side.indexOf(b) < 0 && b.type !== 'tag'; });
        var tag = ctx.first('tag');
        var skin = { h2: function (b, i) { return h('div', { key: b.id || i, style: { fontFamily: f.head, fontWeight: 800, fontSize: u(14), lineHeight: 1.2, margin: u(10) + ' 0 ' + u(4), paddingTop: u(8), borderTop: '1px solid ' + c.b } }, b.text); },
          h1: function (b, i) { return h('div', { key: b.id || i, style: { fontFamily: f.head, fontWeight: 800, fontSize: u(fit(b.text, 22, 15, 110)), lineHeight: 1.12, margin: '0 0 ' + u(8) } }, b.text); } };
        var sk2 = { ul: function (b, i) { return h('div', { key: b.id || i, style: { display: 'flex', flexDirection: 'column', gap: u(7), margin: '0 0 ' + u(10) } }, lines(b.text).map(function (l, j) { var m = l.split(/\s[—–-]\s|\s:\s/); return h('div', { key: j, style: { fontFamily: f.body, fontSize: u(10), lineHeight: 1.35 } }, m.length > 1 ? [h('strong', { key: 'a' }, m[0]), h('br', { key: 'b' }), m.slice(1).join(' — ')] : l); })); },
          quote: function (b, i) { return h('div', { key: b.id || i, style: { fontFamily: f.body, fontSize: u(10), lineHeight: 1.45, margin: '0 0 ' + u(10), whiteSpace: 'pre-line' } }, b.text); } };
        return frame(ctx, { background: c.d, color: c.c, display: 'flex', flexDirection: 'column' }, [
          h('div', { key: 'hd', style: { background: c.a, color: onC(c.a), padding: u(16) + ' ' + u(22), display: 'flex', flexDirection: 'column', gap: u(2) } },
            h('div', { style: { display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: u(10) } }, h('span', { style: { fontFamily: f.head, fontWeight: 800, fontSize: u(30) } }, 'Infos'), h('span', { style: { fontFamily: f.body, fontSize: u(10), fontWeight: 600 } }, tag ? tag.text : '')),
            h('span', { style: { fontFamily: f.body, fontSize: u(10.5) } }, ctx.org.emetteur + (ctx.org.section ? ' · ' + ctx.org.section : ''))),
          h('div', { key: 'bd', style: { flex: '1 1 auto', minHeight: 0, display: 'grid', gridTemplateColumns: side.length ? '1.6fr 1fr' : '1fr', gap: u(14), padding: u(16) + ' ' + u(20), overflow: 'hidden' } },
            h('div', { style: { minWidth: 0 } }, flow(ctx, main, k, skin)),
            side.length ? h('div', { style: { background: c.b, borderRadius: u(10), padding: u(12), minWidth: 0, alignSelf: 'start' } }, h('div', { style: { fontFamily: f.body, fontWeight: 800, fontSize: u(11), textTransform: 'uppercase', letterSpacing: '.06em', marginBottom: u(8) } }, 'Agenda & contacts'), flow(ctx, side, Object.assign({}, k, { u: ctx.u * .9 }), sk2)) : null),
          h('div', { key: 'ft', style: { borderTop: '1px solid #E2E2E6', padding: u(8) + ' ' + u(20), fontFamily: f.body, fontSize: u(9.5) } }, ctx.org.contact)
        ]);
      }
    },
    {
      id: 'qr', label: 'Question / réponse', desc: 'Les questions des salariés, des réponses courtes.', formats: ['a5', 'a4'],
      suits: ['droits', 'question', 'faq', 'heures', 'congés', 'fiche'],
      uniiHint: 'Fiche « vos droits » : 3 à 5 questions telles que les salariés les posent (intertitres), réponse de 2 phrases maximum chacune, référence juridique en encadré.',
      palettes: [{ id: 'rouge', label: 'Rouge', colors: { a: '#E3051B', b: '#FFF1F2', c: '#17181C', d: '#FFFFFF' } }, { id: 'violet', label: 'Violet', colors: { a: '#7B2CBF', b: '#F3EAFB', c: '#1B1027', d: '#FFFFFF' } }, { id: 'nuit', label: 'Nuit', colors: { a: '#FFD23F', b: '#2A2A2E', c: '#FFFFFF', d: '#18181B' } }, { id: 'vert', label: 'Vert', colors: { a: '#0E7A55', b: '#E8F5EF', c: '#0F241C', d: '#FFFFFF' } }],
      fonts: [{ id: 'dm', label: 'DM Serif + Franklin', head: F('DM Serif Display', 'serif'), body: F('Libre Franklin') }, { id: 'space', label: 'Space Grotesk', head: F('Space Grotesk'), body: F('Space Grotesk') }, { id: 'anton', label: 'Anton + Archivo', head: F('Anton'), body: F('Archivo') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), k = kit(ctx), afterQ = false;
        var Q = function (b, i) { afterQ = true; return h('div', { key: b.id || i, style: { fontFamily: f.body, fontWeight: 800, fontSize: u(13), lineHeight: 1.25, margin: u(8) + ' 0 ' + u(5) } }, h('span', { style: { color: c.a } }, 'Q. '), b.text); };
        var skin = { h2: Q, h3: Q,
          h1: function (b, i) { return h('div', { key: b.id || i, style: { position: 'relative', fontFamily: f.head, fontSize: u(fit(b.text, 32, 20, 160)), lineHeight: 1.05, maxWidth: '72%', margin: '0 0 ' + u(10) } }, b.text); },
          p: function (b, i) { var a = afterQ; afterQ = false; return h('div', { key: b.id || i, style: { background: a ? c.b : 'transparent', padding: a ? u(8) + ' ' + u(11) : 0, borderRadius: u(10), fontFamily: f.body, fontSize: u(11), lineHeight: 1.45, margin: '0 0 ' + u(6) } }, b.text); } };
        return frame(ctx, { background: c.d, color: c.c, padding: u(28), display: 'flex', flexDirection: 'column' }, [
          h('div', { key: 'q', 'data-pdf-decoration': true, style: { position: 'absolute', right: u(-14), top: u(-40), fontFamily: f.head, fontSize: u(260), lineHeight: 1, color: c.a, opacity: .9 } }, '?'),
          h('div', { key: 'f', style: { position: 'relative', flex: '1 1 auto', minHeight: 0, overflow: 'hidden' } }, flow(ctx, ctx.blocks, k, skin)),
          h('div', { key: 'ft', style: { fontFamily: f.body, fontSize: u(10), lineHeight: 1.4, marginTop: u(6) } }, h('strong', null, 'Une autre question ? '), ctx.org.contact)
        ]);
      }
    },
    {
      id: 'satirique', label: 'Journal satirique', desc: 'Titre gothique, dessin de presse avec bulles, encadré « FO exige ».', formats: ['a4', 'wide'], review: 'satire',
      slots: [{ id: 'img0', label: 'Dessin de presse', type: 'studio.photo', index: 0 }, { id: 'img1', label: 'Mascotte du journal', type: 'studio.photo', index: 1, optional: true }],
      suits: ['ia', 'intelligence artificielle', 'réorganisation', 'robot', 'humour', 'satire', 'numéro spécial'],
      notice: 'Format satirique : on caricature une décision, jamais une personne. Aucun nom, aucun visage reconnaissable — unii le vérifie avant diffusion.',
      uniiHint: 'Journal satirique : un titre de journal (badge), un titre-question ironique, un chapeau qui oppose la direction et FO, 2 répliques de bulles (personnages génériques : « La direction », « Le délégué FO »), 2 brèves avec intertitre, un encadré « FO exige » de 3 lignes. Humour sans attaque personnelle, faits exacts.',
      palettes: [{ id: 'papier', label: 'Papier journal', colors: { a: '#C8102E', b: '#151515', c: '#151515', d: '#F1E6CF' } }, { id: 'bleu', label: 'Encre bleue', colors: { a: '#1F3D8A', b: '#151515', c: '#151515', d: '#EFEADF' } }, { id: 'noir', label: 'Noir', colors: { a: '#111111', b: '#151515', c: '#151515', d: '#F4F1EA' } }],
      fonts: [{ id: 'gothic', label: 'Gothique + Oswald', head: F('Oswald'), body: F('Source Serif 4', 'serif'), hand: F('UnifrakturMaguntia', 'serif') }, { id: 'playfair', label: 'Playfair + Oswald', head: F('Oswald'), body: F('Source Serif 4', 'serif'), hand: F('Playfair Display', 'serif') }],
      render: function (ctx) {
        if (ctx.format.id === 'wide') ctx = Object.assign({}, ctx, { u: ctx.format.h / 420, landscapeKind: 'satirique' });
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), used = [];
        var take = function (t) { var b = ctx.first(t); if (b) used.push(b); return b; };
        var tag = take('tag'), h1 = take('h1'), deck = take('p'), img = take('studio.photo'), bub = take('studio.bulles'), ex = take('studio.exige'), ul = ex ? null : take('ul');
        var mas = ctx.all('studio.photo')[1]; if (mas) used.push(mas);
        var rest = except(ctx, used), k = kit(ctx, { ink: c.c, paper: c.d });
        var src = srcOf(img);
        var bl = bub ? lines(bub.text).map(function (l) { var m = l.match(/^([^:]{1,30})\s:\s?(.*)$/); return m ? m[2] : l; }) : [];
        var hw = String(h1 ? h1.text : '').split(':'), red = hw.length > 1 ? hw[0] + ' :' : '', black = hw.length > 1 ? hw.slice(1).join(':') : hw[0];
        var exBox = function (L) { return h('div', { style: { border: u(2.5) + ' solid ' + c.a, background: '#FFFFFF', alignSelf: 'start' } }, h('div', { style: { background: c.a, color: onC(c.a), fontFamily: f.head, fontWeight: 700, fontSize: u(22), textAlign: 'center', textTransform: 'uppercase', padding: u(2) + ' 0' } }, L[0]), h('div', { style: { padding: u(8), display: 'flex', flexDirection: 'column', gap: u(5), fontFamily: f.head, fontWeight: 700, fontSize: u(10.5), lineHeight: 1.15, color: '#151515' } }, L.slice(1).map(function (l, i) { return h('span', { key: i }, h('span', { style: { color: c.a } }, '• '), l); }))); };
        var exL = ex ? lines(ex.text) : (ul ? ['FO exige !'].concat(lines(ul.text)) : null);
        var skin = { h2: function (b, i) { return h('div', { key: b.id || i, style: { fontFamily: f.head, fontWeight: 700, fontSize: u(13), lineHeight: 1.1, textTransform: 'uppercase', margin: '0 0 ' + u(4) } }, b.text); },
          p: function (b, i) { return h('p', { key: b.id || i, style: { fontFamily: f.body, fontSize: u(8.8), lineHeight: 1.45, textAlign: 'justify', margin: '0 0 ' + u(6) } }, b.text); } };
        return frame(ctx, { background: 'radial-gradient(circle at 18% 70%, rgba(150,110,50,.10), transparent 40%), radial-gradient(circle at 85% 20%, rgba(150,110,50,.08), transparent 35%), ' + c.d, color: c.c, padding: u(18) + ' ' + u(20), display: 'flex', flexDirection: 'column', gap: u(8) }, [
          h('div', { key: 'm', style: { display: 'flex', gap: u(12), alignItems: 'center' } },
            srcOf(ctx.all('studio.photo')[1]) ? h('div', { style: { flex: '0 0 auto', width: u(74), height: u(80), background: 'url("' + srcOf(ctx.all('studio.photo')[1]) + '") center / contain no-repeat' } }) : ctx.org.logo ? logo(ctx, 60) : h('div', { style: { flex: '0 0 auto', width: u(74), height: u(80), borderRadius: u(10), background: ph(), border: '1.5px dashed rgba(0,0,0,.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontFamily: mono, fontSize: u(7.5) } }, 'Mascotte'),
            h('div', { style: { flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: u(1) } },
              h('span', { style: { fontFamily: f.head, fontWeight: 700, fontSize: u(11), textTransform: 'uppercase', color: c.a } }, ctx.org.emetteur),
              h('span', { style: { fontFamily: f.hand, fontSize: u(fit(tag ? tag.text : '', 42, 26, 190)), lineHeight: 1 } }, tag ? tag.text : 'La Gazette de la section'),
              h('span', { style: { alignSelf: 'flex-end', fontFamily: f.head, fontWeight: 500, fontSize: u(8.5) } }, ctx.org.section))),
          h('div', { key: 'r', style: { borderTop: u(3) + ' solid ' + c.c, borderBottom: '1px solid ' + c.c, height: u(5) } }),
          h1 ? h('div', { key: 'h', style: { fontFamily: f.head, fontWeight: 700, fontSize: u(fit(h1.text, 26, 16, 160)), lineHeight: 1.02, textTransform: 'uppercase' } }, red ? h('span', { style: { color: c.a } }, red + ' ') : null, black) : null,
          h('div', { key: 'i', style: { display: 'grid', gridTemplateColumns: '38% 1fr', gap: u(10) } },
            h('div', { style: { fontFamily: f.head, fontWeight: 500, fontSize: u(14), lineHeight: 1.18 } }, deck ? deck.text : ''),
            h('div', { style: { position: 'relative', height: u(ctx.landscapeKind ? 110 : 190), background: src ? 'url("' + src + '") center / cover' : ph(), border: src ? 'none' : '1.5px dashed rgba(0,0,0,.3)' } },
              src ? null : h('span', { style: { position: 'absolute', left: u(8), bottom: u(6), right: u(8), fontFamily: mono, fontSize: u(7.5), lineHeight: 1.35 } }, 'Illustration · ' + (img ? lines(img.text)[0] : 'ajoutez un bloc Photo (dessin de presse)')),
              bl[0] ? h('div', { style: { position: 'absolute', left: u(8), top: u(8), width: '46%', background: '#FFFFFF', border: u(2) + ' solid #151515', borderRadius: u(14), padding: u(5) + ' ' + u(7), fontFamily: F('Comic Neue', 'cursive'), fontWeight: 700, fontSize: u(9), lineHeight: 1.2, textAlign: 'center', color: '#151515' } }, bl[0]) : null,
              bl[1] ? h('div', { style: { position: 'absolute', right: u(8), top: u(70), width: '46%', background: '#FFFFFF', border: u(2) + ' solid #151515', borderRadius: u(14), padding: u(5) + ' ' + u(7), fontFamily: F('Comic Neue', 'cursive'), fontWeight: 700, fontSize: u(9), lineHeight: 1.2, textAlign: 'center', color: '#151515' } }, bl[1]) : null)),
          h('div', { key: 'c', style: { display: 'grid', gridTemplateColumns: exL ? '1fr 1fr 0.95fr' : '1fr 1fr', gap: u(10), borderTop: '1px solid ' + c.c, paddingTop: u(8), flex: '1 1 auto', minHeight: 0, overflow: 'hidden' } },
            h('div', { style: { columnCount: 2, columnGap: u(10), gridColumn: 'span 2', minWidth: 0 } }, flow(ctx, rest, Object.assign({}, k, { u: ctx.u * .9 }), skin)),
            exL ? exBox(exL) : null)
        ]);
      }
    },
    {
      id: 'bd', label: 'Bande dessinée', desc: 'Cases, récitatifs, bulles, chute en dernière case.', formats: ['a5', 'a4', 'wide'], review: 'satire',
      slots: [{ id: 'img0', label: 'Case 1', type: 'studio.photo', index: 0 }, { id: 'img1', label: 'Case 2', type: 'studio.photo', index: 1 }, { id: 'img2', label: 'Case 3', type: 'studio.photo', index: 2 }],
      suits: ['humour', 'bd', 'histoire', 'nao', 'réunion'],
      notice: 'Personnages génériques uniquement (« la direction », « un collègue »). Aucun nom réel.',
      uniiHint: 'Bande dessinée en 4 cases : un titre (badge), 3 répliques « Personnage : texte » dans un bloc Bulles, une chute en citation (appel à l\'action avec date).',
      palettes: [{ id: 'jaune', label: 'Jaune et rouge', colors: { a: '#E3051B', b: '#FFD23F', c: '#111111', d: '#FFFFFF' } }, { id: 'bleu', label: 'Bleu et jaune', colors: { a: '#2433A8', b: '#FFD23F', c: '#111111', d: '#FFFFFF' } }, { id: 'vert', label: 'Vert et rose', colors: { a: '#0E7A55', b: '#FFB5C5', c: '#111111', d: '#FFFFFF' } }],
      fonts: [{ id: 'bangers', label: 'Bangers + Comic', head: F('Bangers', 'cursive'), body: F('Comic Neue', 'cursive') }, { id: 'marker', label: 'Feutre', head: F('Permanent Marker', 'cursive'), body: F('Comic Neue', 'cursive') }],
      render: function (ctx) {
        if (ctx.format.id === 'wide') ctx = Object.assign({}, ctx, { u: ctx.format.h / 420, landscapeKind: 'bd' });
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx);
        var title = ctx.first('tag') || ctx.first('h1'), bub = ctx.first('studio.bulles'), q = ctx.first('quote'), pics = ctx.all('studio.photo');
        var reps = bub ? lines(bub.text) : ctx.all('p').map(function (b) { return b.text; });
        reps = reps.slice(0, 3);
        while (reps.length < 3) reps.push('');
        var panel = function (txt, i) {
          var m = txt.match(/^([^:]{1,30})\s:\s?(.*)$/);
          var sp = srcOf(pics[i]);
          return h('div', { key: i, style: { position: 'relative', border: u(3) + ' solid ' + c.c, background: sp ? 'url("' + sp + '") center / cover' : ph() } },
            m ? h('span', { style: { position: 'absolute', top: 0, left: 0, background: c.b, borderRight: u(2) + ' solid ' + c.c, borderBottom: u(2) + ' solid ' + c.c, fontFamily: f.body, fontWeight: 700, fontSize: u(9.5), padding: u(3) + ' ' + u(6) } }, m[1]) : null,
            txt ? h('div', { style: { position: 'absolute', left: u(9), right: u(9), bottom: u(10), background: '#FFFFFF', border: u(2) + ' solid ' + c.c, borderRadius: u(16), padding: u(7) + ' ' + u(9), fontFamily: f.body, fontWeight: 700, fontSize: u(11), lineHeight: 1.2, textAlign: 'center' } }, m ? m[2] : txt) : null);
        };
        return frame(ctx, { background: c.d, color: c.c, padding: u(14), display: 'flex', flexDirection: 'column', gap: u(9) }, [
          h('div', { key: 't', style: { background: c.b, border: u(3) + ' solid ' + c.c, padding: u(5) + ' ' + u(12), fontFamily: f.head, fontSize: u(fit(title ? title.text : '', 34, 20, 140)), letterSpacing: '.03em', lineHeight: 1, transform: 'rotate(-1.5deg)' } }, title ? title.text : 'Les aventures de la section'),
          h('div', { key: 'g', style: { flex: '1 1 auto', display: 'grid', gridTemplateColumns: ctx.landscapeKind ? 'repeat(4,minmax(0,1fr))' : '1fr 1fr', gridTemplateRows: ctx.landscapeKind ? 'minmax(0,1fr)' : '1fr 1fr', minHeight: ctx.landscapeKind ? 0 : undefined, gap: u(8) } },
            reps.map(panel),
            h('div', { key: 'z', style: { border: u(3) + ' solid ' + c.c, background: c.a, color: onC(c.a), display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', gap: u(6), padding: u(8), textAlign: 'center' } },
              h('span', { style: { fontFamily: f.head, fontSize: u(30), lineHeight: .95, whiteSpace: 'pre-line' } }, q ? lines(q.text)[0] : 'La suite ? C\'est vous !'),
              q && lines(q.text)[1] ? h('span', { style: { fontFamily: f.body, fontWeight: 700, fontSize: u(11) } }, lines(q.text).slice(1).join(' · ')) : null)),
          h('div', { key: 'f', style: { fontFamily: f.body, fontWeight: 700, fontSize: u(9.5) } }, ctx.org.emetteur)
        ]);
      }
    },
    {
      id: 'annonce', label: 'Petite annonce parodique', desc: 'Détournement d\'un format connu, puis retournement.', formats: ['a5', 'a4'], review: 'satire',
      suits: ['humour', 'salaire', 'conditions', 'recrutement', 'charge de travail'],
      notice: 'Le détournement vise une situation, jamais une personne.',
      uniiHint: 'Petite annonce parodique : titre d\'annonce (titre principal), texte d\'annonce absurde (premier paragraphe), tampon (badge), retournement en intertitre, message réel et date en paragraphe.',
      palettes: [{ id: 'gris', label: 'Papier gris', colors: { a: '#E3051B', b: '#FFFFFF', c: '#1A1A1A', d: '#EDEBE6' } }, { id: 'jaune', label: 'Papier jauni', colors: { a: '#1F3D8A', b: '#FFFDF4', c: '#1A1A1A', d: '#F3E9C9' } }],
      fonts: [{ id: 'elite', label: 'Machine à écrire', head: F('Oswald'), body: F('Special Elite', 'monospace') }, { id: 'plex', label: 'Plex', head: F('Oswald'), body: F('IBM Plex Sans') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx), used = [];
        var take = function (t) { var b = ctx.first(t); if (b) used.push(b); return b; };
        var h1 = take('h1'), ad = take('p'), tag = take('tag'), tw = take('h2');
        var rest = except(ctx, used), k = kit(ctx, { body: F('Archivo') });
        return frame(ctx, { background: c.d, color: c.c, padding: u(22), display: 'flex', flexDirection: 'column', gap: u(12) }, [
          h('div', { key: 'r', style: { display: 'flex', justifyContent: 'space-between', borderBottom: u(2) + ' solid ' + c.c, paddingBottom: u(5), fontFamily: f.body, fontSize: u(10), textTransform: 'uppercase' } }, h('span', null, 'Petites annonces'), h('span', null, 'Rubrique emploi')),
          h('div', { key: 'a', style: { border: u(2) + ' solid ' + c.c, background: c.b, padding: u(14), display: 'flex', flexDirection: 'column', gap: u(9), transform: 'rotate(-1deg)' } },
            h('span', { style: { fontFamily: f.head, fontWeight: 700, fontSize: u(fit(h1 ? h1.text : '', 26, 16, 120)), textTransform: 'uppercase', lineHeight: 1 } }, h1 ? h1.text : ''),
            h('span', { style: { fontFamily: f.body, fontSize: u(12), lineHeight: 1.5 } }, ad ? ad.text : '')),
          tag ? h('div', { key: 's', style: { alignSelf: 'center', border: u(4) + ' solid ' + c.a, color: c.a, fontFamily: f.head, fontWeight: 700, fontSize: u(fit(tag.text, 32, 18, 110)), textTransform: 'uppercase', padding: u(2) + ' ' + u(14), transform: 'rotate(-8deg)', marginTop: u(6) } }, tag.text) : null,
          h('div', { key: 'b', style: { marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: u(6) } },
            tw ? h('span', { style: { fontFamily: f.head, fontWeight: 700, fontSize: u(fit(tw.text, 30, 18, 140)), lineHeight: 1.02, textTransform: 'uppercase', whiteSpace: 'pre-line' } }, tw.text) : null,
            flow(ctx, rest, k),
            h('span', { style: { fontFamily: F('Archivo'), fontWeight: 800, fontSize: u(11), textTransform: 'uppercase' } }, ctx.org.emetteur))
        ]);
      }
    },
    {
      id: 'retro', label: 'Affiche rétro', desc: 'Rayons, diagonales, deux couleurs et fond crème.', formats: ['a5', 'a4'],
      slots: [{ id: 'img0', label: 'Silhouette ou photo détourée', type: 'studio.photo', index: 0 }],
      suits: ['adhésion', 'adhérer', 'anniversaire', '1er mai', 'ensemble', 'rejoindre'],
      uniiHint: 'Affiche rétro : un mot d\'ordre de 2 à 4 mots (le dernier mot mis en couleur), un appel à l\'action court en badge, une ligne pratique en citation.',
      palettes: [{ id: 'rn', label: 'Rouge et noir', colors: { a: '#D7261E', b: '#141414', c: '#141414', d: '#EFE4CC' } }, { id: 'ob', label: 'Or et bleu', colors: { a: '#E8A317', b: '#1D2B5A', c: '#1D2B5A', d: '#F1E8D2' } }, { id: 'vn', label: 'Vert et noir', colors: { a: '#2E7D5B', b: '#1A1A1A', c: '#1A1A1A', d: '#EEE6D3' } }],
      fonts: [{ id: 'oswald', label: 'Oswald', head: F('Oswald'), body: F('Archivo') }, { id: 'bebas', label: 'Bebas', head: F('Bebas Neue'), body: F('Barlow') }],
      render: function (ctx) {
        var h = ctx.h, c = ctx.colors, f = ctx.fonts, u = P(ctx);
        var h1 = ctx.first('h1'), tag = ctx.first('tag'), q = ctx.first('quote'), img = ctx.first('studio.photo');
        var w = String(h1 ? h1.text : '').trim().split(/\s+/), last = w.length > 1 ? w.pop() : '', first = w.join(' ');
        var src = srcOf(img);
        return frame(ctx, { background: c.d }, [
          h('div', { key: 'ray', style: { position: 'absolute', left: '-28%', top: '20%', width: '156%', aspectRatio: '1', borderRadius: '50%', background: 'repeating-conic-gradient(' + c.a + ' 0 6deg, transparent 6deg 14deg)', opacity: .9 } }),
          h('div', { key: 'bot', style: { position: 'absolute', left: 0, right: 0, bottom: 0, height: '32%', background: c.b, clipPath: 'polygon(0 35%, 100% 0, 100% 100%, 0 100%)' } }),
          h('div', { key: 'sil', style: { position: 'absolute', left: '29%', top: '29%', width: '42%', height: '49%', borderRadius: u(90) + ' ' + u(90) + ' ' + u(10) + ' ' + u(10), background: src ? 'url("' + src + '") center / cover' : 'rgba(255,255,255,.55)', border: src ? 'none' : '1.5px dashed rgba(0,0,0,.35)', display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontFamily: mono, fontSize: u(9), padding: u(10), boxSizing: 'border-box' } }, src ? null : 'Silhouette ou photo détourée (bloc Photo)'),
          h('div', { key: 't', style: { position: 'absolute', left: u(22), top: u(60), right: u(22), fontFamily: f.head, fontWeight: 700, fontSize: u(fit(h1 ? h1.text : '', 74, 36, 260)), lineHeight: .9, textTransform: 'uppercase', color: c.b, transform: 'rotate(-6deg)', transformOrigin: 'left top' } }, first, first ? h('br') : null, h('span', { style: { color: c.a } }, last)),
          h('div', { key: 'b', style: { position: 'absolute', left: u(22), right: u(22), bottom: u(20), color: c.d, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', gap: u(10) } },
            h('span', { style: { fontFamily: f.head, fontWeight: 700, fontSize: u(22), lineHeight: 1, textTransform: 'uppercase' } }, tag ? tag.text : ''),
            h('span', { style: { fontFamily: f.body, fontSize: u(10.5), textAlign: 'right', lineHeight: 1.35, whiteSpace: 'pre-line' } }, (q ? q.text + '\n' : '') + ctx.org.emetteur))
        ]);
      }
    }
  ];

  // Preserve each composition; use the available page height for its typographic scale.
  // The three dedicated landscape compositions retain their existing layout.
  DOC_STYLES.forEach(function (style) {
    var render = style.render;
    style.render = function (ctx) {
      if (ctx.format.id === 'wide' && ['choc','satirique','bd'].indexOf(style.id) < 0)
        ctx = Object.assign({}, ctx, {u: Math.min(ctx.u,ctx.format.h / 620)});
      return render(ctx);
    };
  });

  /* ---------- thèmes de pages web ---------- */
  function themeCss(id, o) {
    return function (ctx) {
      var c = ctx.colors, S = '.up-site[data-theme="' + id + '"]';
      return S + '{--up-accent:' + c.a + ';--up-head:' + (o.head ? o.head(c) : c.c) + ';--up-tint:' + (o.tint ? o.tint(c) : c.b) + ';--up-tint2:' + c.b + ';--up-r:' + o.r + 'px;background:' + c.d + ';color:' + c.c + ';font-family:' + o.body + '}'
        + S + ' h1,' + S + ' h2,' + S + ' h3,' + S + ' .up-brand strong{font-family:' + o.title + '}'
        + S + ' .up-hero h1,' + S + ' .up-article h2{font-family:' + o.title + ';color:inherit}'
        + (o.extra ? o.extra(S, c) : '');
    };
  }
  var PAGE_THEMES = [
    { id: 'editorial', label: 'Éditorial', desc: 'Typographie de presse, crème, filets fins.',
      palettes: [{ id: 'r', label: 'Rouge', colors: { a: '#C8102E', b: '#EFE8DA', c: '#1B1A17', d: '#FAF7F0' } }, { id: 'b', label: 'Bleu', colors: { a: '#1F4E9C', b: '#E3E8EF', c: '#111827', d: '#FFFFFF' } }, { id: 'v', label: 'Vert', colors: { a: '#2F5D50', b: '#E6EDE6', c: '#14211C', d: '#F8FAF7' } }],
      css: themeCss('editorial', { r: 2, title: F('Newsreader', 'serif'), body: F('Libre Franklin'), extra: function (S, c) { return S + ' .up-hero{background:' + c.d + ';border-bottom:1px solid ' + c.c + '}' + S + ' .up-hero h1{font-size:44px;font-weight:600;line-height:1.05}' + S + ' .up-kicker{background:none;color:' + c.a + ';padding:0;letter-spacing:.16em}' + S + ' .up-article,' + S + ' .up-card{background:transparent;border:0;border-top:1px solid ' + c.c + ';border-radius:0}' + S + ' .up-head,' + S + ' .up-nav{background:' + c.d + '}'; } }) },
    { id: 'cartes', label: 'Moderne à cartes', desc: 'Fond gris clair, cartes arrondies, boutons pilules.',
      palettes: [{ id: 'r', label: 'Rouge', colors: { a: '#E3051B', b: '#FDE8EA', c: '#14161B', d: '#F1F2F5' } }, { id: 'v', label: 'Violet', colors: { a: '#5B4BFF', b: '#ECEAFF', c: '#15132B', d: '#F3F2FA' } }, { id: 'g', label: 'Vert', colors: { a: '#0FA37F', b: '#E2F5EF', c: '#0F241C', d: '#EEF4F1' } }],
      css: themeCss('cartes', { r: 24, title: F('Space Grotesk'), body: F('Space Grotesk'), extra: function (S, c) { return S + ' .up-hero{background:transparent;border:0}' + S + ' .up-hero .up-wrap{background:#FFFFFF;border-radius:24px;margin-top:18px;padding:30px}' + S + ' .up-hero h1{font-size:40px;font-weight:700;letter-spacing:-.02em}' + S + ' .up-article,' + S + ' .up-card{border:0;box-shadow:0 1px 2px rgba(0,0,0,.04)}' + S + ' .up-head{background:transparent;border:0}' + S + ' .up-nav{background:transparent;border:0}' + S + ' .up-nav ul{background:#FFFFFF;border-radius:99px;padding:4px}' + S + ' .up-nav a{border-radius:99px;border-bottom:0}' + S + ' .up-nav a[aria-current=page]{background:' + c.a + ';color:' + (lum(c.a) > .45 ? '#111' : '#fff') + '}'; } }) },
    { id: 'militant', label: 'Militant', desc: 'Bandeau plein de couleur, titres condensés en capitales.',
      palettes: [{ id: 'r', label: 'Rouge et jaune', colors: { a: '#E3051B', b: '#FFE14D', c: '#14141A', d: '#FFFFFF' } }, { id: 'n', label: 'Noir et rouge', colors: { a: '#151515', b: '#FF3B2F', c: '#151515', d: '#F4F1EA' } }, { id: 'b', label: 'Bleu et jaune', colors: { a: '#2433A8', b: '#FFD23F', c: '#101433', d: '#FFFFFF' } }],
      css: themeCss('militant', { r: 0, title: F('Anton'), body: F('Archivo'), tint: function (c) { return c.b; }, extra: function (S, c) { var on = lum(c.a) > .45 ? '#111' : '#fff'; return S + ' .up-hero{background:' + c.a + ';color:' + on + ';border:0}' + S + ' .up-hero h1{color:' + on + ';font-size:58px;line-height:.95;text-transform:uppercase;font-weight:400}' + S + ' .up-chapo,' + S + ' .up-byline{color:' + on + ';opacity:.92}' + S + ' .up-kicker{background:' + c.b + ';color:#111;border-radius:0}' + S + ' .up-cta{background:' + c.b + ';color:#111;border-radius:0;text-transform:uppercase;font-weight:800}' + S + ' .up-article h2{text-transform:uppercase;font-weight:400;font-size:26px}' + S + ' .up-callout{border-left:0;border-radius:0;background:' + c.b + ';color:#111}' + S + ' .up-callout strong{color:#111}'; } }) },
    { id: 'institutionnel', label: 'Institutionnel', desc: 'Sobre, marine, structuré, très lisible.',
      palettes: [{ id: 'm', label: 'Marine', colors: { a: '#1E3A6E', b: '#E8EEF7', c: '#141A26', d: '#FFFFFF' } }, { id: 'r', label: 'Rouge', colors: { a: '#C8102E', b: '#FBECEE', c: '#1C1E24', d: '#FFFFFF' } }, { id: 'o', label: 'Olive', colors: { a: '#3F4A3C', b: '#EEF0EA', c: '#1D211B', d: '#FFFFFF' } }],
      css: themeCss('institutionnel', { r: 4, title: F('IBM Plex Sans'), body: F('IBM Plex Sans'), extra: function (S, c) { return S + ' .up-hero{background:#F3F5F8}' + S + ' .up-hero h1{font-weight:600;font-size:32px}' + S + ' .up-kicker{border-radius:2px}' + S + ' .up-cta{border-radius:2px}'; } }) },
    { id: 'magazine', label: 'Magazine', desc: 'Fond sombre, titres en grand, accent vif.',
      palettes: [{ id: 'r', label: 'Rouge', colors: { a: '#FF3B2F', b: '#1F2026', c: '#F4F4F6', d: '#111216' } }, { id: 'j', label: 'Jaune', colors: { a: '#FFD23F', b: '#22201A', c: '#F6F2E8', d: '#14120D' } }, { id: 'c', label: 'Cyan', colors: { a: '#4CC9F0', b: '#16213A', c: '#EEF3FF', d: '#0B1222' } }],
      css: themeCss('magazine', { r: 0, title: F('Bebas Neue'), body: F('Barlow'), head: function (c) { return c.b; }, tint: function (c) { return c.b; }, extra: function (S, c) { return S + ' .up-head,' + S + ' .up-nav{background:' + c.d + ';border-color:' + c.b + '}' + S + ' .up-nav a,' + S + ' .up-brand span,' + S + ' .up-crumb,' + S + ' .up-crumb a{color:' + c.c + '}' + S + ' .up-hero{background:' + c.b + ';border:0}' + S + ' .up-hero h1{color:' + c.c + ';font-size:62px;line-height:.92;font-weight:400}' + S + ' .up-chapo,' + S + ' .up-byline{color:' + c.c + ';opacity:.8}' + S + ' .up-article,' + S + ' .up-card{background:' + c.b + ';border-color:' + c.b + ';color:' + c.c + '}' + S + ' .up-article h2{color:' + c.c + ';font-size:30px;font-weight:400}' + S + ' .up-card p,' + S + ' .up-card h3{color:' + c.c + '}' + S + ' .up-callout{background:rgba(255,255,255,.06);color:' + c.c + '}' + S + ' .up-file{background:rgba(255,255,255,.04);border-color:rgba(255,255,255,.12)}' + S + ' .up-search input{background:' + c.b + ';color:' + c.c + ';border-color:rgba(255,255,255,.2)}' + S + ' .up-cta{color:#111}'; } }) },
    { id: 'minimal', label: 'Minimal', desc: 'Beaucoup de blanc, un seul accent, filets.',
      palettes: [{ id: 'r', label: 'Rouge', colors: { a: '#E3051B', b: '#F2F2F2', c: '#111111', d: '#FFFFFF' } }, { id: 'b', label: 'Bleu', colors: { a: '#2D6BFF', b: '#F2F4F8', c: '#0E1116', d: '#FFFFFF' } }, { id: 'n', label: 'Noir', colors: { a: '#111111', b: '#EFEFEF', c: '#111111', d: '#FFFFFF' } }],
      css: themeCss('minimal', { r: 0, title: F('Archivo'), body: F('Archivo'), extra: function (S, c) { return S + ' .up-hero{background:#fff;border-bottom:1px solid ' + c.b + '}' + S + ' .up-hero h1{font-weight:400;font-size:46px;letter-spacing:-.02em}' + S + ' .up-kicker{background:none;color:' + c.a + ';padding:0}' + S + ' .up-article,' + S + ' .up-card{border:0;border-top:1px solid ' + c.b + ';border-radius:0;padding-left:0;padding-right:0}' + S + ' .up-callout{border-left-width:2px;background:none}'; } }) }
  ];

  /* ---------- sections de pages web ----------
     html(block, x) — x : { esc, lines, cells } ; la chaîne produite doit être du HTML sémantique, sans script. */
  var SEC_CSS = '.up-site .ux-sec{margin:0 0 24px}'
    + '.up-site .ux-band{background:var(--up-accent);color:#fff;border-radius:var(--up-r);padding:26px 28px}.up-site .ux-band h2{color:inherit;margin:0 0 6px!important;font-size:26px}.up-site .ux-band p{margin:0 0 14px;opacity:.92}.up-site .ux-band a{display:inline-block;background:#fff;color:#111;border-radius:99px;padding:10px 18px;font-weight:700;text-decoration:none}'
    + '.up-site .ux-figs{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:14px}.up-site .ux-figs div{border-top:3px solid var(--up-accent);padding-top:8px}.up-site .ux-figs b{display:block;font-size:30px;line-height:1.1;color:var(--up-accent)}.up-site .ux-figs span{font-size:13px}'
    + '.up-site .ux-steps{list-style:none;padding:0!important;margin:0 0 24px}.up-site .ux-steps li{position:relative;padding:0 0 14px 26px!important;margin:0!important}.up-site .ux-steps li::before{content:"";position:absolute;left:4px!important;top:6px!important;width:12px!important;height:12px!important;border-radius:50%;background:#fff!important;border:2px solid var(--up-accent)}.up-site .ux-steps li.ux-done::before{background:var(--up-accent)!important}.up-site .ux-steps li::after{content:"";position:absolute;left:10px;top:20px;bottom:0;width:2px;background:var(--up-tint2)}.up-site .ux-steps li:last-child::after{display:none}'
    + '.up-site .ux-faq details{border-bottom:1px solid rgba(128,128,128,.25);padding:12px 0}.up-site .ux-faq summary{cursor:pointer;font-weight:700}.up-site .ux-faq details p{margin:8px 0 0}'
    + '.up-site .ux-people{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.up-site .ux-people div{border:1px solid rgba(128,128,128,.2);border-radius:var(--up-r);padding:14px}.up-site .ux-people i{display:block;width:48px;height:48px;border-radius:50%;margin-bottom:8px;background:repeating-linear-gradient(135deg,#EEEFF2 0 6px,#F7F7F9 6px 12px)}.up-site .ux-people b{display:block}.up-site .ux-people span{font-size:13px;opacity:.8}'
    + '.up-site .ux-agenda{display:flex;flex-direction:column;gap:10px}.up-site .ux-agenda div{display:flex;gap:14px;align-items:center}.up-site .ux-agenda time{flex:0 0 auto;min-width:64px;text-align:center;background:var(--up-accent);color:#fff;border-radius:12px;padding:8px 6px;font-weight:700;font-size:13px}.up-site .ux-agenda span{font-size:14px}'
    + '.up-site .ux-join{background:var(--up-head);color:#fff;border-radius:var(--up-r);padding:22px 24px;display:flex;flex-wrap:wrap;gap:14px;align-items:center;justify-content:space-between}.up-site .ux-join strong{font-size:20px}.up-site .ux-join a{background:var(--up-accent);color:#fff;border-radius:99px;padding:11px 18px;font-weight:700;text-decoration:none}';
  var PAGE_SECTIONS = [
    { type: 'studio.bandeau', label: 'Bandeau d\'accroche', rows: 3, sample: 'On vous reçoit, sans rendez-vous.\nMardi et jeudi, 12 h – 14 h, local B12.\nPrendre rendez-vous | /intranet/contacts', hint: 'Titre, phrase, puis « libellé du bouton | lien ».',
      html: function (b, x) { var L = x.lines(b.text), btn = x.cells(L[2] || ''); return '  <section class="ux-sec ux-band"><h2>' + x.esc(L[0] || '') + '</h2>' + (L[1] ? '<p>' + x.esc(L[1]) + '</p>' : '') + (btn[0] ? '<a href="' + x.esc(btn[1] || '#') + '">' + x.esc(btn[0]) + '</a>' : '') + '</section>'; } },
    { type: 'studio.chiffres', label: 'Chiffres clés', rows: 3, sample: '68 % | des salariés placent les salaires en priorité\n4,5 % | d\'augmentation demandée\n3 | séances prévues', hint: 'Une ligne par chiffre : valeur | légende.',
      html: function (b, x) { return '  <section class="ux-sec ux-figs" aria-label="Chiffres clés">' + x.lines(b.text).map(function (l) { var c = x.cells(l); return '<div><b>' + x.esc(c[0]) + '</b><span>' + x.esc(c[1] || '') + '</span></div>'; }).join('') + '</section>'; } },
    { type: 'studio.frise', label: 'Frise de la négociation', rows: 4, sample: '2 oct. | Ouverture et calendrier | fait\n16 oct. | La direction propose 0,8 % | fait\n13 nov. | 3e séance', hint: 'Une ligne par étape : date | libellé | « fait ».',
      html: function (b, x) { return '  <ol class="ux-steps">' + x.lines(b.text).map(function (l) { var c = x.cells(l); return '<li' + (/^fait/i.test(c[2] || '') ? ' class="ux-done"' : '') + '><strong>' + x.esc(c[0]) + '</strong> — ' + x.esc(c[1] || '') + '</li>'; }).join('') + '</ol>'; } },
    { type: 'studio.faq', label: 'FAQ dépliable', rows: 4, sample: 'Puis-je venir pendant mon temps de travail ? | Oui, avec l\'accord de votre responsable.\nCe que je dis reste-t-il confidentiel ? | Oui. Rien n\'est transmis sans votre accord.', hint: 'Une ligne par question : question | réponse.',
      html: function (b, x) { return '  <section class="ux-sec ux-faq" aria-label="Questions fréquentes">' + x.lines(b.text).map(function (l) { var c = x.cells(l); return '<details><summary>' + x.esc(c[0]) + '</summary><p>' + x.esc(c.slice(1).join(' | ')) + '</p></details>'; }).join('') + '</section>'; } },
    { type: 'studio.elus', label: 'Cartes des élus', rows: 3, sample: 'Sophie M. | Déléguée syndicale\nLéa T. | Référente SSCT', hint: 'Une ligne par élu : prénom | mandat. Coordonnées professionnelles uniquement.',
      html: function (b, x) { return '  <section class="ux-sec ux-people" aria-label="Vos élus">' + x.lines(b.text).map(function (l) { var c = x.cells(l); return '<div><i aria-hidden="true"></i><b>' + x.esc(c[0]) + '</b><span>' + x.esc(c[1] || '') + '</span></div>'; }).join('') + '</section>'; } },
    { type: 'studio.agenda', label: 'Agenda', rows: 3, sample: '4 nov. | Assemblée du personnel, 12 h 15, réfectoire\n13 nov. | 3e séance de négociation', hint: 'Une ligne par date : date | événement.',
      html: function (b, x) { return '  <section class="ux-sec ux-agenda" aria-label="Agenda">' + x.lines(b.text).map(function (l) { var c = x.cells(l); return '<div><time>' + x.esc(c[0]) + '</time><span>' + x.esc(c[1] || '') + '</span></div>'; }).join('') + '</section>'; } },
    { type: 'studio.adherer', label: 'Appel à adhérer', rows: 2, sample: 'Seul, on subit. Ensemble, on négocie.\nAdhérer | /adherer', hint: 'Phrase d\'appel, puis « libellé | lien ».',
      html: function (b, x) { var L = x.lines(b.text), c = x.cells(L[1] || 'Adhérer | /adherer'); return '  <section class="ux-sec ux-join"><strong>' + x.esc(L[0] || '') + '</strong><a href="' + x.esc(c[1] || '#') + '">' + x.esc(c[0]) + '</a></section>'; } }
  ];
  PAGE_SECTIONS.forEach(function (s) { s.css = SEC_CSS; });

  var manifest = {
    id: 'uniion-studio',
    name: 'uniion Studio',
    version: '1.2.0',
    apiVersion: 1,
    author: 'uniion',
    description: 'Styles graphiques de documents et tracts (dont satire, BD, détournement), blocs visuels, thèmes et sections pour les pages intranet et internet.',
    permissions: ['documents.styles', 'documents.blocks', 'pages.themes', 'pages.sections', 'pages.devices', 'unii.hints'],
    assets: { css: [FONTS] },
    contributes: {
      docStyles: DOC_STYLES,
      docBlocks: DOC_BLOCKS,
      pageThemes: PAGE_THEMES,
      pageSections: PAGE_SECTIONS,
      pageDevices: [{ id: 'desktop', label: 'Ordinateur', width: null }, { id: 'tablet', label: 'Tablette', width: 640 }, { id: 'mobile', label: 'Mobile', width: 360 }]
    }
  };

  var U = window.uniion = window.uniion || {};
  if (typeof U.register === 'function') U.register(manifest);
  else (U.queue = U.queue || []).push(manifest);
})();

// Fidélité au prototype proto-v3.0 : chaque section doit rendre comme le prototype (≤ 0,5 % d'écart).
// Dépendances : npm i -D @playwright/test pngjs pixelmatch @types/pngjs
// Prérequis : prototype servi sur PROTO_URL (ex. npx serve à la racine du projet design), appli sur APP_URL,
// mêmes données d'amorçage. Ajouter ici chaque section portée (spec_uniion_app/fidelite/INVENTAIRE_V3.md).
import { test, expect } from '@playwright/test';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

function ecart(a: Buffer, b: Buffer) {
  const A = PNG.sync.read(a), B = PNG.sync.read(b);
  const w = Math.max(A.width, B.width), h = Math.max(A.height, B.height);
  const pad = (p: PNG) => { const o = new PNG({ width: w, height: h }); PNG.bitblt(p, o, 0, 0, p.width, p.height, 0, 0); return o; };
  const a2 = pad(A), b2 = pad(B), d = new PNG({ width: w, height: h });
  const n = pixelmatch(a2.data, b2.data, d.data, w, h, { threshold: 0.1 });
  return { ratio: n / (w * h), diff: PNG.sync.write(d), memeTaille: A.width === B.width && A.height === B.height };
}

const PROTO = process.env.PROTO_URL ?? 'http://localhost:5050/uniion%20App%20v3.dc.html';
const APP = process.env.APP_URL ?? 'http://localhost:5173';
const TAILLES = [{ w: 1440, h: 900, n: 'bureau' }, { w: 1024, h: 768, n: 'tablette' }, { w: 390, h: 844, n: 'mobile' }];

// [ID inventaire, route prototype] — route application = même nom (à aligner dans le routeur).
const SECTIONS: [string, string][] = [
  ['ACC', 'accueil'],
  ['LEC', 'viewer'],
  ['DOS', 'dossiers'],
  ['DOS-NEW', 'nouveau'],
  ['DOS-DET', 'dossier'],
  ['REP', 'reporting'],
  ['PJ', 'pieces'],
  ['SIG', 'signature'],
  ['IA', 'assistant'],
  ['SON-NEW', 'newpoll'],
  ['SON', 'sondages'],
  ['SON-DET', 'sondage'],
  ['REU', 'reunions'],
  ['REU-DIC', 'record'],
  ['REU-DET', 'reunion'],
  ['DOC', 'documents'],
  ['DOC-EDI', 'docedit'],
  ['DOC-GEN', 'tract'],
  ['RAC', 'raccourcis'],
  ['AGE', 'agenda'],
  ['ADH', 'adherents'],
  ['ADH-IMP', 'adhimport'],
  ['ADH-FIC', 'adherent'],
  ['ADH-MSG', 'adhmsg'],
  ['INT', 'intranet'],
  ['INT-GEN', 'webgen'],
  ['INT-EDI', 'webedit'],
  ['INT-PUB', 'webpub'],
  ['INT-SUI', 'webqueue'],
  ['INT-CHA', 'webcharte'],
  ['NOT', 'notifs'],
  ['RCH', 'recherche'],
  ['UNII-CFG', 'unii'],
  ['EXT', 'extensions'],
  ['PAR', 'params'],
  ['PAR-PRO', 'profil'],
  ['COM', 'communication'],
  ['MOB', 'mobile'],
  ['FOR', 'formations'],
  ['CTC', 'contacts'],
  ['MEM', 'memoire'],
  ['PAR-NOT', 'prefs'],
  ['SEC-IA', 'iasecu'],
  ['PAR-SEC', 'securite'],
  ['PAR-RGPD', 'rgpd'],
  ['PAR-MBR', 'membres'],
  ['PAR-MAR', 'marque'],
  ['PAR-IA', 'apikey'],
  ['OFF', 'offline'],
  ['ONB', 'onboarding'],
  ['ADB', 'admin'],
];

for (const [id, route] of SECTIONS) {
  for (const t of TAILLES) {
    test(`${id} — ${t.n}`, async ({ page }) => {
      await page.setViewportSize({ width: t.w, height: t.h });
      await page.goto(PROTO);
      await page.waitForFunction(() => (window as any).__proto);
      await page.evaluate((r) => (window as any).__proto.setState({ authed: true, route: r }), route);
      await page.waitForTimeout(600);
      const ref = await page.screenshot({ fullPage: true, animations: 'disabled' });
      await page.goto(`${APP}/#/${route}`);
      await page.waitForLoadState('networkidle');
      const app = await page.screenshot({ fullPage: true, animations: 'disabled' });
      const r = ecart(ref, app);
      for (const [n, b] of [['prototype', ref], ['application', app], ['ecart', r.diff]] as const)
        test.info().attachments.push({ name: `${n}-${id}-${t.n}`, body: b, contentType: 'image/png' });
      expect(r.memeTaille, 'hauteur de page différente du prototype').toBe(true);
      expect(r.ratio, `écart ${(r.ratio * 100).toFixed(2)} %`).toBeLessThanOrEqual(0.005);
    });
  }
}

// Garde-fou de build : aucun secret, aucun appel tiers dans le bundle livré.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const INTERDITS = [
  [/service_role/, 'clé service_role'],
  [/sk-ant-|sk-[A-Za-z0-9]{32,}/, "clé d'API de modèle"],
  [/api\.anthropic\.com|api\.mistral\.ai|api\.openai\.com/, 'appel direct à un fournisseur IA'],
  [/fonts\.googleapis\.com|fonts\.gstatic\.com/, 'police Google (IP transmise à un tiers)'],
  [/anthropic-dangerous-direct-browser-access/, 'accès navigateur direct au modèle'],
  [/localStorage\.setItem\(['"]uniion\.(demo|localLlm)/, 'persistance de démonstration'],
];
const fichiers = (d) => readdirSync(d).flatMap((f) => (statSync(join(d, f)).isDirectory() ? fichiers(join(d, f)) : [join(d, f)]));
let echec = false;
let poids = 0;
for (const f of fichiers('dist')) {
  if (!/\.(js|html|css)$/.test(f)) continue;
  const t = readFileSync(f, 'utf8');
  if (f.endsWith('.js')) poids += Buffer.byteLength(t);
  for (const [rx, lib] of INTERDITS) if (rx.test(t)) { console.error(`✗ ${lib} dans ${f}`); echec = true; }
}
const BUDGET = 450 * 1024;  // RECETTE.md §3 — JS initial non compressé, à resserrer par découpage
if (poids > BUDGET) { console.error(`✗ budget JS dépassé : ${(poids / 1024).toFixed(0)} Ko > ${BUDGET / 1024} Ko`); echec = true; }
if (echec) process.exit(1);
console.log(`✓ bundle sain — ${(poids / 1024).toFixed(0)} Ko de JS`);

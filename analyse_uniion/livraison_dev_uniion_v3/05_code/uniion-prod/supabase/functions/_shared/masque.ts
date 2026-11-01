// Masquage de référence, côté serveur. Remplace maskText() du prototype (motifs figés de démo).
// Trois sources : motifs (e-mail, téléphone, NIR, IBAN…), dictionnaire de l'organisation (noms
// des membres et adhérents, établissements, employeur) et heuristique de nom propre résiduel.
// Règle : si un identifiant probable subsiste après masquage, l'envoi est REFUSÉ.
// Limite connue : un nom inconnu écrit entièrement en minuscules n'est pas détectable (jeu de tests §limites).

export type Niveau = 'standard' | 'rh' | 'rps';
export interface Dictionnaire { personnes: { prenom: string; nom: string }[]; lieux: string[]; employeurs: string[] }
export interface Correspondance { jeton: string; clair: string; type: string }
export interface Resultat { masque: string; correspondances: Correspondance[]; residuel: string[] }

const RANG: Record<Niveau, number> = { standard: 0, rh: 1, rps: 2 };
type Motif = { type: string; min: Niveau; rx: RegExp };

// Phase 1, avant le dictionnaire : identifiants structurés (un nom dans une adresse e-mail ne doit
// pas casser la détection de l'adresse).
const STRUCTURES: Motif[] = [
  { type: 'EMAIL', min: 'standard', rx: /[\p{L}\d._%+-]+@[\p{L}\d.-]+\.[a-z]{2,}/giu },
  { type: 'EMAIL', min: 'standard', rx: /[\p{L}\d._%+-]+\s?(?:\[at\]|\(at\)|\sat\s|\sarobase\s)\s?[\p{L}\d-]+(?:\.|\s?\[?(?:dot|point)\]?\s?)[a-z]{2,}\b/giu },
  { type: 'URL', min: 'standard', rx: /\b(?:https?:\/\/|www\.)\S+|\b[\p{L}\d-]+\.(?:com|fr|net|org|eu|io)\/\S+/giu },
  { type: 'IBAN', min: 'standard', rx: /\bFR\d{2}(?:[ ]?[0-9A-Z]{4}){5}[ ]?[0-9A-Z]{3}\b/gi },
  { type: 'NIR', min: 'standard', rx: /\b[12][ .]?\d{2}[ .]?(?:0[1-9]|1[0-2]|[2-9]\d)[ .]?(?:\d{2}|2A|2B)[ .]?\d{3}[ .]?\d{3}(?:[ .]?\d{2})?\b/gi },
  { type: 'TEL', min: 'standard', rx: /(?:(?:\+|\b00)33[ .]?|\b0)[1-9](?:[ .-]?\d{2}){4}\b/g },
  { type: 'IMMAT', min: 'standard', rx: /\b[A-Z]{2}[- ]?\d{3}[- ]?[A-Z]{2}\b/g },
  { type: 'MATRICULE', min: 'standard', rx: /\b(?:matricule|mle|badge|n°\s?salarié)\s*:?\s*[A-Z0-9-]{3,}/giu },
];
// Phase 3, après le dictionnaire.
const MOTIFS: Motif[] = [
  { type: 'ADRESSE', min: 'standard', rx: /\b\d{1,4}(?:\s?(?:bis|ter))?,?\s+(?:rue|avenue|av\.|boulevard|bd|chemin|impasse|allée|place|route|quai)\s+[^\n,.;]{2,40}/giu },
  { type: 'DATE_NAISSANCE', min: 'standard', rx: /\b(?:née?|naissance)\s+(?:le\s+)?\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}/giu },
  { type: 'NUMERO', min: 'standard', rx: /\b\d{5,}\b/g },
  { type: 'DATE', min: 'rps', rx: /\b\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?\b/g },
  { type: 'AGE', min: 'rps', rx: /\b\d{2}\s?ans\b/giu },
  { type: 'SERVICE', min: 'rps', rx: /\b(?:service|atelier|équipe|ligne|poste)\s+(?:de\s+|du\s+|des\s+)?[\p{Lu}][\p{L}-]+/gu },
];

const CIVILITE = /\b(?:M\.?|Mr\.?|Mme\.?|Mlle\.?|Monsieur|Madame|Mademoiselle|Dr\.?|Docteur|Me|Maître|Pr\.?)\s+((?:[\p{Lu}][\p{L}'’-]+\s?){1,3})/gu;
const INITIALE = /\b[\p{Lu}]\.\s?[\p{Lu}][\p{L}'’-]+/gu;

// Mots à majuscule qui ne sont pas des personnes (corpus juridique et syndical).
const ADMIS = new Set(('Code Travail Cour Cassation Conseil Prud Hommes CSE CSSCT SSCT CHSCT CE DS RSS DP URSSAF DREETS ' +
  'Inspection Médecine Médecin Convention Collective Métallurgie Accord Article Loi Décret Ordonnance Direction Comité ' +
  'Social Économique Santé Sécurité Conditions France Paris Lundi Mardi Mercredi Jeudi Vendredi Samedi Dimanche ' +
  'Janvier Février Mars Avril Mai Juin Juillet Août Septembre Octobre Novembre Décembre FO Force Ouvrière CGT CFDT ' +
  'CFE CGC CFTC UNSA Bonjour Merci Cordialement Objet Madame Monsieur RH DRH PDG DG ' +
  'NAO PSE APC GPEC BDESE BDES CDI CDD SMIC IPP RQTH CPAM CARSAT OPCO CPF CSP RCC PV ODJ IRP AT MP ' +
  'Légifrance Conseil État Constitutionnel Défenseur Droits CNIL RGPD Prud’hommes Unii').split(' '));
// Mots qui commencent une phrase sans être des noms.
const DEBUTS = new Set(('Le La Les L Un Une Des Du De D Ce Cet Cette Ces Mon Ma Mes Ton Ta Tes Son Sa Ses Notre Nos Votre Vos Leur Leurs ' +
  'Il Elle Ils Elles On Nous Vous Je J Tu Depuis Suite Selon Pour Par Dans En Au Aux Lors Après Avant Pendant Quel Quelle Quels Quelles ' +
  'Que Qu Qui Quand Comment Pourquoi Combien Est Peut Puis Doit Faut Si Et Mais Ou Donc Or Ni Car Sur Sous Chez Avec Sans Entre Contre ' +
  'Vers Malgré Hier Aujourd Demain Concernant Bonjour Merci Oui Non Voici Voilà Enfin Ensuite Également Toutefois Cependant Rédige ' +
  'Rédiger Écris Écrire Explique Résume Propose Liste Donne Fais Aide Peux Pouvez Faut Ya Y Rappel Attention Important Ordre Point Question').split(' '));

const sansAccent = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
const echapper = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
function distance(a: string, b: string) {  // Levenshtein, bornée à 2
  if (Math.abs(a.length - b.length) > 1) return 2;
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++)
    d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return d[a.length][b.length];
}

export function detecterNiveau(t: string): Niveau {
  const s = sansAccent(t);
  if (/harc|rps|souffrance|moral|burn|suicid|depress|agression|sexis/.test(s)) return 'rps';
  if (/licenci|sanction|disciplin|entretien prealable|rupture|arret maladie|inaptitude|salaire/.test(s)) return 'rh';
  return 'standard';
}

export function masquer(texte: string, niveau: Niveau, dico: Dictionnaire): Resultat {
  let out = texte;
  const corr: Correspondance[] = [];
  const compteur: Record<string, number> = {};
  const jetonPour = (type: string, clair: string) => {
    const deja = corr.find((c) => c.type === type && sansAccent(c.clair) === sansAccent(clair));
    if (deja) return deja.jeton;
    compteur[type] = (compteur[type] || 0) + 1;
    const jeton = `[${type}_${compteur[type]}]`;
    corr.push({ jeton, clair, type });
    return jeton;
  };
  const appliquer = (motifs: Motif[]) => {
    for (const m of motifs) if (RANG[niveau] >= RANG[m.min]) out = out.replace(m.rx, (clair) => jetonPour(m.type, clair));
  };
  const remplacerTerme = (terme: string, type: string) => {
    if (terme.trim().length < 3) return;
    const motif = sansAccent(terme).split('').map((ch) => echapper(ch)).join('');
    // Recherche insensible aux accents : on travaille sur une version normalisée de même longueur.
    const norm = sansAccent(out);
    const rx = new RegExp(`(^|[^\\p{L}\\[])(${motif})(?=$|[^\\p{L}\\]])`, 'gu');
    let m: RegExpExecArray | null;
    const zones: [number, number][] = [];
    while ((m = rx.exec(norm))) zones.push([m.index + m[1].length, m.index + m[1].length + m[2].length]);
    for (const [a, b] of zones.reverse()) out = out.slice(0, a) + jetonPour(type, out.slice(a, b)) + out.slice(b);
  };

  // 1. Identifiants structurés
  appliquer(STRUCTURES);

  // 2. Dictionnaire de l'organisation (noms complets, puis noms, puis prénoms), puis variantes à une faute près
  const personnes = [...dico.personnes].sort((x, y) => (y.prenom + y.nom).length - (x.prenom + x.nom).length);
  for (const p of personnes) { remplacerTerme(`${p.prenom} ${p.nom}`, 'PERSONNE'); remplacerTerme(`${p.nom} ${p.prenom}`, 'PERSONNE'); }
  for (const p of personnes) remplacerTerme(p.nom, 'PERSONNE');
  for (const p of personnes) remplacerTerme(p.prenom, 'PERSONNE');
  const nomsLongs = personnes.map((p) => sansAccent(p.nom)).filter((n) => n.length >= 5);
  if (nomsLongs.length) out = out.replace(/(?<![\p{L}\[])[\p{L}][\p{L}'’-]{4,}(?![\p{L}\]])/gu, (mot) =>
    nomsLongs.some((n) => distance(sansAccent(mot), n) <= 1) ? jetonPour('PERSONNE', mot) : mot);
  if (RANG[niveau] >= RANG.rh) {
    for (const l of dico.lieux) remplacerTerme(l, 'LIEU');
    for (const e of dico.employeurs) remplacerTerme(e, 'EMPLOYEUR');
  }

  // 3. Autres motifs
  appliquer(MOTIFS);

  // 4. Civilité ou initiale suivie d'un nom inconnu : masqué comme personne
  out = out.replace(CIVILITE, (tout, nom: string) => tout.replace(nom.trim(), jetonPour('PERSONNE', nom.trim())));
  out = out.replace(INITIALE, (tout) => jetonPour('PERSONNE', tout));

  // 5. Résiduel, sur le texte sans jetons
  const residuel = new Set<string>();
  const nu = out.replace(/\[[A-Z_]+_\d+\]/g, ' ');
  const mots = [...nu.matchAll(/[\p{L}][\p{L}-]*/gu)].map((m) => {
    const avant = nu.slice(0, m.index).trimEnd();
    return { t: m[0], i: m.index!, fin: m.index! + m[0].length, cap: /^\p{Lu}/u.test(m[0]), debut: !avant || /[.!?:;\n«"(]$/.test(avant) };
  });
  const admis = (t: string) => ADMIS.has(t) || ADMIS.has(t.toUpperCase()) || ADMIS.has(t.charAt(0) + t.slice(1).toLowerCase());
  for (let k = 0; k < mots.length - 1; k++) {  // deux mots à majuscule côte à côte : « Julien Moreau », « MOREAU Julien »
    const a = mots[k]!, b = mots[k + 1]!;
    if (!a.cap || !b.cap || !/^\s+$/.test(nu.slice(a.fin, b.i))) continue;
    if (admis(a.t) || admis(b.t) || (a.debut && DEBUTS.has(a.t)) || a.t.length < 2 || b.t.length < 2) continue;
    residuel.add('NOM_PROBABLE');
  }
  if (RANG[niveau] >= RANG.rps) {  // risques psychosociaux : un prénom seul suffit à identifier
    for (const m of mots) if (m.cap && !m.debut && m.t.length >= 3 && !admis(m.t) && !DEBUTS.has(m.t)) residuel.add('NOM_PROBABLE');
  }
  if (/\b\d{5,}\b/.test(nu)) residuel.add('NUMERO');
  if (/@/.test(nu)) residuel.add('EMAIL');

  return { masque: out, correspondances: corr, residuel: [...residuel] };
}

const META = [/quel (mod[eè]le|llm|ia) es[- ]tu/i, /qui t'a (cr[ée]{2}|con[çc]u|entra[iî]n[ée])/i, /(cl[ée]|key) (d'?api|secr[eè]te)/i,
  /\b(openai|anthropic|claude|mistral|gpt|gemini|llama)\b/i, /prompt syst[eè]me|system prompt|tes instructions/i,
  /o[uù] es[- ]tu h[ée]berg[ée]/i, /quelle version/i, /ignore (les|tes|toutes)/i, /texte (original|non masqu[ée]|en clair)/i];
export const estQuestionMeta = (t: string) => META.some((rx) => rx.test(t));

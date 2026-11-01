// PORTÉ À L'IDENTIQUE depuis « uniion App v3.dc.html » (proto-v3.0). Ne pas modifier à la main :
// régénérer depuis le prototype (spec_uniion_app/fidelite/STRATEGIE.md, étape 3).
export type Marque = typeof DEFAULT_BRAND & { sites: Record<string, Partial<typeof DEFAULT_BRAND>> };

export const FONT_PAIRS = [
  { id: 'philosopher', title: 'Philosopher, Georgia, serif', body: 'Inter, system-ui, sans-serif', label: 'Philosopher / Inter', note: 'Le duo uniion : titres chaleureux, texte neutre.' },
  { id: 'montserrat', title: 'Montserrat, Helvetica, sans-serif', body: 'Inter, system-ui, sans-serif', label: 'Montserrat / Inter', note: 'Militant et affirmé, proche des tracts imprimés.' },
  { id: 'lora', title: 'Lora, Georgia, serif', body: 'Inter, system-ui, sans-serif', label: 'Lora / Inter', note: 'Institutionnel, lisible sur documents longs.' },
  { id: 'inter', title: 'Inter, system-ui, sans-serif', body: 'Inter, system-ui, sans-serif', label: 'Inter seul', note: 'Sobre et discret, idéal pour un thème neutre.' }
] as const;

export const BRAND_PRESETS = [
  { id: 'orange', label: 'Orange uniion', accent: '#F97316', accent2: '#DC2626', desc: 'Identité par défaut du produit.' },
  { id: 'rouge', label: 'Rouge militant', accent: '#E11D48', accent2: '#9F1239', desc: 'Contraste fort, registre revendicatif.' },
  { id: 'bleu', label: 'Bleu institutionnel', accent: '#2563EB', accent2: '#1E3A8A', desc: 'Registre paritaire et administratif.' },
  { id: 'vert', label: 'Vert', accent: '#059669', accent2: '#065F46', desc: 'Santé, sécurité, conditions de travail.' },
  { id: 'prune', label: 'Prune', accent: '#7C3AED', accent2: '#4C1D95', desc: 'Différenciant, peu utilisé en entreprise.' },
  { id: 'ardoise', label: 'Ardoise', accent: '#475569', accent2: '#1E293B', desc: 'Sobre, sans connotation politique.' },
  { id: 'neutre', label: 'Neutre employeur', accent: '#0F766E', accent2: '#134E4A', desc: 'Aucune dominante militante : pour les organisations qui ne veulent afficher aucune couleur syndicale.' }
] as const;

export const DEFAULT_BRAND = {
  preset: 'orange', accent: '#F97316', accent2: '#DC2626',
  mode: 'light', fonts: 'philosopher',
  product: 'uniion',
  logoLight: 'uniion-logo.png', logoDark: '', mono: '', logoIntranet: '', logoPublic: '', initials: 'UN', logoScale: 100,
  logoScales: { logoLight: 100, logoDark: 100, mono: 100, logoIntranet: 100, logoPublic: 100 },
  loginTint: 'accent', favicon: 'mono',
  intranetInherit: true,
  sites: {}
};

export const ICONS: Record<string, string[]> = {
  megaphone: ['m3 11 18-5v12L3 14v-3z', 'M11.6 16.8a3 3 0 1 1-5.8-1.6'],
  phone: ['M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z', 'M11 18h2'],
  grad: ['M22 10 12 5 2 10l10 5 10-5Z', 'M6 12v5c3 3 9 3 12 0v-5'],
  home: ['m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z', 'M9 22V12h6v10'],
  folder: ['M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z', 'M8 10v6M12 10v4M16 10v6'],
  sparkles: ['m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z'],
  chart: ['M3 3v16a2 2 0 0 0 2 2h16', 'M7 16v-5M12 16V8M17 16v-3'],
  settings: ['M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z', 'M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z'],
  file: ['M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z', 'M14 2v5h6M8 13h8M8 17h6'],
  calendar: ['M8 2v4M16 2v4M3 10h18', 'M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z'],
  bell: ['M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9', 'M10.3 21a1.94 1.94 0 0 0 3.4 0'],
  shield: ['M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z', 'm9 12 2 2 4-4'],
  lock: ['M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z', 'M7 11V7a5 5 0 0 1 10 0v4'],
  users: ['M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2', 'M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75'],
  user: ['M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2', 'M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z'],
  chat: ['M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z', 'M8 9h8M8 13h5'],
  wifioff: ['m2 2 20 20', 'M8.5 16.5a5 5 0 0 1 7 0M5 12.9a10 10 0 0 1 5.2-2.7M19 12.9a10 10 0 0 0-4-2.6M2 8.8a15 15 0 0 1 6-3.4'],
  link: ['M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71', 'M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71'],
  rocket: ['M4.5 16.5c-1.5 1.3-2 5-2 5s3.7-.5 5-2a3 3 0 0 0-3-3Z', 'M12 15l-3-3a22 22 0 0 1 8-10c2 0 4 2 4 4a22 22 0 0 1-10 8Z'],
  gauge: ['M12 21a9 9 0 1 1 0-18 9 9 0 0 1 0 18Z', 'm12 12 4-4'],
  mic: ['M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z', 'M19 10v2a7 7 0 0 1-14 0v-2M12 19v3'],
  card: ['M2 7h20a1 1 0 0 1 1 1v9a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a1 1 0 0 1 1-1Z', 'M1 11h22M6 15h3'],
  funnel: ['M3 4h18l-7 8v7l-4 2v-9Z', 'M3 4h18'],
  mail: ['M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z', 'm2 7 10 7 10-7'],
  euro: ['M18 6a8 8 0 1 0 0 12', 'M3 10h9M3 14h9']
};

export function hexToHsl(hex: string) {
  const h = (hex || '#F97316').replace('#', '');
  const r = parseInt(h.slice(0, 2), 16) / 255, g = parseInt(h.slice(2, 4), 16) / 255, b = parseInt(h.slice(4, 6), 16) / 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
  let s = 0, hh = 0;
  if (mx !== mn) {
    const d = mx - mn;
    s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    hh = mx === r ? ((g - b) / d + (g < b ? 6 : 0)) : (mx === g ? (b - r) / d + 2 : (r - g) / d + 4);
    hh *= 60;
  }
  return { h: hh, s: s * 100, l: l * 100 };
}

export function hsl(h: number, s: number, l: number) {
  return 'hsl(' + Math.round(h) + ' ' + Math.round(Math.max(0, Math.min(100, s))) + '% ' + Math.round(Math.max(0, Math.min(100, l))) + '%)';
}

export function brandTokens(brand: { accent: string; accent2: string; mode: string; fonts: string }): Record<string, string> {
  const a = hexToHsl(brand.accent);
    const dark = brand.mode === 'dark';
    const pair = FONT_PAIRS.find(function (p) { return p.id === brand.fonts; }) || FONT_PAIRS[0];
    const t = {
      '--ac': brand.accent, '--ac2': brand.accent2,
      '--fTitle': pair.title, '--fBody': pair.body,
      '--acShadow': dark ? 'rgba(0,0,0,.6)' : hsl(a.h, a.s, 45),
      '--acH': String(Math.round(a.h)),
      '--acOnDark': hsl(a.h, 90, 74),
      '--shC': dark ? Math.round(a.h) + ' 40% 2%' : Math.round(a.h) + ' 28% 14%'
    };
    if (dark) {
      Object.assign(t, {
        '--acMid': hsl(a.h, Math.min(a.s, 55), 38), '--acTx': hsl(a.h, 90, 66),
        '--acTx2': hsl(a.h, 88, 76), '--acTx3': hsl(a.h, 85, 84), '--acDeep': hsl(a.h, 55, 18),
        '--acBg': hsl(a.h, 42, 12), '--acBg2': hsl(a.h, 42, 9), '--acBd': hsl(a.h, 38, 21), '--acBd2': hsl(a.h, 38, 27),
        '--surface': '#151A22', '--surf2': '#0E1218', '--chip': '#202836', '--track': '#2C3542',
        '--bd': '#222B36', '--bd2': '#2F3846', '--inkSurf': '#080C12', '--ink2Surf': '#1A212B',
        '--ink': '#F3F4F6', '--ink2': '#E5E7EB', '--ink3': '#D6DBE2', '--ink4': '#C0C7D1', '--ink5': '#A7AFBA', '--ink6': '#8B94A0',
        '--ok': '#22C55E', '--okTx': '#4ADE80', '--okTx2': '#86EFAC', '--okBg': '#0F2018', '--okBg2': '#0C1A14',
        '--okBd': '#1E3A2B', '--okBd2': '#235340', '--okChip': '#1B3729', '--okDeep': '#0B2716',
        '--info': '#60A5FA', '--infoTx2': '#93C5FD', '--infoBg': '#101C2E', '--infoBd': '#1E3356', '--info2': '#3B82F6',
        '--pri': '#A78BFA', '--priBg': '#1A1430', '--priBd': '#2E2352',
        '--danger': '#F87171', '--danger2': '#EF4444', '--dangerTx2': '#FCA5A5', '--dangerBg': '#2A1214', '--dangerBd': '#4A1F22', '--dangerBd2': '#3A1A1C',
        '--warnTx': '#FCD34D', '--warnBg': '#2A2010', '--warnBd': '#4A3A14'
      });
    } else {
      Object.assign(t, {
        '--acMid': hsl(a.h, Math.min(a.s, 95), 72), '--acTx': hsl(a.h, Math.min(a.s, 92), 43),
        '--acTx2': hsl(a.h, Math.min(a.s, 92), 35), '--acTx3': hsl(a.h, Math.min(a.s, 88), 28), '--acDeep': hsl(a.h, Math.min(a.s, 88), 27),
        '--acBg': hsl(a.h, 92, 96), '--acBg2': hsl(a.h, 90, 98), '--acBd': hsl(a.h, 90, 90), '--acBd2': hsl(a.h, 90, 84),
        '--surface': '#FFFFFF', '--surf2': '#F9FAFB', '--chip': '#F3F4F6', '--track': '#E5E7EB',
        '--bd': '#F3F4F6', '--bd2': '#E5E7EB', '--inkSurf': '#111827', '--ink2Surf': '#1F2937',
        '--ink': '#111827', '--ink2': '#1F2937', '--ink3': '#374151', '--ink4': '#4B5563', '--ink5': '#6B7280', '--ink6': '#9CA3AF',
        '--ok': '#16A34A', '--okTx': '#15803D', '--okTx2': '#166534', '--okBg': '#F0FDF4', '--okBg2': '#ECFDF5',
        '--okBd': '#DCFCE7', '--okBd2': '#BBF7D0', '--okChip': '#DCFCE7', '--okDeep': '#14532D',
        '--info': '#2563EB', '--infoTx2': '#1D4ED8', '--infoBg': '#EFF6FF', '--infoBd': '#DBEAFE', '--info2': '#3B82F6',
        '--pri': '#7C3AED', '--priBg': '#F5F3FF', '--priBd': '#DDD6FE',
        '--danger': '#DC2626', '--danger2': '#EF4444', '--dangerTx2': '#B91C1C', '--dangerBg': '#FEF2F2', '--dangerBd': '#FCA5A5', '--dangerBd2': '#FEE2E2',
        '--warnTx': '#A16207', '--warnBg': '#FEF3C7', '--warnBd': '#FDE68A'
      });
    }
    return t;
  
}

export function activeBrand(brand: Marque, site?: string) {
  const ov = brand.sites && site && site !== 'Tous les sites' ? brand.sites[site] : null;
  return ov ? Object.assign({}, brand, ov) : brand;
}

export function applyTheme(brand: Marque, site?: string) {
  const b = activeBrand(brand, site);
  const t = brandTokens(b as any);
  const root = document.documentElement;
  Object.keys(t).forEach((k) => root.style.setProperty(k, t[k]));
  root.style.colorScheme = b.mode === 'dark' ? 'dark' : 'light';
}

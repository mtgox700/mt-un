import {FONT_PAIRS,BRAND_PRESETS} from '../../generated/constants.js';
// Migrated without UI changes. State access is restricted to this module.
export function createActions(store,ports){const context={get state(){return store.read()},setState:patch=>store.update(patch),...ports};Object.assign(context,{hexToHsl(hex) {
    const h = (hex || 'var(--ac)').replace('#', '');
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
  },
hsl(h, s, l) { return 'hsl(' + Math.round(h) + ' ' + Math.round(Math.max(0, Math.min(100, s))) + '% ' + Math.round(Math.max(0, Math.min(100, l))) + '%)'; },
brandTokens(brand) {
    const a = this.hexToHsl(brand.accent);
    const dark = brand.mode === 'dark';
    const pair = FONT_PAIRS.find(function (p) { return p.id === brand.fonts; }) || FONT_PAIRS[0];
    const t = {
      '--ac': brand.accent, '--ac2': brand.accent2,
      '--fTitle': pair.title, '--fBody': pair.body,
      '--acShadow': dark ? 'rgba(0,0,0,.6)' : this.hsl(a.h, a.s, 45),
      '--acH': String(Math.round(a.h)),
      '--acOnDark': this.hsl(a.h, 90, 74),
      '--shC': dark ? Math.round(a.h) + ' 40% 2%' : Math.round(a.h) + ' 28% 14%'
    };
    if (dark) {
      Object.assign(t, {
        '--acMid': this.hsl(a.h, Math.min(a.s, 55), 38), '--acTx': this.hsl(a.h, 90, 66),
        '--acTx2': this.hsl(a.h, 88, 76), '--acTx3': this.hsl(a.h, 85, 84), '--acDeep': this.hsl(a.h, 55, 18),
        '--acBg': this.hsl(a.h, 42, 12), '--acBg2': this.hsl(a.h, 42, 9), '--acBd': this.hsl(a.h, 38, 21), '--acBd2': this.hsl(a.h, 38, 27),
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
        '--acMid': this.hsl(a.h, Math.min(a.s, 95), 72), '--acTx': this.hsl(a.h, Math.min(a.s, 92), 43),
        '--acTx2': this.hsl(a.h, Math.min(a.s, 92), 35), '--acTx3': this.hsl(a.h, Math.min(a.s, 88), 28), '--acDeep': this.hsl(a.h, Math.min(a.s, 88), 27),
        '--acBg': this.hsl(a.h, 92, 96), '--acBg2': this.hsl(a.h, 90, 98), '--acBd': this.hsl(a.h, 90, 90), '--acBd2': this.hsl(a.h, 90, 84),
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
  },
applyTheme() {
    if (typeof document === 'undefined') return;
    const t = this.brandTokens(this.activeBrand());
    const root = document.documentElement;
    Object.keys(t).forEach(function (k) { root.style.setProperty(k, t[k]); });
    root.style.colorScheme = this.activeBrand().mode === 'dark' ? 'dark' : 'light';
  },
publishBrand() {
    const d = this.state.brandDraft;
    const preset = (BRAND_PRESETS.find(function (p) { return p.id === d.preset; }) || {}).label || 'personnalisé';
    this.setState((s) => ({
      brand: s.brandDraft, brandPreview: false,
      charte: d.intranetInherit ? Object.assign({}, s.charte, { accent: d.accent2 }) : s.charte,
      webCharte: d.intranetInherit ? { intranet: Object.assign({}, (this.wcStore().intranet || {}), { inherit: true }), public: Object.assign({}, (this.wcStore().public || {}), { inherit: true }) } : s.webCharte,
      brandLog: [{ date: '29/08/2026', who: 'Sophie Marchand', what: 'Identité publiée — ' + preset + ' · mode ' + (d.mode === 'dark' ? 'sombre' : 'clair') }].concat(s.brandLog)
    }));
    this.flash('Identité publiée à l\'organisation — 84 adhérents concernés');
  }});return Object.freeze(Object.fromEntries(["hexToHsl","hsl","brandTokens","applyTheme","publishBrand"].map(name=>[name,context[name].bind(context)])));}

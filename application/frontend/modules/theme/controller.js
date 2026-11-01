import React from 'react';import {FONT_PAIRS,BRAND_PRESETS,DEFAULT_BRAND,ICONS,MARKER_DEFS,REUNION_TYPES,REUNIONS,DOC_FORMATS,DOC_FONTS,BLOCK_DEFS,DOC_MODELS,ADH_CRIT,ADH_STATUTS,ADHERENTS,ADH_CSV_COLS,ADH_CSV_MODEL,ADH_GROUPES,ADH_MSG_MODELS,ELUS,DOSSIERS,PIECES,POLLS,CONVOS,CONTACTS,CONVO_META,CT_CATS,AV_BG,WHO_FG,MOB_ST,MOB_ST_C,MOB_KIND,MOB_AUD,MOB_TPL,MOB_SEED,UNII_ROLES,UNII_MODS,UNII_ACTS,COM_ST,COM_ST_C,COM_OBJ,COM_FMT,COM_SEED,COM_MOMENTS,COM_FORMULES,COM_SUPPORTS,FM_IA,FM_PARCOURS,FM_FORMATS,FM_GEN,FM_SUGG,FM_TYPE_C,AI_CORPUS,AI_SYS,DOCS,SIGDOCS,NO_CLICK_UNTIL,STATUS_LABELS,ADH_PER_PAGE,SHORTCUTS,PLANS,FACTURES,ADM_USERS,ADM_ORGS,ADM_KEYS,ADM_LOGS,PLAN_PRIX,PLAN_MIGRATE,planPrix,planNom,STORE_KEY,SEED_MERGE_KEYS,EXT_API,CORE_DOC_TYPES,PLAN_RANK,PERSIST_KEYS} from '../../generated/constants.js';export const methods={activeBrand() {
    const base = this.state.brandPreview ? this.state.brandDraft : this.state.brand;
    const site = this.state.site;
    const ov = base.sites && site && site !== 'Tous les sites' ? base.sites[site] : null;
    return ov ? Object.assign({}, base, ov) : base;
  },
patchBrandDraft(patch) {
    this.setState((s) => {
      const scope = s.brandScope;
      if (scope === 'org') return { brandDraft: Object.assign({}, s.brandDraft, patch) };
      const sites = Object.assign({}, s.brandDraft.sites);
      sites[scope] = Object.assign({}, sites[scope] || {}, patch);
      return { brandDraft: Object.assign({}, s.brandDraft, { sites: sites }) };
    });
  },
brandScopeValue(key) {
    const d = this.state.brandDraft;
    const scope = this.state.brandScope;
    if (scope !== 'org' && d.sites && d.sites[scope] && d.sites[scope][key] !== undefined) return d.sites[scope][key];
    return d[key];
  }};
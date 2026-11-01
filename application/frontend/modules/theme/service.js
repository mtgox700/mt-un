export function createThemeService(store,{selectedSite}){return Object.freeze({
 active(){const s=store.read();const base=s.brandPreview?s.brandDraft:s.brand;const site=selectedSite();const override=base.sites&&site&&site!=='Tous les sites'?base.sites[site]:null;return override?{...base,...override}:base;},
 patchDraft(patch){store.update(s=>s.brandScope==='org'?{brandDraft:{...s.brandDraft,...patch}}:{brandDraft:{...s.brandDraft,sites:{...s.brandDraft.sites,[s.brandScope]:{...(s.brandDraft.sites||{})[s.brandScope],...patch}}}});},
 scopeValue(key){const s=store.read();return s.brandScope!=='org'&&s.brandDraft.sites?.[s.brandScope]?.[key]!==undefined?s.brandDraft.sites[s.brandScope][key]:s.brandDraft[key];}
});}

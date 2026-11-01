import {ADH_STATUTS} from '../../generated/constants.js';export function createMemberFilter(store,ports){const context={get state(){return store.read()},setState:p=>store.update(p),...ports};Object.assign(context,{setAdhF(p) { this.setState((s) => ({ adhF: Object.assign({}, s.adhF, p), adhPage: 0 })); },
adhMatch(a, f) {
    if (f.ent && f.ent !== 'Toutes' && a.ent !== f.ent) return false;
    if (f.etab && f.etab !== 'Tous' && a.etab !== f.etab) return false;
    if (f.sect && f.sect !== 'Toutes' && a.sect !== f.sect) return false;
    if (f.dir && f.dir !== 'Toutes' && a.dir !== f.dir) return false;
    if (f.statut && f.statut !== 'Tous' && a.statut !== f.statut) return false;
    const q = (f.q || '').trim().toLowerCase();
    if (q && (a.prenom + ' ' + a.nom + ' ' + a.email + ' ' + a.poste).toLowerCase().indexOf(q) < 0) return false;
    return true;
  },
adhFiltered() { return this.state.adherents.filter((a) => this.adhMatch(a, this.state.adhF)); },
adhCritLabel(c) {
    const parts = [];
    if (c.ent && c.ent !== 'Toutes') parts.push(c.ent);
    if (c.etab && c.etab !== 'Tous') parts.push(c.etab);
    if (c.sect && c.sect !== 'Toutes') parts.push(c.sect);
    if (c.dir && c.dir !== 'Toutes') parts.push(c.dir);
    if (c.statut && c.statut !== 'Tous' && this.W().showCotis) parts.push('Cotisation : ' + (ADH_STATUTS[c.statut] || {}).label);
    return parts;
  },
curAdherent() { return this.state.adherents.find((x) => x.id === this.state.adherentId) || this.state.adherents[0]; },
toggleAdhSel(id) {
    this.setState((s) => ({ adhSel: s.adhSel.indexOf(id) >= 0 ? s.adhSel.filter((x) => x !== id) : s.adhSel.concat([id]) }));
  }});return Object.freeze(Object.fromEntries(["setAdhF","adhMatch","adhFiltered","adhCritLabel","curAdherent","toggleAdhSel"].map(n=>[n,context[n].bind(context)])));}

// Migrated without UI changes. State access is restricted to this module.
export function createActions(store,ports){const context={get state(){return store.read()},setState:patch=>store.update(patch),...ports};Object.assign(context,{openContactEdit(id) {
    const x = id ? this.contactById(id) : null;
    if (x && x.adhId) { this.setState({ ctEdit: null }); this.go('adherent', { adherentId: x.adhId }); return; }
    this.setState({ ctEdit: x ? { id: x.id, name: x.name, role: x.role, cat: x.cat, tel: x.tel, email: x.email, me: !!x.me } : { id: null, name: '', role: '', cat: 'elu', tel: '', email: '' } });
  },
whoContact(who) {
    const p = String(who || '').replace(/\./g, '').trim().split(/\s+/).filter(Boolean);
    if (!p.length) return null;
    return this.allContacts().find((x) => { const q = x.name.split(/\s+/); return !x.me && q[0] === p[0] && (!p[1] || (q[q.length - 1] || '')[0] === p[1][0]); }) || null;
  }});return Object.freeze(Object.fromEntries(["openContactEdit","whoContact"].map(name=>[name,context[name].bind(context)])));}

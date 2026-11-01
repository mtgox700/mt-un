
// Migrated without UI changes. State access is restricted to this module.
export function createActions(store,ports){const context={get state(){return store.read()},setState:patch=>store.update(patch),...ports};Object.assign(context,{currentDossier() {
    const id = this.state.dossierId;
    return this.state.dossiers.find(function (d) { return d.id === id; }) || this.state.dossiers[0];
  },
addNoteNow() {
    const txt = this.state.noteDraft.trim();
    if (!txt) return;
    const id = this.state.dossierId;
    this.setState((s) => ({
      noteDraft: '',
      dossiers: s.dossiers.map(function (x) {
        return x.id === id ? Object.assign({}, x, { timeline: x.timeline.concat([{ date: "Aujourd'hui", title: 'Note ajoutée', body: txt }]) }) : x;
      })
    }));
    this.flash('Note ajoutée au dossier');
  },
dossierContext(d) {
    if (!d) return '';
    const parts = [d.title || '', d.long || d.desc || ''];
    parts.push('Historique :\n' + (d.timeline || []).map((x) => [x.date, x.title, x.body].filter(Boolean).join(' — ')).join('\n'));
    parts.push('Pièces disponibles (métadonnées ; contenu uniquement si enregistré) :\n' + ((this.state.pieces || {})[d.id] || []).map((x) => [x.name, x.date, x.note, x.content].filter(Boolean).join(' — ')).join('\n'));
    return parts.join('\n\n');
  },
msgToDossier(did) {
    const p = this.state.dosPick; if (!p) return;
    const d = this.state.dossiers.find((x) => x.id === did); if (!d) return;
    this.patchDossier(did, { timeline: d.timeline.concat([{ date: "Aujourd'hui · " + this.nowTime(), title: 'Message versé depuis la messagerie', body: p.who + ' — « ' + p.conv + ' », ' + p.time + ' :\n' + p.text }]) });
    this.setState({ dosPick: null });
    this.flash('Message versé au dossier « ' + d.title + ' »');
  }});return Object.freeze(Object.fromEntries(["currentDossier","addNoteNow","dossierContext","msgToDossier"].map(name=>[name,context[name].bind(context)])));}

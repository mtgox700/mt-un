export function createCasePicker(store,ports){const context={get state(){return store.read()},setState:p=>store.update(p),...ports};Object.assign(context,{dpmVals() {
    const p = this.state.dosPick;
    if (!p) return { open: false, rows: [] };
    const q = String(this.state.dosQ || '').trim().toLowerCase();
    const list = (this.state.dossiers || []).filter((d) => !q || (d.title + ' ' + (d.tag || '')).toLowerCase().indexOf(q) >= 0);
    return {
      open: true, title: 'Envoyer dans un dossier', head: p.who + ' · ' + p.conv, text: p.text, error: p.error || '',
      q: this.state.dosQ || '', onQ: (e) => this.setState({ dosQ: e.target.value }),
      rows: list.map((d) => ({ title: d.title, meta: (d.tag || 'Dossier') + ' · échéance ' + (d.due || '—') + ' · ' + (d.owner || ''), go: () => this.msgToDossier(d.id) })),
      noRows: !list.length,
      create: () => this.msgToNewDossier(p), close: () => this.setState({ dosPick: null })
    };
  }});return Object.freeze({dpmVals:context.dpmVals.bind(context)});}

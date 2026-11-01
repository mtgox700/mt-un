export function createMessageMenu(store,ports){const context={get state(){return store.read()},setState:p=>store.update(p),...ports};Object.assign(context,{msgActs(c, m) {
    const p = this.msgPayload(c, m);
    const snip = p.text.length > 160 ? p.text.slice(0, 160) + '…' : p.text;
    const close = () => this.setState({ waMenu: null });
    const ct = !m.mine && c.kind === 'group' ? this.whoContact(m.who) : null;
    const A = [{ label: 'Répondre', go: () => this.setState({ waMenu: null, waReply: { who: p.who, text: snip } }) }];
    if (ct) {
      const first = ct.name.split(' ')[0];
      A.push({ label: 'Répondre en privé à ' + first, go: () => { close(); this.openDirect(ct.id); this.setState({ waReply: { who: m.who, text: snip, from: c.name } }); } });
      A.push({ label: 'Écrire à ' + first, go: () => { close(); this.openDirect(ct.id); } });
    }
    A.push({ label: 'Transférer', go: () => this.setState({ waMenu: null, fwdMsg: p, fwdSel: [], fwdQ: '' }) });
    A.push({ label: 'Envoyer dans un dossier', go: () => { close(); this.openCasePicker(p); } });
    A.push({ label: 'Créer un dossier à partir du message', go: () => { close(); this.msgToNewDossier(p); } });
    A.push({ label: 'Copier le texte', go: () => { close(); try { this.copyText(p.text); this.flash('Texte copié'); } catch (e) { this.flash('Copie impossible dans ce navigateur'); } } });
    return A;
  }});return Object.freeze({msgActs:context.msgActs.bind(context)});}

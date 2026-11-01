import {ADH_MSG_MODELS,AV_BG} from '../../generated/constants.js';
export function createCampaigns(store,ports,readConversations,writeConversations){const context={get state(){return {...store.read(),convos:readConversations()}},setState:update=>{const patch=typeof update==='function'?update(context.state):update;const {convos,waInfo,waPane,...own}=patch;if(convos!==undefined)writeConversations({convos,waInfo,waPane});if(Object.keys(own).length)store.update(own)},...ports};Object.assign(context,{setAdhMsg(p) { this.setState((s) => ({ adhMsg: Object.assign({}, s.adhMsg, p) })); },
adhTargets() {
    const m = this.state.adhMsg;
    if (m.cible === 'groupe') {
      const g = this.state.groupes.find((x) => x.id === m.groupeId) || this.state.groupes[0];
      return { list: this.groupMembers(g), label: 'Liste « ' + g.name + ' »' };
    }
    const sel = this.state.adherents.filter((a) => this.state.adhSel.indexOf(a.id) >= 0);
    if (sel.length) return { list: sel, label: 'Sélection manuelle' };
    const f = this.adhFiltered();
    return { list: f, label: 'Adhérents filtrés' };
  },
openAdhMsg(extra) {
    this.setState((s) => ({ adhMsg: Object.assign({}, s.adhMsg, extra || {}) }));
    this.go('adhmsg');
  },
applyAdhModel(id) {
    const m = ADH_MSG_MODELS.find((x) => x.id === id);
    if (!m) return;
    this.setAdhMsg({ modele: id, objet: m.objet, corps: m.corps, joinBulletin: id === 'bienvenue' });
  },
sendAdhCampagne() {
    const m = this.state.adhMsg;
    const tg = this.adhTargets();
    if (!tg.list.length) return this.flash('Aucun destinataire — élargissez les critères ou choisissez une liste');
    if (!m.objet.trim() || !m.corps.trim()) return this.flash('Objet et message sont requis avant l\'envoi');
    const canal = { email: 'E-mail', sms: 'SMS', app: 'Notification app' }[m.canal];
    const n = tg.list.length;
    const msg = { mine: true, subj: m.objet, text: m.corps, time: this.nowTime(), chan: canal, sentTo: n, att: m.joinBulletin ? 'Bulletin d\'adhésion.pdf' : '' };
    const full = this.state.convos.map((c) => this.cvFull(c));
    let cid, nc = null;
    if (n === 1) {
      const a = tg.list[0], ctId = 'adh-' + a.id, nm = ((a.prenom || '') + ' ' + (a.nom || '')).trim();
      const ex = full.find((c) => c.kind === 'direct' && c.contactId === ctId);
      cid = ex ? ex.id : 'dm-' + ctId;
      if (!ex) nc = { id: cid, kind: 'direct', contactId: ctId, name: nm, initials: a.initials || this.initialsOf(nm), avatarBg: AV_BG[this.hashIdx(ctId, AV_BG.length)], memberIds: ['c-me', ctId], admins: [], members: 'Adhérent·e', messages: [], unread: 0 };
    } else {
      const g = m.cible === 'groupe' ? this.state.groupes.find((x) => x.id === m.groupeId) : null;
      cid = g ? 'bc-' + g.id : 'bc-sel-' + tg.list.map((a) => a.id).sort().join('-').slice(0, 48);
      if (!full.find((c) => c.id === cid)) nc = { id: cid, kind: 'broadcast', groupeId: g ? g.id : '', adhIds: tg.list.map((a) => a.id), name: g ? g.name : 'Sélection de ' + n + ' adhérents', initials: g ? this.initialsOf(g.name) : 'DI', avatarBg: 'linear-gradient(135deg, #334155, #0F172A)', memberIds: [], admins: [], members: 'Liste de diffusion', messages: [], unread: 0 };
    }
    this.setState((s) => {
      const base = nc ? [nc].concat(s.convos) : s.convos;
      const x = base.find((c) => c.id === cid);
      const nx = Object.assign({}, x, { messages: x.messages.concat([msg]) }, n > 1 ? { count: n, chan: canal, adhIds: tg.list.map((a) => a.id) } : {});
      return {
        adhSel: [], waInfo: false, waPane: 'chats',
        convos: [nx].concat(base.filter((c) => c.id !== cid)),
        adhLog: [{ date: new Date().toLocaleDateString('fr-FR'), what: m.objet + ' — ' + n + ' adhérent' + (n > 1 ? 's' : ''), who: 'Sophie Marchand', canal: canal }].concat(s.adhLog)
      };
    });
    this.go('thread', { convoId: cid });
    this.flash(canal + ' envoyé à ' + n + ' adhérent' + (n > 1 ? 's' : '') + (m.joinBulletin ? ' · bulletin joint' : '') + ' — l\'envoi est classé dans Messages');
  }});return Object.freeze(Object.fromEntries(["setAdhMsg","adhTargets","openAdhMsg","applyAdhModel","sendAdhCampagne"].map(n=>[n,context[n].bind(context)])));}

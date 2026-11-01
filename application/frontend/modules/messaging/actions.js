import {CONVO_META,AV_BG} from '../../generated/constants.js';
export function createMessagingActions(store,ports){const context={get state(){return store.read()},setState:p=>store.update(p),...ports};Object.assign(context,{cvFull(c) { return Object.assign({ kind: 'direct', memberIds: [], admins: [] }, CONVO_META[c.id] || {}, c); },
lastReal(c) { const ms = (c.messages || []).filter((m) => !m.ai && !m.sys); return ms[ms.length - 1]; },
patchConvo(id, fn) { this.setState((s) => ({ convos: s.convos.map((c) => (c.id === id ? Object.assign({}, c, fn(this.cvFull(c))) : c)) })); },
convoSub(c) {
    if (c.kind === 'group') return c.memberIds.map((id) => (id === 'c-me' ? 'Vous' : ((this.contactById(id) || {}).name || '').split(' ')[0])).filter(Boolean).join(', ');
    if (c.kind === 'broadcast') return 'Liste de diffusion · ' + (c.count || 0) + ' adhérent' + ((c.count || 0) > 1 ? 's' : '') + (c.chan ? ' · ' + c.chan : '');
    const ct = this.contactById(c.contactId);
    return ct ? (ct.cat === 'adherent' ? 'Adhérent·e · ' + ct.role : ct.role) : (c.members || '');
  },
openConvo(id) {
    this.setState((s) => ({ waInfo: false, waMenu: null, waReply: null, thSel: [], thQuote: '', thSelMode: false, convos: s.convos.map((x) => (x.id === id ? Object.assign({}, x, { unread: 0 }) : x)) }));
    if (this.route() === 'thread') this.setState({ convoId: id }); else this.go('thread', { convoId: id });
  },
openDirect(cid) {
    const ct = this.contactById(cid); if (!ct) return;
    if (ct.me) return this.flash('C\'est votre propre fiche');
    const ex = this.state.convos.map((c) => this.cvFull(c)).find((c) => c.kind === 'direct' && c.contactId === cid);
    if (ex) return this.openConvo(ex.id);
    const id = 'dm-' + cid;
    const nc = { id: id, kind: 'direct', contactId: cid, name: ct.name, initials: ct.initials, avatarBg: AV_BG[this.hashIdx(cid, AV_BG.length)], memberIds: ['c-me', cid], admins: [], members: 'Message direct', messages: [], unread: 0 };
    this.setState((s) => ({ convos: [nc].concat(s.convos), waPane: 'chats', waQ: '' }));
    this.openConvo(id);
  },
waDelete(id) {
    this.setState((s) => ({ waInfo: false, convos: s.convos.filter((c) => c.id !== id) }));
    this.go('messagerie'); this.flash('Discussion supprimée de cet appareil');
  },
grToggleAdmin(gid, cid) {
    const nm = (this.contactById(cid) || {}).name || 'Ce membre';
    this.patchConvo(gid, (c) => { const on = c.admins.indexOf(cid) >= 0; return { admins: on ? c.admins.filter((x) => x !== cid) : c.admins.concat([cid]), messages: c.messages.concat([{ sys: true, text: on ? nm + ' n\'est plus administrateur' : nm + ' est désormais administrateur', time: this.nowTime() }]) }; });
  },
grRemove(gid, cid) {
    const nm = (this.contactById(cid) || {}).name || 'un membre';
    this.patchConvo(gid, (c) => { const ids = c.memberIds.filter((x) => x !== cid); return { memberIds: ids, admins: c.admins.filter((x) => x !== cid), members: ids.length + ' membres', messages: c.messages.concat([{ sys: true, text: 'Vous avez retiré ' + nm, time: this.nowTime() }]) }; });
  },
openGroupEdit(id) {
    const raw = id ? this.state.convos.find((x) => x.id === id) : null;
    const c = raw ? this.cvFull(raw) : null;
    this.setState({ grQ: '', grEdit: c ? { id: c.id, name: c.name, desc: c.desc || '', memberIds: c.memberIds.filter((x) => x !== 'c-me') } : { id: null, name: '', desc: '', memberIds: [] } });
  },
saveGroup() {
    const g = this.state.grEdit; if (!g) return;
    const name = String(g.name || '').trim();
    if (!name) return this.flash('Donnez un nom au groupe');
    if (!g.memberIds.length) return this.flash('Ajoutez au moins un membre');
    const t = this.nowTime(), nm = (id) => (this.contactById(id) || {}).name || 'un membre';
    if (!g.id) {
      const id = 'grp-' + Date.now();
      const nc = { id: id, kind: 'group', name: name, initials: this.initialsOf(name), avatarBg: AV_BG[this.hashIdx(id, AV_BG.length)], desc: g.desc, memberIds: ['c-me'].concat(g.memberIds), admins: ['c-me'], members: (g.memberIds.length + 1) + ' membres', unread: 0, messages: [{ sys: true, text: 'Vous avez créé le groupe « ' + name + ' » avec ' + g.memberIds.map(nm).join(', '), time: t }] };
      this.setState((s) => ({ convos: [nc].concat(s.convos), grEdit: null, waPane: 'chats' }));
      this.flash('Groupe « ' + name + ' » créé');
      this.openConvo(id); return;
    }
    this.patchConvo(g.id, (c) => {
      const prev = c.memberIds.filter((x) => x !== 'c-me');
      const add = g.memberIds.filter((x) => prev.indexOf(x) < 0), rem = prev.filter((x) => g.memberIds.indexOf(x) < 0);
      const sys = [];
      if (name !== c.name) sys.push('Vous avez renommé le groupe en « ' + name + ' »');
      if ((g.desc || '') !== (c.desc || '')) sys.push('Vous avez modifié la description');
      if (add.length) sys.push('Vous avez ajouté ' + add.map(nm).join(', '));
      if (rem.length) sys.push('Vous avez retiré ' + rem.map(nm).join(', '));
      const ids = ['c-me'].concat(g.memberIds);
      return Object.assign({ name: name, desc: g.desc, memberIds: ids, admins: c.admins.filter((x) => ids.indexOf(x) >= 0), members: ids.length + ' membres', messages: c.messages.concat(sys.map((x) => ({ sys: true, text: x, time: t }))) }, name !== c.name ? { initials: this.initialsOf(name) } : {});
    });
    this.setState({ grEdit: null }); this.flash('Groupe mis à jour');
  },
curConvo() { return this.state.convos.find((x) => x.id === this.state.convoId) || this.state.convos[0] || {id:"",name:"",messages:[],memberIds:[],admins:[],type:"direct"}; },
threadUniiContext() {
    const c = this.curConvo();
    const msgs = c.messages;
    const who = (m) => (m.mine ? 'Moi' : (m.who || 'Membre')) + ' (' + (m.time || '') + ') : ' + (m.subj ? m.subj + ' — ' : '') + m.text;
    const sel = (this.state.thSel || []).slice().sort((x, y) => x - y).filter((i) => msgs[i] && !msgs[i].ai && !msgs[i].sys);
    const q = String(this.state.thQuote || '').trim();
    const parts = []; const lab = [];
    if (q) { parts.push('Passage surligné : « ' + q + ' »'); lab.push('passage surligné'); }
    if (sel.length) { parts.push(sel.map((i) => who(msgs[i])).join('\n')); lab.push(sel.length + ' message' + (sel.length > 1 ? 's' : '') + ' sélectionné' + (sel.length > 1 ? 's' : '')); }
    if (!parts.length) {
      const last = msgs.filter((m) => !m.ai && !m.sys).slice(-10);
      parts.push(last.map(who).join('\n'));
      lab.push(last.length + ' dernier' + (last.length > 1 ? 's' : '') + ' message' + (last.length > 1 ? 's' : '') + ' du fil');
    }
    return { label: lab.join(' + '), raw: 'Fil « ' + c.name + ' » (' + c.members + ')\n' + parts.join('\n\n') };
  },
uniiPush(msg, conversationId) {
    const id = conversationId || this.curConvo().id;
    this.setState((s) => ({ thBusy: false, thSel: [], thQuote: '', thSelMode: false, convos: s.convos.map((c) => (c.id === id ? Object.assign({}, c, { messages: c.messages.concat([Object.assign({ ai: true, time: "à l'instant" }, msg)]) }) : c)) }));
  },
threadToDossier() {
    const c = this.curConvo();
    const ctx = this.threadUniiContext();
    this.setState({ thSel: [], thQuote: '', thSelMode: false });
    this.buildDossier({
      title: 'Suivi — ' + c.name, desc: 'Dossier ouvert depuis la messagerie (' + ctx.label + ').', long: ctx.raw,
      timeline: [{ date: "Aujourd'hui", title: 'Dossier créé depuis la messagerie', body: 'Fil « ' + c.name + ' » · ' + ctx.label + '.' }, { date: "Aujourd'hui", title: 'Extraits versés au dossier', body: ctx.raw.slice(0, 900) }]
    });
  },
sendMsgNow() {
    const txt = this.state.msgDraft.trim();
    if (!txt) return;
    if (/@unii\b/i.test(txt)) { this.setState({ msgDraft: '' }); this.threadUniiRun(txt); return; }
    const c0 = this.curConvo(); if (!c0) return;
    const id = c0.id, c = this.cvFull(c0), bc = c.kind === 'broadcast';
    const msg = { mine: true, text: txt, time: this.nowTime() };
    if (this.state.waReply) msg.reply = this.state.waReply;
    if (bc) { msg.chan = 'Notification app'; msg.sentTo = c.count || 0; }
    this.setState((s) => {
      const x = s.convos.find((y) => y.id === id);
      const nx = Object.assign({}, x, { messages: x.messages.concat([msg]) });
      return {
        msgDraft: '', waReply: null, convos: [nx].concat(s.convos.filter((y) => y.id !== id))
      };
    });
    if (bc) this.recordBroadcast(txt,c.count || 0);
    if (bc) this.flash('Diffusé à ' + (c.count || 0) + ' adhérents · consigné dans le journal des envois');
  },
msgPayload(c, m) {
    const full = (m.subj ? m.subj + ' — ' : '') + String(m.text || '');
    return { who: m.mine ? 'Vous' : (m.who || c.name), text: full, time: m.time || '', conv: c.name };
  },
doForward() {
    const f = this.state.fwdMsg, ids = this.state.fwdSel || [];
    if (!f || !ids.length) return this.flash('Choisissez au moins une discussion');
    const t = this.nowTime();
    this.setState((s) => {
      const list = s.convos.map((c) => (ids.indexOf(c.id) >= 0 ? Object.assign({}, c, { messages: c.messages.concat([{ mine: true, fwd: true, text: f.text, time: t }]) }) : c));
      return { fwdMsg: null, fwdSel: [], convos: list.filter((c) => ids.indexOf(c.id) >= 0).concat(list.filter((c) => ids.indexOf(c.id) < 0)) };
    });
    this.flash('Message transféré à ' + ids.length + ' discussion' + (ids.length > 1 ? 's' : ''));
  }});return Object.freeze(Object.fromEntries(["cvFull","lastReal","patchConvo","convoSub","openConvo","openDirect","waDelete","grToggleAdmin","grRemove","openGroupEdit","saveGroup","curConvo","threadUniiContext","uniiPush","threadToDossier","sendMsgNow","msgPayload","doForward"].map(n=>[n,context[n].bind(context)])));}

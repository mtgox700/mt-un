import {AV_BG,WHO_FG,CT_CATS} from '../../generated/constants.js';
export function createMessagingPresenters(store,ports,readContext,writeContacts){const context={get state(){return {...readContext(),...store.read()}},setState:update=>{const patch=typeof update==='function'?update(context.state):update;const {adhTab,...own}=patch;if(adhTab!==undefined)writeContacts({adhTab});if(Object.keys(own).length)store.update(own)},...ports};Object.assign(context,{fwmVals() {
    const f = this.state.fwdMsg;
    if (!f) return { open: false, rows: [] };
    const q = String(this.state.fwdQ || '').trim().toLowerCase();
    const sel = this.state.fwdSel || [];
    const KIND = { group: 'Groupe', direct: 'Message direct', broadcast: 'Diffusion aux adhérents' };
    const rows = this.state.convos.map((c) => this.cvFull(c)).filter((c) => !q || c.name.toLowerCase().indexOf(q) >= 0).map((c) => { const on = sel.indexOf(c.id) >= 0; return { name: c.name, initials: c.initials, avatarBg: c.avatarBg, sub: KIND[c.kind] || '', on: on, boxBg: on ? 'var(--ac)' : 'var(--surface)', boxBd: on ? 'var(--ac)' : 'var(--bd2)', check: on ? '✓' : '', toggle: () => this.setState((s) => { const cur = s.fwdSel || []; return { fwdSel: cur.indexOf(c.id) >= 0 ? cur.filter((x) => x !== c.id) : cur.concat([c.id]) }; }) }; });
    return {
      open: true, sendLabel:'Transférer', title: 'Transférer le message', head: f.who + ' · ' + f.conv, text: f.text,
      q: this.state.fwdQ || '', onQ: (e) => this.setState({ fwdQ: e.target.value }),
      rows: rows, count: sel.length ? sel.length + ' discussion' + (sel.length > 1 ? 's' : '') + ' sélectionnée' + (sel.length > 1 ? 's' : '') : 'Aucune sélection',
      send: () => this.doForward(), close: () => this.setState({ fwdMsg: null, fwdSel: [] })
    };
  },
waVals() {
    const r = this.state.route, desk = this.state.isDesktop, wide = this.state.isWide;
    const onThread = r === 'thread' && !!this.curConvo();
    const pane = this.state.waPane || 'chats';
    const all = this.state.convos.map((c) => this.cvFull(c));
    const q = String(this.state.waQ || '').trim().toLowerCase();
    const F = this.state.waF || 'all';
    const T = {
      all: () => true,
      unread: (c) => (c.unread || 0) > 0,
      noreply: (c) => { const l = this.lastReal(c); return !!(l && !l.mine) && c.kind !== 'broadcast'; },
      mine: (c) => { const l = this.lastReal(c); return !!(l && l.mine); },
      group: (c) => c.kind === 'group',
      bc: (c) => c.kind === 'broadcast'
    };
    const FL = [['all', 'Toutes'], ['unread', 'Non lues'], ['noreply', 'Sans réponse de ma part'], ['mine', 'Dernier message de moi'], ['group', 'Groupes'], ['bc', 'Diffusions']];
    const hit = (c) => !q || c.name.toLowerCase().indexOf(q) >= 0 || c.messages.some((m) => !m.ai && (String(m.subj || '') + ' ' + String(m.text || '')).toLowerCase().indexOf(q) >= 0);
    const ord = all.filter((c) => c.pinned).concat(all.filter((c) => !c.pinned));
    const list = ord.filter((c) => T[F](c) && hit(c));
    const curId = onThread ? this.curConvo().id : '';
    const rows = list.map((c) => {
      const vis = c.messages.filter((m) => !m.ai);
      const s = vis[vis.length - 1];
      const prefix = !s || s.sys ? '' : (s.mine ? 'Vous : ' : (c.kind === 'group' && s.who ? s.who + ' : ' : ''));
      const un = c.unread || 0;
      return {
        name: c.name, initials: c.initials, avatarBg: c.avatarBg,
        preview: s ? String(s.subj || s.text || '').split('\n')[0] : 'Aucun message — écrivez le premier',
        prefix: prefix, time: s ? s.time : '', mineTick: !!(s && s.mine && !s.sys),
        unread: un, hasUnread: un > 0, timeFg: un ? 'var(--acTx)' : 'var(--ink6)', timeW: un ? '700' : '400',
        bg: c.id === curId ? 'var(--acBg)' : 'transparent', muted: !!c.muted, pinned: !!c.pinned, isBc: c.kind === 'broadcast',
        go: () => this.openConvo(c.id)
      };
    });
    const cts = this.allContacts().filter((x) => !x.me);
    const ctHit = (x) => !q || (x.name + ' ' + x.role).toLowerCase().indexOf(q) >= 0;
    const ctRow = (x) => ({ name: x.name, initials: x.initials, role: x.role, avatarBg: AV_BG[this.hashIdx(x.id, AV_BG.length)], go: () => this.openDirect(x.id) });
    const groups = all.filter((c) => c.kind === 'group' && (!q || c.name.toLowerCase().indexOf(q) >= 0));
    const cur = onThread ? this.cvFull(this.curConvo()) : null;
    const ctOf = cur && cur.kind === 'direct' ? this.contactById(cur.contactId) : null;
    const bcSend = () => {
      if (!cur) return;
      if (cur.groupeId) this.openAdhMsg({ cible: 'groupe', groupeId: cur.groupeId, modele: '', objet: '', corps: '' });
      else { this.setState({ adhSel: cur.adhIds || [] }); this.openAdhMsg({ cible: 'selection', modele: '', objet: '', corps: '' }); }
    };
    return {
      shell: r === 'messagerie' || r === 'thread',
      showList: desk || !onThread, showChat: onThread, showEmpty: desk && !onThread, showBack: !desk,
      listFlex: desk ? '0 0 380px' : '1 1 auto',
      paneTitle: pane === 'chats' ? 'Messages' : 'Nouvelle discussion',
      isChats: pane === 'chats', isContacts: pane === 'contacts',
      panes: [['chats', 'Discussions'], ['contacts', 'Contacts & groupes']].map((p) => ({ label: p[1], on: pane === p[0], bg: pane === p[0] ? 'var(--surface)' : 'transparent', fg: pane === p[0] ? 'var(--ink)' : 'var(--ink5)', go: () => this.setState({ waPane: p[0], waQ: '' }) })),
      q: this.state.waQ || '', hasQ: !!q, onQ: (e) => this.setState({ waQ: e.target.value }), clearQ: () => this.setState({ waQ: '' }),
      qPh: pane === 'chats' ? 'Rechercher une discussion ou un message' : 'Rechercher un contact ou un groupe',
      filters: FL.map((f) => { const n = f[0] === 'all' ? 0 : all.filter(T[f[0]]).length; const on = F === f[0]; return { label: f[1], n: n, hasN: n > 0, on: on, bg: on ? 'var(--acBg)' : 'var(--surface)', fg: on ? 'var(--acTx)' : 'var(--ink4)', bd: on ? 'var(--acBd)' : 'var(--bd2)', go: () => this.setState({ waF: f[0] }) }; }),
      rows: rows, noRows: !rows.length,
      noRowsText: q ? 'Aucune discussion ne correspond à « ' + this.state.waQ + ' ».' : ({ unread: 'Tout est lu.', noreply: 'Vous avez répondu à toutes les discussions.', mine: 'Aucune discussion où vous avez écrit en dernier.', group: 'Aucun groupe — créez-en un avec l\'icône Nouveau groupe.', bc: 'Aucune diffusion — les messages envoyés aux adhérents apparaîtront ici.' }[F] || 'Aucune discussion.'),
      newChat: () => this.setState({ waPane: 'contacts', waQ: '' }),
      newGroup: () => this.openGroupEdit(null),
      newContact: () => this.openContactEdit(null),
      newBc: () => this.openAdhMsg({ cible: 'groupe', groupeId: (this.state.groupes[0] || {}).id, modele: '', objet: '', corps: '' }),
      manage: () => this.go('contacts'),
      hasGroups: groups.length > 0,
      groupRows: groups.map((c) => ({ name: c.name, initials: c.initials, avatarBg: c.avatarBg, role: c.memberIds.length + ' membres', go: () => this.openConvo(c.id) })),
      teamRows: cts.filter((x) => x.cat !== 'adherent' && ctHit(x)).map(ctRow),
      adhRows: cts.filter((x) => x.cat === 'adherent' && ctHit(x)).map(ctRow),
      ref: this.waRef,
      back: () => this.go('messagerie'),
      chatSub: cur ? this.convoSub(cur) : '',
      isBc: !!(cur && cur.kind === 'broadcast'), bcSend: bcSend,
      infoOpen: !!(onThread && this.state.waInfo),
      toggleInfo: () => this.setState((s) => ({ waInfo: !s.waInfo })),
      closeInfo: () => this.setState({ waInfo: false }),
      drPos: wide ? 'relative' : 'absolute', drW: wide ? '340px' : 'min(380px, 100%)', drShadow: wide ? 'none' : '-20px 0 50px -30px hsl(var(--shC) / .5)',
      info: cur ? this.waInfoVals(cur, ctOf, all) : { del: {} },
      closeMenu: () => { if (this.state.waMenu !== null) this.setState({ waMenu: null }); },
      hasReply: !!this.state.waReply, replyHead: this.state.waReply ? 'Réponse à ' + this.state.waReply.who + (this.state.waReply.from ? ' · depuis « ' + this.state.waReply.from + ' »' : '') : '', replyText: this.state.waReply ? this.state.waReply.text : '',
      cancelReply: () => this.setState({ waReply: null }),
      composerPh: cur && cur.kind === 'broadcast' ? 'Message à diffuser aux ' + (cur.count || 0) + ' adhérents (notification app)…' : 'Message chiffré… ou @unii + consigne'
    };
  },
waInfoVals(c, ct, all) {
    const isG = c.kind === 'group', isB = c.kind === 'broadcast', isD = c.kind === 'direct';
    const adm = c.admins || [];
    const meAdmin = adm.indexOf('c-me') >= 0;
    const mem = c.memberIds.slice().sort((x, y) => (x === 'c-me' ? -1 : (y === 'c-me' ? 1 : (adm.indexOf(y) >= 0) - (adm.indexOf(x) >= 0))));
    const common = ct ? all.filter((g) => g.kind === 'group' && g.memberIds.indexOf(ct.id) >= 0).map((g) => g.name) : [];
    const mu = this.swv(!!c.muted), pi = this.swv(!!c.pinned);
    return {
      title: isG ? 'Infos du groupe' : (isB ? 'Infos de la diffusion' : 'Infos du contact'),
      name: c.name, initials: c.initials, avatarBg: c.avatarBg,
      sub: isG ? 'Groupe · ' + c.memberIds.length + ' membres' : (isB ? 'Liste de diffusion · ' + (c.count || 0) + ' adhérents' : (ct ? ct.role : '')),
      isGroup: isG, showMembers: isG, isBc: isB, isDirect: isD,
      desc: c.desc || '', hasDesc: !!c.desc,
      canEdit: isG && meAdmin, edit: () => this.openGroupEdit(c.id), addMembers: () => this.openGroupEdit(c.id),
      tel: (ct && ct.tel) || '—', email: (ct && ct.email) || '—', catLabel: ct ? CT_CATS[ct.cat] : '',
      ctGroups: common.join(', '), hasCtGroups: common.length > 0,
      isAdh: !!(ct && ct.adhId), canEditCt: !!(ct && !ct.adhId),
      editCt: () => ct && this.openContactEdit(ct.id),
      fiche: () => { if (ct && ct.adhId) this.go('adherent', { adherentId: ct.adhId }); },
      memberCount: c.memberIds.length + ' membres',
      members: mem.map((id) => {
        const x = this.contactById(id) || { name: 'Contact supprimé', initials: '?', role: '' };
        const me = id === 'c-me', isA = adm.indexOf(id) >= 0;
        return { name: me ? 'Vous' : x.name, initials: x.initials, role: x.role, avatarBg: AV_BG[this.hashIdx(id, AV_BG.length)], isAdmin: isA, canAct: meAdmin && !me, adminLabel: isA ? 'Retirer admin' : 'Nommer admin', toggleAdmin: () => this.grToggleAdmin(c.id, id), remove: () => this.grRemove(c.id, id), msg: () => this.openDirect(id) };
      }),
      bcCount: (c.count || 0) + ' adhérents', bcChan: c.chan || '—',
      bcList: () => { this.setState({ adhTab: 'groupes' }); this.go('adherents'); },
      muteBg: mu.bg, muteLeft: mu.left, toggleMute: () => this.patchConvo(c.id, (x) => ({ muted: !x.muted })),
      pinBg: pi.bg, pinLeft: pi.left, togglePin: () => this.patchConvo(c.id, (x) => ({ pinned: !x.pinned })),
      del: this.askDel('cv-' + c.id, isG ? 'Supprimer le groupe' : (isB ? 'Supprimer la diffusion' : 'Supprimer la discussion'), () => this.waDelete(c.id))
    };
  },
grmVals() {
    const g = this.state.grEdit;
    if (!g) return { open: false, chips: [], cands: [] };
    const set = (p) => this.setState((s) => ({ grEdit: Object.assign({}, s.grEdit, p) }));
    const q = String(this.state.grQ || '').trim().toLowerCase();
    const pool = this.allContacts().filter((x) => !x.me);
    const sel = g.memberIds;
    const cands = pool.filter((x) => !q || (x.name + ' ' + x.role).toLowerCase().indexOf(q) >= 0).sort((x, y) => (sel.indexOf(y.id) >= 0) - (sel.indexOf(x.id) >= 0));
    return {
      open: true, showDetails: true, searchPlaceholder: 'Ajouter un élu, un adhérent, un contact…', title: g.id ? 'Membres & réglages du groupe' : 'Nouveau groupe',
      name: g.name, desc: g.desc, onName: (ev) => set({ name: ev.target.value }), onDesc: (ev) => set({ desc: ev.target.value }),
      q: this.state.grQ || '', onQ: (ev) => this.setState({ grQ: ev.target.value }),
      count: sel.length + ' sélectionné' + (sel.length > 1 ? 's' : '') + ' + vous',
      hasChips: sel.length > 0,
      chips: sel.map((id) => ({ name: (((this.contactById(id) || {}).name) || '?').split(' ')[0], rm: () => set({ memberIds: sel.filter((y) => y !== id) }) })),
      cands: cands.slice(0, 60).map((x) => { const on = sel.indexOf(x.id) >= 0; return { name: x.name, initials: x.initials, role: x.role, catLabel: CT_CATS[x.cat], avatarBg: AV_BG[this.hashIdx(x.id, AV_BG.length)], on: on, boxBg: on ? 'var(--ac)' : 'var(--surface)', boxBd: on ? 'var(--ac)' : 'var(--bd2)', check: on ? '✓' : '', toggle: () => set({ memberIds: on ? sel.filter((y) => y !== x.id) : sel.concat([x.id]) }) }; }),
      save: () => this.saveGroup(), close: () => this.setState({ grEdit: null }),
      saveLabel: g.id ? 'Enregistrer' : 'Créer le groupe'
    };
  },
convoVals() {
        const c0 = this.curConvo();
        if (!c0) return { name: '', initials: '', avatarBg: '', members: '', messages: [] };
        const c = this.cvFull(c0);
        const isGrp = c.kind === 'group';
        return {
          name: c.name, initials: c.initials, members: this.convoSub(c), avatarBg: c.avatarBg,
          messages: c.messages.map((m, i) => {
            const selMode = !!this.state.thSelMode;
            const on = (this.state.thSel || []).indexOf(i) >= 0;
            const body = String(m.text || '').split(/\n\s*(---|Sources)/)[0].trim();
            return {
              text: m.text, time: m.time, who: m.who, mine: !!m.mine && !m.ai && !m.sys, theirs: !m.mine && !m.ai && !m.sys, isAi: !!m.ai, isSys: !!m.sys,
              showWho: isGrp && !!m.who, whoFg: WHO_FG[this.hashIdx(m.who, WHO_FG.length)],
              hasChan: !!m.chan, chanLabel: m.chan ? m.chan + (m.sentTo ? ' · ' + m.sentTo + ' destinataire' + (m.sentTo > 1 ? 's' : '') : '') : '',
              hasSubj: !!m.subj, subj: m.subj || '', hasAtt: !!m.att, att: m.att || '',
              fwd: !!m.fwd, hasReply: !!m.reply, replyWho: m.reply ? m.reply.who + (m.reply.from ? ' · ' + m.reply.from : '') : '', replyText: m.reply ? m.reply.text : '',
              menuOpen: this.state.waMenu === i,
              toggleMenu: (e) => { if (e && e.stopPropagation) e.stopPropagation(); this.setState((s) => ({ waMenu: s.waMenu === i ? null : i })); },
              acts: this.state.waMenu === i ? this.msgActs(c, m) : [],
              ask: m.ask || '', ctxLabel: m.ctxLabel || '', reid: m.reid || '', ok: !!m.ai && !m.failed,
              selBd: on ? 'var(--ac)' : 'transparent', cursor: selMode ? 'pointer' : 'auto', checked: on,
              pick: () => {
                if (!this.state.thSelMode) return;
                this.setState((s) => { const cur = s.thSel || []; return { thSel: cur.indexOf(i) >= 0 ? cur.filter((x) => x !== i) : cur.concat([i]) }; });
              },
              insert: () => { this.setState({ msgDraft: body }); this.flash('Texte de unii inséré — relisez avant envoi'); },
              toAsst: () => this.toAssistant({ origin: 'Messages', route: 'thread', params: { convoId: c.id }, title: 'Messagerie — ' + c.name, ctx: 'Fil « ' + c.name + ' » — ' + (m.ctxLabel || '') + '\nExtraits : ' + (m.ctx || '') + '\nConsigne : ' + (m.ask || '') + '\nRéponse de unii : ' + body, messages: [{ isUser: true, text: m.ask || 'Analyse du fil' }, { isBot: true, source: 'unii · messagerie', text: m.text }] }),
              hide: () => this.setState((s) => ({ convos: s.convos.map((x) => (x.id === c.id ? Object.assign({}, x, { messages: x.messages.filter((y, j) => j !== i) }) : x)) }))
            };
          })
        };
      },
thVals() {
        const sel = (this.state.thSel || []).length;
        const q = String(this.state.thQuote || '');
        const ctx = this.threadUniiContext();
        const c = this.curConvo();
        const PRE = [
          ['Résumer', 'Résume ces échanges : décisions prises, désaccords, points en suspens.'],
          ['Proposer une réponse', 'Rédige une réponse que je peux envoyer dans ce fil.'],
          ['Points juridiques', 'Identifie les points juridiques soulevés et les textes applicables, avec leurs sources.'],
          ['Extraire les actions', 'Liste les actions à mener, avec responsable et échéance quand ils sont mentionnés.']
        ];
        return {
          selMode: !!this.state.thSelMode, selLabel: this.state.thSelMode ? 'Terminer la sélection' : 'Sélectionner',
          toggleSel: () => this.setState((s) => ({ thSelMode: !s.thSelMode, thUniiOpen: true })),
          toggleUnii: () => this.setState((s) => ({ thUniiOpen: !s.thUniiOpen })),
          panel: !!(this.state.thUniiOpen || sel || q || this.state.thBusy),
          ctxLabel: ctx.label, hasQuote: !!q, quote: q.length > 260 ? q.slice(0, 260) + '…' : q,
          hasSel: !!(sel || q),
          clear: () => this.setState({ thSel: [], thQuote: '', thSelMode: false, thUniiOpen: false }),
          busy: !!this.state.thBusy, busyAsk: this.state.thAsk || '',
          presets: PRE.map((p) => ({ label: p[0], go: () => this.threadUniiRun(p[1]) })),
          toAsst: () => { const x = this.threadUniiContext(); this.setState({ thSel: [], thQuote: '', thSelMode: false }); this.toAssistant({ origin: 'Messages', route: 'thread', params: { convoId: c.id }, title: 'Messagerie — ' + c.name, ctx: x.raw }); },
          toDossier: () => this.threadToDossier(),
          dosLabel: this.state.dosBusy ? 'Qualification…' : 'Créer un dossier',
          onMouseUp: () => {
            if (typeof window === 'undefined' || !window.getSelection) return;
            const t = String(window.getSelection().toString() || '').trim();
            if (t.length > 3) this.setState({ thQuote: t.slice(0, 1500), thUniiOpen: true });
          }
        };
      }});return Object.freeze(Object.fromEntries(["waVals","waInfoVals","grmVals","fwmVals","convoVals","thVals"].map(n=>[n,context[n].bind(context)])));}

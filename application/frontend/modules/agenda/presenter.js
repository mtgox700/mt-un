import {AG_TYPES,AG_VISIB,AG_MOIS,AG_JOURS,AG_JOURS_C} from './constants.js';
export function createAgendaPresenter(store,ports,ui){const context={get state(){return {...store.read(),...ui()}},setState:p=>store.update(p),...ports};Object.assign(context,{exportIcs(ev) {
    const esc = v => String(v || '').replace(/\\/g,'\\\\').replace(/\r?\n/g,'\\n').replace(/;/g,'\\;').replace(/,/g,'\\,');
    const day = ev.date.replace(/-/g,'');
    const start = ev.start ? 'DTSTART:'+day+'T'+ev.start.replace(':','')+'00' : 'DTSTART;VALUE=DATE:'+day;
    const end = ev.end ? 'DTEND:'+day+'T'+ev.end.replace(':','')+'00' : '';
    const lines = ['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//uniion//Prototype local//FR','BEGIN:VEVENT','UID:'+esc(ev.id)+'@uniion.local','DTSTAMP:'+new Date().toISOString().replace(/[-:]/g,'').replace(/\.\d+Z/,'Z'),start,end,'SUMMARY:'+esc(ev.title),'LOCATION:'+esc(ev.lieu),'DESCRIPTION:'+esc(ev.notes),'END:VEVENT','END:VCALENDAR'].filter(Boolean);
    window.uniionFiles.download(new Blob([lines.join('\r\n')+'\r\n'],{type:'text/calendar;charset=utf-8'}),'evenement.ics');
  },
agPad(n) { return (n < 10 ? '0' : '') + n; },
agIso(y, m, d) { return y + '-' + this.agPad(m + 1) + '-' + this.agPad(d); },
agParse(s) { const p = String(s || '').split('-'); return { y: Number(p[0]), m: Number(p[1]) - 1, d: Number(p[2]) }; },
agToday() { return '2026-09-02'; },
agCap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ''; },
agFrLong(s) {
    const p = this.agParse(s);
    if (!p.y) return '';
    const dt = new Date(p.y, p.m, p.d);
    return this.agCap(AG_JOURS[(dt.getDay() + 6) % 7]) + ' ' + p.d + ' ' + AG_MOIS[p.m];
  },
agTypeDef(id) {
    const W = this.W();
    const t = AG_TYPES.find(function (x) { return x.id === id; }) || AG_TYPES[0];
    const over = { cse: W.seance, perm: W.perm, ag: W.plenary };
    return over[t.id] ? Object.assign({}, t, { label: over[t.id] }) : t;
  },
agVisibDefs() {
    const W = this.W();
    return AG_VISIB.map((v) => v.id === 'elus'
      ? Object.assign({}, v, { label: W.visibElus })
      : (v.id === 'adherents' ? Object.assign({}, v, { label: W.visibMembers }) : v));
  },
agHours(e) {
    if (!e.start) return 'Toute la journée';
    return e.start.replace(':', ' h ') + (e.end ? ' → ' + e.end.replace(':', ' h ') : '');
  },
agFiltered() {
    const f = this.state.agTypeF;
    if (!f.length) return this.state.agenda;
    return this.state.agenda.filter(function (e) { return f.indexOf(e.type) >= 0; });
  },
agShiftMonth(step) {
    const p = this.agParse(this.state.agMonth + '-01');
    const dt = new Date(p.y, p.m + step, 1);
    this.setState({ agMonth: dt.getFullYear() + '-' + this.agPad(dt.getMonth() + 1), agEvtId: '' });
  },
agSetNew(patch) { this.setState((s) => ({ agNew: Object.assign({}, s.agNew, patch) })); },
agOpenNew(date) {
    if (!this.state.isDesktop) setTimeout(() => { const el = document.getElementById('agenda-new'); if (el) { el.scrollIntoView({ block: 'start' }); const input = el.querySelector('input'); if (input) input.focus({ preventScroll: true }); } }, 100);
    this.setState((s) => ({
      agEvtId: '',
      agNew: Object.assign({}, s.agNew, { open: true, editId: '', date: date || s.agSel || this.agToday() })
    }));
  },
agCreate() {
    const n = this.state.agNew;
    if (!String(n.title).trim()) return this.flash('Donnez un intitulé à l\'événement');
    if (!this.validDate(n.date)) return this.flash('Date attendue au format AAAA-MM-JJ');
    if (n.start && n.end && n.end <= n.start) return this.flash('L\'heure de fin doit suivre l\'heure de début');
    const id = n.editId || ('e' + Date.now());
    const evt = {
      id: id, date: n.date, start: n.start, end: n.end, type: n.type,
      title: n.title.trim(), lieu: n.lieu.trim(), org: 'Vous', visib: n.visib,
      invites: [], notes: n.notes.trim(), rappel: n.rappel
    };
    if (n.editId) { delete evt.org; delete evt.invites; }
    this.setState((s) => ({
      agenda: n.editId ? s.agenda.map((e) => e.id === n.editId ? Object.assign({}, e, evt) : e) : s.agenda.concat([evt]),
      agMonth: n.date.slice(0, 7),
      agSel: n.date,
      agEvtId: id,
      agNew: { open: false, title: '', type: n.type, date: '', start: '09:00', end: '11:00', lieu: '', visib: n.visib, notes: '', rappel: true, editId: '' }
    }));
    this.flash((n.editId ? 'Événement modifié' : 'Événement ajouté à l\'agenda partagé') + (n.rappel ? ' — rappel programmé' : ''));
  },
agDelete(id) {
    this.setState((s) => ({ agenda: s.agenda.filter(function (e) { return e.id !== id; }), agEvtId: '' }));
    this.flash('Événement retiré de l\'agenda');
  },
agVals() {
    const st = this.state;
    const mobileView = !st.isDesktop ? (st.mobileAgView || 'liste') : st.agView;
    const p = this.agParse(st.agMonth + '-01');
    const evts = this.agFiltered();
    const today = this.agToday();
    const byDate = {};
    evts.forEach(function (e) { (byDate[e.date] = byDate[e.date] || []).push(e); });
    Object.keys(byDate).forEach(function (k) { byDate[k].sort(function (a, b) { return (a.start || '').localeCompare(b.start || ''); }); });

    const first = new Date(p.y, p.m, 1);
    const lead = (first.getDay() + 6) % 7;
    const start = new Date(p.y, p.m, 1 - lead);
    const weeks = [];
    for (let w = 0; w < 6; w++) {
      const days = [];
      for (let i = 0; i < 7; i++) {
        const dt = new Date(start.getFullYear(), start.getMonth(), start.getDate() + w * 7 + i);
        const iso = this.agIso(dt.getFullYear(), dt.getMonth(), dt.getDate());
        const list = byDate[iso] || [];
        const out = dt.getMonth() !== p.m;
        const sel = iso === st.agSel;
        days.push({
          num: dt.getDate(), iso: iso, isToday: iso === today, out: out, sel: sel,
          bg: sel ? 'var(--acBg2)' : (out ? 'transparent' : 'var(--surface)'),
          ring: sel ? 'var(--acMid)' : 'var(--bd)',
          numColor: out ? 'var(--ink6)' : (iso === today ? 'var(--acTx2)' : 'var(--ink3)'),
          numWeight: iso === today ? 800 : 600,
          chips: list.slice(0, 3).map((e) => {
            const t = this.agTypeDef(e.type);
            return { id: e.id, label: e.title, bg: t.bg, fg: t.fg, open: () => this.setState({ agSel: e.date, agEvtId: e.id, agNew: Object.assign({}, st.agNew, { open: false }) }) };
          }),
          more: list.length > 3 ? '+' + (list.length - 3) + ' autre' + (list.length - 3 > 1 ? 's' : '') : '',
          hasMore: list.length > 3,
          pick: () => this.setState({ agSel: iso, agEvtId: '' })
        });
      }
      weeks.push({ days: days });
    }

    const selList = (byDate[st.agSel] || []).map((e) => {
      const t = this.agTypeDef(e.type);
      return {
        id: e.id, title: e.title, hours: this.agHours(e), lieu: e.lieu || 'Lieu à préciser',
        tLabel: t.label, bg: t.bg, fg: t.fg, dot: t.dot,
        on: e.id === st.agEvtId,
        ring: e.id === st.agEvtId ? 'var(--acMid)' : 'var(--bd)',
        open: () => this.setState({ agEvtId: e.id })
      };
    });

    const upcoming = evts.filter(function (e) { return e.date >= today; })
      .sort(function (a, b) { return (a.date + a.start).localeCompare(b.date + b.start); })
      .slice(0, 5)
      .map((e) => {
        const t = this.agTypeDef(e.type);
        return {
          id: e.id, title: e.title, when: this.agFrLong(e.date) + (e.start ? ' · ' + e.start.replace(':', ' h ') : ''),
          tLabel: t.label, bg: t.bg, fg: t.fg,
          open: () => this.setState({ agMonth: e.date.slice(0, 7), agSel: e.date, agEvtId: e.id })
        };
      });

    const ev = st.agenda.find(function (e) { return e.id === st.agEvtId; }) || null;
    const evT = ev ? this.agTypeDef(ev.type) : null;
    const AGV = this.agVisibDefs();
    const evV = ev ? (AGV.find(function (v) { return v.id === ev.visib; }) || AGV[0]) : null;
    const n = st.agNew;

    return {
      intro: 'Séances, négociations, permanences et échéances de mandat — visibles de tous les ' + this.W().people.toLowerCase() + '.',
      rappelNote: 'Les rappels sont envoyés aux ' + this.W().people.toLowerCase() + ' concernés 48 h avant l\'échéance, par notification et par courriel.',
      monthLabel: this.agCap(AG_MOIS[p.m]) + ' ' + p.y,
      prev: () => this.agShiftMonth(-1),
      next: () => this.agShiftMonth(1),
      today: () => this.setState({ agMonth: today.slice(0, 7), agSel: today, agEvtId: '' }),
      dayNames: AG_JOURS_C.map(function (j) { return { label: j }; }),
      weeks: weeks,
      isMonth: mobileView === 'mois',
      isList: mobileView === 'liste',
      views: [{ id: 'mois', label: 'Mois' }, { id: 'liste', label: 'Liste' }].map((v) => {
        const on = mobileView === v.id;
        return { label: v.label, on: on, bg: on ? 'var(--surface)' : 'transparent', fg: on ? 'var(--ink)' : 'var(--ink5)', go: () => this.setState(st.isDesktop ? { agView: v.id } : { mobileAgView: v.id }) };
      }),
      types: AG_TYPES.map((t0) => {
        const t = this.agTypeDef(t0.id);
        const on = st.agTypeF.indexOf(t.id) >= 0;
        return {
          label: t.label, dot: t.dot, on: on,
          bg: on ? t.bg : 'var(--surface)', fg: on ? t.fg : 'var(--ink5)', ring: on ? 'transparent' : 'var(--bd2)',
          go: () => this.setState((s) => ({ agTypeF: on ? s.agTypeF.filter(function (x) { return x !== t.id; }) : s.agTypeF.concat([t.id]), agEvtId: '' }))
        };
      }),
      filterOn: st.agTypeF.length > 0,
      clearFilter: () => this.setState({ agTypeF: [] }),
      count: evts.length + ' événement' + (evts.length > 1 ? 's' : '') + ' — ' + st.agenda.length + ' au total',
      agenda: evts.slice().sort(function (a, b) { return (a.date + a.start).localeCompare(b.date + b.start); }).map((e) => {
        const t = this.agTypeDef(e.type);
        return {
          id: e.id, title: e.title, when: this.agFrLong(e.date), hours: this.agHours(e),
          lieu: e.lieu || '—', tLabel: t.label, bg: t.bg, fg: t.fg, dot: t.dot,
          op: e.date < today ? .62 : 1,
          open: () => this.setState({ agMonth: e.date.slice(0, 7), agSel: e.date, agEvtId: e.id, agView: 'mois' })
        };
      }),
      selLabel: this.agFrLong(st.agSel) || 'Aucun jour sélectionné',
      selList: selList,
      selEmpty: selList.length === 0,
      addHere: () => this.agOpenNew(st.agSel),
      upcoming: upcoming,
      hasEvt: !!ev,
      evt: ev ? {
        title: ev.title, tLabel: evT.label, bg: evT.bg, fg: evT.fg,
        when: this.agFrLong(ev.date), hours: this.agHours(ev),
        lieu: ev.lieu || 'Lieu à préciser', org: ev.org || '—',
        visib: evV.label, visibNote: evV.note,
        notes: ev.notes || 'Aucune note pour cette échéance.',
        invites: (ev.invites || []).map(function (i) { return { label: i }; }),
        hasInvites: (ev.invites || []).length > 0,
        close: () => this.setState({ agEvtId: '' }),
        edit: () => this.setState((s) => ({
          agNew: { open: true, title: ev.title, type: ev.type, date: ev.date, start: ev.start, end: ev.end, lieu: ev.lieu, visib: ev.visib, notes: ev.notes, rappel: true, editId: ev.id }
        })),
        convoque: () => { this.go('adhmsg'); this.flash('Campagne préremplie — choisissez la liste à convoquer'); },
        odj: () => this.createAgendaDocument(ev),
        ics: () => this.exportIcs(ev),
        remove: () => this.agDelete(ev.id)
      } : null,
      newOpen: n.open,
      newTitle: n.editId ? 'Modifier l\'événement' : 'Nouvel événement',
      newCta: n.editId ? 'Enregistrer les modifications' : 'Ajouter à l\'agenda partagé',
      newClosed: !n.open,
      openNew: () => this.agOpenNew(st.agSel),
      cancelNew: () => this.agSetNew({ open: false, editId: '' }),
      f: {
        title: n.title, onTitle: (e) => this.agSetNew({ title: e.target.value }),
        date: n.date, onDate: (e) => this.agSetNew({ date: e.target.value }),
        start: n.start, onStart: (e) => this.agSetNew({ start: e.target.value }),
        end: n.end, onEnd: (e) => this.agSetNew({ end: e.target.value }),
        lieu: n.lieu, onLieu: (e) => this.agSetNew({ lieu: e.target.value }),
        notes: n.notes, onNotes: (e) => this.agSetNew({ notes: e.target.value }),
        types: AG_TYPES.map((t0) => {
          const t = this.agTypeDef(t0.id);
          const on = n.type === t.id;
          return { label: t.label, on: on, bg: on ? t.bg : 'var(--surf2)', fg: on ? t.fg : 'var(--ink4)', ring: on ? t.dot : 'transparent', go: () => this.agSetNew({ type: t.id }) };
        }),
        visibs: AGV.map((v) => {
          const on = n.visib === v.id;
          return { label: v.label, on: on, bg: on ? 'var(--acBg)' : 'var(--surf2)', fg: on ? 'var(--acTx2)' : 'var(--ink4)', ring: on ? 'var(--acMid)' : 'transparent', go: () => this.agSetNew({ visib: v.id }) };
        }),
        visibNote: (AGV.find(function (v) { return v.id === n.visib; }) || AGV[0]).note,
        rappelBg: n.rappel ? 'var(--ok)' : 'var(--bd2)',
        rappelLeft: n.rappel ? '23px' : '3px',
        rappelOn: n.rappel,
        toggleRappel: () => this.agSetNew({ rappel: !n.rappel }),
        submit: () => this.agCreate()
      }
    };
  },
createAgendaDocument(ev) {
    const id = 'odj-' + Date.now();
    const doc = { id: id, title: 'Ordre du jour — ' + ev.title, model: 'cr', format: 'a4', status: 'Brouillon', updated: "à l'instant",
      blocks: [['h1','Ordre du jour — ' + ev.title], ['p', [ev.date, ev.start + ' — ' + ev.end, ev.lieu].filter(Boolean).join(' · ')], ['h2','Participants'], ['p',(ev.invites || []).join(', ') || 'À compléter'], ['h2','Points à examiner'], ['p', ev.notes || 'À compléter']].map((x,i) => ({id:id+'-'+i,type:x[0],text:x[1]})) };
    this.saveDocument(doc); this.go('docedit', { docId: id });
  }});const actions=Object.fromEntries(Object.keys(context).filter(k=>typeof context[k]==='function'&&!Object.hasOwn(ports,k)&&k!=='setState').map(k=>[k,context[k].bind(context)]));return {...actions,configure:overrides=>Object.assign(context,overrides)};}

export function initialAgenda(){return {agenda:[],agMonth:'2026-09',agSel:'2026-09-03',agView:'mois',agTypeF:[],agEvtId:'',agNew:{open:false,title:'',type:'cse',date:'',start:'09:00',end:'11:00',lieu:'',visib:'elus',notes:'',rappel:true}};}
export function homeAgenda(events,today,open,now=Date.now()){return events.filter(e=>e.date>=today&&new Date(e.date+'T'+(e.end||'23:59')).getTime()>=now).slice().sort((a,b)=>(a.date+a.start).localeCompare(b.date+b.start)||a.id.localeCompare(b.id)).slice(0,3).map(e=>({date:new Intl.DateTimeFormat('fr-FR',{day:'2-digit',month:'short'}).format(new Date(e.date+'T12:00:00')),title:e.title,meta:[e.lieu,[e.start,e.end].filter(Boolean).join(' — ')].filter(Boolean).join(' · '),go:()=>open(e.id)}));}

export function agendaContext(events){return 'Agenda :\n'+events.slice(0,10).map(e=>'- '+e.date+' '+e.start+' — '+e.title+' ('+e.lieu+')'+(e.notes?' : '+e.notes:'')).join('\n');}

export async function openAgendaEvent(store,navigate,id){const allowed=await navigate('agenda');if(allowed===false)return false;const event=store.read().agenda.find(e=>e.id===id);if(!event)return false;store.update({agEvtId:id,agSel:event.date,agMonth:event.date.slice(0,7)});return true;}

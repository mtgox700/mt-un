import {ADH_MSG_MODELS,ADH_STATUTS,ADH_CSV_COLS,ADH_CSV_MODEL,ADH_CRIT,ADH_PER_PAGE} from '../../generated/constants.js';
export function createMemberManagement(store,ports,readContext,writeContext){const context={get state(){return {...readContext(),...store.read()}},setState:update=>{const patch=typeof update==='function'?update(context.state):update;const own={},external={};for(const [key,value]of Object.entries(patch)){if(['delKey','members','onb','importMembers'].includes(key))external[key]=value;else own[key]=value;}if(Object.keys(external).length)writeContext(external);if(Object.keys(own).length)store.update(own)},...ports};Object.assign(context,{createAdhGroup() {
    const crit = Object.assign({}, this.state.adhF);
    const labels = this.adhCritLabel(crit);
    const name = this.state.adhGName.trim() || (labels.length ? labels.join(' · ') : 'Nouvelle liste');
    const g = { id: 'g' + Date.now(), name: name, type: 'dyn', crit: crit, desc: 'Créée depuis les critères de filtre — recalculée ' + (this.W().showCotis ? 'à chaque nouvelle adhésion.' : 'à chaque changement de rattachement.'), canal: 'E-mail' };
    this.setState((s) => ({ groupes: s.groupes.concat([g]), adhGName: '', adhTab: 'groupes' }));
    this.flash('Liste de diffusion « ' + name + ' » créée — ' + this.groupMembers(g).length + ' adhérents');
  },
adhFieldDefs() {
    return [
      { k: 'prenom', label: 'Prénom', req: true },
      { k: 'nom', label: 'Nom', req: true },
      { k: 'email', label: 'Courriel', req: true },
      { k: 'tel', label: 'Téléphone' },
      { k: 'poste', label: 'Emploi occupé' },
      { k: 'ent', label: 'Entreprise' },
      { k: 'etab', label: 'Établissement' },
      { k: 'sect', label: 'Section syndicale' },
      { k: 'dir', label: 'Direction' },
      { k: 'mandat', label: 'Mandat' },
      { k: 'since', label: 'Adhérent depuis' },
      { k: 'mode', label: 'Mode de règlement' },
      { k: 'montant', label: 'Montant de cotisation' }
    ];
  },
adhStartEdit() { this.setState((s) => ({ adhEdit: true, adhDraft: Object.assign({}, this.curAdherent()), delKey: '' })); },
adhCancelEdit() { this.setState({ adhEdit: false, adhDraft: null }); },
adhPatchDraft(k, v) { this.setState((s) => ({ adhDraft: Object.assign({}, s.adhDraft, { [k]: v }) })); },
adhSaveEdit() {
    const d = this.state.adhDraft || {};
    if (!String(d.prenom || '').trim() || !String(d.nom || '').trim()) return this.flash('Le prénom et le nom sont obligatoires');
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(d.email || ''))) return this.flash('Adresse de courriel invalide');
    const dup = this.state.adherents.some((a) => a.id !== d.id && String(a.email).toLowerCase() === String(d.email).toLowerCase());
    if (dup) return this.flash('Ce courriel est déjà rattaché à un autre adhérent');
    const ini = (String(d.prenom).trim()[0] || '') + (String(d.nom).trim()[0] || '');
    this.setState((s) => ({
      adherents: s.adherents.map((a) => a.id === d.id ? Object.assign({}, a, d, { initials: ini.toUpperCase() }) : a),
      adhEdit: false, adhDraft: null
    }));
    this.flash('Fiche adhérent mise à jour');
  },
adhDelete(id) {
    const a = this.state.adherents.find((x) => x.id === id);
    this.setState((s) => {
      const rest = s.adherents.filter((x) => x.id !== id);
      return {
        adherents: rest,
        adhSel: s.adhSel.filter((x) => x !== id),
        adherentId: (rest[0] || {}).id || '',
        adhEdit: false, adhDraft: null,
        groupes: s.groupes.map((g) => g.ids ? Object.assign({}, g, { ids: g.ids.filter((x) => x !== id) }) : g)
      };
    });
    this.go('adherents');
    this.flash((a ? a.prenom + ' ' + a.nom : 'Adhérent') + ' retiré du fichier — radiation consignée au journal');
  },
adhMarkPaid(id) {
    this.setState((s) => ({
      adherents: s.adherents.map((a) => a.id === id ? Object.assign({}, a, { statut: 'ajour', du: '', dernier: '31 août 2026', echeance: '5 octobre 2026' }) : a)
    }));
    this.flash('Cotisation encaissée — reçu fiscal généré et journalisé');
  },
adhRelance(id) {
    const a = this.state.adherents.find((x) => x.id === id);
    this.openAdhMsg({ cible: 'selection', canal: 'email' });
    this.setState({ adhSel: [id] });
    this.applyAdhModel('relance');
    if (a) this.flash('Relance préparée pour ' + a.prenom + ' ' + a.nom);
  },
adhBulletin(a) {
    this.createFromModel('bulletin');
    this.flash('Bulletin d\'adhésion créé dans les documents' + (a ? ' — à faire signer par ' + a.prenom + ' ' + a.nom : ''));
  },
parseAdhCsv(text) {
    const input = String(text || '').replace(/^\uFEFF/, '');
    if (!input.trim()) return { empty: true, cols: [], rows: [], ok: 0, ko: 0, sep: ';', missing: [] };
    const first = input.split(/\r?\n/)[0];
    const sep = this.csvRows(first, ';').rows[0].length >= this.csvRows(first, ',').rows[0].length ? ';' : ',';
    const parsed = this.csvRows(input, sep), raw = parsed.rows;
    const norm = (v) => v.trim().toLowerCase().replace(/[éè]/g, 'e').replace(/\s+/g, '_');
    const head = raw[0].map(norm);
    const missing = ADH_CSV_COLS.filter((c) => c.req && head.indexOf(c.h) < 0).map((c) => c.h);
    const known = new Set();
    const val = (cells, h) => { const i = head.indexOf(h); return i < 0 ? '' : (cells[i] || '').trim(); };
    const rows = raw.slice(1).map((cells, n) => {
      const rec = {};
      ADH_CSV_COLS.forEach((c) => { rec[c.k] = val(cells, c.h); });
      const errs = parsed.error ? [parsed.error] : [];
      if (cells.length !== head.length) errs.push('Nombre de colonnes incohérent');
      ADH_CSV_COLS.forEach((c) => { if (c.req && !rec[c.k]) errs.push(c.label + ' manquant'); });
      if (rec.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(rec.email)) errs.push('Courriel invalide');
      const admin = this.adminImportActive();
      const dup = (admin ? this.state.members : this.state.adherents).some((a) => String(a.email || '').toLowerCase() === rec.email.toLowerCase());
      if (dup) errs.push(admin ? 'Membre déjà présent' : 'Adhérent déjà présent');
      const warn = [];
      [['ent', ADH_CRIT.ent, 'Entreprise'], ['etab', ADH_CRIT.etab, 'Établissement'], ['sect', ADH_CRIT.sect, 'Section'], ['dir', ADH_CRIT.dir, 'Direction']].forEach((x) => {
        if (rec[x[0]] && x[1].indexOf(rec[x[0]]) < 0) warn.push(x[2] + ' inconnue — sera créée');
      });
      if (known.has(rec.email.toLowerCase())) errs.push('Doublon dans le fichier');
      known.add(rec.email.toLowerCase());
      return { line: n + 2, rec: rec, errs: errs, warn: warn, valid: errs.length === 0 };
    });
    return {
      empty: false, sep: sep, head: head, missing: missing, rows: rows,
      ok: rows.filter((r) => r.valid).length, ko: rows.filter((r) => !r.valid).length
    };
  },
adhCsvText() { return this.state.adhImp.touched ? this.state.adhImp.text : ''; },
loadCsvSample() { this.setState((s) => ({ adhImp: Object.assign({}, s.adhImp, { text: ADH_CSV_MODEL, touched: true, fileName: 'adherents-exemple.csv' }) })); },
runCsvImport() {
    const p = this.parseAdhCsv(this.adhCsvText());
    const valid = p.rows.filter((r) => r.valid);
    if (!valid.length) return this.flash('Aucune ligne valide à importer');
    if (this.adminImportActive()) return this.importAdministrators(valid);
    const add = valid.map((r, i) => {
      const rec = r.rec;
      return {
        id: 'imp' + Date.now() + i, prenom: rec.prenom, nom: rec.nom,
        initials: (rec.prenom.charAt(0) + rec.nom.charAt(0)).toUpperCase(),
        poste: rec.poste || 'Emploi non renseigné', email: rec.email, tel: rec.tel || '—',
        ent: rec.ent, etab: rec.etab, sect: rec.sect || 'Section à rattacher', dir: rec.dir || 'Direction à rattacher',
        since: rec.since || 'septembre 2026', statut: 'nouveau',
        mode: rec.mode || 'Prélèvement SEPA', montant: rec.montant || 'à définir',
        dernier: '—', echeance: 'premier prélèvement à programmer', du: '', mandat: '',
        bulletin: 'Bulletin à signer'
      };
    });
    this.setState((s) => ({
      adherents: s.adherents.concat(add),
      adhImp: { text: '', touched: false, fileName: '' },
      adhTab: 'liste',
      adhF: Object.assign({}, s.adhF, { statut: 'nouveau' }),
      adhLog: [{ date: '31/08/2026', what: 'Import CSV — ' + add.length + ' adhésion' + (add.length > 1 ? 's' : '') + ' créée' + (add.length > 1 ? 's' : ''), who: 'Sophie Marchand', canal: 'Import fichier' }].concat(s.adhLog)
    }));
    this.go('adherents');
    this.flash(add.length + ' adhérent' + (add.length > 1 ? 's' : '') + ' importé' + (add.length > 1 ? 's' : '') + ' — bulletins d\'adhésion à faire signer');
  },
adhVals() {
    const W = this.W();
    const visGroupes = this.state.groupes.filter(function (g) {
      return W.showCotis || !(g.crit && g.crit.statut && g.crit.statut !== 'Tous');
    });
    const f = this.state.adhF;
    const list = this.adhFiltered();
    const adhPage = Math.min(this.state.adhPage || 0, Math.max(0, Math.ceil(list.length / ADH_PER_PAGE) - 1));
    const pageList = list.slice(adhPage * ADH_PER_PAGE, (adhPage + 1) * ADH_PER_PAGE);
    const all = this.state.adherents;
    const sel = this.state.adhSel;
    const retard = all.filter((a) => a.statut === 'retard');
    const nouveaux = all.filter((a) => a.statut === 'nouveau');
    const ajour = all.filter((a) => a.statut === 'ajour');
    const tab = this.state.adhTab;
    const r = this.state.route;
    const a0 = this.curAdherent() || {id:'',prenom:'',nom:'',initials:'',statut:'nouveau'};
    const m = this.state.adhMsg;
    const tg = this.adhTargets();
    const opt = (arr, allLabel) => [allLabel].concat(arr).map((v) => ({ v: v }));
    const pill = (k) => ADH_STATUTS[k] || ADH_STATUTS.ajour;
    const recouv = Math.round((ajour.length / all.length) * 100);
    const modes = [
      { label: 'Prélèvement SEPA', n: all.filter((a) => a.mode.indexOf('Prélèvement') === 0).length },
      { label: 'Chèque en permanence', n: all.filter((a) => a.mode === 'Chèque').length },
      { label: 'Virement annuel', n: all.filter((a) => a.mode.indexOf('Virement') === 0).length }
    ].map((x) => ({ label: x.label, n: x.n + ' adhérents', w: Math.round((x.n / all.length) * 100) + '%' }));

    return {
      isList: r === 'adherents', isFiche: r === 'adherent', isMsg: r === 'adhmsg',
      title: W.memberTitle, kicker: W.memberKicker,
      importTitle: this.state.importMembers ? 'Importer les élus' : W.importTitle, msgTitle: W.msgTitle, listNote: W.listNote,
      tabList: tab === 'liste', tabGroupes: tab === 'groupes', tabCotis: tab === 'cotisations' && W.showCotis,
      tabs: [{ id: 'liste', label: W.memberTitle }, { id: 'groupes', label: 'Listes de diffusion' }].concat(W.showCotis ? [{ id: 'cotisations', label: W.moneyTab }] : []).map((x) => ({
        id: x.id, label: x.label, on: tab === x.id,
        bg: tab === x.id ? 'var(--surface)' : 'transparent', fg: tab === x.id ? 'var(--ink)' : 'var(--ink5)',
        go: () => this.setState({ adhTab: x.id })
      })),
      summary: W.showCotis
        ? all.length + ' adhérents suivis sur 3 entreprises · ' + retard.length + ' cotisations en retard · ' + nouveaux.length + ' adhésions à finaliser'
        : all.length + ' ' + W.memberMany + ' recensés sur 3 entreprises · ' + all.filter(function (a) { return !!a.mandat; }).length + ' porteurs de mandat · ' + visGroupes.length + ' listes de convocation',
      showCotis: W.showCotis,
      hideCotis: !W.showCotis,
      sensNote: W.showCotis
        ? "L'appartenance syndicale est une donnée sensible : le fichier reste chiffré sur l'appareil, n'est jamais transmis à l'employeur et les exports sont journalisés."
        : "Ce fichier relève du CSE, pas de l'employeur : il reste chiffré sur l'appareil, n'est jamais versé au fichier du personnel et les exports sont journalisés.",
      filterTitle: 'Filtrer les ' + W.memberMany,
      searchLabel: 'Rechercher un ' + W.memberOne,
      emptyNote: 'Aucun ' + W.memberOne + ' ne correspond à ces critères.',
      stats: W.showCotis ? [
        { value: String(all.length), label: 'adhérents actifs' },
        { value: recouv + ' %', label: 'à jour de cotisation' },
        { value: String(retard.length), label: 'retards à relancer' },
        { value: String(visGroupes.length), label: 'listes de diffusion' }
      ] : [
        { value: String(all.length), label: W.memberMany + ' recensés' },
        { value: String(all.filter(function (a) { return !!a.mandat; }).length), label: 'porteurs de mandat' },
        { value: String(ADH_CRIT.etab.length), label: 'établissements couverts' },
        { value: String(visGroupes.length), label: 'listes de convocation' }
      ],
      fq: f.q, onQ: (e) => this.setAdhF({ q: e.target.value }),
      filters: [
        { label: 'Entreprise', value: f.ent, opts: opt(ADH_CRIT.ent, 'Toutes'), on: (e) => this.setAdhF({ ent: e.target.value }) },
        { label: 'Établissement', value: f.etab, opts: opt(ADH_CRIT.etab, 'Tous'), on: (e) => this.setAdhF({ etab: e.target.value }) },
        { label: 'Section', value: f.sect, opts: opt(ADH_CRIT.sect, 'Toutes'), on: (e) => this.setAdhF({ sect: e.target.value }) },
        { label: 'Direction', value: f.dir, opts: opt(ADH_CRIT.dir, 'Toutes'), on: (e) => this.setAdhF({ dir: e.target.value }) },
        { label: 'Cotisation', value: f.statut, cotis: true, opts: [{ v: 'Tous' }, { v: 'ajour' }, { v: 'retard' }, { v: 'nouveau' }].map((o) => ({ v: o.v, label: o.v === 'Tous' ? 'Toutes' : pill(o.v).label })), on: (e) => this.setAdhF({ statut: e.target.value }) }
      ].filter(function (x) { return W.showCotis || !x.cotis; }).map((x) => ({ label: x.label, value: x.value, on: x.on, opts: x.opts.map((o) => ({ v: o.v, label: o.label || o.v })) })),
      resetFilters: () => this.setState({ adhF: { q: '', ent: 'Toutes', etab: 'Tous', sect: 'Toutes', dir: 'Toutes', statut: 'Tous' }, adhPage: 0 }),
      critChips: this.adhCritLabel(f),
      hasCrit: this.adhCritLabel(f).length > 0,
      countLabel: list.length + ' ' + (list.length > 1 ? W.memberMany : W.memberOne) + ' sur ' + all.length,
      selCount: sel.length,
      hasSel: sel.length > 0,
      selLabel: sel.length + ' sélectionné' + (sel.length > 1 ? 's' : ''),
      selectAll: () => this.setState({ adhSel: list.map((a) => a.id) }),
      clearSel: () => this.setState({ adhSel: [] }),
      msgSel: () => this.openAdhMsg({ cible: 'selection', modele: '', objet: '', corps: '' }),
      gName: this.state.adhGName,
      onGName: (e) => this.setState({ adhGName: e.target.value }),
      createGroup: () => this.createAdhGroup(),
      pageStart: list.length ? (adhPage * ADH_PER_PAGE + 1) : 0,
      pageEnd: Math.min(list.length, (adhPage + 1) * ADH_PER_PAGE),
      pageTotal: list.length,
      pageLabel: list.length ? ((adhPage * ADH_PER_PAGE + 1) + '–' + Math.min(list.length, (adhPage + 1) * ADH_PER_PAGE) + ' sur ' + list.length) : '',
      hasPager: list.length > ADH_PER_PAGE,
      pagePrevOff: adhPage === 0,
      pageNextOff: (adhPage + 1) * ADH_PER_PAGE >= list.length,
      pagePrev: () => this.setState((s) => ({ adhPage: Math.max(0, s.adhPage - 1) })),
      pageNext: () => this.setState((s) => ({ adhPage: Math.min(Math.ceil(list.length / ADH_PER_PAGE) - 1, s.adhPage + 1) })),
      list: pageList.map((a) => {
        const p = pill(a.statut);
        const on = sel.indexOf(a.id) >= 0;
        return {
          initials: a.initials, name: a.prenom + ' ' + a.nom, poste: a.poste,
          where: a.etab + ' · ' + a.sect,
          cotis: W.showCotis ? a.montant + ' · ' + a.mode : a.dir + ' · ' + a.ent,
          showPill: W.showCotis,
          statut: p.label, pillBg: p.bg, pillFg: p.fg,
          hasMandat: !!a.mandat, mandat: a.mandat,
          selected: on, checkBg: on ? 'var(--ac)' : 'var(--surface)', checkBd: on ? 'var(--ac)' : 'var(--bd2)',
          toggle: () => this.toggleAdhSel(a.id),
          open: () => this.go('adherent', { adherentId: a.id })
        };
      }),
      empty: list.length === 0,
      groupes: visGroupes.map((g) => {
        const gname = W.showCotis ? g.name : String(g.name).replace(/adhérents/gi, W.memberMany);
        const gdesc = W.showCotis ? g.desc : String(g.desc)
          .replace(/à chaque nouvelle adhésion/gi, 'à chaque changement de rattachement')
          .replace(/adhérents/gi, W.memberMany);
        const mem = this.groupMembers(g);
        const dyn = g.type === 'dyn';
        return {
          id:g.id,name: gname, desc: gdesc, canal: g.canal,
          typeLabel: dyn ? 'Dynamique' : 'Figée',
          typeBg: dyn ? 'var(--acBg)' : 'var(--chip)', typeFg: dyn ? 'var(--acTx2)' : 'var(--ink4)',
          count: mem.length + ' ' + (mem.length > 1 ? W.memberMany : W.memberOne),
          chips: dyn ? (this.adhCritLabel(g.crit).length ? this.adhCritLabel(g.crit) : ['Aucun critère — tous les ' + W.memberMany]) : ['Membres choisis à la main'],
          renameVal: gname,
          onRename: (e) => this.setState((s) => ({ groupes: s.groupes.map((x) => x.id === g.id ? Object.assign({}, x, { name: e.target.value }) : x) })),
          onDesc: (e) => this.setState((s) => ({ groupes: s.groupes.map((x) => x.id === g.id ? Object.assign({}, x, { desc: e.target.value }) : x) })),
          descVal: gdesc,
          editing: this.state.gEditId === g.id,
          reading: this.state.gEditId !== g.id,
          edit: () => this.setState({ gEditId: g.id, delKey: '' }),
          done: () => { this.setState({ gEditId: '' }); this.flash('Liste « ' + gname + ' » mise à jour'); },
          del: this.askDel('grp-' + g.id, 'Supprimer', () => {
            this.setState((s) => ({ groupes: s.groupes.filter((x) => x.id !== g.id), gEditId: '' }));
            this.flash('Liste de diffusion supprimée');
          }),
          send: () => this.openAdhMsg({ cible: 'groupe', groupeId: g.id, modele: '', objet: '', corps: '' }),
          showLabel: 'Voir les ' + W.memberMany,
          show: () => this.setState({ adhF: Object.assign({ q: '', ent: 'Toutes', etab: 'Tous', sect: 'Toutes', dir: 'Toutes', statut: 'Tous' }, g.crit || {}), adhTab: 'liste', adhPage: 0 })
        };
      }),
      recouvPct: recouv + ' %', recouvW: recouv + '%',
      cotisStats: [
        { value: '1 842 €', label: 'encaissé ce trimestre' },
        { value: '136 €', label: 'en attente de règlement' },
        { value: '66 %', label: 'de crédit d\'impôt pour l\'adhérent' }
      ],
      modes: modes,
      retards: retard.map((a) => ({
        name: a.prenom + ' ' + a.nom, where: a.etab + ' · ' + a.sect,
        du: a.du, mode: a.mode, echeance: a.echeance,
        relance: () => this.adhRelance(a.id),
        paid: () => this.adhMarkPaid(a.id),
        open: () => this.go('adherent', { adherentId: a.id })
      })),
      noRetard: retard.length === 0, emptyArrears:'Toutes les cotisations sont à jour.',
      relanceAll: () => this.openAdhMsg({ cible: 'groupe', groupeId: 'g3', modele: 'relance', objet: ADH_MSG_MODELS[0].objet, corps: ADH_MSG_MODELS[0].corps }),
      log: this.state.adhLog,
      newBulletin: () => this.adhBulletin(null),
      goImport: () => { this.setState({importMembers:false}); this.go('adhimport'); },
      imp: (() => {
        const txt = this.adhCsvText();
        const p = this.parseAdhCsv(txt);
        const hasTxt = txt.trim().length > 0;
        return {
          isImport: r === 'adhimport',
policy0:"Chaque ligne valide crée une adhésion au statut « Adhésion en cours », bulletin à faire signer.",
policy1:"Les doublons de courriel, dans le fichier comme dans le fichier des adhérents, sont écartés.",
policy2:"Une entreprise, section ou direction inconnue est créée à l'import et reste filtrable.",
policy3:"Le fichier n'est lu que sur l'appareil : rien n'est envoyé à un serveur, l'import est journalisé.",

          entityLabel: this.adminImportActive() ? 'élu(s)' : 'adhérent(s)',
          text: txt,
          onText: (e) => this.setState((s) => ({ adhImp: Object.assign({}, s.adhImp, { text: e.target.value, touched: true }) })),
          fileName: this.state.adhImp.fileName || 'Aucun fichier chargé',
          pick: () => this.pickCsvFile(),
          sample: () => this.loadCsvSample(),
          download: () => this.downloadCsvModel(),
          modelText: ADH_CSV_MODEL,
          cols: ADH_CSV_COLS.map((c) => ({ h: c.h, label: c.label, req: c.req ? 'obligatoire' : 'facultative', reqFg: c.req ? 'var(--acTx2)' : 'var(--ink6)' })),
          hasText: hasTxt,
          sepLabel: p.sep === ';' ? 'point-virgule' : 'virgule',
          okCount: p.ok, koCount: p.ko,
          summary: p.ok + ' ligne' + (p.ok > 1 ? 's' : '') + ' prête' + (p.ok > 1 ? 's' : '') + ' à importer · ' + p.ko + ' à corriger',
          hasMissing: (p.missing || []).length > 0,
          missing: (p.missing || []).join(', '),
          rows: p.rows.map((x) => ({
            line: 'L' + x.line,
            name: (x.rec.prenom + ' ' + x.rec.nom).trim() || '(sans nom)',
            where: [x.rec.etab, x.rec.sect].filter(Boolean).join(' · ') || '—',
            email: x.rec.email || '—',
            valid: x.valid, invalid: !x.valid,
            bd: x.valid ? 'var(--bd)' : 'var(--dangerBd2)',
            notes: x.errs.concat(x.warn).map((n) => ({ n: n })),
            hasNotes: x.errs.length + x.warn.length > 0,
            noteFg: x.valid ? 'var(--warnTx)' : 'var(--dangerTx2)'
          })),
          canImport: p.ok > 0,
          run: () => this.runCsvImport(),
          cancelLabel: this.adminImportActive() ? 'Retour aux membres' : 'Retour aux adhérents',
          cancel: () => { const admin = this.adminImportActive(); this.setState({importMembers:false}); this.go(admin ? 'membres' : 'adherents'); },
          clear: () => this.setState({ adhImp: { text: '', touched: false, fileName: '' } })
        };
      })(),

      fiche: {
        initials: a0.initials, name: a0.prenom + ' ' + a0.nom, poste: a0.poste,
        statut: pill(a0.statut).label, pillBg: pill(a0.statut).bg, pillFg: pill(a0.statut).fg,
        since: (W.showCotis ? 'Adhérent depuis ' : 'Recensé depuis ') + a0.since,
        hasMandat: !!a0.mandat, mandat: a0.mandat,
        showCotis: W.showCotis,
        showPill: W.showCotis,
        backLabel: 'Tous les ' + W.memberMany,
        listNote: W.showCotis
          ? 'Ces listes se déduisent du rattachement et du statut de cotisation : aucun ajout manuel à maintenir.'
          : 'Ces listes se déduisent du rattachement à l\'établissement, à la section et à la direction : aucun ajout manuel à maintenir.',
        coords: [
          { label: 'Courriel', value: a0.email }, { label: 'Téléphone', value: a0.tel },
          { label: 'Emploi', value: a0.poste }
        ].concat(W.showCotis ? [{ label: 'Bulletin', value: a0.bulletin }] : [{ label: 'Mandat', value: a0.mandat || 'Sans mandat' }]),
        crit: [
          { label: 'Entreprise', value: a0.ent }, { label: 'Établissement', value: a0.etab },
          { label: 'Section', value: a0.sect }, { label: 'Direction', value: a0.dir }
        ],
        cotis: [
          { label: 'Mode de règlement', value: a0.mode }, { label: 'Montant', value: a0.montant },
          { label: 'Dernier versement', value: a0.dernier }, { label: 'Prochaine échéance', value: a0.echeance }
        ],
        hasDu: !!a0.du, du: a0.du,
        groupes: this.state.groupes.filter((g) => this.groupMembers(g).some((x) => x.id === a0.id)).map((g) => ({ name: g.name })),
        histo: a0.statut === 'nouveau'
          ? [{ date: 'août 2026', what: 'Bulletin d\'adhésion reçu — mandat SEPA à signer', ok: false }]
          : [
            { date: 'août 2026', what: a0.statut === 'retard' ? 'Échéance non réglée — relance à envoyer' : 'Cotisation encaissée — ' + a0.montant, ok: a0.statut !== 'retard' },
            { date: 'juillet 2026', what: a0.statut === 'retard' ? 'Échéance non réglée' : 'Cotisation encaissée — ' + a0.montant, ok: a0.statut !== 'retard' },
            { date: 'juin 2026', what: 'Cotisation encaissée — ' + a0.montant, ok: true },
            { date: 'janvier 2026', what: 'Attestation fiscale 2025 transmise', ok: true }
          ],
        docs: W.showCotis ? [
          { label: 'Bulletin d\'adhésion', meta: a0.bulletin, action: a0.statut === 'nouveau' ? 'Générer' : 'Ouvrir', act: () => this.adhBulletin(a0) },
          { label: 'Attestation fiscale 2025', meta: 'Crédit d\'impôt de 66 % — PDF signé', action: 'Ouvrir', act: () => this.flash('Attestation fiscale ouverte depuis la base documentaire') },
          { label: 'Notice des droits de l\'adhérent', meta: 'Assistance juridique, fonds de solidarité', action: 'Envoyer', act: () => this.openAdhMsg({ cible: 'selection', modele: 'bienvenue', objet: ADH_MSG_MODELS[2].objet, corps: ADH_MSG_MODELS[2].corps, joinBulletin: true }) }
        ] : [
          { label: 'Attestation de mandat', meta: a0.mandat || 'Aucun mandat en cours', action: a0.mandat ? 'Ouvrir' : 'Générer', act: () => this.flash('Attestation de mandat ouverte depuis la base documentaire') },
          { label: 'Convocations reçues', meta: 'Séances et commissions du mandat en cours', action: 'Ouvrir', act: () => this.go('agenda') },
          { label: 'Notice des droits du représentant', meta: 'Heures de délégation, liberté de circulation, formation', action: 'Envoyer', act: () => this.openAdhMsg({ cible: 'selection', modele: '', objet: 'Vos droits de représentant du personnel', corps: '' }) }
        ],
        editing: this.state.adhEdit,
        reading: !this.state.adhEdit,
        startEdit: () => this.adhStartEdit(),
        cancelEdit: () => this.adhCancelEdit(),
        saveEdit: () => this.adhSaveEdit(),
        fields: this.adhFieldDefs().map((f) => ({
          label: f.label,
          value: ((this.state.adhDraft || a0)[f.k]) || '',
          on: (e) => this.adhPatchDraft(f.k, e.target.value)
        })),
        del: this.askDel('adh-' + a0.id, 'Retirer du fichier', () => this.adhDelete(a0.id)),
        back: () => this.go('adherents'),
        msg: () => { this.setState({ adhSel: [a0.id] }); this.openAdhMsg({ cible: 'selection', modele: '', objet: '', corps: '' }); },
        relance: () => this.adhRelance(a0.id),
        paid: () => this.adhMarkPaid(a0.id),
        canPaid: a0.statut !== 'ajour'
      },

      msg: this.campaignVals()
    };
  }});return Object.freeze(Object.fromEntries(["createAdhGroup","adhFieldDefs","adhStartEdit","adhCancelEdit","adhPatchDraft","adhSaveEdit","adhDelete","adhMarkPaid","adhRelance","adhBulletin","parseAdhCsv","adhCsvText","loadCsvSample","runCsvImport","adhVals"].map(n=>[n,context[n].bind(context)])));}

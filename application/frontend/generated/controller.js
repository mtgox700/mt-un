import React from 'react';import {planDocumentPages} from '../extensions/document-pages.js';import {prepareCaseColumns,prepareCaseHome} from '../modules/cases/presenter.js';import {prepareClassicBlock,prepareClassicPage} from '../extensions/classic-layout.js';import {DCLogic} from '../host/controller-base.js';import {setNoClickUntil,FONT_PAIRS,BRAND_PRESETS,DEFAULT_BRAND,ICONS,MARKER_DEFS,REUNION_TYPES,REUNIONS,DOC_FORMATS,DOC_FONTS,BLOCK_DEFS,DOC_MODELS,ADH_CRIT,ADH_STATUTS,ADHERENTS,ADH_CSV_COLS,ADH_CSV_MODEL,ADH_GROUPES,ADH_MSG_MODELS,ELUS,DOSSIERS,PIECES,POLLS,CONVOS,CONTACTS,CONVO_META,CT_CATS,AV_BG,WHO_FG,MOB_ST,MOB_ST_C,MOB_KIND,MOB_AUD,MOB_TPL,MOB_SEED,UNII_ROLES,UNII_MODS,UNII_ACTS,COM_ST,COM_ST_C,COM_OBJ,COM_FMT,COM_SEED,COM_MOMENTS,COM_FORMULES,COM_SUPPORTS,FM_IA,FM_PARCOURS,FM_FORMATS,FM_GEN,FM_SUGG,FM_TYPE_C,AI_CORPUS,AI_SYS,DOCS,SIGDOCS,NO_CLICK_UNTIL,STATUS_LABELS,ADH_PER_PAGE,SHORTCUTS,PLANS,FACTURES,ADM_USERS,ADM_ORGS,ADM_KEYS,ADM_LOGS,PLAN_PRIX,PLAN_MIGRATE,planPrix,planNom,STORE_KEY,SEED_MERGE_KEYS,EXT_API,CORE_DOC_TYPES,PLAN_RANK,PERSIST_KEYS} from './constants.js';import {methods as theme} from '../modules/theme/controller.js';
import {methods as cases} from '../modules/cases/controller.js';
import {methods as contacts} from '../modules/contacts/controller.js';
import {methods as navigation} from '../modules/navigation/controller.js';
export class Component extends DCLogic {
  waRef = React.createRef();
  state = {
    route: 'accueil', history: [], isDesktop: true, isWide: true,
    org: {
      type: 'section',
      nom: 'Section syndicale Métallurgie — Valenciennes',
      sigle: 'SECTION MÉTA VAL',
      siret: '412 857 336 00021',
      idcc: '3109 — Métallurgie (convention collective nationale)',
      effectif: '1 240',
      sieges: '24',
      mandatDebut: '2024-01-15',
      mandatFin: '2028-01-14',
      adresse: 'Local syndical — 12 rue de la Fonderie, 59300 Valenciennes',
      email: 'section@syndicat-valenciennes.fr',
      tel: '03 27 14 88 20',
      tresorier: 'Karim Benali',
      secretaire: 'Sophie Marchand'
    },
    orgEdit: false, orgDraft: null,
    shortcuts: SHORTCUTS, scDraft: null, scArmDel: null,
    navOrder: ['accueil','assistant','dossiers','messagerie','agenda','reunions','documents','formations','communication','mobile','adherents','intranet','reporting','raccourcis','params'],
    adherents: ADHERENTS, groupes: ADH_GROUPES, adherentId: 'a1', adhTab: 'liste', adhSel: [],
    adhF: { q: '', ent: 'Toutes', etab: 'Tous', sect: 'Toutes', dir: 'Toutes', statut: 'Tous' },
    adhGName: '',
    adhEdit: false, adhDraft: null, delKey: '', gEditId: '', dosEdit: false, adhPage: 0,
    adhImp: { text: '', touched: false, fileName: '' },
    adhMsg: { cible: 'selection', groupeId: 'g1', canal: 'email', modele: '', objet: '', corps: '', joinBulletin: false },
    adhLog: [
      { date: '28/08/2026', what: 'Relance de cotisation — 3 adhérents en retard', who: 'Jean-Paul Diallo', canal: 'E-mail' },
      { date: '21/08/2026', what: 'Convocation assemblée du 2 septembre — 12 adhérents', who: 'Sophie Marchand', canal: 'E-mail + SMS' },
      { date: '14/08/2026', what: 'Bienvenue — 2 nouvelles adhésions', who: 'Sophie Marchand', canal: 'E-mail' }
    ],
    authed: false, adminAuthed: false, admRoute: 'supervision', admQuery: '', admFilter: 'Tous', admSel: null, admKeyNew: false, admKeyDraft: { label: '', fournisseur: 'Mistral (Paris)', quota: 40 }, admReveal: null,
    plan: 'p2', planCycle: 'mois', planCard: { nom: 'Section Métallurgie Valenciennes', num: '•••• •••• •••• 4417', exp: '08/2029', type: 'Visa' }, factures: FACTURES, planConfirm: null,
    admEditor: { maintenance: false, inscriptions: true, banniere: '', iaPublique: true, versionPrompt: 'v4.2', retention: '36 mois' },
    admUsers: ADM_USERS, admOrgs: ADM_ORGS, admKeys: ADM_KEYS, admLogs: ADM_LOGS,
    auth: { step: 'id', email: 'sophie.marchand@syndicat-valenciennes.fr', pwd: '', code: '', err: '', sso: false },
    sig: { docId: 'pv', style: 'script', name: 'Sophie Marchand', consent: false },
    signed: {},
    previewOpen: false,
    dossiers: DOSSIERS.map(function (d) { return Object.assign({}, d, { timeline: d.timeline.slice() }); }),
    dossierId: 'harcelement', noteDraft: '',
    pollId: 'nao',
    pollsData: POLLS.slice(),
    pieces: JSON.parse(JSON.stringify(PIECES)), pieceId: 'f1', upload: null,


    repPeriod: 'year', repTab: 'cse',
    brand: DEFAULT_BRAND,
    brandDraft: DEFAULT_BRAND,
    brandPreview: false, brandScope: 'org', brandTab: 'couleurs',
    brandLog: [
      { date: '12/03/2024', who: 'Karim Benali', what: 'Identité initiale publiée — accent orange uniion' }
    ],
    dchats: {}, dchatDraft: '', dchatTyping: false, cardAi: null,
    np: { step: 1, title: '', type: 'unique', options: ['', ''], target: 'all', close: '7', remind: true, mod: 'draft' },
    query: '', toast: '',
    draftId: '', sigOrigin: '', drag: null, grabbed: '',
    sheet: '', sheetCtx: {}, sheetOpt: 0, sheetText: '', sheetChecks: [0, 1], sheetDone: false, sheetErr: '',
    viewerId: '', viewerKind: 'doc',
    anonOpen: false, anonQuery: '', anonLevel: 'standard', anonPieces: 0, anonOrigin: 'Assistant', aiCalls: 38,
    input: '', typing: false,
    aiErr: '', aiBusy: false, docGen: null,
    messages: [{ isBot: true, source: 'uniion Assistant', text: "Bonjour Sophie. Je peux répondre sur la Convention Métallurgie, le Code du travail ou analyser un accord d'entreprise." }],
    aiConvId: null, aiConvFilter: 'Toutes', asstFull: false,
    aiMemOn: true, memDraft: '', memCat: 'Mandat & organisation', memEdit: null, memWipe: false,
    aiMem: [
      { id: 'm1', cat: 'Mandat & organisation', text: 'Élue titulaire au CSE et secrétaire adjointe ; mandat jusqu’en juin 2027.', on: true, src: 'Ajouté manuellement', at: Date.now() - 86400e3 * 20 },
      { id: 'm2', cat: 'Textes applicables', text: 'Convention collective nationale de la Métallurgie applicable ; accord d’entreprise télétravail signé en mars 2025.', on: true, src: 'Proposé par l’assistant', at: Date.now() - 86400e3 * 12 },
      { id: 'm3', cat: 'Préférences de rédaction', text: 'Réponses courtes : d’abord le délai légal, puis un plan d’action daté.', on: true, src: 'Ajouté manuellement', at: Date.now() - 86400e3 * 6 },
      { id: 'm4', cat: 'Sujets en cours', text: 'NAO 2026 ouverte : revendication de 4,5 % d’augmentation générale.', on: true, src: 'Retenu depuis une réponse', at: Date.now() - 86400e3 * 2 }
    ],
    aiConvs: [
      { id: 'seed-c1', title: 'Heures de délégation non payées en cas d\'arrêt maladie', origin: 'Assistant', updated: Date.now() - 3600e3 * 26, messages: [
        { isUser: true, text: 'Mes heures de délégation sont-elles payées si je suis en arrêt maladie ?' },
        { isBot: true, source: 'Code du travail — art. L2315-10', text: "Non : pendant la suspension du contrat pour maladie, le mandat se poursuit mais les heures de délégation ne sont pas rémunérées comme temps de travail, sauf accord plus favorable.\n\nSources\n· Code du travail — art. L2315-10 — https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000035627400" }
      ] },
      { id: 'seed-c2', title: 'Projet de PV — CSE ordinaire de septembre', origin: 'Réunions', originRoute: 'reunions', updated: Date.now() - 3600e3 * 72, ctx: 'Séance CSE ordinaire · ordre du jour : NAO, plan de formation, ASC.', messages: [
        { isBot: true, source: 'Contexte importé', text: 'Contexte importé depuis Réunions : CSE ordinaire de septembre. Je m\'appuie dessus pour la suite.' },
        { isUser: true, text: 'Le vote sur le plan de formation est-il valable si deux titulaires étaient absents ?' },
        { isBot: true, source: 'Code du travail — art. L2315-32', text: "Oui si le quorum n'est pas exigé : les résolutions du CSE sont prises à la majorité des membres présents, l'absence de titulaires non suppléés ne l'invalide pas.\n\nSources\n· Code du travail — art. L2315-32 — https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000035627476\n· PV — CSE ordinaire de septembre — Réunions › CSE ordinaire" }
      ] }
    ],
    newTitle: '', newTag: 'Juridique', newDesc: '',
    reunions: REUNIONS.map(function (x) { return Object.assign({}, x, { markers: x.markers.slice(), access: x.access.slice() }); }),
    reunionId: 'r-0812',
    rec: { phase: 'consent', c1: false, c2: false, t: 0, level: 0, wave: [], markers: [], sim: false, err: '', type: 'CSE ordinaire' },
    audioImport: null,
    docs: [
      { id: 'd-nao', title: 'NAO 2027 — où en sont les négociations', model: 'nao', format: 'wide', status: 'Brouillon', updated: 'il y a 20 min', blocks: null },
      { id: 'd-atelier', title: 'Courrier — enquête paritaire atelier B', model: 'courrier', format: 'a4', status: 'Signé', updated: 'hier', blocks: null },
      { id: 'd-cr', title: 'Compte rendu — séance du 26 août', model: 'cr', format: 'a4', status: 'Relu', updated: 'il y a 3 jours', blocks: null }
    ],
    docId: 'd-nao', docTab: 'contenu', docMode: 'blocks', docZoom: .72, docSrcDraft: null,
    pages: [
      {
        id: 'p-nao', title: 'NAO 2027 : où en sont les négociations ?', rubrique: 'actus', slug: 'nao-2027-point-etape',
        status: 'Brouillon', updated: 'il y a 12 min', author: 'Sophie Marchand', review: null, pub: null,
        chapo: 'Trois séances de négociation se sont tenues depuis juin. Voici ce que la direction propose, ce que nous demandons, et la suite du calendrier.',
        blocks: [
          { id: 'p-nao-1', t: 'p', text: 'La direction a présenté le 20 août une enveloppe d\'augmentation générale de 0,8 %, hors mesures individuelles. Vos élus ont rappelé que l\'inflation constatée sur douze mois s\'établit à 2,1 %.' },
          { id: 'p-nao-2', t: 'h2', text: 'Nos revendications' },
          { id: 'p-nao-3', t: 'list', items: ['Augmentation générale de 2,5 % pour tous les coefficients', 'Talon de 60 € mensuels pour les salaires sous 2 000 €', 'Revalorisation de la prime de transport gelée depuis 2023'] },
          { id: 'p-nao-4', t: 'callout', text: 'Le sondage mené auprès des salariés a recueilli 312 réponses : 78 % placent le pouvoir d\'achat en première priorité.' },
          { id: 'p-nao-5', t: 'h2', text: 'Prochaine étape' },
          { id: 'p-nao-6', t: 'p', text: 'La quatrième séance est fixée au 12 septembre. Un compte rendu sera publié dans les 48 heures suivant la réunion.' },
          { id: 'p-nao-7', t: 'cta', text: 'Donner votre avis avant la séance', href: '/intranet/sondages/nao-2027' },
          { id: 'p-nao-8', t: 'file', text: 'Tableau comparatif des propositions (PDF, 210 Ko)' }
        ]
      },
      { id: 'p-cssct', title: 'Sécurité atelier B : ce que le CSE a obtenu', rubrique: 'actus', slug: 'securite-atelier-b', status: 'Relue', updated: 'hier', author: 'Jean-Paul Deniau', review: { by: 'Sophie Marchand', note: 'Deux tournures adoucies, chiffres vérifiés au registre CSSCT.' }, pub: null, chapo: 'Après l\'accident du 25 août, l\'enquête paritaire a abouti à quatre mesures immédiates.', blocks: null },
      { id: 'p-cheques', title: 'Chèques vacances 2026 : mode d\'emploi', rubrique: 'asc', slug: 'cheques-vacances-2026', status: 'En attente webmaster', updated: 'il y a 2 j', author: 'Karim Belkacem', review: { by: 'Sophie Marchand', note: 'Validée en commission ASC.' }, pub: { date: '1er septembre 2026', vis: 'Tous les salariés', ref: 'PUB-2026-041', sentAt: 'il y a 2 j', msg: 'À mettre en ligne en tête de la rubrique ASC, avant l\'ouverture des demandes.' }, chapo: 'Barème, plafonds et calendrier des commandes pour la campagne 2026.', blocks: null },
      { id: 'p-permanences', title: 'Permanences des élus — rentrée 2026', rubrique: 'cse', slug: 'permanences-rentree-2026', status: 'Publiée', updated: 'il y a 6 j', author: 'Sophie Marchand', review: { by: 'Karim Belkacem', note: 'OK.' }, pub: { date: '22 août 2026', vis: 'Tous les salariés', ref: 'PUB-2026-038', sentAt: 'il y a 8 j', msg: '' }, chapo: 'Horaires et lieux des permanences sur les trois sites, de septembre à décembre.', blocks: null },
      { id: 'p-pub-home', site: 'public', title: 'Accueil — Section syndicale Métallurgie Valenciennes', rubrique: 'pub-accueil', slug: 'accueil', status: 'Publiée', updated: 'il y a 11 j', author: 'Karim Belkacem', review: { by: 'Sophie Marchand', note: 'Validée en bureau de section.' }, pub: { date: '25 août 2026', vis: 'Public — indexé', ref: 'PUB-2026-036', sentAt: 'il y a 12 j', msg: '' }, chapo: 'Nous défendons les 840 salariés de la métallurgie du Valenciennois. Voici nos combats du moment.', blocks: null },
      { id: 'p-pub-nao', site: 'public', title: 'Salaires : la direction s\'arrête à 0,8 %, nous continuons', rubrique: 'pub-actus', slug: 'communique-nao-septembre', status: 'Relue', updated: "aujourd'hui", author: 'Sophie Marchand', review: { by: 'Karim Belkacem', note: 'Relu pour la presse : aucun nom de salarié, aucun chiffre de séance non public.' }, pub: null, chapo: 'Communiqué de la section à l\'issue de la troisième séance de négociation annuelle.', blocks: null },
      { id: 'p-pub-adherer', site: 'public', title: 'Adhérer à la section', rubrique: 'pub-adhesion', slug: 'adherer', status: 'Brouillon', updated: 'il y a 4 j', author: 'Karim Belkacem', review: null, pub: null, chapo: 'Ce que couvre la cotisation, comment elle est calculée, et le bulletin d\'adhésion en ligne.', blocks: null },
      { id: 'p-teletravail', title: 'Télétravail : vos droits après l\'avenant', rubrique: 'droits', slug: 'teletravail-avenant-2026', status: 'Retournée', updated: 'il y a 3 j', author: 'Sophie Marchand', review: { by: 'Jean-Paul Deniau', note: 'Relue le 24 août.' }, pub: { date: '28 août 2026', vis: 'Tous les salariés', ref: 'PUB-2026-039', sentAt: 'il y a 4 j', msg: '', back: 'Le visuel d\'en-tête pèse 3,2 Mo — merci de fournir une image sous 400 Ko, ou je publie sans visuel.' }, chapo: 'L\'avenant du 1er juillet ouvre deux jours par semaine et clarifie l\'indemnité d\'équipement.', blocks: null }
    ],
    pageId: 'p-nao', webTab: 'apercu', pageHtmlDraft: null, webRole: true, webSite: 'intranet',
    webGen: { model: 'actu', rubrique: 'actus', prompt: 'Séance NAO du 20 août : la direction propose 0,8 %, nous demandons 2,5 % et un talon de 60 €. Prochaine séance le 12 septembre. Renvoyer vers le sondage salariés.', tone: 'Clair', clair: true, resume: true, phase: 'empty' },
    pubForm: { slug: '', date: '2026-09-03', vis: 'Tous les salariés', msg: '', attach: true, notify: true, home: true },
    wcSite: 'intranet',
    webCharte: {
      intranet: { inherit: true, accent: '#DC2626', head: '#1F2937', titleFont: 'Philosopher, Georgia, serif', width: 760, logo: true, logoSrc: '', logoScale: 100, gabarit: 'actu', nav: 'inline', radius: 'doux' },
      public: { inherit: false, accent: '#E11D48', head: '#1E293B', titleFont: 'Philosopher, Georgia, serif', width: 820, logo: true, logoSrc: '', logoScale: 100, gabarit: 'dense', nav: 'bar', radius: 'doux' }
    },
    charte: {
      accent: '#DC2626', ink: '#111827', titleFont: 'philosopher', bodyFont: 'inter', density: 'standard',
      logo: 'uniion-logo.png', header: true, footer: true, caps: false,
      emetteur: '', section: '', email: '', phone: '03 27 14 88 20'
    },
    docType: 'Tract', tone: 'Combatif', prompt: "NAO 2027 — la direction propose 0,8 %. 68 % des salariés demandent une revalorisation générale. Appeler à l'AG du personnel mardi.", tract: 'empty',
    keyRevealed: false, keySaved: false, provider: 'anthropic', prudence: 'Élevée',
    flags: { visible: true, push: true, email: true, sms: false, dnd: true, escalade: true, mfa: true, bio: true, sso: false, sourcing: true },
    devices: [
      { id: 'd1', name: 'iPhone 15 — Sophie', meta: 'Valenciennes · actif à l\'instant' },
      { id: 'd2', name: 'MacBook Air — bureau CSE', meta: 'Valenciennes · il y a 2 jours' },
      { id: 'd3', name: 'Chrome — Windows', meta: 'Lille · il y a 3 semaines' }
    ],
    members: [
      { id: 'm1', name: 'Sophie Marchand', initials: 'SM', role: 'Admin organisation', last: 'en ligne', status: 'Actif' },
      { id: 'm2', name: 'Jean-Paul Diallo', initials: 'JD', role: 'Élu titulaire', last: 'il y a 1 h', status: 'Actif' },
      { id: 'm3', name: 'Leïla Chaïb', initials: 'LC', role: 'Commission ASC', last: 'hier', status: 'Actif' },
      { id: 'm4', name: 'Marc Aubert', initials: 'MA', role: 'Suppléant', last: 'jamais connecté', status: 'Invité' },
      { id: 'm5', name: 'Cabinet Berger (avocat)', initials: 'CB', role: 'Lecture seule', last: 'il y a 6 jours', status: 'Suspendu' }
    ],
    unread: true, notifRead: {},
    convos: CONVOS.map(function (c) { return Object.assign({}, c, { messages: c.messages.slice(), unread: c.id === 'nego' ? 2 : (c.id === 'jd' ? 1 : 0) }); }),
    convoId: 'nego', msgDraft: '', contacts: CONTACTS, waPane: 'chats', waQ: '', waF: 'all', waInfo: false, navMini: false, fmTab: 'ia', fmQ: '', fmType: 'Tous', fmCat: 'Toutes', fmMode: 'all', fmReq: {}, fmSessions: [], fmSessId: null, fmBusy: false, fmSetup: { theme: '', dur: 30, level: 'Découverte', role: 'Élu·e CSE', goal: '' }, fmChat: '', fmChatBusy: false, fmRevBusy: false, waMenu: null, waReply: null, fwdMsg: null, fwdSel: [], fwdQ: '', dosPick: null, dosQ: '', ctEdit: null, grEdit: null, grQ: '', ctQ: '', ctCat: 'all',
    cached: {}, autoSync: true, syncing: false, lastSync: 'jamais',
    onb: { convention: true, commissions: false, membres: false, notifs: false },
    site: 'Tous les sites'
  };

  /*@method:theme:hexToHsl*/

  /*@method:theme:hsl*/

  

  /*@method:theme:brandTokens*/

  /*@method:theme:applyTheme*/

  

  

  /*@method:theme:publishBrand*/

  componentDidUpdate() {
    this.applyTheme(); this.persist();
    const cv = this.curConvo();
    const sig = this.state.route + '|' + (cv ? cv.id + ':' + cv.messages.length : '') + '|' + (this.state.thBusy ? 1 : 0) + '|' + (this.state.uniiOpen ? 1 : 0);
    if (sig !== this._waSig) { this._waSig = sig; const el = this.waRef.current; if (el) el.scrollTop = el.scrollHeight; }
    if (this._lastMsgs !== this.state.messages) {
      const first = this._lastMsgs === undefined;
      this._lastMsgs = this.state.messages;
      if (!first) this.convSync();
    }
  }

  /* ---- Mémoire locale de l'assistant ---- */
  memPrompt() {
    if (!this.state.aiMemOn) return '';
    const items = (this.state.aiMem || []).filter((x) => x.on);
    if (!items.length) return '';
    const raw = items.map((x) => '- [' + x.cat + '] ' + x.text).join('\n');
    const m = this.maskText(raw, this.detectLevel(raw));
    return m.residual.length ? '' : m.masked;
  }
  memNovel(t) {
    const s = String(t || '').trim();
    if (s.length < 8) return '';
    const low = s.toLowerCase();
    return (this.state.aiMem || []).some((x) => x.text.toLowerCase() === low) ? '' : s.slice(0, 280);
  }
  memAdd(text, cat, src) {
    const t = String(text || '').trim();
    if (!t) { this.flash('Écrivez le fait à retenir'); return false; }
    this.setState((s) => ({ aiMem: [{ id: 'm' + Date.now(), cat: cat || 'Sujets en cours', text: t.slice(0, 400), on: true, src: src || 'Ajouté manuellement', at: Date.now() }].concat(s.aiMem || []) }));
    this.flash('Ajouté à la mémoire — modifiable dans Réglages › Mémoire');
    return true;
  }
  msgPatch(i, patch) { this.setState((s) => ({ messages: s.messages.map((m, j) => (j === i ? Object.assign({}, m, patch) : m)) })); }
  memVals() {
    const CATS = ['Mandat & organisation', 'Textes applicables', 'Préférences de rédaction', 'Sujets en cours'];
    const all = this.state.aiMem || [];
    const on = !!this.state.aiMemOn;
    const ed = this.state.memEdit;
    const fmt = (t) => new Date(t || Date.now()).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });
    const groups = CATS.concat(all.map((x) => x.cat).filter((c) => CATS.indexOf(c) < 0)).filter((c, i, a) => a.indexOf(c) === i)
      .map((c) => ({ label: c, items: all.filter((x) => x.cat === c) })).filter((g) => g.items.length)
      .map((g) => ({
        label: g.label, count: g.items.length,
        items: g.items.map((x) => ({
          text: x.text, meta: x.src + ' · ' + fmt(x.at),
          editing: !!(ed && ed.id === x.id), notEditing: !(ed && ed.id === x.id),
          editText: ed && ed.id === x.id ? ed.text : '',
          onEdit: (e) => this.setState({ memEdit: { id: x.id, text: e.target.value } }),
          edit: () => this.setState({ memEdit: { id: x.id, text: x.text } }),
          cancel: () => this.setState({ memEdit: null }),
          save: () => {
            const t = String((this.state.memEdit || {}).text || '').trim();
            if (!t) return this.flash('Le texte ne peut pas être vide');
            this.setState((s) => ({ memEdit: null, aiMem: s.aiMem.map((y) => (y.id === x.id ? Object.assign({}, y, { text: t, at: Date.now() }) : y)) }));
            this.flash('Élément de mémoire mis à jour');
          },
          swBg: x.on ? 'var(--ok)' : 'var(--bd2)', swLeft: x.on ? '21px' : '3px', textFg: x.on ? 'var(--ink)' : 'var(--ink6)',
          swLabel: x.on ? 'Actif — désactiver' : 'Inactif — activer',
          toggle: () => this.setState((s) => ({ aiMem: s.aiMem.map((y) => (y.id === x.id ? Object.assign({}, y, { on: !y.on }) : y)) })),
          del: () => { this.setState((s) => ({ aiMem: s.aiMem.filter((y) => y.id !== x.id) })); this.flash('Élément oublié'); }
        }))
      }));
    const act = all.filter((x) => x.on).length;
    return {
      on: on, swBg: on ? 'var(--ok)' : 'var(--bd2)', swLeft: on ? '23px' : '3px',
      toggleAll: () => { this.setState({ aiMemOn: !on }); this.flash(on ? 'Mémoire suspendue — rien n’est transmis au modèle' : 'Mémoire réactivée'); },
      statusLine: on ? act + ' élément' + (act > 1 ? 's' : '') + ' actif' + (act > 1 ? 's' : '') + ' transmis (anonymisés) à chaque requête IA' : 'Mémoire suspendue : aucun élément n’est transmis au modèle',
      short: on ? 'Mémoire · ' + act : 'Mémoire off',
      cats: CATS.map((c) => ({ label: c, bg: c === this.state.memCat ? 'var(--acBg)' : 'var(--surf2)', fg: c === this.state.memCat ? 'var(--acTx)' : 'var(--ink5)', go: () => this.setState({ memCat: c }) })),
      draft: this.state.memDraft,
      onDraft: (e) => this.setState({ memDraft: e.target.value }),
      add: () => { if (this.memAdd(this.state.memDraft, this.state.memCat, 'Ajouté manuellement')) this.setState({ memDraft: '' }); },
      groups: groups, empty: !all.length, hasAny: !!all.length,
      wipeLabel: this.state.memWipe ? 'Confirmer : tout effacer définitivement' : 'Tout oublier',
      wipe: () => {
        if (!this.state.memWipe) { this.setState({ memWipe: true }); clearTimeout(this._mw); this._mw = setTimeout(() => this.setState({ memWipe: false }), 4000); return; }
        this.setState({ aiMem: [], memWipe: false, memEdit: null }); this.flash('Mémoire effacée de ce navigateur');
      },
      open: () => this.go('memoire')
    };
  }

  /* ---- Historique des conversations IA ---- */
  convGreeting() { return [{ isBot: true, source: 'uniion Assistant', text: "Nouvelle conversation. Posez votre question : je réponds en citant mes sources." }]; }
  curConv() { const id = this.state.aiConvId; return id ? (this.state.aiConvs || []).find((c) => c.id === id) || null : null; }
  convSync() {
    const msgs = this.state.messages || [];
    if (!this.state.aiConvId && !msgs.some((m) => m.isUser)) return;
    const id = this.state.aiConvId || ('c' + Date.now());
    this.setState((s) => {
      const list = s.aiConvs || [];
      const ex = list.find((c) => c.id === id);
      const q = (msgs.find((m) => m.isUser) || {}).text || 'Nouvelle conversation';
      const conv = Object.assign({ id: id, title: String(q).slice(0, 80), origin: s.asstIntake ? 'Dossiers' : 'Assistant', intake: !!s.asstIntake }, ex || {}, { messages: msgs, updated: Date.now() });
      return { aiConvId: id, aiConvs: [conv].concat(list.filter((c) => c.id !== id)) };
    });
  }
  convNew() { this.setState({ aiConvId: null, asstIntake: false, messages: this.convGreeting(), input: '' }); }
  convIntake() {
    this.setState({ aiConvId: null, asstIntake: true, input: '', messages: [{ isBot: true, source: 'unii · ouverture de dossier', text: "Décrivez la situation : qui est concerné (fonction, service), les faits et leurs dates, ce que demande le salarié. Je vous pose les questions manquantes ; quand vous êtes prêt, cliquez « Créer le dossier » : je l’intitule, le qualifie et propose un plan d’action." }] });
  }
  convOpen(id) {
    const c = (this.state.aiConvs || []).find((x) => x.id === id);
    if (c) this.setState({ aiConvId: id, asstIntake: false, messages: c.messages, typing: false });
  }
  convDel(id) {
    this.setState((s) => ({ aiConvs: (s.aiConvs || []).filter((c) => c.id !== id) }));
    if (this.state.aiConvId === id) this.convNew();
    this.flash('Conversation supprimée de l’historique');
  }
  convHistoryText() {
    const msgs = (this.state.messages || []).filter((m) => m.isUser || m.isBot).slice(-7, -1);
    return msgs.map((m) => (m.isUser ? 'Élu : ' + (m.payload || m.text) : 'Assistant : ' + String(m.text || '').slice(0, 600))).join('\n');
  }
  toAssistant(o) {
    const lvl = this.detectLevel(o.ctx || '');
    const m = this.maskText(o.ctx || '', lvl);
    if (m.residual.length) { this.flash('Contexte non transmissible — un identifiant échappe au filtre'); return; }
    const id = 'c' + Date.now();
    const seed = [{ isBot: true, source: 'Contexte importé', text: 'Contexte importé depuis ' + o.origin + ' : ' + o.title + '. Je m’appuie dessus pour la suite de la conversation' + (m.tags.length ? ' (' + m.tags.length + ' entité' + (m.tags.length > 1 ? 's' : '') + ' masquée' + (m.tags.length > 1 ? 's' : '') + ')' : '') + '.' }].concat(o.messages || []);
    const conv = { id: id, title: o.title, origin: o.origin, originRoute: o.route, originParams: o.params || null, dossierId: o.dossierId || null, ctx: m.masked, messages: seed, updated: Date.now() };
    this.setState((s) => ({ aiConvs: [conv].concat(s.aiConvs || []), aiConvId: id, messages: seed, typing: false, input: '' }));
    this.go('assistant');
    if (typeof window !== 'undefined') window.scrollTo(0, 0);
    this.flash('Sujet transféré dans l’Assistant — historique conservé');
  }
  convToDossier() {
    const c = this.curConv();
    let msgs = (this.state.messages || []).filter((m) => m.isUser || m.isBot);
    const draftIn = String(this.state.input || '').trim();
    if (!msgs.some((m) => m.isUser) && draftIn) { msgs = msgs.concat([{ isUser: true, text: draftIn }]); this.setState({ input: '' }); }
    if (!msgs.some((m) => m.isUser)) { this.flash('Décrivez la situation avant de créer un dossier'); return; }
    const dm = msgs.map((m) => (m.isUser ? { isUser: true, text: m.text } : { isBot: true, source: m.source || 'uniion Assistant', text: m.text }));
    const pairs = [];
    msgs.forEach((m) => { if (m.isUser) pairs.push({ q: m.text, a: '' }); else if (pairs.length && !pairs[pairs.length - 1].a) { pairs[pairs.length - 1].a = m.text; pairs[pairs.length - 1].src = m.source; } });
    const exch = pairs.map((p) => ({ date: "Aujourd'hui", title: 'Échange IA — ' + (p.src || 'Assistant'), body: 'Q : ' + String(p.q).slice(0, 220) + (p.a ? '\nR : ' + String(p.a).slice(0, 420) : '') }));
    const exist = c && c.dossierId && this.state.dossiers.find((d) => d.id === c.dossierId);
    if (exist) {
      this.setState((s) => ({
        asstFull: false,
        dchats: Object.assign({}, s.dchats, { [exist.id]: dm }),
        dossiers: s.dossiers.map((d) => (d.id === exist.id ? Object.assign({}, d, { timeline: [{ date: "Aujourd'hui", title: 'Conversation Assistant rattachée', body: pairs.length + ' échange' + (pairs.length > 1 ? 's' : '') + ' versé' + (pairs.length > 1 ? 's' : '') + ' au dossier depuis l’Assistant.' }].concat(d.timeline || []) }) : d))
      }));
      this.go('dossier', { dossierId: exist.id });
      this.flash('Conversation versée au dossier « ' + exist.title + ' »');
      return;
    }
    const title = (c && c.title && c.title !== 'Nouvelle conversation' ? c.title : String(pairs[0].q)).slice(0, 80);
    const transcript = pairs.map((p) => 'Q : ' + p.q + (p.a ? '\nR : ' + p.a : '')).join('\n\n');
    const cid = this.state.aiConvId;
    this.buildDossier({
      title: title, desc: String(pairs[0].q).slice(0, 220),
      long: (c && c.ctx ? 'Contexte importé (' + c.origin + ') : ' + c.ctx + '\n\n' : '') + transcript,
      timeline: [{ date: "Aujourd'hui", title: 'Dossier créé depuis l’Assistant IA', body: 'Conversation « ' + title + ' » · ' + pairs.length + ' échange' + (pairs.length > 1 ? 's' : '') + ' importé' + (pairs.length > 1 ? 's' : '') + (c && c.origin && c.origin !== 'Assistant' ? ' · origine : ' + c.origin : '') + '.' }].concat(exch),
      dchat: dm,
      onId: (id) => this.setState((s) => ({ aiConvs: (s.aiConvs || []).map((x) => (x.id === cid ? Object.assign({}, x, { dossierId: id, intake: false }) : x)) }))
    });
  }

  /*@method:cases:buildDossier*/
  asstVals() {
    const full = !!this.state.asstFull;
    const c = this.curConv();
    const OC = { Assistant: ['var(--acBg)', 'var(--acTx)'], Messages: ['var(--infoBg)', 'var(--info2)'], Dossiers: ['var(--infoBg)', 'var(--infoTx2)'], Documents: ['var(--dangerBg)', 'var(--danger)'], Intranet: ['var(--okBg2)', 'var(--okTx)'], 'Réunions': ['var(--priBg)', 'var(--pri)'] };
    const all = this.state.aiConvs || [];
    const flt = this.state.aiConvFilter || 'Toutes';
    const origins = ['Toutes'].concat(Object.keys(OC).filter((o) => all.some((x) => x.origin === o)));
    const when = (t) => {
      const d = new Date(t || Date.now()); const n = new Date();
      const mn = Math.round((n - d) / 60000);
      if (mn < 1) return 'à l’instant';
      if (mn < 60) return 'il y a ' + mn + ' min';
      if (d.toDateString() === n.toDateString()) return 'aujourd’hui ' + d.getHours() + 'h' + String(d.getMinutes()).padStart(2, '0');
      return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
    };
    const list = all.filter((x) => flt === 'Toutes' || x.origin === flt).sort((a, b) => (b.updated || 0) - (a.updated || 0));
    const back = c && c.originRoute;
    const isDos = !!(c && c.dossierId && this.state.dossiers.find((d) => d.id === c.dossierId));
    return {
      full: full, notFull: !full,
      pos: full ? 'fixed' : 'relative', inset: full ? '0' : 'auto', z: full ? '300' : 'auto',
      bg: full ? 'var(--bg, var(--surf2))' : 'transparent', pad: full ? '18px' : '0', maxW: full ? 'none' : '1180px',
      ovf: full ? 'auto' : 'visible', secH: full ? 'calc(100vh - 92px)' : 'auto', msgMax: full ? 'none' : '58vh', asideMax: full ? 'calc(100vh - 92px)' : '640px',
      fullLabel: full ? 'Quitter le plein écran' : 'Plein écran',
      toggleFull: () => this.setState({ asstFull: !full }),
      originLabel: c ? c.origin : (this.state.asstIntake ? 'Nouveau dossier' : 'Nouvelle conversation'), oBg: (OC[c ? c.origin : 'Assistant'] || OC.Assistant)[0], oFg: (OC[c ? c.origin : 'Assistant'] || OC.Assistant)[1],
      convTitle: c ? c.title : (this.state.asstIntake ? 'Ouverture de dossier guidée — décrivez la situation' : 'Pas encore enregistrée — posez une question'),
      hasBack: !!back, backLabel: back ? 'Retour à ' + c.origin : '',
      goBack: () => { if (!back) return; this.setState({ asstFull: false }); this.go(c.originRoute, c.originParams || {}); },
      dossierLabel: this.state.dosBusy ? 'Qualification…' : (isDos ? 'Verser au dossier' : ((c && c.intake) || (!c && this.state.asstIntake) ? 'Créer le dossier' : 'Créer un dossier')),
      newIntake: () => this.convIntake(),
      toDossier: () => this.convToDossier(),
      newConv: () => this.convNew(),
      count: all.length + ' conversation' + (all.length > 1 ? 's' : ''),
      filters: origins.map((o) => ({ label: o, bg: o === flt ? 'var(--ink, #111)' : 'var(--surf2)', fg: o === flt ? 'var(--surface)' : 'var(--ink4)', go: () => this.setState({ aiConvFilter: o }) })),
      empty: !list.length,
      convs: list.map((x) => {
        const on = x.id === this.state.aiConvId;
        const oc = OC[x.origin] || OC.Assistant;
        return {
          title: x.title, origin: x.origin, when: when(x.updated), oBg: oc[0], oFg: oc[1],
          n: (x.messages || []).filter((m) => m.isUser).length + ' q.',
          bg: on ? 'var(--acBg)' : 'transparent', bd: on ? 'var(--acBd)' : 'transparent',
          open: () => this.convOpen(x.id), del: () => this.convDel(x.id)
        };
      })
    };
  }

  /* ================= Hôte d'extensions (API v1) — voir « Guide extensions uniion.md » ================= */
  extInit() {
    if (typeof window === 'undefined') return;
    const U = window.uniion = window.uniion || {};
    U.apiVersion = EXT_API;
    U.extensions = U.extensions || [];
    U.errors = U.errors || [];
    if (typeof U.register !== 'function') {
      U.register = (m) => {
        const ok = m && typeof m === 'object' && /^[a-z0-9][a-z0-9-]{1,40}$/.test(String(m.id || '')) && m.name && m.contributes && typeof m.contributes === 'object';
        if (!ok) { U.errors.push({ id: (m && m.id) || '?', msg: 'Manifeste refusé : id (minuscules, chiffres, tirets), name et contributes sont obligatoires.' }); window.dispatchEvent(new CustomEvent('uniion:extensions')); return false; }
        if (!(m.apiVersion >= 1 && m.apiVersion <= EXT_API)) { U.errors.push({ id: m.id, msg: 'Version d\'API ' + m.apiVersion + ' non prise en charge (hôte : v' + EXT_API + ').' }); window.dispatchEvent(new CustomEvent('uniion:extensions')); return false; }
        U.extensions = U.extensions.filter((x) => x.id !== m.id).concat([m]);
        (((m.assets || {}).css) || []).forEach((href) => {
          if (!/^(\.\/|https:\/\/)/.test(String(href)) || document.querySelector('link[data-ext-css="' + href + '"]')) return;
          const l = document.createElement('link'); l.rel = 'stylesheet'; l.href = href; l.setAttribute('data-ext-css', href); document.head.appendChild(l);
        });
        window.dispatchEvent(new CustomEvent('uniion:extensions'));
        return true;
      };
    }
    (U.queue || []).splice(0).forEach((m) => U.register(m));
    this.onExt = () => this.forceUpdate();
    window.addEventListener('uniion:extensions', this.onExt);
    let srcs = [];
    try { srcs = ((JSON.parse(window.localStorage.getItem(STORE_KEY) || '{}').extCfg) || {}).sources || []; } catch (e) { srcs = []; }
    srcs.forEach((s) => this.extLoad(s, true));
  }
  extLoad(src, silent) {
    src = String(src || '').trim();
    if (!/^(\.\/|https:\/\/)[^\s"'<>]+\.js$/.test(src)) { if (!silent) this.flash('Adresse refusée : fichier .js relatif (./…) ou en https:// uniquement'); return; }
    if (!silent) this.setState((s) => { const c = Object.assign({ items: {}, sources: [] }, s.extCfg || {}); if (c.sources.indexOf(src) < 0) c.sources = c.sources.concat([src]); return { extCfg: c, extUrl: '' }; });
    if (document.querySelector('script[data-ext-src="' + src + '"]')) { if (!silent) this.flash('Extension déjà chargée'); return; }
    const sc = document.createElement('script'); sc.src = src; sc.setAttribute('data-ext-src', src);
    sc.onerror = () => { this.extErr(src, 'Chargement', 'fichier introuvable ou bloqué'); this.forceUpdate(); };
    sc.onload = () => { if (!silent) this.flash('Extension chargée depuis ' + src); };
    document.head.appendChild(sc);
  }
  extUnload(src) { this.setState((s) => { const c = Object.assign({ items: {}, sources: [] }, s.extCfg || {}); c.sources = c.sources.filter((x) => x !== src); return { extCfg: c }; }); this.flash('Source retirée — effective au prochain chargement'); }
  extErr(id, where, e) {
    const U = (typeof window !== 'undefined' && window.uniion) || {};
    U.errors = U.errors || [];
    const msg = where + ' : ' + String((e && e.message) || e);
    if (!U.errors.some((x) => x.id === id && x.msg === msg)) { U.errors.push({ id: id, msg: msg }); if (U.errors.length > 40) U.errors.shift(); }
  }
  extSafe(id, where, fn, fb) { try { const v = fn(); return v === undefined || v === null ? fb : v; } catch (e) { this.extErr(id, where, e); return fb; } }
  extAll() { return (typeof window !== 'undefined' && window.uniion && window.uniion.extensions) || []; }
  extCfgOf(id) { return (((this.state.extCfg || {}).items) || {})[id] || {}; }
  extPlanOk(m) { return !m.minPlan || (PLAN_RANK[this.state.plan] || 1) >= (PLAN_RANK[m.minPlan] || 1); }
  extActive(m) { return !this._extOff && this.extCfgOf(m.id).on !== false && this.extPlanOk(m); }
  extItems(kind) {
    const out = [];
    this.extAll().forEach((m) => {
      if (!this.extActive(m)) return;
      const off = this.extCfgOf(m.id).off || {};
      (((m.contributes || {})[kind]) || []).forEach((it) => { const key = it && (it.id || it.type); if (key && !off[kind + ':' + key]) out.push(Object.assign({ extId: m.id, extName: m.name }, it)); });
    });
    return out;
  }
  extDocStyle(id) { return id ? (this.extItems('docStyles').find((x) => x.id === id) || null) : null; }
  extDocBlock(type) { return CORE_DOC_TYPES.indexOf(type) >= 0 ? null : (this.extItems('docBlocks').find((x) => x.type === type) || null); }
  extPageTheme(id) { return id ? (this.extItems('pageThemes').find((x) => x.id === id) || null) : null; }
  extPageSection(type) { return this.extItems('pageSections').find((x) => x.type === type) || null; }
  extSet(id, patch) { this.setState((s) => { const c = Object.assign({ items: {}, sources: [] }, s.extCfg || {}); c.items = Object.assign({}, c.items, { [id]: Object.assign({}, c.items[id] || {}, patch) }); return { extCfg: c }; }); }
  extToggleItem(id, key) { const off = Object.assign({}, this.extCfgOf(id).off || {}); off[key] = !off[key]; this.extSet(id, { off: off }); this.setState({ pageHtmlDraft: null }); }
  extLines(s) { return String(s || '').split('\n').map((l) => l.trim()).filter(Boolean); }
  extCells(l) { return String(l || '').split('|').map((c) => c.trim()); }
  extSw(c) { c = c || {}; return 'linear-gradient(135deg, ' + (c.a || '#999') + ' 0 50%, ' + ((c.d === c.a ? c.b : c.d) || '#FFF') + ' 50% 100%)'; }
  extDocCtx(sty, grp, cdoc, dfmt, chr, i, n) {
    const o = cdoc.styleOpts || {};
    const pal = (sty.palettes || [])[o.palette || 0] || (sty.palettes || [])[0] || { colors: { a: '#E3051B', b: '#FFE14D', c: '#111111', d: '#FFFFFF' } };
    const fnt = (sty.fonts || [])[o.font || 0] || (sty.fonts || [])[0] || { head: 'Inter, sans-serif', body: 'Inter, sans-serif' };
    const lines = (s) => this.extLines(s);
    return {
      h: React.createElement, blocks: grp,
      first: (t) => grp.find((b) => b.type === t) || null,
      all: (t) => grp.filter((b) => b.type === t),
      block: (b, k) => { const d = this.extDocBlock(b.type); return d ? this.extSafe(d.extId, 'bloc ' + b.type, () => d.render(b, Object.assign({ h: React.createElement, lines: lines }, k)), null) : null; },
      lines: lines, cells: (l) => this.extCells(l),
      colors: Object.assign({}, pal.colors), fonts: Object.assign({}, fnt),
      format: { id: dfmt.id, w: dfmt.w, h: dfmt.h }, u: dfmt.w / 420,
      page: { index: i, count: n },
      org: { emetteur: chr.emetteur || '', section: chr.section || '', contact: [chr.email, chr.phone].filter(Boolean).join(' — '), logo: chr.logo || '' }
    };
  }
  extReadImage(e, cb) {
    const input = e && e.target, file = input && input.files && input.files[0];
    if (!file) return;
    if (!/^image\//.test(file.type)) { this.flash('Choisissez un fichier image (JPG, PNG, WebP)'); return; }
    if (file.size > 15 * 1024 * 1024) { this.flash('Image trop lourde (15 Mo maximum)'); return; }
    const fr = new FileReader();
    fr.onload = () => {
      const im = new Image();
      im.onload = () => {
        const k = Math.min(1, 1400 / Math.max(im.width, im.height));
        const cv = document.createElement('canvas'); cv.width = Math.round(im.width * k); cv.height = Math.round(im.height * k);
        cv.getContext('2d').drawImage(im, 0, 0, cv.width, cv.height);
        let out = ''; try { out = cv.toDataURL('image/jpeg', .82); } catch (err) { out = String(fr.result); }
        cb(out); this.flash('Image ajoutée — réduite à ' + cv.width + ' × ' + cv.height + ' px, conservée sur cet appareil');
      };
      im.onerror = () => this.flash('Image illisible');
      im.src = String(fr.result);
    };
    fr.readAsDataURL(file);
    try { input.value = ''; } catch (err) { /* certains navigateurs refusent */ }
  }
  extAssetLinks() {
    const out = [];
    this.extAll().forEach((m) => { if (!this.extActive(m)) return; (((m.assets || {}).css) || []).forEach((h) => { if (/^(\.\/|https:\/\/)/.test(String(h)) && out.indexOf(h) < 0) out.push(h); }); });
    return out.map((h) => '<link rel="stylesheet" href="' + this.esc(h) + '">').join('');
  }
  extWebGenVals(g) {
    const themes = this.extItems('pageThemes'), secs = this.extItems('pageSections');
    const cur = this.extPageTheme(g.theme);
    const it = (label, on, go) => ({ label: label, bg: on ? 'var(--acBg)' : 'var(--surf2)', fg: on ? 'var(--acTx)' : 'var(--ink5)', go: go });
    return {
      has: themes.length > 0,
      themes: [it('Charte du site', !cur, () => this.setWebGen({ theme: null }))].concat(themes.map((th) => it(th.label, !!cur && cur.id === th.id, () => this.setWebGen({ theme: th.id })))),
      note: secs.length ? 'unii peut aussi composer avec les sections ' + secs.map((s) => s.label.toLowerCase()).join(', ') + '. Vous relisez avant tout envoi.' : 'Le thème s\'applique à la page créée ; il reste modifiable dans l\'éditeur.'
    };
  }
  extSlotPut(slot, src) {
    const bl = this.curDoc().blocks.slice();
    const idx = []; bl.forEach((b, i) => { if (b.type === slot.type) idx.push(i); });
    if (idx.length > slot.index) { const i = idx[slot.index]; bl[i] = Object.assign({}, bl[i], { img: src }); }
    else {
      let at = idx.length ? idx[idx.length - 1] + 1 : (bl.findIndex((b) => b.type === 'h1') + 1);
      if (at < 0) at = 0;
      for (let n = idx.length; n <= slot.index; n++) { bl.splice(at, 0, Object.assign({ id: 'im' + Date.now() + '-' + n, type: slot.type, text: slot.label }, n === slot.index ? { img: src } : {})); at++; }
    }
    this.setBlocks(bl);
  }
  extSlotDel(slot) {
    const bl = this.curDoc().blocks.slice(); let n = -1;
    this.setBlocks(bl.map((b) => { if (b.type !== slot.type) return b; n++; if (n !== slot.index) return b; const y = Object.assign({}, b); delete y.img; return y; }));
  }
  extDocUniiLine(d) {
    const s = this.extDocStyle(d && d.style);
    return s ? '\nStyle graphique choisi : ' + s.label + (s.uniiHint ? ' — consigne de rédaction : ' + s.uniiHint : '') + (s.notice ? ' — règle : ' + s.notice : '') : '';
  }
  extDocStyleVals(cdoc, dfmt, chr) {
    const styles = this.extItems('docStyles');
    const cur = this.extDocStyle(cdoc.style), o = cdoc.styleOpts || {};
    const card = (on) => ({ bd: on ? 'var(--ac)' : 'var(--bd2)', bg: on ? 'var(--acBg)' : 'var(--surface)' });
    const set = (patch) => this.patchDoc(patch);
    const grp = []; for (let j = 0; j < cdoc.blocks.length; j++) { if (cdoc.blocks[j].type === 'pagebreak') break; grp.push(cdoc.blocks[j]); }
    const mini = (sty) => {
      const sc = 108 / dfmt.w;
      const el = this.extSafe(sty.extId, 'style ' + sty.id, () => sty.render(this.extDocCtx(sty, grp, Object.assign({}, cdoc, { styleOpts: {} }), dfmt, chr, 0, 1)), null);
      return React.createElement('div', { style: { width: Math.round(dfmt.w * sc) + 'px', height: Math.round(dfmt.h * sc) + 'px', overflow: 'hidden', position: 'relative', borderRadius: '3px', background: '#FFFFFF' } },
        React.createElement('div', { style: { width: dfmt.w + 'px', height: dfmt.h + 'px', transform: 'scale(' + sc + ')', transformOrigin: 'top left', position: 'absolute', top: 0, left: 0, pointerEvents: 'none' } }, el));
    };
    const txt = ((cdoc.model || '') + ' ' + (cdoc.title || '') + ' ' + cdoc.blocks.map((b) => b.text || '').join(' ')).toLowerCase();
    const best = styles.map((s, i) => ({ s: s, sc: (s.suits || []).reduce((a, w) => a + (txt.indexOf(String(w).toLowerCase()) >= 0 ? 1 : 0), 0) - i * 0.001 })).sort((a, b) => b.sc - a.sc).slice(0, 3).map((x) => x.s);
    const locked = this.state.plan === 'p1';
    const fmt0 = cur && (cur.formats || [])[0];
    const slots = cur ? (cur.slots || []).map((sl) => {
      const b = cdoc.blocks.filter((x) => x.type === sl.type)[sl.index];
      const src = b && (b.img || ((this.extLines(b.text)[0] || '').match(/^(https?:|data:image)/) ? this.extLines(b.text)[0] : ''));
      return { label: sl.label + (sl.optional ? ' (facultatif)' : ''), optional: !!sl.optional, hasImg: !!src, bg: src ? 'url("' + src + '") center / cover' : 'repeating-linear-gradient(135deg, var(--surf2) 0 6px, var(--surface) 6px 12px)',
        state: src ? 'Image en place' : (sl.optional ? 'Emplacement laissé vide si aucune image' : 'Image attendue — un emplacement apparaît sur la page'),
        btn: src ? 'Changer' : 'Déposer une image',
        onImg: (e) => this.extReadImage(e, (s) => this.extSlotPut(sl, s)), del: () => this.extSlotDel(sl), def: sl };
    }) : [];
    const missing = slots.filter((s) => !s.hasImg && !s.optional);
    return {
      has: styles.length > 0,
      classic: Object.assign({ label: 'Classique', desc: 'Charte graphique de l\'organisation — rendu habituel.', on: !cur, go: () => set({ style: null }) }, card(!cur)),
      list: styles.map((s) => { const on = !!cur && cur.id === s.id; return Object.assign({ label: s.label, desc: s.desc || '', on: on, sw: this.extSw(((s.palettes || [])[0] || {}).colors), go: () => set({ style: s.id, styleOpts: {} }) }, card(on)); }),
      hasCur: !!cur, curLabel: cur ? cur.label : '', src: cur ? 'Fourni par l\'extension ' + cur.extName : '',
      hasNotice: !!(cur && cur.notice), notice: cur && cur.notice ? cur.notice : '',
      hasSlots: slots.length > 0, slots: slots,
      hasMissing: missing.length > 0,
      missingLabel: missing.length ? 'Le style « ' + cur.label + ' » attend ' + (missing.length > 1 ? missing.length + ' images' : 'une image') + ' : ' + missing.map((s) => s.label.toLowerCase()).join(', ') + '.' : '',
      goSlots: () => this.setState({ docTab: 'style' }),
      dragOver: (e) => { if (slots.length) { e.preventDefault(); if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy'; } },
      drop: (e) => {
        if (!slots.length) return;
        const f = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
        if (!f) return;
        e.preventDefault();
        const target = slots.find((s) => !s.hasImg) || slots[0];
        this.extReadImage({ target: { files: [f] } }, (s) => this.extSlotPut(target.def, s));
      },
      hasPals: !!cur && (cur.palettes || []).length > 0,
      pals: cur ? (cur.palettes || []).map((p, i) => ({ label: p.label, bg: this.extSw(p.colors), ring: (o.palette || 0) === i ? '0 0 0 2px #FFFFFF, 0 0 0 4px #111827' : '0 0 0 1px var(--bd2)', go: () => set({ styleOpts: Object.assign({}, o, { palette: i }) }) })) : [],
      hasFonts: !!cur && (cur.fonts || []).length > 1,
      fonts: cur ? (cur.fonts || []).map((f, i) => { const on = (o.font || 0) === i; return { label: f.label, bg: on ? '#111827' : 'var(--surface)', fg: on ? '#FFFFFF' : 'var(--ink3)', go: () => set({ styleOpts: Object.assign({}, o, { font: i }) }) }; }) : [],
      hasFmt: !!fmt0 && DOC_FORMATS[fmt0] && (cur.formats || []).indexOf(cdoc.format) < 0,
      fmtLabel: fmt0 && DOC_FORMATS[fmt0] ? 'Passer au format conseillé : ' + DOC_FORMATS[fmt0].label : '',
      fmtGo: () => { if (fmt0 && DOC_FORMATS[fmt0]) { this.patchDoc({ format: fmt0 }); this.syncPageSize(fmt0); } },
      locked: locked && styles.length > 0,
      hasSuggs: !locked && styles.length > 0,
      suggs: locked ? [] : best.map((s) => ({ label: s.label, el: mini(s), bd: cur && cur.id === s.id ? 'var(--ac)' : 'var(--bd2)', go: () => set({ style: s.id, styleOpts: {} }) })),
      hasAsk: !!cur && !locked && !!cur.uniiHint,
      askUnii: () => {
        if (!cur) return;
        this.uniiOpen({ mod: 'documents', itemId: cdoc.id });
        setTimeout(() => this.uniiRun(null, 'Réécris le contenu de ce document pour le style graphique « ' + cur.label + ' ». Consigne : ' + (cur.uniiHint || '') + (cur.notice ? ' Règle impérative : ' + cur.notice : '') + ' Conserve tous les faits, n\'invente aucun chiffre, aucune date, aucun nom. Réponds en Markdown : # titre, ## intertitre, - liste, > encadré, [badge].'), 0);
      }
    };
  }
  extPageCss(pg, blocks, th) {
    const parts = [];
    if (th && typeof th.css === 'function') {
      const o = pg.themeOpts || {}, pal = (th.palettes || [])[o.palette || 0] || (th.palettes || [])[0] || { colors: {} };
      parts.push(this.extSafe(th.extId, 'thème ' + th.id, () => String(th.css({ colors: Object.assign({}, pal.colors), charte: this.webCharteDef(this.pageSite(pg)) })), ''));
    }
    const seen = {};
    blocks.forEach((b) => { if (!b.ext) return; const s = this.extPageSection(b.t); if (s && s.css && !seen[s.css]) { seen[s.css] = 1; parts.push(String(s.css)); } });
    return parts.join('').replace(/<\/?style/gi, '').replace(/<\/?script/gi, '');
  }
  extPageVals(pg, src) {
    const themes = this.extItems('pageThemes'), secs = this.extItems('pageSections');
    const cur = this.extPageTheme(pg.theme), o = pg.themeOpts || {};
    const reset = (patch) => { this.setState({ pageHtmlDraft: null }); this.patchPage(patch); };
    const pill = (on) => ({ bd: on ? 'var(--ac)' : 'var(--bd2)', bg: on ? 'var(--acBg)' : 'var(--surface)', fg: on ? 'var(--acTx)' : 'var(--ink4)' });
    const devs = []; this.extItems('pageDevices').forEach((d) => { if (!devs.some((x) => x.id === d.id)) devs.push(d); });
    const dv = devs.find((d) => d.id === this.state.webDevice) || devs[0];
    return {
      has: themes.length > 0, src: cur ? 'Thème fourni par l\'extension ' + cur.extName : 'Rendu défini dans Charte des sites',
      themes: [Object.assign({ label: 'Charte du site', desc: 'Rendu habituel', on: !cur, go: () => reset({ theme: null }) }, pill(!cur))].concat(themes.map((th) => { const on = !!cur && cur.id === th.id; return Object.assign({ label: th.label, desc: th.desc || '', on: on, go: () => reset({ theme: th.id, themeOpts: {} }) }, pill(on)); })),
      hasPals: !!cur && (cur.palettes || []).length > 1,
      pals: cur ? (cur.palettes || []).map((p, i) => ({ label: p.label, bg: this.extSw(p.colors), ring: (o.palette || 0) === i ? '0 0 0 2px #FFFFFF, 0 0 0 4px #111827' : '0 0 0 1px var(--bd2)', go: () => reset({ themeOpts: Object.assign({}, o, { palette: i }) }) })) : [],
      hasSecs: secs.length > 0,
      secs: secs.map((s) => ({ label: s.label, hint: s.hint || '', go: () => { reset({ blocks: this.pageBlocks(pg).concat([{ id: 'x' + Date.now(), t: s.type, ext: s.extId, text: s.sample || '' }]) }); this.flash('Section « ' + s.label + ' » ajoutée en fin de page'); } })),
      hasDevs: devs.length > 0,
      devs: devs.map((d) => { const on = !!dv && dv.id === d.id; return { label: d.label, bg: on ? '#111827' : 'var(--surface)', fg: on ? '#FFFFFF' : 'var(--ink4)', go: () => this.setState({ webDevice: d.id }) }; }),
      devW: dv && dv.width ? dv.width + 'px' : 'none',
      isFrame: !!(dv && dv.width), noFrame: !(dv && dv.width),
      frameEl: dv && dv.width ? React.createElement('iframe', {
        title: 'Aperçu ' + dv.label.toLowerCase() + ' de la page',
        srcDoc: '<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' + this.extAssetLinks() + '<style>body{margin:0}' + this.pageCss(this.pageSite(pg)) + '</style></head><body>' + String(src || '') + '</body></html>',
        style: { display: 'block', width: dv.width + 'px', maxWidth: '100%', height: '640px', margin: '0 auto', border: '10px solid #15161A', borderRadius: dv.width < 500 ? '34px' : '22px', background: '#FFFFFF', boxSizing: 'content-box' }
      }) : null
    };
  }
  extSelfTest() {
    const res = [];
    const add = (ok, label) => res.push({ ok: ok, label: label, mark: ok ? '✓' : '✕', fg: ok ? 'var(--okTx)' : 'var(--danger)' });
    const pages = (this.state.pages || []).filter((pg) => !(pg.blocks || []).some((b) => b.ext));
    let same = 0; const diff = [];
    pages.forEach((pg) => { const p0 = Object.assign({}, pg, { theme: null }); this._extOff = true; let a = ''; try { a = this.buildPageHtml(p0); } finally { this._extOff = false; } const b = this.buildPageHtml(p0); if (a === b) same++; else diff.push(pg.title); });
    add(!diff.length, 'Pages web sans thème : ' + same + ' / ' + pages.length + ' identiques au caractère près, extensions actives ou non' + (diff.length ? ' — écarts : ' + diff.join(', ') : ''));
    const docs = this.state.docs || [];
    let rt = 0;
    docs.forEach((d) => { const bl = d.blocks || this.modelOf(d.model).blocks.map((b, i) => ({ id: 'b' + i, type: b[0], text: b[1] })); const back = this.mdToBlocks(this.blocksToMd(bl)); if (back.map((b) => b.type).join() === bl.map((b) => b.type).join()) rt++; });
    add(rt === docs.length, 'Documents : ' + rt + ' / ' + docs.length + ' conservent tous leurs blocs après un aller-retour Markdown');
    const sample = this.extItems('docBlocks').map((x, i) => ({ id: 's' + i, type: x.type, text: x.sample || 'x' }));
    const sb = this.mdToBlocks(this.blocksToMd(sample));
    add(sb.map((b) => b.type).join() === sample.map((b) => b.type).join(), 'Blocs d\'extension : ' + sample.length + ' types conservés en Markdown (« :::type »), même extension désactivée');
    const styles = this.extItems('docStyles'), chr = this.charteDef(); let okR = 0, tot = 0;
    docs.forEach((d) => { const bl = d.blocks || this.modelOf(d.model).blocks.map((b, i) => ({ id: 'b' + i, type: b[0], text: b[1] })); const grp = []; for (let j = 0; j < bl.length; j++) { if (bl[j].type === 'pagebreak') break; grp.push(bl[j]); } const f = DOC_FORMATS[d.format] || DOC_FORMATS.a4;
      styles.forEach((s) => { tot++; try { const el = s.render(this.extDocCtx(s, grp.concat(sample), d, f, chr, 0, 1)); if (el) okR++; } catch (e) { this.extErr(s.extId, 'auto-test style ' + s.id, e); } }); });
    add(okR === tot, 'Styles de documents : ' + okR + ' / ' + tot + ' rendus sans erreur (' + styles.length + ' styles × ' + docs.length + ' documents, avec tous les blocs)');
    const themes = this.extItems('pageThemes'); let okT = 0;
    themes.forEach((th) => { const css = this.extSafe(th.extId, 'auto-test thème ' + th.id, () => String(th.css({ colors: ((th.palettes || [])[0] || {}).colors || {}, charte: {} })), ''); if (css && css.indexOf('data-theme="' + th.id + '"') >= 0) okT++; });
    add(okT === themes.length, 'Thèmes de pages : ' + okT + ' / ' + themes.length + ' produisent une feuille de style limitée à leur page');
    const secs = this.extItems('pageSections'); let okS = 0;
    const x = { esc: (s) => this.esc(s), lines: (s) => this.extLines(s), cells: (l) => this.extCells(l) };
    secs.forEach((s) => { const h = this.extSafe(s.extId, 'auto-test section ' + s.type, () => String(s.html({ t: s.type, text: s.sample || '' }, x)), ''); if (h && !/<script|\son[a-z]+=/i.test(h)) okS++; });
    add(okS === secs.length, 'Sections de pages : ' + okS + ' / ' + secs.length + ' produisent du HTML sans script');
    const errs = ((window.uniion || {}).errors || []).length;
    add(!errs, errs ? errs + ' erreur(s) d\'extension journalisée(s) — voir ci-dessus' : 'Aucune erreur d\'extension journalisée');
    this.setState({ extTest: res });
    this.flash(res.every((r) => r.ok) ? 'Auto-test réussi — aucune régression détectée' : 'Auto-test : des points sont à vérifier');
  }
  extVals() {
    const U = (typeof window !== 'undefined' && window.uniion) || {};
    const errs = U.errors || [];
    const KIND = [['docStyles', 'Styles de documents'], ['docBlocks', 'Blocs de documents'], ['pageThemes', 'Thèmes de pages'], ['pageSections', 'Sections de pages'], ['pageDevices', 'Aperçus par appareil']];
    const PERM = { 'documents.styles': 'Mettre en page les documents', 'documents.blocks': 'Ajouter des blocs aux documents', 'pages.themes': 'Habiller les pages web', 'pages.sections': 'Ajouter des sections aux pages', 'pages.devices': 'Aperçus par appareil', 'unii.hints': 'Donner des consignes de rédaction à unii' };
    const all = this.extAll();
    const list = all.map((m) => {
      const cfg = this.extCfgOf(m.id), on = cfg.on !== false, planOk = this.extPlanOk(m), off = cfg.off || {};
      const st = !planOk ? ['Offre insuffisante', 'var(--warnBg, #FEF3C7)', 'var(--warnTx, #92400E)'] : (on ? ['Active', 'var(--okBg)', 'var(--okTx)'] : ['Désactivée', 'var(--chip)', 'var(--ink5)']);
      const me = errs.filter((e) => e.id === m.id);
      return {
        name: m.name, meta: 'v' + (m.version || '?') + ' · ' + (m.author || 'auteur inconnu') + ' · API v' + m.apiVersion + ' · identifiant ' + m.id, desc: m.description || '',
        on: on, swBg: on ? 'var(--ok)' : 'var(--bd2)', swLeft: on ? '21px' : '3px',
        toggle: () => { this.extSet(m.id, { on: !on }); this.setState({ pageHtmlDraft: null }); this.flash(m.name + (on ? ' désactivée — rendu d\'origine rétabli partout' : ' activée')); },
        status: st[0], stBg: st[1], stFg: st[2],
        perms: (m.permissions || []).map((p) => ({ label: PERM[p] || p })),
        groups: KIND.filter((k) => (((m.contributes || {})[k[0]]) || []).length).map((k) => ({ label: k[1] + ' · ' + m.contributes[k[0]].length, items: m.contributes[k[0]].map((it) => { const key = k[0] + ':' + (it.id || it.type); const iOn = !off[key]; return { label: it.label || it.id || it.type, on: iOn, bg: iOn ? 'var(--acBg)' : 'var(--surface)', fg: iOn ? 'var(--acTx)' : 'var(--ink6)', bd: iOn ? 'var(--acBd)' : 'var(--bd2)', go: () => this.extToggleItem(m.id, key) }; }) })),
        hasErrs: me.length > 0, errs: me.map((e) => ({ msg: e.msg }))
      };
    });
    const ids = all.map((m) => m.id);
    const orphan = errs.filter((e) => ids.indexOf(e.id) < 0).map((e) => ({ msg: e.id + ' — ' + e.msg }));
    const srcs = ((this.state.extCfg || {}).sources) || [];
    return {
      list: list, empty: !list.length, count: list.length + ' extension' + (list.length > 1 ? 's' : '') + ' chargée' + (list.length > 1 ? 's' : '') + ' · API v' + EXT_API,
      hasOrphan: orphan.length > 0, orphan: orphan,
      url: this.state.extUrl || '', onUrl: (e) => this.setState({ extUrl: e.target.value }), install: () => this.extLoad(this.state.extUrl),
      hasSources: srcs.length > 0, sources: srcs.map((s) => ({ src: s, del: () => this.extUnload(s) })),
      test: () => this.extSelfTest(), hasTest: (this.state.extTest || []).length > 0, testRes: this.state.extTest || [],
      back: () => this.go('params')
    };
  }

  persist() {
    if (typeof window === 'undefined' || !window.localStorage) return;
    clearTimeout(this._save);
    this._save = setTimeout(() => {
      try {
        const out = {};
        // Quarantine legacy AI browser data without importing, transmitting or deleting it.
        if(window.uniionS01){const old=JSON.parse(window.localStorage.getItem(STORE_KEY)||'{}');for(const k of ['aiConvs','aiConvId','aiMem','aiMemOn'])if(old[k]!==undefined)out[k]=old[k];}
        PERSIST_KEYS.forEach((k) => { if(window.uniionS01&&['dossiers','pieces','dchats','convos','messages','aiConvs','aiConvId','aiMem','aiMemOn'].includes(k))return; if (this.state[k] !== undefined) out[k] = k==='convos'?this.state[k].filter(x=>!String(x.id).startsWith('convocation-')):this.state[k]; });
        window.localStorage.setItem(STORE_KEY, JSON.stringify(out));
      } catch (e) { /* quota ou mode privé : la démonstration reste utilisable en mémoire */ }
    }, 500);
  }

  restore() {
    if (typeof window === 'undefined' || !window.localStorage) return;
    try {
      const raw = window.localStorage.getItem(STORE_KEY);
      if (!raw) return;
      const data = JSON.parse(raw);
      // Migration : l'identité de l'émetteur des documents était figée dans « charte » ; elle est
      // désormais dérivée de l'organisation. On neutralise la copie persistée non surchargée.
      if (data.charte && data.charte.emetteurOverride === undefined) {
        data.charte = Object.assign({}, data.charte, { emetteurOverride: false });
        delete data.charte.emetteur; delete data.charte.section; delete data.charte.email;
      }
      const patch = {};
      PERSIST_KEYS.forEach((k) => { if(window.uniionS01&&['dossiers','pieces','dchats','convos','messages','aiConvs','aiConvId','aiMem','aiMemOn'].includes(k))return;
        if (data[k] === undefined) return;
        const seed = this.state[k];
        if (SEED_MERGE_KEYS.indexOf(k) >= 0 && Array.isArray(seed) && Array.isArray(data[k])) {
          const kept = data[k].filter(function (x) { return x && x.id; });
          const ids = kept.map(function (x) { return x.id; });
          const missing = seed.filter(function (x) { return ids.indexOf(x.id) < 0; });
          patch[k] = missing.concat(kept);
          return;
        }
        patch[k] = data[k];
      });
      if (Object.keys(patch).length) this.setState(patch);
    } catch (e) { /* données illisibles : on repart des données d'exemple */ }
  }

  resetDemo() {
    if (typeof window !== 'undefined' && window.localStorage) {
      try { window.localStorage.removeItem(STORE_KEY); } catch (e) {}
      this.flash('Démonstration réinitialisée — rechargement…');
      setTimeout(() => window.location.reload(), 700);
    }
  }

  componentDidMount() {
    this.restore();
    const initial = new URLSearchParams(location.search).get('screen'); if (!window.uniionS01 && ['accueil','dossiers','dossier','contacts'].includes(initial)) this.setState({authed:true,route:initial}); const self = this;
    window.__proto = { setState: (p) => self.setState(p), get state() { return self.state; } };
    this.extInit();
    this.applyTheme();
    this.syncPageSize(this.curDoc().format);
    this.sync = () => {
      const d = window.innerWidth >= 940;
      const w = window.innerWidth >= 1240;
      const patch = {};
      if (window.innerWidth !== this.state.viewportWidth) patch.viewportWidth = window.innerWidth;
      if (d !== this.state.isDesktop) patch.isDesktop = d;
      if (w !== this.state.isWide) patch.isWide = w;
      if (Object.keys(patch).length) this.setState(patch);
    };
    this.sync();
    window.addEventListener('resize', this.sync);
    this.syncVisualViewport = () => { if (window.visualViewport) document.documentElement.style.setProperty('--mobile-vh', window.visualViewport.height + 'px'); };
    this.syncVisualViewport();
    if (window.visualViewport) window.visualViewport.addEventListener('resize', this.syncVisualViewport);
    this.onEsc = (e) => { if (e.key === 'Escape' && this.state.asstFull) this.setState({ asstFull: false }); };
    window.addEventListener('keydown', this.onEsc);
    this._lastMsgs = this.state.messages;
  }
  componentWillUnmount() {
    this.recAborted = true; this.stopPlayback();
    clearTimeout(this._save);
    if (this.onExt) window.removeEventListener('uniion:extensions', this.onExt);
    this.releaseMic();
    clearInterval(this.impTimer);
    window.removeEventListener('resize', this.sync);
    if (window.visualViewport) window.visualViewport.removeEventListener('resize', this.syncVisualViewport);
    window.removeEventListener('keydown', this.onEsc);
    clearTimeout(this.t1); clearTimeout(this.t2); clearTimeout(this.t3);
    clearTimeout(this.t4); clearTimeout(this.t5); clearInterval(this.t6);
    clearTimeout(this.askTimer);
    clearTimeout(this._lp);
    this._kDetach();
  }

  recPatch(patch) { this.setState({ rec: Object.assign({}, this.state.rec, patch) }); }

  recTick(level) {
    this.setState(function (prev) {
      if (prev.rec.phase !== 'live') return null;
      return { rec: Object.assign({}, prev.rec, { t: prev.rec.t + 0.1, level: level, wave: prev.rec.wave.concat([level]).slice(-56) }) };
    });
  }

  startSimulated(msg) {
    clearInterval(this.recTimer);
    this.recTimer = null;
    if (this.state.rec.phase === 'live' && this.state.rec.sim) return;
    this.recPatch({ phase: 'live', sim: true, err: msg || '', t: 0, wave: [], level: 0 });
    let a = 0;
    this.recTimer = setInterval(() => {
      a += 0.35;
      const lvl = Math.max(0.06, Math.min(1, 0.38 + Math.sin(a) * 0.22 + Math.sin(a * 3.7) * 0.14 + (Math.random() - 0.5) * 0.18));
      this.recTick(lvl);
    }, 100);
  }

  async startRecording() {
    this.recPatch({ t: 0, wave: [], markers: [], err: '', phase: 'asking' });
    this.recAborted = false; this.recChunks = []; this._recStopped = null;
    if (typeof navigator === 'undefined' || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.startSimulated('Micro indisponible sur cet appareil — enregistrement simulé pour la démonstration.');
      return;
    }
    try {
      const ask = navigator.mediaDevices.getUserMedia({ audio: true });
      ask.then(stream => { if (this.recAborted) stream.getTracks().forEach(t => t.stop()); }, () => {});
      const stream = await Promise.race([
        ask,
        new Promise((res, rej) => { this.askTimer = setTimeout(function () { rej(new Error('timeout')); }, 7000); })
      ]);
      clearTimeout(this.askTimer);
      if (this.recAborted) { stream.getTracks().forEach(function (t) { t.stop(); }); return; }
      this.recStream = stream;
      const AC = window.AudioContext || window.webkitAudioContext;
      this.recCtx = new AC();
      const src = this.recCtx.createMediaStreamSource(stream);
      const an = this.recCtx.createAnalyser();
      an.fftSize = 512;
      src.connect(an);
      this.recAnalyser = an;
      this.recBuf = new Uint8Array(an.frequencyBinCount);
      if (typeof MediaRecorder !== 'undefined') {
        try { this.recorder = new MediaRecorder(stream); this.recChunks = []; this.recorder.ondataavailable = (e) => { if (e.data.size) this.recChunks.push(e.data); }; this._recStopped = new Promise(resolve => { this.recorder.onstop = resolve; }); this.recorder.start(); } catch (e) { this.recorder = null; }
      }
      if (!this.recorder) { this.releaseMic(); this.startSimulated('Capture audio indisponible — aucun son conservé.'); return; }
      this.recPatch({ phase: 'live', sim: false, err: '' });
      this.recTimer = setInterval(() => {
        if (!this.recAnalyser) return;
        this.recAnalyser.getByteTimeDomainData(this.recBuf);
        let peak = 0;
        for (let i = 0; i < this.recBuf.length; i++) { const v = Math.abs(this.recBuf[i] - 128) / 128; if (v > peak) peak = v; }
        this.recTick(Math.max(0.04, Math.min(1, peak * 2.4)));
      }, 100);
    } catch (err) {
      clearTimeout(this.askTimer);
      if (this.recAborted) return;
      this.releaseMic();
      this.recAborted = true;
      this.startSimulated(err && err.message === 'timeout'
        ? 'Aucune réponse à la demande d\'autorisation — enregistrement simulé, aucun son n\'est capté.'
        : 'Accès au micro refusé — enregistrement simulé, aucun son n\'est capté.');
    }
  }

  forceSimulated() {
    clearTimeout(this.askTimer);
    this.recAborted = true;
    this.startSimulated('Enregistrement simulé — aucun son n\'est capté.');
  }

  pauseRecording() {
    clearInterval(this.recTimer);
    if (this.recorder && this.recorder.state === 'recording') { try { this.recorder.pause(); } catch (e) {} }
    this.recPatch({ phase: 'paused' });
  }

  resumeRecording() {
    clearInterval(this.recTimer);
    const rc = this.state.rec;
    if (rc.sim) { this.recPatch({ phase: 'live' }); let a = 0; this.recTimer = setInterval(() => { a += 0.35; this.recTick(Math.max(0.06, Math.min(1, 0.38 + Math.sin(a) * 0.22 + (Math.random() - 0.5) * 0.2))); }, 100); return; }
    if (this.recorder && this.recorder.state === 'paused') { try { this.recorder.resume(); } catch (e) {} }
    this.recPatch({ phase: 'live' });
    this.recTimer = setInterval(() => {
      if (!this.recAnalyser) return;
      this.recAnalyser.getByteTimeDomainData(this.recBuf);
      let peak = 0;
      for (let i = 0; i < this.recBuf.length; i++) { const v = Math.abs(this.recBuf[i] - 128) / 128; if (v > peak) peak = v; }
      this.recTick(Math.max(0.04, Math.min(1, peak * 2.4)));
    }, 100);
  }

  releaseMic() {
    clearInterval(this.recTimer);
    this.recTimer = null;
    if (this.recorder && this.recorder.state !== 'inactive') { try { this.recorder.stop(); } catch (e) {} }
    this.recorder = null;
    if (this.recStream) { this.recStream.getTracks().forEach(function (t) { t.stop(); }); this.recStream = null; }
    if (this.recCtx) { try { this.recCtx.close(); } catch (e) {} this.recCtx = null; }
    this.recAnalyser = null;
  }

  stopRecording() { this.releaseMic(); this.recPatch({ phase: 'done', level: 0 }); }

  addMarker(kind) {
    const rc = this.state.rec;
    const def = MARKER_DEFS.find(function (m) { return m.id === kind; });
    this.recPatch({ markers: rc.markers.concat([{ t: Math.round(rc.t), kind: kind, note: def.label }]) });
    this.flash(def.label + ' — marqueur posé à ' + this.clock(rc.t));
  }

  clock(sec) {
    const s = Math.max(0, Math.round(sec));
    const m = Math.floor(s / 60);
    const h = Math.floor(m / 60);
    const pad = function (n) { return n < 10 ? '0' + n : '' + n; };
    return h > 0 ? h + ' h ' + pad(m % 60) + ' min' : pad(m) + ':' + pad(s % 60);
  }

  async saveRecording() {
    const rc = this.state.rec;
    if (rc.sim) return this.flash('Simulation uniquement — aucun audio à enregistrer');
    if (this._savingAudio) return;
    this._savingAudio = true;
    if (this.recorder) this.releaseMic();
    await this._recStopped;
    const id = 'r-' + Date.now();
    try { const blob = new Blob(this.recChunks || [], {type: ((this.recChunks || [])[0] || {}).type || 'audio/webm'}); if (!blob.size) throw new Error('Audio vide'); await window.uniionFiles.put('audio:' + id, blob); } catch (e) { this._savingAudio = false; return this.flash('Audio non enregistré : ' + e.message); }
    this._savingAudio = false;
    const now = new Date();
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    const mins = Math.max(1, Math.round(rc.t / 60));
    const reunion = {
      id: id, type: rc.type, title: rc.type + ' du ' + now.getDate() + ' ' + months[now.getMonth()],
      date: now.getDate() + ' ' + months[now.getMonth()] + ' ' + now.getFullYear() + ' · ' + now.getHours() + ' h ' + (now.getMinutes() < 10 ? '0' : '') + now.getMinutes(),
      dur: this.clock(rc.t), audio: 'kept', retention: 30, pv: 'À rédiger', pvDoc: '',
      ordre: [], markers: rc.markers.slice(), access: [], destroyed: null
    };
    this.setState({ reunions: [reunion].concat(this.state.reunions), rec: { phase: 'consent', c1: false, c2: false, t: 0, level: 0, wave: [], markers: [], sim: false, err: '', type: rc.type } });
    this.go('reunion', { reunionId: id });
    this.recChunks = []; this.flash('Audio enregistré dans ce navigateur — conservation locale sans chiffrement applicatif');
  }

  discardRecording() {
    this.releaseMic();
    this.setState({ rec: { phase: 'consent', c1: false, c2: false, t: 0, level: 0, wave: [], markers: [], sim: false, err: '', type: this.state.rec.type } });
    this.flash('Enregistrement supprimé — rien n\'a été conservé');
  }

  importAudioFile(file) {
    if (!file) return;
    if (!file.size || (!/^audio\//.test(file.type || '') && !/\.(wav|mp3|m4a|ogg|webm|aac|flac)$/i.test(file.name || ''))) return this.flash('Choisissez un fichier audio non vide');
    this._audioImportFile = file;
    this.setState({audioImport:{name:file.name,size:(file.size/1048576).toFixed(1)+' Mo',step:3,done:true}});
  }

  async confirmImport() {
    const imp = this.state.audioImport, file = this._audioImportFile;
    if (!imp || !file || this._savingAudio) return;
    this._savingAudio = true;
    const id = 'r-imp-' + Date.now();
    try { await window.uniionFiles.put('audio:' + id, file); }
    catch (e) { this._savingAudio = false; return this.flash('Import non enregistré : ' + e.message); }
    this._savingAudio = false; this._audioImportFile = null;
    const reunion = {id:id,type:this.state.rec.type,title:'Enregistrement importé — '+imp.name.replace(/\.[a-z0-9]+$/i,''),date:new Date().toLocaleString('fr-FR'),dur:'—',audio:'kept',retention:30,pv:'À rédiger',pvDoc:'',ordre:[],markers:[],access:[],destroyed:null};
    this.setState({reunions:[reunion].concat(this.state.reunions),audioImport:null});
    this.go('reunion',{reunionId:id});
    this.flash('Fichier audio conservé dans ce navigateur — sans chiffrement applicatif');
  }

  async listenAudio(reunion, offset) {
    if (this._playingAudio) { this.stopPlayback(); if (offset == null) return; }
    try {
      const blob = await window.uniionFiles.get('audio:' + reunion.id);
      if (!blob) throw new Error('Aucun fichier audio local pour cette réunion');
      const audio = new Audio(URL.createObjectURL(blob));
      if (offset != null) audio.currentTime = Math.max(0,offset);
      try { await audio.play(); } catch (e) { URL.revokeObjectURL(audio.src); throw e; }
      this._playingAudio = audio;
      audio.onended = () => { URL.revokeObjectURL(audio.src); this._playingAudio = null; };
      this.setState(s => ({reunions:s.reunions.map(r => r.id === reunion.id ? Object.assign({},r,{access:(r.access || []).concat([{who:'Utilisateur local',when:new Date().toLocaleString('fr-FR'),what:'Écoute audio'}])}) : r)}));
      this.flash('Lecture en cours — cliquez à nouveau pour arrêter');
    } catch (e) { this.flash(e.message); }
  }

  

  exportLocalLogs() {
    const q = v => '"'+String(v == null ? '' : v).replace(/"/g,'""')+'"';
    const lines = [['Date','Auteur','Action','Niveau']].concat(this.state.admLogs.map(l => [l.t,l.qui,l.quoi,l.niv]));
    window.uniionFiles.download(new Blob(['\ufeff'+lines.map(r => r.map(q).join(';')).join('\r\n')],{type:'text/csv;charset=utf-8'}),'journal-local.csv');
  }

  curReunion() { return this.state.reunions.find((x) => x.id === this.state.reunionId) || this.state.reunions[0]; }


  charteDef() {
    const c = Object.assign({}, this.state.charte || {});
    const org = this.state.org || {};
    // L'identité de l'émetteur est dérivée de l'organisation par défaut : une seule source de vérité.
    // Elle n'est conservée telle quelle que si l'utilisateur l'a explicitement modifiée.
    if (!c.emetteurOverride) {
      c.emetteur = org.sigle || org.nom || '';
      c.section = (org.adresse || '').split(',')[0] || org.nom || '';
      c.email = org.email || '';
    }
    return c;
  }
  modelOf(id) { return DOC_MODELS.find(function (m) { return m.id === id; }) || DOC_MODELS[0]; }

  curDoc() {
    const d = this.state.docs.find((x) => x.id === this.state.docId) || this.state.docs[0];
    if (!d.blocks) {
      const seeded = this.modelOf(d.model).blocks.map((b, i) => ({ id: d.id + '-b' + i, type: b[0], text: b[1] }));
      return Object.assign({}, d, { blocks: seeded });
    }
    return d;
  }

  patchDoc(patch, touch) {
    const cur = this.curDoc();
    const merged = Object.assign({}, cur, patch);
    if (touch !== false) merged.updated = "à l'instant";
    this.setState({ docs: this.state.docs.map((x) => (x.id === cur.id ? merged : x)) });
  }

  setBlocks(blocks) { this.patchDoc({ blocks: blocks }); this.setState({ docSrcDraft: null }); }

  addBlock(type) {
    const bl = this.curDoc().blocks.slice();
    bl.push({ id: 'nb' + Date.now() + '-' + bl.length, type: type, text: (this.extDocBlock(type) || {}).sample || '' });
    this.setBlocks(bl);
  }

  moveBlock(id, dir) {
    const bl = this.curDoc().blocks.slice();
    const i = bl.findIndex((b) => b.id === id);
    const j = i + dir;
    if (i < 0 || j < 0 || j >= bl.length) return;
    const tmp = bl[i]; bl[i] = bl[j]; bl[j] = tmp;
    this.setBlocks(bl);
  }

  charteSet(patch) {
    const ident = ['emetteur', 'section', 'email'].some(function (k) { return patch[k] !== undefined; });
    const add = ident ? Object.assign({}, this.charteDef(), patch, { emetteurOverride: true }) : patch;
    this.setState({ charte: Object.assign({}, this.state.charte, add) });
  }
  charteResetIdent() {
    this.setState({ charte: Object.assign({}, this.state.charte, { emetteurOverride: false }) });
    this.flash('Identité de l\'émetteur reprise de l\'organisation');
  }

  blocksToMd(bl) {
    return bl.map(function (b) {
      const t = (b.text || '').trim();
      if (b.type === 'pagebreak') return '---';
      if (b.type === 'tag') return '[' + t + ']';
      if (b.type === 'h1') return '# ' + t;
      if (b.type === 'h2') return '## ' + t;
      if (b.type === 'h3') return '### ' + t;
      if (b.type === 'quote') return t.split('\n').map(function (l) { return '> ' + l.trim(); }).join('\n');
      if (b.type === 'ul') return t.split('\n').filter(function (l) { return l.trim(); }).map(function (l) { return '- ' + l.trim(); }).join('\n');
      if (b.type === 'table') {
        return t.split('\n').filter(function (l) { return l.trim(); }).map(function (l) {
          return '| ' + l.split('|').map(function (c) { return c.trim(); }).join(' | ') + ' |';
        }).join('\n');
      }
      if (CORE_DOC_TYPES.indexOf(b.type) < 0) return ':::' + b.type + '\n' + t.replace(/\n{2,}/g, '\n') + '\n:::';
      return t;
    }).join('\n\n');
  }

  mdToBlocks(md) {
    const out = [];
    let n = 0;
    const push = function (type, text) { out.push({ id: 'md' + (n++) , type: type, text: text }); };
    (md || '').split(/\n{2,}/).forEach(function (chunk) {
      const xm = chunk.trim().match(/^:::([a-z0-9][a-z0-9_.-]*)\n([\s\S]*?)\n?:::$/i);
      if (xm) { push(xm[1], xm[2].trim()); return; }
      const lines = chunk.split('\n').map(function (l) { return l.trim(); }).filter(function (l) { return l; });
      let i = 0;
      while (i < lines.length) {
        const l = lines[i];
        if (/^-{3,}$/.test(l)) { push('pagebreak', ''); i++; continue; }
        if (/^\[[^\]]*\]$/.test(l)) { push('tag', l.slice(1, -1)); i++; continue; }
        if (l.indexOf('### ') === 0) { push('h3', l.slice(4)); i++; continue; }
        if (l.indexOf('## ') === 0) { push('h2', l.slice(3)); i++; continue; }
        if (l.indexOf('# ') === 0) { push('h1', l.slice(2)); i++; continue; }
        if (l.charAt(0) === '>') {
          const buf = [];
          while (i < lines.length && lines[i].charAt(0) === '>') { buf.push(lines[i].replace(/^>\s?/, '')); i++; }
          push('quote', buf.join('\n')); continue;
        }
        if (/^[-*]\s/.test(l)) {
          const buf = [];
          while (i < lines.length && /^[-*]\s/.test(lines[i]) && !/^-{3,}$/.test(lines[i])) { buf.push(lines[i].slice(2).trim()); i++; }
          push('ul', buf.join('\n')); continue;
        }
        if (l.indexOf('|') >= 0) {
          const buf = [];
          while (i < lines.length && lines[i].indexOf('|') >= 0) {
            const raw = lines[i].replace(/^\|/, '').replace(/\|$/, '');
            if (!/^[\s|:\-]+$/.test(raw)) buf.push(raw.split('|').map(function (c) { return c.trim(); }).join(' | '));
            i++;
          }
          push('table', buf.join('\n')); continue;
        }
        const buf = [];
        while (i < lines.length && !/^([-*>#|]|\[)/.test(lines[i])) { buf.push(lines[i]); i++; }
        push('p', buf.join(' '));
      }
    });
    return out.length ? out : [{ id: 'md0', type: 'p', text: '' }];
  }

  syncPageSize(fmtId) {
    if (typeof document === 'undefined') return;
    let el = document.getElementById('docPageSize');
    if (!el) { el = document.createElement('style'); el.id = 'docPageSize'; document.head.appendChild(el); }
    el.textContent = '@media print { @page { size: ' + (DOC_FORMATS[fmtId] || DOC_FORMATS.a4).page + '; margin: 0; } }';
  }

  openDoc(id) { this.setState({ docSrcDraft: null, docTab: 'contenu' }); this.go('docedit', { docId: id }); }

  createFromModel(modelId) {
    const m = this.modelOf(modelId);
    const id = 'd-' + modelId + '-' + Date.now();
    const doc = {
      id: id, title: m.blocks.filter(function (b) { return b[0] === 'h1'; }).map(function (b) { return b[1]; })[0] || m.label,
      model: modelId, format: m.format, status: 'Brouillon', updated: "à l'instant",
      blocks: m.blocks.map((b, i) => ({ id: id + '-b' + i, type: b[0], text: b[1] }))
    };
    this.setState({ docs: [doc].concat(this.state.docs), docSrcDraft: null, docTab: 'contenu' });
    this.go('docedit', { docId: id });
    this.flash('Document créé depuis le modèle « ' + m.label + ' »');
  }

/* ---- Adhérents ---- */
  
  

  

  

  

  

  

  

  

  

  

  

  


  askDel(key, label, fn) {
    const armed = this.state.delKey === key;
    return {
      label: armed ? 'Confirmer la suppression' : label,
      armed: armed,
      bg: armed ? 'var(--dangerBg)' : 'transparent',
      fg: armed ? 'var(--dangerTx2)' : 'var(--ink5)',
      act: () => {
        if (armed) { this.setState({ delKey: '' }); fn(); }
        else { this.setState({ delKey: key }); this.flash('Cliquez à nouveau pour confirmer — action irréversible'); }
      }
    };
  }

  

  

  

  

  

  

  

  

  



  

  

  

  

  

    

  stopPlayback() { if (this._playingAudio) { this._playingAudio.pause(); URL.revokeObjectURL(this._playingAudio.src); this._playingAudio = null; } }
  leaveAudio() { this.stopPlayback(); if (this.state.rec.phase === 'asking') { this.recAborted = true; clearTimeout(this.askTimer); this.releaseMic(); this.recPatch({phase:'consent'}); } else if (this.state.rec.phase === 'live') this.pauseRecording(); }
    
  
  flash(msg) {
    this.setState({ toast: msg });
    clearTimeout(this.t3);
    this.t3 = setTimeout(() => this.setState({ toast: '' }), 2600);
  }
  setAuth(patch) {
    this.setState((s) => ({ auth: Object.assign({}, s.auth, patch) }));
  }
  setSig(patch) {
    this.setState((s) => ({ sig: Object.assign({}, s.sig, patch) }));
  }
  submitId() {
    const a = this.state.auth;
    if (!/.+@.+\..+/.test(a.email.trim())) return this.setAuth({ err: 'Adresse professionnelle invalide.' });
    if (a.pwd.trim().length < 4) return this.setAuth({ err: 'Saisissez votre mot de passe (4 caractères minimum en démonstration).' });
    this.setAuth({ step: 'mfa', err: '', code: '', admin: /@uniion\.fr\s*$/i.test(a.email.trim()) });
  }
  submitMfa() {
    const code = this.state.auth.code;
    if (code.length < 6) return this.setAuth({ err: 'Le code comporte 6 chiffres.' });
    if (code !== '402913') return this.setAuth({ err: 'Code incorrect. Il expire au bout de 60 secondes — demandez un nouvel envoi.', code: '' });
    if (this.state.auth.admin) {
      this.setState({ adminAuthed: true, admRoute: 'supervision', auth: Object.assign({}, this.state.auth, { err: '', pwd: '', code: '' }) });
      return this.flash('Console d\u2019administration ouverte');
    }
    this.setState({ authed: true, auth: Object.assign({}, this.state.auth, { err: '', pwd: '', code: '' }), route: 'accueil', history: [] });
    this.flash('Session ouverte — appareil de confiance enregistré');
  }
  toggle(name) {
    const f = Object.assign({}, this.state.flags);
    f[name] = !f[name];
    this.setState({ flags: f });
  }

  sheetDefs() {
    const c = this.state.sheetCtx || {};
    return {
      editSignature: { title: 'Modifier la signature', sub: 'Une ligne pour le nom, une pour la fonction, une pour le courriel.', field: 'Signature', confirm: 'Enregistrer', doneTitle: 'Signature enregistrée', doneLines: ['Signature textuelle conservée dans ce navigateur.'], doneAction: 'Retour au profil', doneGo: 'profil' },
      reset: {
        title: 'Réinitialiser le mot de passe',
        sub: 'Un lien à usage unique est envoyé sur votre adresse professionnelle. Il expire au bout de 30 minutes.',
        optLabel: 'Canal de réception',
        options: [
          { label: 'Email professionnel', hint: 'sophie.marchand@cse-valenciennes.fr' },
          { label: 'SMS — appareil de confiance', hint: 'iPhone 15 · •• 47' }
        ],
        confirm: 'Envoyer le lien',
        doneTitle: 'Lien envoyé',
        doneLines: ['Valable 30 minutes, usage unique.', 'Envoi consigné au journal d\'audit (26/08, 14 h 22).'],
        doneAction: 'Revenir à la connexion', doneGo: 'auth'
      },
      exportRep: {
        title: 'Exporter le bilan de mandat',
        sub: 'Le bilan reprend la période sélectionnée à l\'écran. Aucune donnée nominative de salarié n\'est incluse.',
        optLabel: 'Format',
        options: [
          { label: 'Excel — 4 onglets', hint: 'Une feuille par thème + synthèse' },
          { label: 'CSV brut', hint: 'Pour retraitement fédération' },
          { label: 'PDF de séance', hint: 'Mise en page prête à distribuer' }
        ],
        confirm: 'Générer le fichier',
        doneTitle: 'Fichier prêt',
        doneLines: ['bilan-cse-valenciennes-2026.xlsx · 248 Ko', 'Conservé 30 jours dans vos exports.'],
        doneAction: 'Retour au bilan', doneGo: 'reporting', file: true
      },
      exportAudit: {
        title: 'Exporter le journal d\'audit',
        sub: 'Export horodaté et signé. Les empreintes d\'appels IA sont incluses, jamais les contenus en clair.',
        optLabel: 'Période',
        options: [
          { label: '30 derniers jours', hint: '148 événements' },
          { label: 'Mandat en cours', hint: '2 914 événements' },
          { label: 'Depuis la création', hint: '4 106 événements' }
        ],
        confirm: 'Exporter en CSV',
        doneTitle: 'Export disponible',
        doneLines: ['journal-audit-2026-08.csv · signé SHA-256', 'Lien de téléchargement valable 7 jours.'],
        doneAction: 'Retour au journal', doneGo: 'rgpd', file: true
      },
      exportData: {
        title: 'Exporter les données de l\'organisation',
        sub: 'Droit à la portabilité (art. 20 RGPD). L\'archive est chiffrée et le lien envoyé par email.',
        optLabel: 'Périmètre',
        options: [
          { label: 'Mes données d\'élu', hint: 'Compte, activité, préférences' },
          { label: 'Coffre du CSE', hint: 'Dossiers, pièces, sondages — 1,4 Go' }
        ],
        confirm: 'Préparer l\'archive',
        doneTitle: 'Archive en préparation',
        doneLines: ['Vous recevrez un lien sous 2 heures.', 'Chiffrée AES-256, mot de passe transmis séparément.'],
        doneAction: 'Retour RGPD', doneGo: 'rgpd'
      },
      diffuse: {
        title: 'Diffuser le document',
        sub: 'Diffusion tracée : date, canal et audience sont consignés pour le registre du CSE.',
        optLabel: 'Audience',
        options: [
          { label: 'Tous les salariés', hint: '416 destinataires' },
          { label: 'Site de Valenciennes', hint: '218 destinataires' },
          { label: 'Élus et représentants', hint: '24 destinataires' }
        ],
        checks: ['Notification mobile', 'Affichage panneau numérique', 'Email avec pièce PDF'],
        confirm: 'Diffuser maintenant',
        doneTitle: 'Diffusion lancée',
        doneLines: ['Accusés de lecture visibles sous 24 h.', 'Copie déposée dans la base documentaire.'],
        doneAction: 'Retour au document', doneGo: 'tract'
      },
      relaunch: {
        title: 'Relancer le sondage',
        sub: (c.count || '104') + ' salariés n\'ont pas encore répondu. La relance reste anonyme : aucune liste de non-répondants n\'est exposée.',
        optLabel: 'Canal de relance',
        options: [
          { label: 'Notification mobile', hint: 'Taux de réouverture ~ 38 %' },
          { label: 'Email + QR code atelier', hint: 'Recommandé pour les postes sans mobile' },
          { label: 'Les deux', hint: 'Une seule relance par salarié' }
        ],
        field: 'Message ajouté à la relance (optionnel)',
        placeholder: 'La clôture est vendredi — votre avis compte.',
        confirm: 'Envoyer la relance',
        doneTitle: 'Relance envoyée',
        doneLines: ['Prochaine relance possible dans 48 h.', 'Aucun lien entre réponse et salarié n\'est conservé.'],
        doneAction: 'Retour au sondage', doneGo: 'sondage'
      },
      signed: {
        title: 'Télécharger le document signé',
        sub: 'Le PDF est scellé avec son certificat eIDAS et son horodatage qualifié.',
        optLabel: 'Contenu du fichier',
        options: [
          { label: 'PDF signé seul', hint: '1 fichier · 420 Ko' },
          { label: 'PDF + certificat + preuve d\'horodatage', hint: 'Archive ZIP · 1,2 Mo' }
        ],
        confirm: 'Télécharger',
        doneTitle: 'Téléchargement prêt',
        doneLines: ['accord-teletravail-signe.pdf · scellé le 26/08 à 14 h 31', 'Vérifiable sur le vérificateur eIDAS européen.'],
        doneAction: 'Retour à la signature', doneGo: 'signature', file: true
      }
    };
  }

  viewerLibrary() {
    return {
      cc: {
        kind: 'Convention collective', title: 'Convention collective Métallurgie 2026', meta: 'IDCC 3248 · PDF 12,4 Mo · disponible hors ligne',
        badge: 'Source de l\'Assistant', version: 'Avenant salaires de branche du 12 juin 2026 intégré',
        extracts: [
          { ref: 'Art. 62 — Classifications', body: 'La grille de classification repose sur six degrés d\'exigence. Toute évolution de poste donne lieu à un réexamen du positionnement.' },
          { ref: 'Art. 104 — Prime d\'ancienneté', body: 'Le taux progresse de 3 % après trois ans de présence, puis de 1 % par année supplémentaire dans la limite de 15 %.' }
        ]
      },
      tt: {
        kind: 'Accord d\'entreprise', title: 'Accord télétravail 2024', meta: 'PDF 1,1 Mo · signé le 04/03/2024 · échéance 03/03/2027',
        badge: 'En vigueur', version: 'Version signée — 3 signataires',
        extracts: [
          { ref: 'Art. 3 — Nombre de jours', body: 'Deux jours de télétravail hebdomadaires pour les postes éligibles, portés à trois sur accord du responsable.' },
          { ref: 'Art. 7 — Indemnité', body: 'Une allocation forfaitaire de 2,70 € par jour télétravaillé couvre les frais engagés.' }
        ]
      },
      pv: {
        kind: 'Procès-verbal', title: 'PV réunion de section — juillet 2026', meta: 'PDF 640 Ko · adopté à l\'unanimité',
        badge: 'Adopté', version: 'Signé par le secrétaire de section',
        extracts: [
          { ref: 'Point 2 — Sondage NAO', body: 'Restitution des 312 réponses. Les élus retiennent la revalorisation générale comme première revendication.' },
          { ref: 'Point 4 — Atelier B', body: 'L\'enquête CSSCT est prolongée. Un point d\'étape est inscrit à l\'ordre du jour de septembre.' }
        ]
      },
      reg: {
        kind: 'Règlement', title: 'Règlement intérieur du CSE', meta: 'PDF 320 Ko · adopté le 18/01/2025',
        badge: 'En vigueur', version: 'Version 2 — modifiée en séance',
        extracts: [
          { ref: 'Art. 5 — Convocations', body: 'L\'ordre du jour est transmis au moins trois jours ouvrés avant la séance, par voie dématérialisée.' },
          { ref: 'Art. 11 — Confidentialité', body: 'Les élus sont tenus à la discrétion sur les informations présentées comme confidentielles par la direction.' }
        ]
      },
      cdt: {
        kind: 'Documentation', title: 'Code du travail — extraits CSE', meta: 'PDF 8,7 Mo · à jour au 1er juillet 2026',
        badge: 'Source de l\'Assistant', version: 'Consolidation Légifrance',
        extracts: [
          { ref: 'L2315-27', body: 'Le comité social et économique se réunit au moins une fois par mois dans les entreprises d\'au moins trois cents salariés.' },
          { ref: 'L1153-5', body: 'L\'employeur prend toutes dispositions nécessaires en vue de prévenir les faits de harcèlement sexuel, d\'y mettre un terme et de les sanctionner.' }
        ]
      }
    };
  }

  viewerEvents() {
    return {
      e1: {
        kind: 'Séance', title: 'Séance NAO 2027', meta: '3 septembre 2026 · 9 h — 12 h · Salle du conseil',
        badge: 'Convocation reçue', version: '4 élus convoqués · direction représentée par la DRH',
        extracts: [
          { ref: 'Ordre du jour', body: '1. Restitution du sondage salaires. 2. Position de la délégation. 3. Calendrier des séances suivantes.' },
          { ref: 'À préparer', body: 'Bilan chiffré du sondage NAO et note de revendication à diffuser aux élus 48 h avant.' }
        ]
      },
      e2: {
        kind: 'Enquête', title: 'Enquête CSSCT — Atelier B', meta: '5 septembre 2026 · 14 h · Visite sur site',
        badge: 'Délégation désignée', version: '2 élus · accompagnés du référent sécurité',
        extracts: [
          { ref: 'Objet', body: 'Suite de l\'accident du 2 août. Vérification des consignes de reprise et de la signalétique de la zone de convoyage.' },
          { ref: 'Suites attendues', body: 'Compte rendu écrit sous 8 jours, inscrit à l\'ordre du jour de la séance ordinaire de septembre.' }
        ]
      },
      e3: {
        kind: 'Échéance', title: 'Clôture du sondage télétravail', meta: '12 septembre 2026 · 18 h',
        badge: 'Automatique', version: 'Résultats publiés aux élus dès la clôture',
        extracts: [
          { ref: 'État actuel', body: '224 réponses sur 416 salariés. Une relance reste possible jusqu\'au 10 septembre.' },
          { ref: 'Après clôture', body: 'Le bilan est généré automatiquement et joint au dossier « Télétravail ».' }
        ]
      }
    };
  }

  async cacheLocalDocs(id) {
    if (this.state.syncing) return;
    this.setState({syncing:true});
    const cached = Object.assign({},this.state.cached);
    try {
      for (const key of (id ? [id] : DOCS.map(d => d.id))) {
        if (id && cached[key]) { await window.uniionFiles.remove('doc:'+key); delete cached[key]; }
        else { const data = this.viewerLibrary()[key]; if (!data) throw new Error('Document absent'); await window.uniionFiles.put('doc:'+key,new Blob([JSON.stringify(data)],{type:'application/json'})); cached[key]=true; }
      }
      this.setState({cached:cached,lastSync:new Date().toLocaleString('fr-FR')});
      this.flash('Cache local mis à jour — extraits uniquement, sans chiffrement');
    } catch(e) { this.flash('Cache incomplet : '+e.message); this.setState({cached:cached}); }
    finally { this.setState({syncing:false}); }
  }

  viewerData() {
    const src = this.state.viewerKind === 'event' ? this.viewerEvents() : Object.assign({}, this.viewerLibrary(), this._cachedDocs || {});
    return src[this.state.viewerId] || { kind: '', title: '', meta: '', badge: '', version: '', extracts: [] };
  }

  openViewer(kind, id) {
    if (kind === 'doc' && this.state.cached[id] && window.uniionFiles) window.uniionFiles.get('doc:'+id).then(async blob => { if (!blob) return; const data = JSON.parse(await blob.text()); this._cachedDocs = Object.assign({},this._cachedDocs,{[id]:data}); this.setState({}); }).catch(() => this.flash('Cache local illisible — extraits de démonstration affichés'));
    this.setState({ viewerKind: kind, viewerId: id });
    this.go('viewer');
  }

  moveCard(id, dir) {
    const order = ['todo', 'doing', 'done'];
    const d = this.state.dossiers.find(function (x) { return x.id === id; });
    if (!d) return;
    const next = order[order.indexOf(d.status) + dir];
    if (!next) return;
    this.dropCard(id, next, -1);
  }

  dropCard(id, col, idx) {
    const list = this.state.dossiers.slice();
    let from = -1;
    list.forEach(function (x, i) { if (x.id === id) from = i; });
    if (from < 0) { this.setState({ drag: null }); return; }
    const item = list[from];
    const changed = item.status !== col;
    list.splice(from, 1);
    const inCol = list.filter(function (x) { return x.status === col; });
    const target = (idx < 0 || idx > inCol.length) ? inCol.length : idx;
    const anchor = inCol[target];
    const next = Object.assign({}, item, {
      status: col,
      due: col === 'done' ? 'Clos' : (item.due === 'Clos' ? '15 j' : item.due)
    });
    if (changed) {
      next.timeline = (item.timeline || []).concat([{
        date: "Aujourd'hui",
        title: 'Déplacé vers ' + STATUS_LABELS[col],
        body: 'Statut modifié par Sophie Marchand depuis le tableau des dossiers.'
      }]);
    }
    let at;
    if (anchor) {
      at = list.indexOf(anchor);
    } else {
      let last = -1;
      list.forEach(function (x, i) { if (x.status === col) last = i; });
      at = last + 1;
    }
    list.splice(at, 0, next);
    this.setState({ dossiers: list, drag: null });
    if (changed) {
      this.flash('« ' + item.title + ' » déplacé vers ' + STATUS_LABELS[col] + (col === 'done' ? ' — échéance close, chronologie mise à jour' : ' — chronologie mise à jour'));
    }
  }

  _kAttach() {
    if (typeof window === 'undefined' || this._kOn) return;
    this._kOn = true;
    window.addEventListener('pointermove', this._pm, { passive: false });
    window.addEventListener('pointerup', this._pu);
    window.addEventListener('pointercancel', this._pu);
  }

  _kDetach() {
    if (typeof window === 'undefined' || !this._kOn) return;
    this._kOn = false;
    window.removeEventListener('pointermove', this._pm);
    window.removeEventListener('pointerup', this._pu);
    window.removeEventListener('pointercancel', this._pu);
  }

  cardPointerDown(id, e) {
    if (e.button > 0) return;
    const tg = e.target;
    if (tg && tg.closest && tg.closest('input, textarea, [data-noDrag]')) return;
    const r = e.currentTarget.getBoundingClientRect();
    this._pending = {
      id: id, sx: e.clientX, sy: e.clientY,
      offX: e.clientX - r.left, offY: e.clientY - r.top,
      w: r.width, h: r.height, touch: e.pointerType === 'touch'
    };
    this._kAttach();
    if (this._pending.touch) {
      clearTimeout(this._lp);
      this._lp = setTimeout(() => this.beginDrag(e.clientX, e.clientY), 320);
    }
  }

  beginDrag(x, y) {
    const p = this._pending;
    if (!p || this.state.drag) return;
    clearTimeout(this._lp);
    const d = this.state.dossiers.find(function (z) { return z.id === p.id; });
    if (!d) return;
    if (typeof document !== 'undefined') document.body.style.userSelect = 'none';
    this.setState({
      grabbed: '',
      drag: {
        id: p.id, title: d.title, tag: d.tag, desc: d.desc, due: d.due,
        who: (d.owner || 'S').slice(0, 2).toUpperCase(),
        x: x, y: y, offX: p.offX, offY: p.offY, w: p.w, h: p.h,
        col: d.status, idx: -1
      }
    });
  }

  hitTest(x, y) {
    if (typeof document === 'undefined') return { col: null, idx: -1 };
    let col = null;
    const cols = Array.prototype.slice.call(document.querySelectorAll('[data-kcol]'));
    cols.forEach(function (el) {
      const r = el.getBoundingClientRect();
      if (x >= r.left && x <= r.right && y >= r.top - 60 && y <= r.bottom + 60) col = el.getAttribute('data-kcol');
    });
    if (!col) return { col: null, idx: -1 };
    const cards = Array.prototype.slice.call(document.querySelectorAll('[data-kcol="' + col + '"] [data-kcard]'));
    let idx = cards.length;
    for (let i = 0; i < cards.length; i++) {
      const r = cards[i].getBoundingClientRect();
      if (y < r.top + r.height / 2) { idx = i; break; }
    }
    return { col: col, idx: idx };
  }

  _pm = (e) => {
    const p = this._pending;
    if (!p) return;
    if (!this.state.drag) {
      const moved = Math.abs(e.clientX - p.sx) + Math.abs(e.clientY - p.sy);
      if (p.touch) {
        if (moved > 14) { clearTimeout(this._lp); this._pending = null; this._kDetach(); }
        return;
      }
      if (moved > 5) this.beginDrag(e.clientX, e.clientY);
      return;
    }
    if (e.cancelable) e.preventDefault();
    const hit = this.hitTest(e.clientX, e.clientY);
    this.setState((s) => s.drag ? ({
      drag: Object.assign({}, s.drag, {
        x: e.clientX, y: e.clientY,
        col: hit.col || s.drag.col,
        idx: hit.col ? hit.idx : s.drag.idx
      })
    }) : null);
  };

  _pu = () => {
    clearTimeout(this._lp);
    const dr = this.state.drag;
    this._pending = null;
    this._kDetach();
    if (typeof document !== 'undefined') document.body.style.userSelect = '';
    if (!dr) return;
    setNoClickUntil(Date.now() + 500);
    if (typeof window !== 'undefined') {
      const swallow = function (ev) {
        ev.stopPropagation();
        ev.preventDefault();
        window.removeEventListener('click', swallow, true);
      };
      window.addEventListener('click', swallow, true);
      setTimeout(function () { window.removeEventListener('click', swallow, true); }, 500);
    }
    this.dropCard(dr.id, dr.col, dr.idx);
  };

  cardKey(id, e) {
    const k = e.key;
    if (k === ' ' || k === 'Spacebar' || k === 'Space') {
      e.preventDefault();
      const on = this.state.grabbed === id;
      this.setState({ grabbed: on ? '' : id });
      this.flash(on ? 'Carte déposée' : 'Carte saisie — ← et → pour la déplacer, Échap pour annuler');
      return;
    }
    if (this.state.grabbed !== id) return;
    if (k === 'ArrowLeft') { e.preventDefault(); this.moveCard(id, -1); }
    if (k === 'ArrowRight') { e.preventDefault(); this.moveCard(id, 1); }
    if (k === 'Escape') { e.preventDefault(); this.setState({ grabbed: '' }); this.flash('Déplacement annulé'); }
  }



  openSheet(kind, ctx) {
    if (kind === 'invite') return this.openInvitation();
    this.setState({ sheet: kind, sheetCtx: ctx || {}, sheetOpt: 0, sheetText: '', sheetChecks: [0, 1], sheetDone: false });
  }

  async confirmSheet() {
    const def = this.sheetDefs()[this.state.sheet];
    if (!def) return;
    if (this.state.sheet === 'editSignature') {
      const lines = this.state.sheetText.split(/\r?\n/).map(x => x.trim());
      if (lines.length !== 3 || !lines[0] || !lines[1] || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(lines[2])) return this.setState({ sheetErr: 'Indiquez un nom, une fonction et un courriel valide sur trois lignes.' });
      this.setState({ profileSignature: lines, sig: Object.assign({}, this.state.sig, { name: lines[0] }) });
    }
    if (this.state.sheet === 'exportRep') {
      try { await this.downloadReport(this.state.sheetOpt); } catch (e) { this.setState({ sheetErr: e.message }); return; }
    }
    this.setState({ sheetDone: true, sheetErr: '' });
    this.flash(def.doneTitle);
  }

  anonRules() {
    return [
      { pat: 'matricule 18432', token: '[MATRICULE MASQUÉ]', kind: 'Matricule RH', min: 'standard' },
      { pat: 'Marie Dupont', token: '[SALARIÉE A]', kind: 'Nom de la salariée', min: 'rh' },
      { pat: 'Mme Dupont', token: '[SALARIÉE A]', kind: 'Nom de la salariée', min: 'rh' },
      { pat: 'Mme Leroy', token: '[SALARIÉE A]', kind: 'Nom de la salariée', min: 'rh' },
      { pat: 'Dupont', token: '[SALARIÉE A]', kind: 'Nom de la salariée', min: 'rh' },
      { pat: 'Leroy', token: '[SALARIÉE A]', kind: 'Nom de la salariée', min: 'rh' },
      { pat: 'Marie', token: '[SALARIÉE A]', kind: 'Nom de la salariée', min: 'rh' },
      { pat: 'Karim', token: '[COLLÈGUE B — lien N+1]', kind: 'Tiers mis en cause', min: 'rh' },
      { pat: 'Valenciennes', token: '[ÉTABLISSEMENT]', kind: 'Établissement', min: 'rh' },
      { pat: 'service logistique', token: '[SERVICE]', kind: 'Service de rattachement', min: 'rps' },
      { pat: 'atelier B', token: '[SERVICE]', kind: 'Service de rattachement', min: 'rps' },
      { pat: 'Sophie Marchand', token: '[ÉLU CSE]', kind: 'Élu rédacteur', min: 'rps' },
      { pat: 'Sophie M.', token: '[ÉLU CSE]', kind: 'Élu rédacteur', min: 'rps' }
    ];
  }

  anonLevelDefs() {
    return [
      { key: 'standard', label: 'Standard', desc: 'NAO, budget, articles — masquage léger (matricules).', pieces: 'Résumé de pièce autorisé' },
      { key: 'rh', label: 'RH sensible', desc: 'Inaptitude, discipline — masquage nominatif + matricules.', pieces: 'Pièces bloquées, résumé masqué' },
      { key: 'rps', label: 'RPS', desc: 'Harcèlement, souffrance au travail — masquage maximal.', pieces: 'Pièces bloquées, aucun envoi en clair' }
    ];
  }

  detectLevel(t) {
    const s = (t || '').toLowerCase();
    if (s.indexOf('harc') > -1 || s.indexOf('rps') > -1 || s.indexOf('souffrance') > -1 || s.indexOf('moral') > -1 || s.indexOf('burn') > -1) return 'rps';
    if (s.indexOf('inaptitude') > -1 || s.indexOf('disciplin') > -1 || s.indexOf('sanction') > -1 || s.indexOf('licenci') > -1 || s.indexOf('reclass') > -1 || s.indexOf('médical') > -1) return 'rh';
    return 'standard';
  }

  levelForDossier(d) {
    if (!d) return 'standard';
    return this.detectLevel((d.tag || '') + ' ' + (d.title || '') + ' ' + (d.long || ''));
  }

  maskText(text, level) {
    let out = String(text || '');
    const tags = [], known = new Map();
    const hide = (clear, kind) => {
      const key = clear.toLocaleLowerCase('fr');
      if (known.has(key)) return known.get(key);
      let n = tags.length + 1, token;
      do { token = '[MASQUE_LOCAL_' + n++ + ']'; } while (out.includes(token) || tags.some((x) => x.token === token));
      known.set(key, token); tags.push({ clear: clear, token: token, kind: kind }); return token;
    };
    // Existing tokens are opaque; no matching inside a previous pseudonym.
    const sub = (re, kind) => { out = out.split(/(\[MASQUE_LOCAL_\d+\])/g).map((x) => /^\[MASQUE_LOCAL_\d+\]$/.test(x) ? x : x.replace(re, (v) => hide(v, kind))).join(''); };
    sub(/[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)+/gi, 'Courriel');
    sub(/\b(?:matricule|identifiant|n[°º]\s*(?:de\s*)?s[ée]curit[ée]\s+sociale)\s*[:#-]?\s*[A-Z0-9][A-Z0-9 .-]{2,24}(?=[,;\n]|$)/gi, 'Identifiant');
    sub(/\bmatricule\s*[:#-]?\s*[A-Z0-9-]+/gi, 'Matricule');
    sub(/(?:\+33\s?(?:\(0\)\s?)?|\b0)[1-9](?:[ .-]?\d{2}){4}\b/g, 'Téléphone');
    sub(/\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){11,30}\b/g, 'IBAN');
    sub(/\b[12]\s?\d{2}\s?\d{2}\s?[\dAB]\d\s?\d{3}\s?\d{3}\s?\d{2}\b/gi, 'Identifiant social');
    const names = (this.state.contacts || []).map((x) => x.name).concat((this.state.adherents || []).map((x) => [x.prenom,x.nom].filter(Boolean).join(' ')));
    this.anonRules().forEach((r) => names.push(r.pat));
    names.filter(Boolean).sort((a,b) => b.length-a.length).forEach((name) => {
      const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      sub(new RegExp('(?<![\\p{L}\\p{N}])' + escaped + '(?![\\p{L}\\p{N}])','giu'), 'Identité connue');
    });
    sub(/\b(?:Mme|Madame|Mlle|Monsieur|M\.)\s+[\p{Lu}][\p{L}'’'-]+(?:\s+[\p{Lu}][\p{L}'’'-]+){0,3}/gu, 'Identité');
    sub(/\b[\p{Lu}][\p{Ll}'’'-]+(?:\s+[\p{Lu}][\p{Ll}'’'-]+){1,3}\b/gu, 'Identité ou désignation');
    if (level === 'rps') sub(/\b\d{1,4}\s+(?:rue|avenue|boulevard|impasse|allée|chemin)\s+[^,;\n.]+/gi, 'Adresse');
    const stripped = out.replace(/\[MASQUE_LOCAL_\d+\]/g, ' ');
    const residual = [];
    if (/[\w.+-]+@[\w.-]+\.[a-z]{2,}/i.test(stripped)) residual.push('courriel');
    if (/\bmatricule\s*[:#-]?\s*\d+/i.test(stripped)) residual.push('matricule');
    return { masked: out, tags: tags, residual: residual };
  }

  /*@method:cases:dossierContext*/

  requestAi(q, level, meta) {
    if (!q) return;
    const ranks = { standard: 0, rh: 1, rps: 2 };
    const requested = level || this.state.anonLevel || 'standard';
    const detected = this.detectLevel(q);
    const lvl = ranks[requested] >= ranks[detected] ? requested : detected;
    this.setState((s) => ({
      route: 'assistant',
      history: s.route === 'assistant' ? s.history : s.history.concat([s.route]),
      input: '',
      anonOpen: true, anonQuery: q, anonLevel: lvl,
      anonPieces: (meta && meta.pieces) || 0,
      anonOrigin: (meta && meta.origin) || 'Assistant'
    }));
    if (typeof window !== 'undefined') window.scrollTo(0, 0);
  }

  confirmAnon() {
    const q = this.state.anonQuery;
    const lvl = this.state.anonLevel;
    const m = this.maskText(q, lvl);
    if (m.residual.length) { this.flash('Envoi refusé — un identifiant échappe au filtre'); return; }
    const levelLabel = (this.anonLevelDefs().find(function (l) { return l.key === lvl; }) || {}).label;
    const reidLine = m.tags.map(function (t) { return t.token + ' → ' + t.clear; }).join(' · ');
    const fp = ('7f3a' + (this.state.aiCalls * 977 % 9973).toString(16) + 'c1').toLowerCase();
    this.setState((s) => ({
      anonOpen: false, typing: true, aiCalls: s.aiCalls + 1,
      messages: s.messages.concat([{ isUser: true, text: q, payload: m.masked, levelLabel: levelLabel, tagCount: m.tags.length + ' entité' + (m.tags.length > 1 ? 's' : '') + ' masquée' + (m.tags.length > 1 ? 's' : '') }])
    }));
    this.flash('Envoi en cours — texte masqué préparé');
    this.runAssistant(q, m.masked, {
      reidLine: reidLine ? 'Ré-identifié à l\'écran : ' + reidLine : '',
      logLine: 'Journal d\'appel IA · empreinte ' + fp + ' · niveau ' + levelLabel + ' · ' + m.tags.length + ' entités masquées · aucun clair enregistré'
    });
  }

/* ---- Agenda partagé ---- */
  iaSecuVals() {
    return {
      back: () => this.go('securite'),
      chapters: [
        {
          title: 'Modèle souverain par défaut',
          note: 'Spécification cible, non garantie par ce prototype local : Aucune donnée ne quitte l\'Union européenne sans décision explicite d\'un administrateur.',
          items: [
            { t: 'Hébergement UE', d: 'Le modèle retenu par défaut est hébergé dans l\'Union européenne, chez un fournisseur soumis au seul droit européen. Aucun transfert vers un pays tiers, aucune clause de rattachement extraterritorial.' },
            { t: 'Pas d\'entraînement sur vos données', d: 'Le contrat de sous-traitance interdit l\'usage des requêtes pour l\'entraînement ou l\'amélioration du modèle. Rétention nulle côté fournisseur (zero data retention).' },
            { t: 'Changement de fournisseur tracé', d: 'Un administrateur peut désigner un autre modèle depuis Configuration IA. Le changement est journalisé, notifié aux élus et bloqué si le fournisseur est hors UE sans analyse d\'impact validée.' },
            { t: 'Repli hors ligne', d: 'Si le modèle est indisponible, l\'application n\'invente rien : l\'erreur est affichée et la fonctionnalité reste inactive. Aucune réponse fabriquée localement ne se substitue à un avis juridique.' }
          ]
        },
        {
          title: 'Anonymisation avant tout appel',
          note: 'Spécification cible, non garantie par ce prototype local : Le masquage est un préalable technique, pas une option de confort.',
          items: [
            { t: 'Trois niveaux', d: 'Standard (noms et matricules), renforcé (identité, service, dates précises) et maximal (toute donnée directement ou indirectement identifiante). Le niveau est proposé automatiquement selon la nature du dossier, et relevable manuellement.' },
            { t: 'Refus en cas de résidu', d: 'Après masquage, le texte est repassé au filtre. S\'il subsiste un identifiant, l\'envoi est annulé et un message le signale. Aucun appel ne part « au bénéfice du doute ».' },
            { t: 'Jetons réversibles côté client', d: 'Les entités masquées sont remplacées par des jetons stables. La correspondance ne quitte jamais l\'appareil : elle sert uniquement à recoller les noms dans la réponse affichée.' },
            { t: 'Pseudonymisation, pas anonymisation', d: 'Le masquage réduit fortement le risque mais ne fait pas sortir les données du champ du RGPD. La minimisation reste une obligation de l\'élu : ne décrivez pas une situation plus précisément que nécessaire.' }
          ]
        },
        {
          title: 'Périmètre de connaissance du modèle',
          note: 'Spécification cible, non garantie par ce prototype local : Le modèle ne répond que sur le corpus de votre organisation.',
          items: [
            { t: 'Corpus injecté, contrôlé', d: 'Convention collective applicable, extraits du Code du travail, accords d\'entreprise et, le cas échéant, les seuls dossiers que vous avez sélectionnés. Rien d\'autre n\'est fourni au modèle.' },
            { t: 'Sources citées', d: 'Chaque réponse indique la source mobilisée. Une réponse sans source rattachable doit être traitée comme non fiable et vérifiée.' },
            { t: 'Hors périmètre refusé', d: 'Les questions étrangères au champ social sont refusées et redirigées vers l\'administrateur ou l\'informatique de la fédération.' },
            { t: 'Questions techniques bloquées', d: 'Les questions portant sur l\'identité du modèle, son fournisseur, sa version, sa clé d\'accès ou son architecture sont interceptées par l\'application avant tout appel réseau ; la réponse reste locale.' }
          ]
        },
        {
          title: 'Conformité RGPD',
          note: 'Spécification cible, non garantie par ce prototype local : Deux responsables de traitement distincts : le CSE et l\'organisation syndicale.',
          items: [
            { t: 'Séparation des périmètres', d: 'Les données du CSE (dossiers, séances, PV) et celles du syndicat (adhésion, cotisations) relèvent de traitements distincts, avec des rôles, des journaux et des registres séparés. Un élu non syndiqué n\'accède pas au fichier d\'adhésion.' },
            { t: 'Données sensibles', d: 'L\'appartenance syndicale et les données de santé relèvent de l\'article 9 : chiffrement au repos, accès restreint par rôle, contrôle serveur sur chaque requête, journal d\'audit inaltérable sur toute consultation.' },
            { t: 'Information des personnes', d: 'Une notice d\'information est présentée sur chaque écran de collecte : saisine d\'un salarié, création de fiche, import de fichier, enregistrement de séance, sondage.' },
            { t: 'Exercice des droits', d: 'Accès, rectification, effacement, portabilité et opposition sont instruits depuis Confidentialité & RGPD, avec un délai d\'un mois affiché et une recherche transverse au nom de la personne concernée.' },
            { t: 'Durées de conservation', d: 'Dossier clos + 5 ans, PV selon les obligations légales, audio détruit à l\'approbation du PV, requêtes au modèle 12 mois sans contenu en clair, journal d\'audit 3 ans.' },
            { t: 'Analyse d\'impact', d: 'Une AIPD est conduite par périmètre et visée par le délégué à la protection des données de la fédération, en raison du croisement de données sensibles et de l\'usage d\'un modèle de langage.' }
          ]
        },
        {
          title: 'Sécurité technique',
          note: 'Spécification cible, non garantie par ce prototype local : Ce que l\'application garantit, et où la garantie s\'arrête.',
          items: [
            { t: 'Chiffrement', d: 'Chiffrement en transit et au repos, clés conservées hors de la base applicative. Les pièces jointes des dossiers sont chiffrées avant envoi.' },
            { t: 'Authentification', d: 'Double authentification obligatoire pour les rôles trésorier et administrateur, recommandée pour tous. Appareils connectés révocables à tout moment.' },
            { t: 'Autorisation côté serveur', d: 'Chaque requête est contrôlée sur le serveur, y compris les filtres de recherche. Les rôles affichés à l\'écran ne sont jamais la source de l\'autorisation.' },
            { t: 'Journal d\'audit', d: 'Ajout seul, sans modification ni suppression possible : consultations du fichier d\'adhésion, exports, imports, campagnes, suppressions et appels au modèle y sont inscrits.' },
            { t: 'Aucun appel tiers depuis votre navigateur', d: 'Polices et ressources sont servies par l\'infrastructure de l\'application. Une politique de sécurité de contenu stricte interdit toute requête sortante non prévue.' },
            { t: 'Réversibilité', d: 'Vos données sont exportables dans un format ouvert à tout moment, sans intervention de l\'éditeur.' }
          ]
        },
        {
          title: 'Ce que vous devez savoir en tant qu\'élu',
          note: 'Spécification cible, non garantie par ce prototype local : Trois limites à garder en tête.',
          items: [
            { t: 'Vérifier avant tout usage contentieux', d: 'Une réponse du modèle est une aide à la rédaction et à la recherche, jamais un avis juridique. Recoupez toujours avec le texte cité avant de l\'opposer à l\'employeur.' },
            { t: 'Ne pas contourner le masquage', d: 'Le masquage porte sur les entités qu\'il sait reconnaître. Un récit très détaillé peut rendre une personne identifiable sans qu\'aucun nom n\'apparaisse : décrivez au plus juste.' },
            { t: 'L\'enregistrement suppose l\'accord des participants', d: 'Une séance ne peut être enregistrée qu\'avec le consentement de chaque participant, révocable, et avec mention en début de séance.' }
          ]
        }
      ],
      docs: [
        { label: 'Registre des traitements', meta: 'Deux périmètres — CSE et organisation syndicale' },
        { label: 'Analyse d\'impact (AIPD)', meta: 'Une par périmètre, visée par le DPO de la fédération' },
        { label: 'Contrat de sous-traitance du modèle', meta: 'Hébergement UE, rétention nulle, non-entraînement' },
        { label: 'Politique de conservation et de purge', meta: 'Durées par catégorie de données' },
        { label: 'Procédure d\'exercice des droits', meta: 'Réception, qualification, réponse sous un mois' },
        { label: 'Journal d\'audit — spécification', meta: 'Événements tracés, format, durée de trois ans' }
      ],
      contact: () => this.flash('Demande adressée au délégué à la protection des données de la fédération')
    };
  }

  orgTypeDefs() {
    return [
      { id: 'cse', label: 'CSE', note: 'Comité social et économique — instance élue de l\'entreprise. Vocabulaire : élus, séances, procès-verbaux, budget.' },
      { id: 'ud', label: 'Union départementale', note: 'Structure interprofessionnelle du syndicat. Vocabulaire : adhérents, militants, assemblée générale, cotisations.' },
      { id: 'section', label: 'Section syndicale', note: 'Section d\'entreprise ou d\'établissement. Vocabulaire : adhérents, militants, réunion de section, cotisations.' }
    ];
  }

  W() {
    const t = (this.state.org || {}).type || 'cse';
    if (t === 'cse') {
      return {
        type: 'cse', synd: false,
        people: 'Élus',
        memberNav: 'Représentants',
        memberTitle: 'Représentants du personnel',
        memberOne: 'représentant',
        memberMany: 'représentants',
        memberKicker: 'Représentation du personnel',
        seance: 'Réunion CSE',
        plenary: 'Réunion plénière',
        perm: 'Permanence des élus',
        moneyTab: 'Budget',
        showCotis: false,
        importTitle: 'Importer des représentants',
        msgTitle: 'Message aux représentants',
        visibElus: 'Élus seulement',
        visibMembers: 'Élus et suppléants',
        listNote: 'Le CSE ne tient pas de fichier d\'adhésion : ces listes servent aux convocations et à l\'information des représentants.'
      };
    }
    const ud = t === 'ud';
    return {
      type: t, synd: true,
      people: 'Militants',
      memberNav: 'Adhérents',
      memberTitle: 'Adhérents',
      memberOne: 'adhérent',
      memberMany: 'adhérents',
      memberKicker: 'Adhésion et cotisations',
      seance: ud ? 'Réunion de l\'UD' : 'Réunion de section',
      plenary: 'Assemblée générale',
      perm: 'Permanence syndicale',
      moneyTab: 'Cotisations',
      showCotis: true,
      importTitle: 'Importer des adhérents',
      msgTitle: 'Message aux adhérents',
      visibElus: 'Militants seulement',
      visibMembers: 'Militants et adhérents',
      listNote: 'Une liste dynamique se recalcule à chaque adhésion, changement de section ou de statut de cotisation.'
    };
  }

  orgFieldDefs() {
    return [
      { k: 'nom', label: 'Dénomination', hint: 'Reprise dans les en-têtes de documents et sur l\'intranet.', type: 'text' },
      { k: 'sigle', label: 'Sigle', hint: 'Utilisé quand la place manque : onglets, pieds de page.', type: 'text' },
      { k: 'siret', label: 'SIRET', hint: '14 chiffres. Obligatoire pour les documents comptables.', type: 'text' },
      { k: 'idcc', label: 'Convention collective', hint: 'Code IDCC et intitulé. Détermine le corpus juridique interrogé par l\'assistant.', type: 'text' },
      { k: 'effectif', label: 'Effectif de l\'établissement', hint: 'Sert au calcul des seuils et du budget de fonctionnement.', type: 'text' },
      { k: 'sieges', label: 'Sièges au CSE', hint: 'Titulaires. Contrôle le quorum affiché en réunion.', type: 'text' },
      { k: 'mandatDebut', label: 'Début du mandat', hint: '', type: 'date' },
      { k: 'mandatFin', label: 'Fin du mandat', hint: 'Les échéances de renouvellement en découlent.', type: 'date' },
      { k: 'adresse', label: 'Adresse du local', hint: '', type: 'text' },
      { k: 'email', label: 'Courriel de l\'instance', hint: 'Adresse d\'expédition des campagnes et convocations.', type: 'text' },
      { k: 'tel', label: 'Téléphone', hint: '', type: 'text' },
      { k: 'secretaire', label: 'Secrétaire', hint: '', type: 'text' },
      { k: 'tresorier', label: 'Trésorier', hint: '', type: 'text' }
    ];
  }

  orgStartEdit() { this.setState((s) => ({ orgEdit: true, orgDraft: Object.assign({}, s.org) })); }

  orgCancelEdit() { this.setState({ orgEdit: false, orgDraft: null }); }

  orgPatch(k, v) { this.setState((s) => ({ orgDraft: Object.assign({}, s.orgDraft, { [k]: v }) })); }

  orgSave() {
    const d = this.state.orgDraft || {};
    if (!String(d.nom || '').trim()) return this.flash('La dénomination est obligatoire');
    if (d.siret && String(d.siret).replace(/\D/g, '').length !== 14) return this.flash('Le SIRET doit comporter 14 chiffres');
    if (d.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(d.email)) return this.flash('Adresse de courriel invalide');
    if (d.mandatDebut && d.mandatFin && d.mandatFin <= d.mandatDebut) return this.flash('La fin du mandat doit suivre son début');
    this.setState({ org: Object.assign({}, d), orgEdit: false, orgDraft: null });
    this.flash('Informations de l\'organisation enregistrées');
  }

  orgVals() {
    const st = this.state;
    const cur = st.orgEdit ? (st.orgDraft || st.org) : st.org;
    const fr = (s) => {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(s || ''))) return s || '—';
      const p = String(s).split('-');
      return Number(p[2]) + ' ' + new Intl.DateTimeFormat('fr-FR',{month:'long'}).format(new Date(2000,Number(p[1])-1,1)) + ' ' + p[0];
    };
    return {
      editing: st.orgEdit,
      reading: !st.orgEdit,
      startEdit: () => this.orgStartEdit(),
      cancelEdit: () => this.orgCancelEdit(),
      save: () => this.orgSave(),
      title: st.org.nom,
      subtitle: st.org.sigle + ' · ' + st.org.sieges + ' sièges · ' + st.org.effectif + ' salariés',
      types: this.orgTypeDefs().map((d) => {
        const on = (cur.type || 'cse') === d.id;
        return {
          label: d.label, on: on,
          bg: on ? 'var(--acBg)' : 'var(--surf2)', fg: on ? 'var(--acTx2)' : 'var(--ink4)',
          ring: on ? 'var(--acMid)' : 'transparent',
          go: () => {
            if (st.orgEdit) this.orgPatch('type', d.id);
            else { this.setState((s) => ({ org: Object.assign({}, s.org, { type: d.id }) })); this.flash('Vocabulaire de l\'application adapté — ' + d.label); }
          }
        };
      }),
      typeNote: (this.orgTypeDefs().find(function (d) { return d.id === (cur.type || 'cse'); }) || {}).note,
      rows: this.orgFieldDefs().map((f) => ({
        label: f.label,
        value: f.type === 'date' ? fr(cur[f.k]) : (cur[f.k] || '—')
      })),
      fields: this.orgFieldDefs().map((f) => ({
        label: f.label,
        hint: f.hint,
        hasHint: !!f.hint,
        type: f.type,
        value: cur[f.k] || '',
        wide: f.k === 'nom' || f.k === 'idcc' || f.k === 'adresse' ? '1 / -1' : 'auto',
        on: (e) => this.orgPatch(f.k, e.target.value)
      }))
    };
  }

  navMove(id, step) {
    this.setState((s) => {
      const o = s.navOrder.slice();
      const i = o.indexOf(id);
      const j = i + step;
      if (i < 0 || j < 0 || j >= o.length) return null;
      o[i] = o[j];
      o[j] = id;
      return { navOrder: o };
    });
  }

  

  

  

  

  

  

  admVals() {
    const s = this.state, r = s.admRoute;
    const setU = (list) => this.setState({ admUsers: list });
    const q = s.admQuery.trim().toLowerCase();
    const etats = { 'Actif': ['var(--okBg)', 'var(--okTx2)'], 'Suspendu': ['var(--dangerBg)', 'var(--dangerTx2)'], 'Invitation en attente': ['var(--warnBg)', 'var(--warnTx2)'] };
    const users = s.admUsers.filter((u) => (s.admFilter === 'Tous' || u.etat === s.admFilter) && (!q || (u.nom + ' ' + u.mail + ' ' + u.org).toLowerCase().includes(q)));
    const mask = (k) => k.slice(0, 7) + '••••-••••-••••' + k.slice(-4);
    const editorSet = (k, v) => this.setState({ admEditor: Object.assign({}, s.admEditor, { [k]: v }) });
    const totalIa = s.admOrgs.reduce((a, o) => a + o.iaMois, 0);
    return {
      nav: [
        { id: 'supervision', label: 'Supervision', d: 'M3 3v18h18', d2: 'm19 9-5 5-4-4-3 3' },
        { id: 'organisations', label: 'Organisations', d: 'M3 21h18', d2: 'M5 21V7l7-4 7 4v14' },
        { id: 'utilisateurs', label: 'Utilisateurs', d: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2', d2: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8' },
        { id: 'cles', label: 'Clés API IA', d: 'M15 7a5 5 0 1 1-4.9 6H7v3H4v-3H2v-3h8.1A5 5 0 0 1 15 7z', d2: 'M17 10h.01' },
        { id: 'editeur', label: 'Éditeur de l\u2019application', d: 'M4 4h16v12H4z', d2: 'M8 20h8' },
        { id: 'facturation', label: 'Abonnements et paiements', d: 'M2 7h20v12H2z', d2: 'M2 11h20M6 15h4' },
        { id: 'journaux', label: 'Journal d\u2019audit', d: 'M4 3h12l4 4v14H4z', d2: 'M8 13h8M8 17h5' }
      ].map((n) => Object.assign({}, n, { active: r === n.id, idle: r !== n.id, go: () => this.setState({ admRoute: n.id, admSel: null, mobileAdmin: false }) })),
      isBilling: r === 'facturation',
      isSup: r === 'supervision', isOrgs: r === 'organisations', isUsers: r === 'utilisateurs', isKeys: r === 'cles', isEditor: r === 'editeur', isLogs: r === 'journaux',
      logout: () => { this.setState({ adminAuthed: false, authed: false, auth: { step: 'id', email: 'admin@uniion.fr', pwd: '', code: '', err: '', sso: false, admin: false } }); if (typeof window !== 'undefined') window.scrollTo(0, 0); },
      kpis: [
        { k: 'Organisations actives', v: String(s.admOrgs.filter((o) => o.etat === 'Actif').length) + ' / ' + s.admOrgs.length, sub: '1 essai en cours' },
        { k: 'Comptes utilisateurs', v: String(s.admUsers.length), sub: String(s.admUsers.filter((u) => u.etat === 'Actif').length) + ' actifs' },
        { k: 'MFA activée', v: Math.round(100 * s.admUsers.filter((u) => u.mfa).length / s.admUsers.length) + ' %', sub: String(s.admUsers.filter((u) => !u.mfa).length) + ' comptes à relancer' },
        { k: 'Requêtes IA (30 j)', v: totalIa.toLocaleString('fr-FR'), sub: 'Coût estimé 214 €' }
      ],
      alerts: [
        { t: 'Quota IA à 80 % — UD 59 — Lille', s: 'Relever le plafond ou prévenir l\u2019organisation.', c: 'var(--warnBg)', b: 'var(--warnBd2)', x: 'var(--warnTx2)' },
        { t: '2 comptes sans MFA', s: 'Nadia Ferrand, Claire Dubois — relance possible en un clic.', c: 'var(--dangerBg)', b: 'var(--dangerBd2)', x: 'var(--dangerTx2)' },
        { t: 'Essai CSE Brasserie du Nord — 12 jours restants', s: 'Aucune commande enregistrée.', c: 'var(--infoBg)', b: 'var(--bd2)', x: 'var(--infoTx2)' }
      ],
      orgs: s.admOrgs.map((o) => ({
        nom: o.nom, type: o.type, membres: String(o.membres), adherents: o.adherents.toLocaleString('fr-FR'), offre: planNom(o.offre), etat: o.etat, ia: o.iaMois.toLocaleString('fr-FR'),
        pct: Math.min(100, Math.round(100 * o.iaMois / 8000)) + '%',
        suspend: () => { this.setState({ admOrgs: s.admOrgs.map((x) => x.id === o.id ? Object.assign({}, x, { etat: x.etat === 'Suspendu' ? 'Actif' : 'Suspendu' }) : x) }); this.flash(o.etat === 'Suspendu' ? 'Organisation réactivée' : 'Organisation suspendue'); },
        suspendLabel: o.etat === 'Suspendu' ? 'Réactiver' : 'Suspendre'
      })),
      query: s.admQuery, onQuery: (e) => this.setState({ admQuery: e.target.value }),
      filters: ['Tous', 'Actif', 'Suspendu', 'Invitation en attente'].map((f) => ({
        label: f, on: s.admFilter === f, off: s.admFilter !== f, go: () => this.setState({ admFilter: f })
      })),
      usersCount: users.length + (users.length > 1 ? ' comptes' : ' compte'),
      usersEmpty: users.length === 0,
      users: users.map((u) => ({
        nom: u.nom, mail: u.mail, org: u.org, role: u.role, etat: u.etat, vu: u.vu,
        initials: u.nom.split(' ').map((p) => p.charAt(0)).join('').slice(0, 2).toUpperCase(),
        etatBg: (etats[u.etat] || ['var(--chip)', 'var(--ink4)'])[0], etatTx: (etats[u.etat] || ['var(--chip)', 'var(--ink4)'])[1],
        mfaLabel: u.mfa ? 'MFA active' : 'Sans MFA', mfaTx: u.mfa ? 'var(--ink5)' : 'var(--dangerTx2)',
        suspendLabel: u.etat === 'Suspendu' ? 'Réactiver' : 'Suspendre',
        suspend: () => { setU(s.admUsers.map((x) => x.id === u.id ? Object.assign({}, x, { etat: x.etat === 'Suspendu' ? 'Actif' : 'Suspendu' }) : x)); this.flash(u.etat === 'Suspendu' ? 'Compte réactivé' : 'Compte suspendu'); },
        resetMfa: () => { setU(s.admUsers.map((x) => x.id === u.id ? Object.assign({}, x, { mfa: false }) : x)); this.flash('MFA réinitialisée — l\u2019utilisateur devra la reconfigurer'); },
        impersonate: () => this.flash('Session d\u2019assistance ouverte en lecture seule — tracée au journal'),
        relance: () => this.flash('Relance envoyée à ' + u.mail)
      })),
      keys: s.admKeys.map((k) => ({
        label: k.label, fournisseur: k.fournisseur, creee: k.creee, etat: k.etat,
        active: k.etat === 'Active', etatBg: k.etat === 'Active' ? 'var(--okBg)' : 'var(--chip)', etatTx: k.etat === 'Active' ? 'var(--okTx2)' : 'var(--ink5)',
        shown: s.admReveal === k.id ? k.cle : mask(k.cle),
        revealLabel: s.admReveal === k.id ? 'Masquer' : 'Afficher',
        reveal: () => this.setState({ admReveal: s.admReveal === k.id ? null : k.id }),
        quota: k.quota + ' k req./mois', conso: k.conso + ' k consommées', pct: Math.min(100, Math.round(100 * k.conso / k.quota)) + '%',
        copy: () => { if (typeof navigator !== 'undefined' && navigator.clipboard) navigator.clipboard.writeText(k.cle); this.flash('Clé copiée — la copie est tracée au journal'); },
        rotate: () => { this.setState({ admKeys: s.admKeys.map((x) => x.id === k.id ? Object.assign({}, x, { cle: 'sk-live-' + Math.random().toString(16).slice(2, 6) + '-' + Math.random().toString(16).slice(2, 6) + '-' + Math.random().toString(16).slice(2, 6) + '-' + Math.random().toString(16).slice(2, 6), creee: '11/09/2026' }) : x) }); this.flash('Clé remplacée — l\u2019ancienne reste valable 24 h'); },
        revoke: () => { this.setState({ admKeys: s.admKeys.map((x) => x.id === k.id ? Object.assign({}, x, { etat: x.etat === 'Active' ? 'Révoquée' : 'Active' }) : x) }); this.flash(k.etat === 'Active' ? 'Clé révoquée' : 'Clé réactivée'); },
        revokeLabel: k.etat === 'Active' ? 'Révoquer' : 'Réactiver'
      })),
      keyNew: s.admKeyNew, keyDraft: s.admKeyDraft,
      keyAdd: () => this.setState({ admKeyNew: true }),
      keyCancel: () => this.setState({ admKeyNew: false }),
      keySetLabel: (e) => this.setState({ admKeyDraft: Object.assign({}, s.admKeyDraft, { label: e.target.value }) }),
      keyProviders: ['Mistral (Paris)', 'Scaleway Génératif (Paris)', 'OVHcloud AI (Gravelines)'].map((p) => ({
        label: p, on: s.admKeyDraft.fournisseur === p, off: s.admKeyDraft.fournisseur !== p,
        go: () => this.setState({ admKeyDraft: Object.assign({}, s.admKeyDraft, { fournisseur: p }) })
      })),
      keySave: () => {
        const d = s.admKeyDraft;
        if (!d.label.trim()) return this.flash('Donnez un nom à la clé');
        this.setState({ admKeys: s.admKeys.concat([{ id: 'k' + Date.now(), label: d.label.trim(), fournisseur: d.fournisseur, cle: 'sk-live-' + Math.random().toString(16).slice(2, 6) + '-' + Math.random().toString(16).slice(2, 6) + '-' + Math.random().toString(16).slice(2, 6) + '-' + Math.random().toString(16).slice(2, 6), etat: 'Active', quota: d.quota, conso: 0, creee: '11/09/2026' }]), admKeyNew: false, admKeyDraft: { label: '', fournisseur: 'Mistral (Paris)', quota: 40 } });
        this.flash('Clé créée — copiez-la, elle ne sera plus affichée en clair');
      },
      mrr: s.admOrgs.reduce((a, o) => a + planPrix(o.offre), 0).toLocaleString('fr-FR') + ' € HT',
      billRows: s.admOrgs.map((o) => ({
        nom: o.nom, offre: planNom(o.offre), etat: o.etat,
        prix: planPrix(o.offre) + ' € HT/mois',
        impayé: o.etat === 'Suspendu',
        plans: ['Élu 1.0', 'Élu 2.0', 'Élu 3.0', 'Élu 4.0'].map((p) => ({
          label: p, on: planNom(o.offre) === p, off: planNom(o.offre) !== p,
          go: () => { this.setState({ admOrgs: s.admOrgs.map((x) => x.id === o.id ? Object.assign({}, x, { offre: p }) : x) }); this.flash(o.nom + ' → ' + p); }
        })),
        invoice: () => this.flash('Facture émise pour ' + o.nom),
        relance: () => this.flash('Relance de paiement envoyée à ' + o.nom)
      })),
      billPlans: PLANS.map((p) => ({
        nom: p.nom, prix: p.prix + ' € HT/mois', bl: p.bl,
        abos: String(s.admOrgs.filter((o) => planNom(o.offre) === p.nom).length),
        pop: p.pop
      })),
      ed: s.admEditor,
      edToggles: [
        { k: 'maintenance', label: 'Mode maintenance', sub: 'Ferme l\u2019accès aux utilisateurs et affiche une page d\u2019attente.' },
        { k: 'inscriptions', label: 'Nouvelles organisations', sub: 'Autorise la création de comptes depuis le site public.' },
        { k: 'iaPublique', label: 'Assistant IA disponible', sub: 'Coupe globalement les appels au modèle en cas d\u2019incident.' }
      ].map((t) => ({
        label: t.label, sub: t.sub, on: !!s.admEditor[t.k],
        bg: s.admEditor[t.k] ? 'var(--ac)' : 'var(--bd2)', x: s.admEditor[t.k] ? 'translateX(20px)' : 'translateX(2px)',
        toggle: () => editorSet(t.k, !s.admEditor[t.k])
      })),
      edBanner: s.admEditor.banniere,
      edSetBanner: (e) => editorSet('banniere', e.target.value),
      edBannerShown: !!s.admEditor.banniere.trim(),
      edPublish: () => this.flash('Réglages appliqués à toutes les organisations'),
      edTemplates: [
        { nom: 'Tract A4', v: 'v3', maj: '09/09/2026', etat: 'Publié' },
        { nom: 'Convocation de réunion', v: 'v2', maj: '28/08/2026', etat: 'Publié' },
        { nom: 'Compte rendu de section', v: 'v5', maj: '02/09/2026', etat: 'Publié' },
        { nom: 'Page intranet — actualité', v: 'v1', maj: '11/09/2026', etat: 'Brouillon' }
      ].map((t) => Object.assign({}, t, {
        bg: t.etat === 'Publié' ? 'var(--okBg)' : 'var(--warnBg)', tx: t.etat === 'Publié' ? 'var(--okTx2)' : 'var(--warnTx2)',
        act: () => this.flash(t.etat === 'Publié' ? 'Gabarit « ' + t.nom + ' » ouvert en édition' : 'Gabarit « ' + t.nom + ' » publié'),
        actLabel: t.etat === 'Publié' ? 'Modifier' : 'Publier'
      })),
      logs: s.admLogs.map((l) => ({
        t: l.t, qui: l.qui, quoi: l.quoi, niv: l.niv,
        bg: l.niv === 'Sensible' ? 'var(--dangerBg)' : l.niv === 'Alerte' ? 'var(--warnBg)' : 'var(--chip)',
        tx: l.niv === 'Sensible' ? 'var(--dangerTx2)' : l.niv === 'Alerte' ? 'var(--warnTx2)' : 'var(--ink4)'
      })),
      exportLogs: () => this.exportLocalLogs()
    };
  }

  planVals() {
    const s = this.state, cur = PLANS.find((p) => p.id === s.plan) || PLANS[0];
    const yearly = s.planCycle === 'an';
    const price = (p) => yearly ? Math.round(p.prix * 10) : p.prix;
    return {
      currentNom: cur.nom,
      currentPrix: price(cur).toLocaleString('fr-FR') + ' € HT / ' + (yearly ? 'an' : 'mois'),
      currentBl: cur.bl,
      renew: yearly ? 'Reconduction le 01/09/2027' : 'Prochaine échéance le 01/10/2026',
      cycles: ['mois', 'an'].map((c) => ({
        label: c === 'mois' ? 'Mensuel' : 'Annuel (2 mois offerts)', on: s.planCycle === c, off: s.planCycle !== c,
        go: () => this.setState({ planCycle: c })
      })),
      cards: PLANS.map((p) => ({
        nom: p.nom, bl: p.bl, cta: p.cta, feats: p.feats, pop: p.pop,
        prix: price(p).toLocaleString('fr-FR') + ' €',
        unite: yearly ? 'HT/an' : 'HT/mois',
        current: p.id === s.plan, other: p.id !== s.plan,
        bd: p.id === s.plan ? 'var(--ac)' : p.pop ? 'var(--acMid)' : 'var(--bd)',
        shadow: p.pop ? '0 12px 30px -18px rgba(0,0,0,.35)' : 'none',
        ctaLabel: p.id === s.plan ? 'Formule actuelle' : p.prix > cur.prix ? 'Passer à ' + p.nom : 'Revenir à ' + p.nom,
        pick: () => { if (p.id === s.plan) return; this.setState({ plan: p.id }); this.flash('Formule ' + p.nom + ' activée — facturation au prorata'); },
        contact: () => this.flash(p.cta + ' — demande transmise, réponse sous 24 h')
      })),
      card: s.planCard,
      changeCard: () => this.flash('Redirection vers le prestataire de paiement (3-D Secure)'),
      factures: s.factures.map((f) => Object.assign({}, f, { dl: () => this.flash('Facture ' + f.num + ' téléchargée') })),
      dlAll: () => this.flash('Toutes les factures exportées (ZIP)')
    };
  }

  scVals() {
    const d = this.state.scDraft;
    const host = (u) => { try { return new URL(u).hostname.replace(/^www\./, ''); } catch (e) { return u; } };
    const valid = !!(d && d.label.trim() && /^https?:\/\//i.test(d.url.trim()));
    const set = (k) => (e) => this.setState({ scDraft: Object.assign({}, this.state.scDraft, { [k]: e.target.value }) });
    return {
      count: this.state.shortcuts.length + (this.state.shortcuts.length === 1 ? ' raccourci' : ' raccourcis'),
      empty: this.state.shortcuts.length === 0,
      items: this.state.shortcuts.map((s) => ({
        label: s.label, url: this.safeHref(s.url), note: s.note || host(s.url), host: host(s.url), color: s.color || '#1D4ED8', initial: (s.label || '?').trim().charAt(0).toUpperCase(),
        armed: this.state.scArmDel === s.id,
        edit: () => this.setState({ scDraft: Object.assign({}, s), scArmDel: null }),
        arm: () => this.setState({ scArmDel: s.id }),
        cancelDel: () => this.setState({ scArmDel: null }),
        del: () => { this.setState({ shortcuts: this.state.shortcuts.filter((x) => x.id !== s.id), scArmDel: null }); this.flash('Raccourci supprimé'); }
      })),
      add: () => this.setState({ scDraft: { id: '', label: '', url: '', note: '', color: '#1D4ED8' }, scArmDel: null }),
      editing: !!d, isNew: !!d && !d.id, draft: d || { label: '', url: '', note: '', color: '#1D4ED8' },
      setLabel: set('label'), setUrl: set('url'), setNote: set('note'),
      colors: ['#1D4ED8', '#B91C1C', '#047857', '#7C3AED', '#C2410C', '#0F766E', '#374151'].map((c) => ({
        c, ring: d && d.color === c ? '0 0 0 3px var(--surface), 0 0 0 5px ' + c : 'none',
        pick: () => this.setState({ scDraft: Object.assign({}, this.state.scDraft, { color: c }) })
      })),
      valid, saveBg: valid ? 'var(--ink)' : 'var(--bd2)', saveFg: valid ? '#fff' : 'var(--ink6)',
      cancel: () => this.setState({ scDraft: null }),
      save: () => {
        if (!valid) return;
        const s = Object.assign({}, d, { label: d.label.trim(), url: d.url.trim() });
        const list = s.id ? this.state.shortcuts.map((x) => x.id === s.id ? s : x) : this.state.shortcuts.concat([Object.assign(s, { id: 'sc' + Date.now() })]);
        this.setState({ shortcuts: list, scDraft: null });
        this.flash(s.id && d.id ? 'Raccourci modifié' : 'Raccourci ajouté');
      }
    };
  }

  

  

  

  

  

  

  

  

  

  

/* ---- Appels au modèle ---- */
  llmLocal() { return null; }
  llmSource() { return 'none'; }
  async llmText() { throw new Error('Passerelle IA authentifiée requise.'); }

  llmConnVals() {
    return {pillBg:'var(--surf2)',pillFg:'var(--ink3)',status:'Connexion requise',note:'La passerelle IA nécessite une session authentifiée.',canReview:false,hasKey:false,models:[],testLabel:'Tester la connexion',testMsg:'',test:()=>this.flash('Connexion requise')};
  }

  aiCorpus() { return AI_CORPUS; }

  offTopic(q) {
    const s = ' ' + String(q || '').toLowerCase().replace(/[’']/g, "'") + ' ';
    const pats = [
      /\bllm\b/, /mod[eè]le de langage/, /quel(le)? mod[eè]le/, /grand mod[eè]le/, /r[eé]seau de neurones/,
      /\bgpt\b/, /chatgpt/, /claude/, /anthropic/, /openai/, /mistral/, /gemini/, /llama/, /copilot/, /deepseek/,
      /prompt syst[eè]me/, /system prompt/, /tes (instructions|consignes|r[eè]gles|directives)/, /tes prompts?/,
      /(ignore|oublie|contourne)[^.]{0,20}(consignes|instructions|r[eè]gles)/,
      /donn[eé]es d'entra[iî]nement/, /entra[iî]n[eé]? sur/, /jeu de donn[eé]es/, /fen[eê]tre de contexte/, /\btokens?\b/, /temp[eé]rature du mod[eè]le/,
      /cl[eé] api/, /\bapi\b/, /quel (fournisseur|[eé]diteur|prestataire)/, /h[eé]berg[eé]e? (o[uù]|sur)/, /architecture technique/, /quelle version/,
      /qui t'a (cr[eé][eé]|con[cç]u|d[eé]velopp[eé]|entra[iî]n[eé]|programm[eé])/, /es-tu (une |un )?(ia|intelligence artificielle|robot|humain|machine|bot)/,
      /tu es (quelle |une |un )?(ia|intelligence artificielle|mod[eè]le)/, /comment (tu )?fonctionnes?-?(tu)? techniquement/
    ];
    return pats.some(function (r) { return r.test(s); });
  }

  offTopicReply() {
    return {
      source: 'Hors périmètre — administrateur de l\'espace',
      text: "Cette demande porte sur le fonctionnement technique de l'outil : elle sort de mon périmètre et je ne communique aucune information à ce sujet, y compris pour un contrôle de sécurité.\n\nAdressez-vous à l'administrateur de votre espace uniion (Réglages, puis Administration de l'organisation) ou au référent informatique de votre fédération : ils détiennent la documentation technique, la fiche de traitement RGPD et les habilitations.\n\nJe reste à votre disposition sur la convention collective, le Code du travail, vos accords d'entreprise, vos dossiers de permanence et vos mandats."
    };
  }

  plain(s) { return String(s || '').replace(/\*\*/g, '').replace(/^#+\s*/gm, '').replace(/^[-*]\s+/gm, '· ').trim(); }

  aiFail(where, e, retry) {
    this._aiRetry = retry || null;
    const msg = (e && e.message) ? e.message : String(e);
    this.setState({ aiErr: where + ' — ' + msg, aiBusy: false });
    return msg;
  }

  maskOrRefuse(text, lvl) {
    const m = this.maskText(text || '', lvl || this.detectLevel(text || ''));
    if (m.residual.length) { this.flash('Envoi refusé — un identifiant échappe au filtre'); return null; }
    return m;
  }

  runAssistant(q, masked, trace) {
    if (this.offTopic(q)) {
      const off = this.offTopicReply();
      clearTimeout(this.t1);
      this.t1 = setTimeout(() => {
        this.setState((s) => ({
          typing: false,
          messages: s.messages.concat([{ isBot: true, source: off.source, text: off.text, reidLine: '', logLine: 'Requête non transmise au modèle — sujet hors périmètre, orientation vers l\'administrateur' }])
        }));
      }, 350);
      return;
    }
    const cv = this.curConv();
    const hist = this.convHistoryText();
    const intake = (cv && cv.intake) || (!cv && this.state.asstIntake);
    const user = (intake ? "MODE OUVERTURE DE DOSSIER : aide l'élu à qualifier la situation ; pose au plus deux questions précises sur les éléments manquants (faits, dates, personnes concernées par fonction, demande du salarié) et rappelle les délais applicables.\n\n" : '') + (cv && cv.ctx ? 'Contexte importé depuis ' + cv.origin + ' (anonymisé) :\n' + cv.ctx + '\n\n' : '')
      + (hist ? 'Échanges précédents de la conversation :\n' + hist + '\n\n' : '')
      + "Question de l'élu (anonymisée) : " + masked + "\n\nCorpus documentaire de la section :\n" + this.aiCorpus();
    this.llmJson(AI_SYS.juris, user, 700).then((r) => {
      this.setState((s) => ({
        typing: false,
        messages: s.messages.concat([{
          isBot: true, source: r.source || 'Corpus de la section', text: this.plain(r.text),
          memoSuggest: this.memNovel(r.memo),
          reidLine: (trace && trace.reidLine) || '', logLine: (trace && trace.logLine) || ''
        }])
      }));
    }).catch((e) => {
      const msg = this.aiFail('Assistant juridique', e, () => { this.setState({ typing: true, aiErr: '' }); this.runAssistant(q, masked, trace); });
      this.setState((s) => ({
        typing: false,
        messages: s.messages.concat([{ isBot: true, source: 'Appel au modèle en échec', text: "Aucune réponse n'a été produite (" + msg + "). La question reste dans votre historique local. Réessayez, ou consultez la base documentaire hors ligne." }])
      }));
    });
  }

  genDocLlm() {
    const st = this.state;
    if (!String(st.prompt || '').trim()) return this.flash('Décrivez le document à rédiger avant de générer.');
    const lvl = this.detectLevel(st.prompt + ' ' + st.docType);
    const m = this.maskOrRefuse(st.prompt, lvl);
    if (!m) return;
    this.setState((s) => ({ tract: 'loading', aiErr: '', aiCalls: s.aiCalls + 1 }));
    const user = 'Type de document : ' + st.docType + '\nTon : ' + st.tone + "\nBrief de l'élu (anonymisé) : " + m.masked + '\n\nCorpus documentaire :\n' + this.aiCorpus();
    this.llmJson(AI_SYS.doc, user, 1300).then((r) => {
      this.setState({ tract: 'ready', docGen: r });
      this.flash('Document rédigé par le modèle — à relire avant diffusion');
    }).catch((e) => {
      this.setState({ tract: 'empty' });
      this.aiFail('Rédaction du document', e, () => this.genDocLlm());
    });
  }

  genPageLlm() {
    const g = this.state.webGen;
    if (!String(g.prompt || '').trim()) return this.flash('Ajoutez au moins deux points clés avant de générer.');
    const m = this.maskOrRefuse(g.prompt, this.detectLevel(g.prompt));
    if (!m) return;
    this.setWebGen({ phase: 'run' });
    this.setState((s) => ({ aiErr: '', aiCalls: s.aiCalls + 1 }));
    const rub = this.rubOf(g.rubrique);
    const xsecs = this.extItems('pageSections');
    const user = 'Rubrique : ' + rub.label + ' (' + rub.path + ")\nTon : " + g.tone + (g.clair ? ' · vulgarisation demandée' : '') + "\nPoints clés de l'élu (anonymisés) : " + m.masked + '\n\nCorpus documentaire :\n' + this.aiCorpus()
      + (xsecs.length ? '\n\nSections enrichies disponibles (facultatives, 2 au maximum, uniquement avec des informations présentes ci-dessus) — format {"t": "<type>", "text": "<lignes>"} : ' + xsecs.map((s) => s.type + ' = ' + s.label + ' (' + (s.hint || '') + ')').join(' ; ') : '');
    this.llmJson(AI_SYS.page, user, 1500).then((r) => {
      const id = 'p' + Date.now();
      const ok = ['p', 'h2', 'h3', 'list', 'callout', 'cta', 'file', 'img'].concat(xsecs.map((s) => s.type));
      const blocks = (Array.isArray(r.blocks) ? r.blocks : []).filter((b) => b && ok.indexOf(b.t) >= 0).map((b, i) => {
        const out = { id: id + '-' + i, t: b.t };
        if (b.t === 'list') out.items = (Array.isArray(b.items) ? b.items : String(b.text || '').split('\n')).filter(Boolean);
        else out.text = String(b.text || '');
        if (b.t === 'cta') out.href = b.href || rub.path;
        const xs = xsecs.find((s) => s.type === b.t);
        if (xs) { out.ext = xs.extId; out.text = String(b.text || (Array.isArray(b.items) ? b.items.join('\n') : '')); delete out.items; }
        return out;
      });
      if (!blocks.length) throw new Error('aucun bloc exploitable dans la réponse');
      const pg = {
        id: id, title: String(r.title || 'Page sans titre'), rubrique: g.rubrique,
        slug: String(r.slug || 'nouvelle-page').replace(/[^a-z0-9-]/gi, '-').toLowerCase(),
        status: 'Brouillon', updated: "à l'instant", author: 'Sophie Marchand', review: null, pub: null,
        chapo: String(r.chapo || '').slice(0, 260), blocks: blocks
      };
      if (g.theme && this.extPageTheme(g.theme)) pg.theme = g.theme;
      this.setState((s) => ({ pages: [pg].concat(s.pages), pageId: id, pageHtmlDraft: null, webTab: 'apercu', webGen: Object.assign({}, s.webGen, { phase: 'done' }) }));
      this.go('webedit');
      this.flash('Page rédigée par le modèle — HTML propre prêt pour relecture');
    }).catch((e) => {
      this.setWebGen({ phase: 'empty' });
      this.aiFail('Génération de page intranet', e, () => this.genPageLlm());
    });
  }

  pvFromReunion(re) {
    const originRoute = this.state.route, originId = this.state.reunionId;
    if (this._pvPending && this._pvPending.has(re.id)) return this.flash('Génération déjà en cours pour cette réunion');
    if (!this._pvPending) this._pvPending = new Set();
    const marks = re.markers.map((m) => {
      const def = MARKER_DEFS.find(function (x) { return x.id === m.kind; }) || { label: m.kind };
      return this.clock(m.t) + ' · ' + def.label + ' : ' + m.note;
    }).join('\n');
    const lvl = this.detectLevel(re.title + ' ' + marks);
    const m = this.maskOrRefuse(marks, lvl);
    if (!m) return;
    this.setState((s) => ({ aiErr: '', aiCalls: s.aiCalls + 1 }));
    this.flash('Rédaction du projet de PV par le modèle…');
    this._pvPending.add(re.id);
    const user = 'Type de séance : ' + re.type + '\nIntitulé : ' + re.title + '\nDate : ' + re.date + '\nDurée : ' + re.dur
      + "\nOrdre du jour :\n" + (re.ordre.length ? re.ordre.join('\n') : 'non renseigné')
      + '\n\nMarqueurs relevés en séance (anonymisés) :\n' + (m.masked || 'aucun marqueur')
      + '\n\nCorpus documentaire :\n' + this.aiCorpus();
    this.llmJson(AI_SYS.pv, user, 2000).then((r) => {
      const id = 'd-pv-' + Date.now();
      const ok = ['h2', 'h3', 'p', 'ul', 'quote', 'table'];
      const blocks = [
        { id: id + '-t', type: 'tag', text: re.type + ' — ' + re.date.split(' · ')[0] },
        { id: id + '-h', type: 'h1', text: 'Procès-verbal — ' + re.title }
      ].concat((Array.isArray(r.blocks) ? r.blocks : []).filter((b) => b && ok.indexOf(b.type) >= 0).map((b, i) => ({ id: id + '-b' + i, type: b.type, text: String(b.text || '') })));
      if (blocks.length < 4) throw new Error('projet de PV trop incomplet pour être exploité');
      const doc = { id: id, title: 'PV — ' + re.title, model: 'cr', format: 'a4', status: 'Brouillon', updated: "à l'instant", blocks: blocks };
      this.setState((s) => ({
        docs: [doc].concat(s.docs), docSrcDraft: null, docTab: 'contenu',
        reunions: s.reunions.map((x) => (x.id === re.id ? Object.assign({}, x, { pvDoc: id, pv: 'À rédiger' }) : x))
      }));
      this._pvPending.delete(re.id);
      if (this.state.route === originRoute && this.state.reunionId === originId) this.go('docedit', { docId: id });
      this.flash('Projet de PV rédigé depuis ' + re.markers.length + ' marqueurs — à relire et compléter');
    }).catch((e) => {
      this._pvPending.delete(re.id);
      this.aiFail('Rédaction du procès-verbal', e, () => this.pvFromReunion(re));
    });
  }


  ask(q) {
    if (!q) return;
    const lvl = this.detectLevel(q);
    const m = this.maskOrRefuse(q, lvl);
    if (!m) return;
    const lvlLabel = (this.anonLevelDefs().find(function (l) { return l.key === lvl; }) || {}).label;
    this.setState((s) => ({
      route: 'assistant', history: s.route === 'assistant' ? s.history : s.history.concat([s.route]),
      input: '', typing: true, aiErr: '', aiCalls: s.aiCalls + 1,
      messages: s.messages.concat([{
        isUser: true, text: q,
        payload: m.tags.length ? m.masked : '',
        levelLabel: m.tags.length ? lvlLabel : '',
        tagCount: m.tags.length ? m.tags.length + ' entité' + (m.tags.length > 1 ? 's' : '') + ' masquée' + (m.tags.length > 1 ? 's' : '') : ''
      }])
    }));
    if (typeof window !== 'undefined') window.scrollTo(0, 0);
    this.runAssistant(q, m.masked, null);
  }

  dchatSeed(d) {
    if (!d) return [];
    return [{
      isBot: true, source: 'Contexte du dossier chargé',
      text: 'J\'ai lu « ' + d.title + ' » : catégorie ' + (d.tag || '—') + ', échéance ' + (d.due || 'non fixée') + ', ' + (d.timeline || []).length + ' entrées d\'historique. Posez votre question, je réponds sur ce dossier en citant les textes applicables.'
    }];
  }

  dchatFor(d) {
    if (!d) return [];
    const c = this.state.dchats[d.id];
    return this.dchatSeed(d).concat((c || []).filter((m) => m.source !== 'Contexte du dossier chargé'));
  }

  dchatAsk(q, dossier) {
    const d = dossier || this.currentDossier();
    const txt = (q || '').trim();
    if (!txt || !d) return;
    const lvl = this.levelForDossier(d);
    const qm = this.maskOrRefuse(txt, lvl);
    if (!qm) return;
    const ctx = this.maskText(this.dossierContext(d), lvl);
    if (ctx.residual.length) { this.flash('Contexte du dossier non transmissible — un identifiant échappe au filtre'); return; }
    const ctxCount = ctx.tags.length;
    const base = this.dchatFor(d).concat([{ isUser: true, text: txt }]);
    this.setState((s) => ({
      dchatDraft: '', dchatTyping: true, aiErr: '', aiCalls: s.aiCalls + 1,
      dchats: Object.assign({}, s.dchats, { [d.id]: base })
    }));
    const ctxLine = 'Contexte transmis (masqué, niveau ' + lvl.toUpperCase() + (ctxCount ? ' · ' + ctxCount + ' entité' + (ctxCount > 1 ? 's' : '') + ' masquée' + (ctxCount > 1 ? 's' : '') : '') + ') : ' + ctx.masked;
    const user = 'Dossier suivi par les élus — nature : ' + (d.tag || 'non qualifiée') + ' · intitulé : ' + (d.title || '')
      + '\n\nContexte du dossier (anonymisé) :\n' + ctx.masked
      + "\n\nQuestion de l'élu (anonymisée) : " + qm.masked
      + '\n\nCorpus documentaire de la section :\n' + this.aiCorpus();
    const push = (msg) => this.setState((s) => ({
      dchatTyping: false,
      dchats: Object.assign({}, s.dchats, { [d.id]: (s.dchats[d.id] || base).concat([msg]) })
    }));
    if (this.offTopic(txt)) {
      const off = this.offTopicReply();
      clearTimeout(this.t3);
      this.t3 = setTimeout(() => push({ isBot: true, source: off.source, text: off.text }), 350);
      return;
    }
    this.llmJson(AI_SYS.juris, user, 700).then((r) => {
      push({ isBot: true, source: r.source || 'Corpus de la section', text: this.plain(r.text) + '\n\n' + ctxLine });
    }).catch((e) => {
      const msg = this.aiFail('Chat du dossier', e, () => this.dchatAsk(txt));
      push({ isBot: true, source: 'Appel au modèle en échec', text: "Aucune réponse n'a été produite (" + msg + "). " + ctxLine });
    });
  }

  

  

  buildDoc() {
    const t = this.state.docType;
    const tone = this.state.tone;
    const g = this.state.docGen;
    if (g && this.state.tract === 'ready') {
      const items = Array.isArray(g.items) ? g.items : [];
      return {
        ref: String(g.ref || (t + ' · 31/08/2026')).toUpperCase(),
        title: String(g.title || t),
        p1: this.plain(g.p1), p2: this.plain(g.p2),
        listTitle: String(g.listTitle || 'Nos demandes'),
        items: items.map((x) => ({ text: this.plain(typeof x === 'string' ? x : (x && x.text)) })).filter((x) => x.text),
        footer: String(g.footer || '')
      };
    }
    if (t === 'Courrier') {
      return {
        ref: 'COURRIER · 25/08/2026',
        title: tone === 'Combatif' ? 'Mise en demeure — obligation de sécurité' : 'Saisine de la direction',
        p1: "Madame la Directrice, nous vous saisissons officiellement d'une situation portée à notre connaissance par une salariée du service logistique, faisant état de faits répétés susceptibles de caractériser un harcèlement moral.",
        p2: "Nous vous rappelons votre obligation de prévention (art. L1153-5 du Code du travail) et demandons l'ouverture d'une enquête paritaire dans les meilleurs délais.",
        listTitle: 'Nous demandons',
        items: [{ text: 'Une enquête paritaire sous 8 jours' }, { text: 'La protection immédiate de la salariée' }, { text: 'Un point à l\'ordre du jour du prochain CSE' }],
        footer: this.signatureLines().join(' — ')
      };
    }
    if (t === 'Ordre du jour') {
      return {
        ref: 'ORDRE DU JOUR · CSE 03/09/2026',
        title: 'Réunion ordinaire du CSE — 3 septembre',
        p1: "Réunion ordinaire convoquée conformément à l'article L2315-27, en présence des membres titulaires et des représentants syndicaux.",
        p2: 'Les documents afférents sont déposés dans la base documentaire partagée 3 jours avant la séance.',
        listTitle: 'Points inscrits',
        items: [{ text: 'Approbation du PV de juillet' }, { text: 'NAO 2027 — restitution du sondage salariés' }, { text: 'Accident Atelier B — retour d\'enquête CSSCT' }, { text: 'Budget ASC — arbre de Noël' }],
        footer: 'Prochaine séance : mardi 3 septembre, 9 h, salle du conseil.'
      };
    }
    return {
      ref: 'TRACT NAO · 25/08/2026',
      title: tone === 'Pédagogique' ? 'NAO 2027 : où en sommes-nous ?' : (tone === 'Institutionnel' ? 'Négociation salariale 2027 — état des discussions' : '0,8 % ? Nos salaires méritent mieux.'),
      p1: "Vous avez été 312 à répondre à notre consultation. Le message est sans ambiguïté : 68 % d'entre vous placent la revalorisation générale en première priorité, loin devant toute prime exceptionnelle.",
      p2: tone === 'Institutionnel' ? "La proposition de la direction s'établit à 0,8 %. Nous avons demandé la communication des éléments économiques permettant une négociation loyale." : "Face à l'inflation, la proposition patronale de 0,8 % représente une perte de pouvoir d'achat. Nous ne la signerons pas en l'état.",
      listTitle: 'Nos exigences',
      items: [{ text: 'Augmentation générale de 5 %' }, { text: 'Rattrapage des bas coefficients' }, { text: 'Clause de revoyure en janvier' }],
      footer: 'AG du personnel — mardi 12 h 30, réfectoire.'
    };
  }

  /* ---- Intranet ---- */
  frDate(v) {
    const s = String(v || '');
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!m) return s;
    const mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    const d = parseInt(m[3], 10);
    return (d === 1 ? '1er' : String(d)) + ' ' + mois[parseInt(m[2], 10) - 1] + ' ' + m[1];
  }
  siteDefs() {
    return [
      {
        id: 'intranet', label: 'Intranet', short: 'Interne',
        kicker: "Site interne de l'organisation",
        host: 'intranet.section-valenciennes.fr',
        audience: 'Salariés authentifiés',
        desc: "Accès réservé aux salariés de l'entreprise, derrière authentification. Non indexé par les moteurs de recherche.",
        note: "Vous pouvez y publier des comptes rendus de séance, des positions de négociation et des documents de travail : l'audience est interne et identifiée."
      },
      {
        id: 'public', label: 'Site internet', short: 'Public',
        kicker: 'Site public de la section',
        host: 'section-valenciennes.fr',
        audience: 'Ouvert à tous · indexé',
        desc: 'Vitrine publique de la section : accessible sans compte, indexée, citable par la presse et par la direction.',
        note: "Tout ce qui est publié ici est lisible par la direction, la presse et les moteurs de recherche : aucune donnée nominative de salarié, aucun élément de stratégie de négociation, aucune pièce de dossier."
      }
    ];
  }
  siteOf(id) { const s = this.siteDefs().find(function (x) { return x.id === id; }); return s || this.siteDefs()[0]; }
  curSite() { return this.siteOf(this.state.webSite || 'intranet'); }
  rubDefs(siteId) {
    const site = siteId || this.state.webSite || 'intranet';
    if (site === 'public') {
      return [
        { id: 'pub-accueil', site: 'public', label: 'Accueil', path: '/', n: 1, desc: 'Vitrine : qui nous sommes, nos combats du moment, comment nous rejoindre.' },
        { id: 'pub-actus', site: 'public', label: 'Actualités publiques', path: '/actualites', n: 8, desc: 'Communiqués destinés à la presse, aux salariés et aux sympathisants.' },
        { id: 'pub-campagnes', site: 'public', label: 'Nos campagnes', path: '/campagnes', n: 4, desc: 'Revendications en cours, pétitions, appels à mobilisation.' },
        { id: 'pub-adhesion', site: 'public', label: 'Adhérer', path: '/adherer', n: 2, desc: 'Pourquoi se syndiquer, montant de la cotisation, bulletin en ligne.' },
        { id: 'pub-equipe', site: 'public', label: 'La section', path: '/la-section', n: 3, desc: 'Bureau, mandats, implantation, histoire de la section.' },
        { id: 'pub-contact', site: 'public', label: 'Contact & presse', path: '/contact', n: 2, desc: 'Coordonnées du local, contact presse, formulaire public.' }
      ];
    }
    return [
      { id: 'actus', site: 'intranet', label: 'Actualités', path: '/intranet/actualites', n: 12, desc: 'Communiqués, comptes rendus de séance, mobilisations.' },
      { id: 'droits', site: 'intranet', label: 'Vos droits', path: '/intranet/vos-droits', n: 18, desc: 'Fiches pratiques : congés, télétravail, temps de travail.' },
      { id: 'cse', site: 'intranet', label: 'La section', path: '/intranet/la-section', n: 9, desc: 'Élus et mandats, permanences, procès-verbaux, comptes.' },
      { id: 'negos', site: 'intranet', label: 'Négociations', path: '/intranet/negociations', n: 6, desc: 'NAO, accords en cours, positions déposées.' },
      { id: 'asc', site: 'intranet', label: 'Loisirs & ASC', path: '/intranet/asc', n: 14, desc: 'Chèques vacances, billetterie, arbre de Noël.' },
      { id: 'contacts', site: 'intranet', label: 'Nous contacter', path: '/intranet/contacts', n: 3, desc: 'Formulaire de saisine, coordonnées, alerte confidentielle.' }
    ];
  }
  allRubs() { return this.rubDefs('intranet').concat(this.rubDefs('public')); }
  rubOf(id) { const f = this.allRubs().find(function (x) { return x.id === id; }); return f || this.rubDefs('intranet')[0]; }
  pageUrl(pg) {
    const host = this.siteOf(this.pageSite(pg)).host;
    const path = String(this.rubOf(pg.rubrique).path || '/').replace(/\/+$/, '');
    return host + path + '/' + (pg.slug || '');
  }
  pageSite(pg) { return (pg && pg.site) || (String(pg && pg.rubrique).indexOf('pub-') === 0 ? 'public' : 'intranet'); }
  pageModels(siteId) {
    const site = siteId || this.state.webSite || 'intranet';
    if (site === 'public') {
      return [
        { id: 'pub-home', label: 'Page d\'accueil', desc: 'Bandeau de mobilisation, trois combats en cours, appel à adhérer.', meta: 'Vitrine · pleine largeur', rub: 'pub-accueil',
          pv: [{ k: 'hero', h: 26 }, { k: 'chip', w: 34 }, { k: 'title', w: 76 }, { k: 'cards' }, { k: 'cta', w: 44 }] },
        { id: 'pub-communique', label: 'Communiqué de presse', desc: 'Date, lieu, position en trois paragraphes, contact presse en pied.', meta: 'Citable · format presse', rub: 'pub-actus',
          pv: [{ k: 'chip', w: 30 }, { k: 'title', w: 84 }, { k: 'line', w: 96 }, { k: 'line', w: 90 }, { k: 'line', w: 62 }, { k: 'quote' }] },
        { id: 'pub-campagne', label: 'Page de campagne', desc: 'Une revendication, les chiffres qui la fondent, une pétition à signer.', meta: 'Avec compteur de signatures', rub: 'pub-campagnes',
          pv: [{ k: 'hero', h: 20 }, { k: 'title', w: 70 }, { k: 'stats' }, { k: 'line', w: 92 }, { k: 'cta', w: 52 }] },
        { id: 'pub-adhesion', label: 'Adhérer', desc: 'Pourquoi se syndiquer, ce que couvre la cotisation, bulletin en ligne.', meta: 'Avec formulaire', rub: 'pub-adhesion',
          pv: [{ k: 'title', w: 58 }, { k: 'split' }, { k: 'line', w: 88 }, { k: 'form' }, { k: 'cta', w: 40 }] },
        { id: 'pub-equipe', label: 'La section', desc: 'Bureau et mandats, implantation sur les sites, repères historiques.', meta: 'Trombinoscope', rub: 'pub-equipe',
          pv: [{ k: 'title', w: 46 }, { k: 'line', w: 92 }, { k: 'faces' }, { k: 'line', w: 74 }] },
        { id: 'pub-contact', label: 'Contact & presse', desc: 'Local syndical, horaires de permanence, contact presse, plan d\'accès.', meta: 'Avec carte', rub: 'pub-contact',
          pv: [{ k: 'title', w: 44 }, { k: 'map' }, { k: 'line', w: 80 }, { k: 'line', w: 58 }] }
      ];
    }
    return [
      { id: 'actu', label: 'Actualité', desc: 'Un fait récent, un chapô, deux ou trois sections courtes.', meta: 'Rubrique Actualités', rub: 'actus',
        pv: [{ k: 'chip', w: 28 }, { k: 'title', w: 82 }, { k: 'line', w: 96 }, { k: 'line', w: 88 }, { k: 'img' }] },
      { id: 'communique', label: 'Communiqué interne', desc: 'Position de la section, ton institutionnel, signature du bureau.', meta: 'Une page', rub: 'actus',
        pv: [{ k: 'chip', w: 34 }, { k: 'title', w: 74 }, { k: 'line', w: 94 }, { k: 'line', w: 90 }, { k: 'line', w: 52 }, { k: 'sign' }] },
      { id: 'fiche', label: 'Fiche pratique', desc: 'Ce que dit le texte, ce que ça change pour vous, qui contacter.', meta: 'Rubrique Vos droits', rub: 'droits',
        pv: [{ k: 'title', w: 62 }, { k: 'callout' }, { k: 'bullets' }, { k: 'line', w: 84 }, { k: 'file' }] },
      { id: 'faq', label: 'Questions-réponses', desc: 'Questions fréquentes sur un dispositif ou un accord, en blocs repliables.', meta: 'Blocs repliables', rub: 'droits',
        pv: [{ k: 'title', w: 50 }, { k: 'accord' }, { k: 'accord' }, { k: 'accord' }] },
      { id: 'event', label: 'Événement', desc: 'Réunion d\'information, permanence, assemblée : date, lieu, inscription.', meta: 'Avec inscription', rub: 'cse',
        pv: [{ k: 'hero', h: 18 }, { k: 'title', w: 66 }, { k: 'meta2' }, { k: 'line', w: 86 }, { k: 'cta', w: 46 }] },
      { id: 'cr', label: 'Compte rendu de séance', desc: 'Repris depuis un PV approuvé, allégé pour les salariés.', meta: 'Depuis Réunions', rub: 'negos',
        pv: [{ k: 'chip', w: 40 }, { k: 'title', w: 78 }, { k: 'bullets' }, { k: 'callout' }, { k: 'line', w: 66 }] }
    ];
  }
  brandFontStack(id) {
    return {
      philosopher: 'Philosopher, Georgia, serif',
      georgia: 'Georgia, "Times New Roman", serif',
      system: 'system-ui, Segoe UI, Helvetica, sans-serif',
      plex: '"IBM Plex Sans", system-ui, sans-serif'
    }[id] || 'Philosopher, Georgia, serif';
  }
  wcStore() {
    const raw = this.state.webCharte || {};
    if (raw.intranet || raw.public) return raw;
    const legacy = Object.assign({ inherit: false, nav: 'inline', radius: 'doux' }, raw);
    return { intranet: legacy, public: Object.assign({}, legacy, { inherit: false, width: 820, nav: 'bar' }) };
  }
  webCharteDef(siteId) {
    const id = siteId || this.state.webSite || 'intranet';
    const own = Object.assign({}, (this.wcStore()[id] || {}));
    const b = Object.assign({}, DEFAULT_BRAND, this.state.brand || {});
    if (own.inherit) {
      const base = b.accent2 || b.accent || '#DC2626';
      own.accent = base;
      const h = /^#[0-9a-fA-F]{6}$/.test(base) ? this.hexToHsl(base) : { h: 0, s: 70 };
      own.head = this.hsl(h.h, Math.min(h.s, 42), id === 'public' ? 20 : 16);
      own.titleFont = this.brandFontStack(b.fonts);
      own.logo = true;
    }
    return Object.assign({
      inherit: false, accent: '#DC2626', head: '#1F2937',
      titleFont: 'Philosopher, Georgia, serif', width: 760, logo: true, logoSrc: '', logoScale: 100,
      gabarit: 'actu', nav: id === 'public' ? 'bar' : 'inline', radius: 'doux'
    }, own);
  }
  brandScaleOf(b, k) {
    const m = (b && b.logoScales) || {};
    const v = m[k];
    if (v !== undefined && v !== null) return Number(v) || 100;
    return k === 'logoLight' ? (Number(b && b.logoScale) || 100) : 100;
  }
  siteLogo(siteId) {
    const id = siteId || this.state.webSite || 'intranet';
    const wc = this.webCharteDef(id);
    const b = Object.assign({}, DEFAULT_BRAND, this.state.brand || {});
    const own = wc.logoSrc || '';
    const bKey = id === 'public' ? 'logoPublic' : 'logoIntranet';
    const brandSpecific = b[bKey] || '';
    const src = own || brandSpecific || b.logoLight || '';
    return {
      src: src,
      from: own ? 'propre à ce site' : (brandSpecific ? 'identité de l\'organisation — emplacement dédié' : 'identité de l\'organisation — logo fond clair'),
      own: !!own,
      scale: Math.min(3, Math.max(0.6, (own ? (Number(wc.logoScale) || 100) : (wc.logoScale !== undefined && wc.logoScale !== 100 ? Number(wc.logoScale) : (brandSpecific ? this.brandScaleOf(b, bKey) : this.brandScaleOf(b, 'logoLight')))) / 100))
    };
  }
  setWc(patch) {
    const id = this.state.wcSite || 'intranet';
    const store = this.wcStore();
    const detach = ['accent', 'head', 'titleFont'].some(function (k) { return patch[k] !== undefined; });
    if (detach && (store[id] || {}).inherit) {
      const cur = this.webCharteDef(id);
      patch = Object.assign({ inherit: false, accent: cur.accent, head: cur.head, titleFont: cur.titleFont }, patch);
      this.flash('Charte détachée de l\'identité de l\'organisation pour ce site');
    }
    this.setState({ webCharte: Object.assign({}, store, { [id]: Object.assign({}, store[id] || {}, patch) }), pageHtmlDraft: null });
  }
  curPage() {
    const p = this.state.pages.find((x) => x.id === this.state.pageId);
    return p || this.state.pages[0];
  }
  patchPage(patch) {
    const id = this.curPage().id;
    this.setState((s) => ({ pages: s.pages.map((x) => (x.id === id ? Object.assign({}, x, patch, { updated: "à l'instant" }) : x)) }));
  }
  defaultBlocks(pg) {
    return [
      { id: pg.id + '-a', t: 'p', text: 'Ce paragraphe d\'introduction reprend le contexte, en deux ou trois phrases, sans jargon.' },
      { id: pg.id + '-b', t: 'h2', text: 'Ce que cela change pour vous' },
      { id: pg.id + '-c', t: 'list', items: ['Premier point concret', 'Deuxième point concret', 'Démarche à suivre'] },
      { id: pg.id + '-d', t: 'callout', text: 'Une question ? Les élus tiennent permanence chaque mardi de 12 h à 14 h, local B12.' }
    ];
  }
  pageBlocks(pg) { return pg.blocks || this.defaultBlocks(pg); }
  esc(s) { return String(s === null || s === undefined ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;'); }
  // R42/R46 : seuls les liens web, internes, ancres et mailto sont conservés ; le reste devient une ancre vide.
  safeHref(u) { const s = String(u === null || u === undefined ? '' : u).trim(); return /^(https?:\/\/|\/(?!\/)|#|mailto:)/i.test(s) ? s : '#'; }
  // Images : données image encodées ou chemin du même site uniquement.
  safeSrc(u) { const s = String(u === null || u === undefined ? '' : u).trim(); return /^(data:image\/(png|jpeg|gif|webp);base64,|\/(?!\/))/i.test(s) ? s : ''; }
  pageCss(siteId) {
    const c = this.webCharteDef(siteId);
    const rad = c.radius === 'net' ? 0 : (c.radius === 'rond' ? 22 : 14);
    const ah = /^#[0-9a-fA-F]{6}$/.test(c.accent) ? this.hexToHsl(c.accent) : { h: 0, s: 84 };
    const tint = this.hsl(ah.h, 92, 96);
    const tint2 = this.hsl(ah.h, 88, 90);
    const dark = /^#[0-9a-fA-F]{6}$/.test(c.head) || String(c.head).indexOf('hsl') === 0 ? c.head : '#1F2937';
    return '.up-site{--up-accent:' + c.accent + ';--up-head:' + dark + ';--up-tint:' + tint + ';--up-tint2:' + tint2 + ';--up-w:' + c.width + 'px}'
      + '.up-site,.up-site *,.up-site *::before,.up-site *::after{box-sizing:border-box}'
      + '.up-site{font-family:system-ui,Segoe UI,Helvetica,sans-serif;color:#1F2937;line-height:1.65;background:#F8F8F7;margin:0}'
      + '.up-site a{color:var(--up-accent)}'
      + '.up-site{--up-r:' + rad + 'px}'
      + '.up-site .up-wrap{max-width:1120px;margin:0 auto;padding:0 24px}'
      + '.up-site .up-skip{position:absolute;left:-9999px}.up-site .up-skip:focus{position:static;display:block;padding:8px;background:#fff}'
      /* barre de service */
      + '.up-util{background:var(--up-head);color:#fff;font-size:12.5px}'
      + '.up-util .up-wrap{display:flex;flex-wrap:wrap;gap:16px;align-items:center;min-height:38px}'
      + '.up-util a{color:rgba(255,255,255,.9);text-decoration:none}'
      + '.up-util .up-right{margin-left:auto;display:flex;gap:14px;align-items:center}'
      /* en-tête */
      + '.up-head{background:#fff;border-bottom:1px solid #E5E7EB}'
      + '.up-head .up-wrap{display:flex;flex-wrap:wrap;gap:18px;align-items:center;padding-top:16px;padding-bottom:16px}'
      + '.up-brand{display:flex;gap:12px;align-items:center;text-decoration:none;color:inherit}'
      + '.up-logo{width:44px;height:44px;flex:0 0 auto;border-radius:calc(var(--up-r) * .6);background:var(--up-accent);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:15px;letter-spacing:.02em}'
      + '.up-brand strong{display:block;font-size:15.5px;line-height:1.25}'
      + '.up-brand span{display:block;font-size:12.5px;color:#6B7280}'
      + '.up-search{margin-left:auto;display:flex;gap:8px;align-items:center}'
      + '.up-search input{border:1px solid #D8D8D6;border-radius:99px;padding:9px 14px;font-size:13.5px;min-width:190px}'
      + '.up-search button{border:0;border-radius:99px;padding:10px 16px;background:var(--up-head);color:#fff;font-size:13px;font-weight:700;cursor:pointer}'
      /* navigation */
      + '.up-nav{background:#fff;border-bottom:1px solid #E5E7EB;position:sticky;top:0;z-index:5}'
      + '.up-nav ul{display:flex;flex-wrap:wrap;gap:2px;list-style:none;margin:0;padding:0}'
      + '.up-nav a{display:block;padding:13px 14px;font-size:13.5px;font-weight:600;color:#374151;text-decoration:none;border-bottom:3px solid transparent}'
      + '.up-nav a:hover{color:var(--up-accent);background:var(--up-tint)}'
      + '.up-nav a[aria-current=page]{color:var(--up-accent);border-bottom-color:var(--up-accent)}'
      /* fil d ariane */
      + '.up-crumb{font-size:12.5px;color:#6B7280;padding:14px 0 0}'
      + '.up-crumb ol{list-style:none;display:flex;flex-wrap:wrap;gap:8px;margin:0;padding:0}'
      + '.up-crumb li::after{content:"›";margin-left:8px;color:#9CA3AF}.up-crumb li:last-child::after{content:""}'
      + '.up-crumb a{color:#6B7280;text-decoration:none}'
      /* bandeau */
      + '.up-hero{background:linear-gradient(180deg,var(--up-tint),#fff);border-bottom:1px solid #EFEFEE}'
      + '.up-hero .up-wrap{padding-top:26px;padding-bottom:30px}'
      + '.up-kicker{display:inline-block;font-size:11px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;color:#fff;background:var(--up-accent);border-radius:99px;padding:5px 12px;margin:0}'
      + '.up-hero h1{font-family:' + c.titleFont + ';font-size:36px;line-height:1.15;margin:14px 0 12px;color:#111827;max-width:22em}'
      + '.up-chapo{font-size:17.5px;color:#4B5563;margin:0;max-width:44em}'
      + '.up-byline{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;margin-top:18px;font-size:12.5px;color:#6B7280}'
      + '.up-byline .up-av{width:30px;height:30px;border-radius:99px;background:var(--up-tint2);color:var(--up-head);display:flex;align-items:center;justify-content:center;font-size:11.5px;font-weight:800}'
      /* corps en deux colonnes */
      + '.up-main .up-wrap{display:flex;flex-wrap:wrap;gap:40px;align-items:flex-start;padding-top:34px;padding-bottom:40px}'
      + '.up-article{flex:1 1 var(--up-w);min-width:0;max-width:var(--up-w);background:#fff;border:1px solid #EDEDEC;border-radius:var(--up-r);padding:32px 34px}'
      + '.up-article h2{font-family:' + c.titleFont + ';font-size:22px;margin:30px 0 10px;color:#111827;scroll-margin-top:70px}'
      + '.up-article h2:first-child{margin-top:0}'
      + '.up-article p{margin:0 0 14px;font-size:16px}'
      + '.up-article ul{margin:0 0 18px;padding-left:0;list-style:none}'
      + '.up-article ul li{position:relative;padding-left:22px;margin:0 0 8px;font-size:16px}'
      + '.up-article ul li::before{content:"";position:absolute;left:4px;top:9px;width:7px;height:7px;border-radius:99px;background:var(--up-accent)}'
      + '.up-callout{background:var(--up-tint);border-left:4px solid var(--up-accent);border-radius:0 10px 10px 0;padding:16px 18px;margin:0 0 20px;font-size:15px}'
      + '.up-callout strong{display:block;font-size:11.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--up-accent);margin-bottom:5px}'
      + '.up-cta{display:inline-flex;align-items:center;gap:9px;background:var(--up-accent);color:#fff;text-decoration:none;font-weight:700;font-size:15px;padding:14px 24px;border-radius:99px;margin:6px 0 22px;min-height:48px}'
      + '.up-file{display:flex;gap:12px;align-items:center;border:1px solid #E5E7EB;border-radius:12px;padding:14px 16px;margin:0 0 16px;font-size:14.5px;background:#FCFCFB;text-decoration:none;color:inherit}'
      + '.up-file .up-ext{flex:0 0 auto;font-size:10.5px;font-weight:800;letter-spacing:.06em;background:var(--up-head);color:#fff;border-radius:5px;padding:5px 7px}'
      + '.up-file small{display:block;color:#6B7280;font-size:12.5px}'
      + '.up-site figure{margin:0 0 20px}'
      + '.up-site .up-ph{aspect-ratio:16/9;border-radius:12px;display:flex;align-items:center;justify-content:center;font-family:ui-monospace,monospace;font-size:12px;color:#8A8A88;background:repeating-linear-gradient(45deg,#F4F4F5,#F4F4F5 9px,#E9EAEC 9px,#E9EAEC 18px)}'
      + '.up-site figcaption{font-size:12.5px;color:#8A8A88;margin-top:8px}'
      + '.up-share{display:flex;flex-wrap:wrap;gap:10px;align-items:center;border-top:1px solid #EDEDEC;margin-top:30px;padding-top:18px;font-size:13px;color:#6B7280}'
      + '.up-share a{display:inline-block;border:1px solid #E5E7EB;border-radius:99px;padding:8px 14px;text-decoration:none;font-weight:600;font-size:12.5px}'
      /* colonne latérale */
      + '.up-aside{flex:1 1 260px;min-width:240px;display:flex;flex-direction:column;gap:16px;position:sticky;top:60px}'
      + '.up-card{background:#fff;border:1px solid #EDEDEC;border-radius:var(--up-r);padding:18px 20px}'
      + '.up-card h3{font-size:11.5px;font-weight:800;letter-spacing:.1em;text-transform:uppercase;color:#6B7280;margin:0 0 12px}'
      + '.up-card ol,.up-card ul{list-style:none;margin:0;padding:0;font-size:14px}'
      + '.up-card li{margin:0 0 9px}.up-card li:last-child{margin:0}'
      + '.up-card a{text-decoration:none}.up-card a:hover{text-decoration:underline}'
      + '.up-card p{margin:0 0 10px;font-size:14px;color:#4B5563}'
      + '.up-card .up-btn{display:block;text-align:center;background:var(--up-head);color:#fff;text-decoration:none;font-weight:700;font-size:14px;padding:12px;border-radius:99px;min-height:46px}'
      + '.up-tag{display:inline-block;background:var(--up-tint);color:var(--up-accent);font-size:11.5px;font-weight:700;border-radius:99px;padding:4px 10px;margin:0 5px 5px 0}'
      /* pied de page */
      + '.up-foot{background:var(--up-head);color:rgba(255,255,255,.82);font-size:13.5px;margin-top:0}'
      + '.up-foot .up-cols{display:flex;flex-wrap:wrap;gap:34px;padding:38px 0 26px}'
      + '.up-foot .up-col{flex:1 1 200px;min-width:180px}'
      + '.up-foot h4{color:#fff;font-size:11.5px;letter-spacing:.1em;text-transform:uppercase;margin:0 0 12px}'
      + '.up-foot ul{list-style:none;margin:0;padding:0}.up-foot li{margin:0 0 8px}'
      + '.up-foot a{color:rgba(255,255,255,.82);text-decoration:none}.up-foot a:hover{color:#fff;text-decoration:underline}'
      + '.up-legal{border-top:1px solid rgba(255,255,255,.18);padding:16px 0 30px;font-size:12.5px;display:flex;flex-wrap:wrap;gap:8px 18px}'
      + (c.nav === 'bar' ? '.up-site .up-nav{background:var(--up-head);border-bottom:0}.up-site .up-nav a{color:rgba(255,255,255,.86);border-bottom-color:transparent}.up-site .up-nav a:hover{color:#fff;background:rgba(255,255,255,.12)}.up-site .up-nav a[aria-current=page]{color:#fff;border-bottom-color:#fff}' : '')
      + '.up-site .up-logo-img{height:' + Math.round(44 * (Math.min(3, Math.max(0.6, (Number(c.logoScale) || 100) / 100)))) + 'px;width:auto;max-width:280px;object-fit:contain;display:block}'
      + (c.logo ? '' : '.up-site .up-logo,.up-site .up-logo-img{display:none}')
      + '@media(max-width:860px){.up-hero h1{font-size:28px}.up-article{padding:24px 20px}.up-aside{position:static}}';
  }
  buildPageHtml(pg) {
    const e = (s) => this.esc(s);
    const rub = this.rubOf(pg.rubrique);
    const site = this.siteOf(this.pageSite(pg));
    const pub = site.id === 'public';
    const org = this.state.org || {};
    const c = this.webCharteDef(site.id);
    const rubs = this.rubDefs(site.id);
    const blocks = this.pageBlocks(pg);
    const heads = blocks.filter(function (b) { return b.t === 'h2'; });
    const slug = (s) => String(s || '').toLowerCase().replace(/[àâä]/g, 'a').replace(/[éèêë]/g, 'e').replace(/[îï]/g, 'i').replace(/[ôö]/g, 'o').replace(/[ùûü]/g, 'u').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    const initials = String(pg.author || '').split(' ').map(function (x) { return x.charAt(0); }).join('').slice(0, 2).toUpperCase();
    const sigle = org.sigle || 'SECTION';
    const L = [];

    L.push('<!-- ' + (pub ? 'Site public' : 'Intranet') + ' · ' + e(site.host) + ' · rubrique ' + e(rub.label) + ' · gabarit ' + e(c.gabarit) + ' · charte ' + (c.inherit ? 'héritée de l\'identité de l\'organisation' : 'propre au site') + ' -->');
    L.push('<!-- Généré par uniion — HTML sémantique, styles dans la feuille du site -->');
    const xth = this.extPageTheme(pg.theme);
    const xcss = this.extPageCss(pg, blocks, xth);
    if (xcss) L.push('<style data-uniion-ext="' + e(xth ? xth.extId : 'sections') + '">' + xcss + '</style>');
    L.push(xth ? '<div class="up-site" data-theme="' + e(xth.id) + '">' : '<div class="up-site">'); // <body class="up-site"> sur le site réel
    L.push('<a class="up-skip" href="#contenu">Aller au contenu</a>');

    L.push('<div class="up-util"><div class="up-wrap">');
    L.push('  <span>' + (pub ? e(org.nom || '') : 'Espace réservé aux salariés') + '</span>');
    L.push('  <span class="up-right">');
    if (pub) {
      L.push('    <a href="/actualites/flux.rss">Flux RSS</a>');
      L.push('    <a href="/contact">Nous écrire</a>');
      L.push('    <a href="/adherer"><strong>Adhérer</strong></a>');
    } else {
      L.push('    <a href="/intranet/recherche">Recherche</a>');
      L.push('    <a href="/intranet/mon-compte">' + e(pg.author) + '</a>');
      L.push('    <a href="/intranet/deconnexion">Se déconnecter</a>');
    }
    L.push('  </span>');
    L.push('</div></div>');

    L.push('<header class="up-head"><div class="up-wrap">');
    L.push('  <a class="up-brand" href="' + (pub ? '/' : '/intranet') + '">');
    const lg = this.siteLogo(site.id);
    if (c.logo && this.safeSrc(lg.src)) L.push('    <img class="up-logo-img" src="' + e(this.safeSrc(lg.src)) + '" alt="' + e(org.nom || '') + '" width="' + Math.round(44 * lg.scale) + '" />');
    else L.push('    <span class="up-logo" aria-hidden="true">' + e(sigle.replace(/[^A-Za-zÀ-ÿ]/g, '').slice(0, 3).toUpperCase()) + '</span>');
    L.push('    <span><strong>' + e(org.nom || '') + '</strong><span>' + (pub ? 'Site public de la section' : 'Intranet des salariés') + '</span></span>');
    L.push('  </a>');
    L.push('  <form class="up-search" role="search" action="' + (pub ? '/recherche' : '/intranet/recherche') + '">');
    L.push('    <label class="up-skip" for="q">Rechercher</label>');
    L.push('    <input id="q" name="q" type="search" placeholder="Rechercher une page…" />');
    L.push('    <button type="submit">Rechercher</button>');
    L.push('  </form>');
    L.push('</div></header>');

    L.push('<nav class="up-nav" aria-label="Navigation principale"><div class="up-wrap"><ul>');
    rubs.forEach((x) => {
      L.push('  <li><a href="' + e(this.safeHref(x.path)) + '"' + (x.id === rub.id ? ' aria-current="page"' : '') + '>' + e(x.label) + '</a></li>');
    });
    L.push('</ul></div></nav>');

    L.push('<div class="up-wrap up-crumb"><nav aria-label="Fil d\'ariane"><ol>');
    L.push('  <li><a href="' + (pub ? '/' : '/intranet') + '">Accueil</a></li>');
    L.push('  <li><a href="' + e(this.safeHref(rub.path)) + '">' + e(rub.label) + '</a></li>');
    L.push('  <li aria-current="page">' + e(pg.title) + '</li>');
    L.push('</ol></nav></div>');

    L.push('<section class="up-hero"><div class="up-wrap">');
    L.push('  <p class="up-kicker">' + e(rub.label) + '</p>');
    L.push('  <h1>' + e(pg.title) + '</h1>');
    L.push('  <p class="up-chapo">' + e(pg.chapo) + '</p>');
    L.push('  <p class="up-byline">');
    L.push('    <span class="up-av" aria-hidden="true">' + e(initials) + '</span>');
    L.push(pg.serverRecord ? '    <span>Brouillon local — contenu à relire</span>' : '    <span>Par ' + e(pg.author) + (pub ? '' : ', ' + e(this.W().memberOne) + ' de la section') + '</span>');
    L.push(pg.serverRecord ? '    <span>Version ' + e(pg.version) + '</span>' : '    <time datetime="2026-09-05">Mis à jour le 5 septembre 2026</time>');
    if(!pg.serverRecord)L.push('    <span>Lecture 3 min</span>');
    L.push('  </p>');
    L.push('</div></section>');

    L.push('<main class="up-main" id="contenu"><div class="up-wrap">');
    L.push('<article class="up-article" data-rubrique="' + e(pg.rubrique) + '">');
    blocks.forEach((b) => {
      if (b.t === 'h2') L.push('  <h2 id="' + slug(b.text) + '">' + e(b.text) + '</h2>');
      else if (b.t === 'p') L.push('  <p>' + e(b.text) + '</p>');
      else if (b.t === 'callout') L.push('  <aside class="up-callout"><strong>À retenir</strong>' + e(b.text) + '</aside>');
      else if (b.t === 'cta') L.push('  <a class="up-cta" href="' + e(this.safeHref(b.href)) + '">' + e(b.text) + ' <span aria-hidden="true">&#8594;</span></a>');
      else if (b.t === 'file') L.push('  <a class="up-file" href="' + (pub ? '/documents/' : '/intranet/fichiers/') + e(pg.slug) + '.pdf" download><span class="up-ext">PDF</span><span>' + e(b.text) + '<small>Télécharger — s\'ouvre dans une nouvelle fenêtre</small></span></a>');
      else if (b.t === 'img') L.push('  <figure>\n    <div class="up-ph" role="img" aria-label="' + e(b.text) + '">visuel à fournir — 1600 × 900</div>\n    <figcaption>' + e(b.text) + '</figcaption>\n  </figure>');
      else if (b.t === 'list') {
        L.push('  <ul>');
        (b.items || []).forEach((it) => L.push('    <li>' + e(it) + '</li>'));
        L.push('  </ul>');
      }
      else if (b.ext) {
        const xs = this.extPageSection(b.t);
        const xk = { esc: e, lines: (s) => this.extLines(s), cells: (l) => this.extCells(l) };
        const xh = xs ? this.extSafe(xs.extId, 'section ' + b.t, () => String(xs.html(b, xk) || '').replace(/<script[\s\S]*?<\/script>/gi, '').replace(/\son[a-z]+\s*=/gi, ' data-x='), '') : '';
        if (xh) L.push(xh);
        else if (b.text) L.push('  <p>' + e(b.text) + '</p>');
      }
    });
    L.push('  <footer class="up-share">');
    L.push('    <span>Partager cette page</span>');
    L.push('    <a href="#" rel="nofollow">Copier le lien</a>');
    L.push('    <a href="mailto:?subject=' + e(pg.title) + '">Par e-mail</a>');
    if (pub) L.push('    <a href="#" rel="nofollow">Imprimer</a>');
    L.push('  </footer>');
    L.push('</article>');

    L.push('<aside class="up-aside">');
    if (heads.length) {
      L.push('  <nav class="up-card" aria-label="Sommaire"><h3>Sur cette page</h3><ol>');
      heads.forEach(function (h) { L.push('    <li><a href="#' + slug(h.text) + '">' + h.text + '</a></li>'); });
      L.push('  </ol></nav>');
    }
    if (pg.serverRecord) {
      L.push('  <div class="up-card"><h3>Informations pratiques</h3><p>À compléter avec des informations vérifiées.</p></div>');
    } else if (pub) {
      L.push('  <div class="up-card"><h3>Rejoindre la section</h3><p>Se syndiquer, c\'est peser dans les négociations et être défendu individuellement.</p><a class="up-btn" href="/adherer">Adhérer en ligne</a></div>');
      L.push('  <div class="up-card"><h3>Contact presse</h3><p>' + e(pg.author) + '<br />presse@' + e(site.host) + '<br />03 27 00 00 00</p></div>');
    } else {
      L.push('  <div class="up-card"><h3>Permanences</h3><p>Local B12 — mardi 12 h-14 h et jeudi 17 h-18 h 30.</p><a class="up-btn" href="/intranet/contacts">Saisir vos représentants</a></div>');
      L.push('  <div class="up-card"><h3>Documents liés</h3><ul><li><a href="' + e(this.safeHref(rub.path)) + '">Toutes les pages de « ' + e(rub.label) + ' »</a></li><li><a href="/intranet/la-section/comptes-rendus">Comptes rendus de séance</a></li><li><a href="/intranet/vos-droits">Fiches pratiques</a></li></ul></div>');
    }
    L.push('  <div class="up-card"><h3>Mots-clés</h3><p><span class="up-tag">' + e(rub.label) + '</span><span class="up-tag">' + e(pg.slug) + '</span><span class="up-tag">2026</span></p></div>');
    L.push('</aside>');
    L.push('</div></main>');

    L.push('<footer class="up-foot"><div class="up-wrap">');
    L.push('  <div class="up-cols">');
    L.push('    <div class="up-col"><h4>' + e(sigle) + '</h4><p style="margin:0">' + e(org.adresse || '') + '<br />' + e(org.email || '') + '</p></div>');
    L.push('    <div class="up-col"><h4>Rubriques</h4><ul>');
    rubs.slice(0, 4).forEach((x) => { L.push('      <li><a href="' + e(this.safeHref(x.path)) + '">' + e(x.label) + '</a></li>'); });
    L.push('    </ul></div>');
    if (pub) {
      L.push('    <div class="up-col"><h4>Agir</h4><ul><li><a href="/adherer">Adhérer</a></li><li><a href="/campagnes">Nos campagnes</a></li><li><a href="/contact">Nous écrire</a></li></ul></div>');
      L.push('    <div class="up-col"><h4>Informations</h4><ul><li><a href="/mentions-legales">Mentions légales</a></li><li><a href="/donnees-personnelles">Données personnelles</a></li><li><a href="/accessibilite">Accessibilité : partiellement conforme</a></li></ul></div>');
    } else {
      L.push('    <div class="up-col"><h4>Services</h4><ul><li><a href="/intranet/contacts">Saisine confidentielle</a></li><li><a href="/intranet/asc">Billetterie et ASC</a></li><li><a href="/intranet/agenda">Agenda des permanences</a></li></ul></div>');
      L.push('    <div class="up-col"><h4>Informations</h4><ul><li><a href="/intranet/donnees-personnelles">Traitement de vos données</a></li><li><a href="/intranet/accessibilite">Accessibilité</a></li><li><a href="/intranet/aide">Aide</a></li></ul></div>');
    }
    L.push('  </div>');
    L.push('  <div class="up-legal">');
    L.push('    <span>© 2026 ' + e(org.nom || '') + '</span>');
    L.push('    <span>' + e(site.host) + '</span>');
    L.push('    <span>' + (pub ? 'Site public — contenus destinés à la diffusion' : 'Espace interne — ne pas diffuser hors de l\'entreprise') + '</span>');
    L.push('  </div>');
    L.push('</div></footer>');
    L.push('</div>');
    return L.join('\n');
  }
  pageHtml(pg) {
    const d = this.state.pageHtmlDraft;
    if (d !== null && d !== undefined) return d;
    return this.buildPageHtml(pg);
  }
  openPage(id) { this.setState({ pageId: id, pageHtmlDraft: null, webTab: 'apercu' }); this.go('webedit'); }
  createPage(modelId) {
    const m = this.pageModels().find(function (x) { return x.id === modelId; }) || this.pageModels()[0];
    const id = 'p' + Date.now();
    const rub = m.rub;
    const pg = {
      id: id, site: this.state.webSite || 'intranet', title: m.label + ' — sans titre', rubrique: rub, slug: 'nouvelle-page',
      status: 'Brouillon', updated: "à l'instant", author: 'Sophie Marchand', review: null, pub: null,
      chapo: 'Résumé en une phrase, affiché en tête de page et dans la liste de la rubrique.', blocks: null
    };
    this.setState((s) => ({ pages: [pg].concat(s.pages), pageId: id, pageHtmlDraft: null, webTab: 'apercu' }));
    this.go('webedit');
    this.flash('Page créée depuis le gabarit « ' + m.label + ' »');
  }
  pvStyle(b) {
    const line = (w, h, c) => ({ isBar: true, w: (w || 100) + '%', h: (h || 5) + 'px', bg: c || 'var(--track)', r: '3px', mt: '6px' });
    switch (b.k) {
      case 'hero': return { isBar: true, w: '100%', h: (b.h || 22) + 'px', bg: 'var(--ac)', r: '6px', mt: '0px' };
      case 'chip': return { isBar: true, w: (b.w || 30) + '%', h: '6px', bg: 'var(--acMid)', r: '99px', mt: '8px' };
      case 'title': return { isBar: true, w: (b.w || 70) + '%', h: '9px', bg: 'var(--ink3)', r: '3px', mt: '8px' };
      case 'line': return line(b.w, 5);
      case 'cta': return { isBar: true, w: (b.w || 44) + '%', h: '12px', bg: 'var(--inkSurf)', r: '99px', mt: '9px' };
      case 'callout': return { isBar: true, w: '100%', h: '18px', bg: 'var(--acBg)', r: '5px', mt: '8px' };
      case 'quote': return { isBar: true, w: '82%', h: '16px', bg: 'var(--infoBg)', r: '5px', mt: '8px' };
      case 'file': return { isBar: true, w: '68%', h: '11px', bg: 'var(--chip)', r: '4px', mt: '8px' };
      case 'img': return { isImg: true, mt: '8px' };
      case 'map': return { isMap: true, mt: '8px' };
      case 'cards': return { isRow: true, cols: 3, h: '26px', mt: '8px' };
      case 'stats': return { isRow: true, cols: 3, h: '20px', mt: '8px' };
      case 'split': return { isRow: true, cols: 2, h: '22px', mt: '8px' };
      case 'faces': return { isFaces: true, mt: '8px' };
      case 'form': return { isForm: true, mt: '8px' };
      case 'accord': return { isBar: true, w: '100%', h: '10px', bg: 'var(--surf2)', r: '4px', mt: '6px', bdr: '1px solid var(--bd2)' };
      case 'bullets': return { isBullets: true, mt: '8px' };
      case 'meta2': return { isRow: true, cols: 2, h: '10px', mt: '8px' };
      case 'sign': return { isBar: true, w: '40%', h: '8px', bg: 'var(--chip)', r: '3px', mt: '10px' };
      default: return line(b.w, 5);
    }
  }
  setWebGen(patch) { this.setState((s) => ({ webGen: Object.assign({}, s.webGen, patch) })); }
  askReview() {
    this.patchPage({ status: 'En relecture', review: { by: 'Jean-Paul Deniau', note: 'Relecture demandée — réponse attendue sous 24 h.' } });
    this.flash('Relecture préparée localement — aucun envoi externe');
  }
  setPub(patch) { this.setState((s) => ({ pubForm: Object.assign({}, s.pubForm, patch) })); }
  sendToWebmaster() {
    const f = this.state.pubForm;
    const pg = this.curPage();
    const ref = 'PUB-2026-0' + (42 + this.state.pages.filter(function (x) { return !!x.pub; }).length);
    this.patchPage({
      status: 'En attente webmaster',
      pub: { date: f.date, vis: f.vis, msg: f.msg, ref: ref, sentAt: "à l'instant" }
    });
    this.go('webqueue');
    this.flash('Demande ' + ref + ' transmise au webmaster' + (f.notify ? ' · notification e-mail envoyée' : ''));
  }

  webVals() {
    const r = this.state.route;
    const pill = {
      'En relecture': ['var(--infoBg)', 'var(--infoTx2)'], 'Brouillon': ['var(--chip)', 'var(--ink4)'], 'Relue': ['var(--infoBg)', 'var(--infoTx2)'],
      'En attente webmaster': ['var(--acBg)', 'var(--acTx2)'], 'Publiée': ['var(--okBg)', 'var(--okTx)'], 'Retournée': ['var(--dangerBg)', 'var(--dangerTx2)']
    };
    const pg = this.curPage() || { id: '', site: 'intranet', rubrique: 'actualites', title: 'Aucune page sélectionnée', chapo: '', slug: '', status: 'Brouillon', author: '', updated: '', blocks: [] };
    const g = this.state.webGen;
    const f = this.state.pubForm;
    const c = this.webCharteDef();
    const wcId = this.state.wcSite || 'intranet';
    const wc = this.webCharteDef(wcId);
    const bd = Object.assign({}, DEFAULT_BRAND, this.state.brand || {});
    const brandLabel = ((BRAND_PRESETS.find(function (p) { return p.id === bd.preset; }) || {}).label) || 'personnalisée';
    const rub = this.rubOf(pg.rubrique);
    const src = this.pageHtml(pg);
    const site = this.curSite();
    const pages = this.state.pages.filter((x) => this.pageSite(x) === site.id);
    const waiting = pages.filter(function (x) { return x.status === 'En attente webmaster'; });
    const online = pages.filter(function (x) { return x.status === 'Publiée'; });
    const back = pages.filter(function (x) { return x.status === 'Retournée'; });
    const blockLabel = { p: 'Paragraphe', h2: 'Intertitre', list: 'Liste', callout: 'Encadré', cta: 'Bouton', file: 'Pièce jointe', img: 'Image' };
    const setBlock = (bid, patch) => {
      const bl = this.pageBlocks(pg).map(function (b) { return b.id === bid ? Object.assign({}, b, patch) : b; });
      this.setState({ pageHtmlDraft: null });
      this.patchPage({ blocks: bl });
    };
    const queue = pages.filter(function (x) { return !!x.pub; }).map((x) => {
      const st = x.status;
      const done = { Brouillon: 1, Relue: 2, 'En attente webmaster': 3, 'Publiée': 4, 'Retournée': 3 }[st] || 1;
      const reviewed = !!x.review;
      return {
        ref: x.pub.ref, title: x.title, rubrique: this.rubOf(x.rubrique).label, status: st,
        pillBg: (pill[st] || pill.Brouillon)[0], pillFg: (pill[st] || pill.Brouillon)[1],
        date: this.frDate(x.pub.date), vis: x.pub.vis, sentAt: 'transmise ' + x.pub.sentAt,
        msg: x.pub.msg || 'Aucune consigne particulière.',
        hasBack: !!x.pub.back, back: x.pub.back || '',
        isPub: st === 'Publiée', url: this.pageUrl(x),
        siteLabel: this.siteOf(this.pageSite(x)).label,
        steps: [
          { label: 'Rédigée', on: done >= 1 },
          { label: reviewed ? 'Relue par un pair' : 'Relecture non effectuée', on: reviewed },
          { label: 'Envoyée au webmaster', on: done >= 3 },
          { label: st === 'Retournée' ? 'Retour du webmaster' : 'Publiée', on: done >= 4 || st === 'Retournée' }
        ],
        open: () => this.openPage(x.id),
        relance: () => this.flash('Relance envoyée au webmaster — ' + x.pub.ref)
      };
    });
    const sw2 = (on) => ({ bg: on ? 'var(--ok)' : 'var(--bd2)', left: on ? '23px' : '3px' });
    return {
      isIntranet: r === 'intranet', isWebGen: r === 'webgen', isWebEdit: r === 'webedit',
      wgToAsst: () => { const g = this.state.webGen; const rb = this.rubOf(g.rubrique); this.toAssistant({ origin: 'Intranet', route: 'webgen', title: 'Page intranet — ' + rb.label, ctx: 'Générateur de pages · rubrique : ' + rb.label + ' (' + rb.path + ') · ton : ' + g.tone + '\nPoints clés : ' + (g.prompt || 'non renseignés') }); },
      isWebPub: r === 'webpub', isWebQueue: r === 'webqueue', isWebCharte: r === 'webcharte',

      siteTabs: this.siteDefs().map((s) => {
        const on = s.id === site.id;
        const n = this.state.pages.filter((x) => this.pageSite(x) === s.id).length;
        return {
          label: s.label, short: s.short, host: s.host, count: n + ' page' + (n > 1 ? 's' : ''),
          bg: on ? 'var(--inkSurf)' : 'var(--surface)', fg: on ? '#FFFFFF' : 'var(--ink3)',
          sub: on ? 'rgba(255,255,255,.66)' : 'var(--ink6)', bd: on ? 'var(--inkSurf)' : 'var(--bd)',
          go: () => this.setState({ webSite: s.id })
        };
      }),
      siteKicker: site.kicker, siteTitle: site.label, siteHost: site.host,
      siteAudience: site.audience, siteDesc: site.desc, siteNote: site.note,
      siteIsPublic: site.id === 'public', siteIsIntra: site.id === 'intranet',
      webSummary: pages.length + (pages.length > 1 ? ' pages suivies · ' : ' page suivie · ') + online.length + ' en ligne, ' + waiting.length + ' en attente du webmaster',
      webStats: [
        { value: String(online.length), label: 'pages en ligne' },
        { value: String(waiting.length), label: 'en attente webmaster' },
        { value: String(pages.filter(function (x) { return x.status === 'Brouillon' || x.status === 'Relue'; }).length), label: 'en préparation' },
        { value: String(back.length), label: 'retour à traiter' }
      ],
      webRoleNote: site.id === 'public'
        ? 'Vous éditez le site public au titre du rôle « communication ». Toute page y passe par une relecture par un pair avant transmission au webmaster : elle engage la section vis-à-vis de la direction et de la presse.'
        : 'Vous éditez l\'intranet au titre du rôle « communication ». 3 ' + this.W().memberMany + ' disposent de ce rôle ; les autres ont un accès en lecture.',
      webRubriques: this.rubDefs().map((x) => ({
        label: x.label, path: x.path, desc: x.desc,
        count: (function (n) { return n + ' page' + (n > 1 ? 's' : ''); })(pages.filter(function (p) { return p.rubrique === x.id; }).length),
        go: () => { this.setWebGen({ rubrique: x.id }); this.go('webgen'); }
      })),
      webPageList: pages.map((x) => ({
        del: this.askDel('page-' + x.id, 'Supprimer', () => {
          this.setState((s) => {
            const rest = s.pages.filter((y) => y.id !== x.id);
            return { pages: rest, pageId: s.pageId === x.id ? (rest[0] || {}).id || '' : s.pageId };
          });
          this.flash('Page supprimée de l\'espace de préparation');
        }),
        title: x.title, meta: this.rubOf(x.rubrique).label + ' · ' + x.author + ' · modifiée ' + x.updated,
        status: x.status, pillBg: (pill[x.status] || pill.Brouillon)[0], pillFg: (pill[x.status] || pill.Brouillon)[1],
        open: () => this.openPage(x.id)
      })),
      webPageCount: pages.length + ' page' + (pages.length > 1 ? 's' : ''),
      webModels: this.pageModels().map((m) => ({
        label: m.label, desc: m.desc, meta: m.meta,
        pv: (m.pv || []).map((b, i) => Object.assign({ key: m.id + '-' + i }, this.pvStyle(b))),
        create: () => this.createPage(m.id)
      })),
      goWebGen: () => { this.setWebGen({ phase: 'empty' }); this.go('webgen'); },
      goWebQueue: () => this.go('webqueue'),
      goWebCharte: () => this.go('webcharte'),
      goIntranet: () => this.go('intranet'),
      webQueueLabel: waiting.length + ' demande' + (waiting.length > 1 ? 's' : '') + ' en attente · ' + back.length + ' retour à traiter',

      wgModels: this.pageModels().map((m) => ({
        label: m.label, bd: g.model === m.id ? 'var(--ac)' : 'var(--bd2)', bg: g.model === m.id ? 'var(--acBg)' : '#FFFFFF',
        fg: g.model === m.id ? 'var(--acTx)' : 'var(--ink4)', go: () => this.setWebGen({ model: m.id })
      })),
      wgRubs: this.rubDefs().map((x) => ({
        label: x.label, bg: g.rubrique === x.id ? 'var(--acBg)' : 'var(--surf2)', fg: g.rubrique === x.id ? 'var(--acTx)' : 'var(--ink5)',
        go: () => this.setWebGen({ rubrique: x.id })
      })),
      wgTones: ['Clair', 'Institutionnel', 'Mobilisateur'].map((t) => ({
        label: t, bg: g.tone === t ? 'var(--acBg)' : 'var(--surf2)', fg: g.tone === t ? 'var(--acTx)' : 'var(--ink5)',
        go: () => this.setWebGen({ tone: t })
      })),
      wgPrompt: g.prompt,
      wgx: this.extWebGenVals(g),
      onWgPrompt: (e) => this.setWebGen({ prompt: e.target.value }),
      wgClair: sw2(g.clair).bg, wgClairL: sw2(g.clair).left, wgClairToggle: () => this.setWebGen({ clair: !g.clair }),
      wgResume: sw2(g.resume).bg, wgResumeL: sw2(g.resume).left, wgResumeToggle: () => this.setWebGen({ resume: !g.resume }),
      wgGenerate: () => this.genPageLlm(),
      wgLabel: g.phase === 'run' ? 'Rédaction en cours…' : 'Générer la page HTML',
      wgRunning: g.phase === 'run', wgWaiting: g.phase !== 'run',
      wgTargetPath: this.rubOf(g.rubrique).path + '/…',

      pgTitle: pg.title,
      onPgTitle: (e) => { this.setState({ pageHtmlDraft: null }); this.patchPage({ title: e.target.value }); },
      pgChapo: pg.chapo,
      onPgChapo: (e) => { this.setState({ pageHtmlDraft: null }); this.patchPage({ chapo: e.target.value }); },
      pgRubrique: rub.label,
      pgUrl: this.pageUrl(pg),
      pgCharteLabel: 'Charte · ' + this.siteOf(this.pageSite(pg)).label,
      pgGoCharte: () => this.setState({ wcSite: this.pageSite(pg), webSite: this.pageSite(pg) }, () => this.go('webcharte')),
      pgStatus: pg.status, pgPillBg: (pill[pg.status] || pill.Brouillon)[0], pgPillFg: (pill[pg.status] || pill.Brouillon)[1],
      pgAuthor: pg.author + ' · modifiée ' + pg.updated,
      pgReviewNote: pg.review ? pg.review.by + ' — ' + pg.review.note : 'Aucune relecture pour l\'instant. Un second membre du rôle communication doit valider avant l\'envoi.',
      pgReviewed: !!pg.review, pgNotReviewed: !pg.review,
      pgBackNote: pg.pub && pg.pub.back ? pg.pub.back : '',
      pgHasBack: !!(pg.pub && pg.pub.back),
      webTabs: [{ id: 'apercu', label: 'Aperçu' }, { id: 'code', label: 'Code HTML' }].map((t) => ({
        label: t.label, bg: this.state.webTab === t.id ? '#111827' : '#FFFFFF', fg: this.state.webTab === t.id ? '#FFFFFF' : 'var(--ink4)',
        bd: this.state.webTab === t.id ? '#111827' : 'var(--bd2)',
        go: () => this.setState({ webTab: t.id })
      })),
      isTabPreview: this.state.webTab !== 'code', isTabCode: this.state.webTab === 'code',
      pgx: this.extPageVals(pg, src),
      // R42 : aperçu isolé (iframe sandbox sans script ni accès à l'origine de l'application).
      webPreview: React.createElement('iframe', { title: 'Aperçu de la page', sandbox: '', referrerPolicy: 'no-referrer', style: { width: '100%', height: '560px', border: '0', background: '#fff' }, srcDoc: '<!doctype html><meta charset="utf-8"><style>' + this.pageCss(this.pageSite(pg)) + '</style>' + src }),
      pageSrc: src,
      onPageSrc: (e) => this.setState({ pageHtmlDraft: e.target.value }),
      srcDirty: this.state.pageHtmlDraft !== null && this.state.pageHtmlDraft !== undefined,
      resetSrc: () => { this.setState({ pageHtmlDraft: null }); this.flash('Code régénéré depuis les blocs'); },
      copySrc: () => {
        if (typeof navigator !== 'undefined' && navigator.clipboard) navigator.clipboard.writeText(src);
        this.flash('HTML copié — prêt à coller dans le CMS');
      },
      srcLines: src.split('\n').length + ' lignes · HTML sémantique, styles dans la feuille du site',
      webBlocks: this.pageBlocks(pg).map((b) => ({
        label: blockLabel[b.t] || (this.extPageSection(b.t) || {}).label || (b.ext ? 'Section « ' + b.t + ' » (extension inactive)' : b.t),
        canDel: !!b.ext,
        del: () => { this.setState({ pageHtmlDraft: null }); this.patchPage({ blocks: this.pageBlocks(pg).filter((y) => y.id !== b.id) }); },
        text: b.t === 'list' ? (b.items || []).join('\n') : b.text,
        onText: (e) => {
          const v = e.target.value;
          setBlock(b.id, b.t === 'list' ? { items: v.split('\n') } : { text: v });
        },
        rows: b.t === 'h2' ? 1 : 3
      })),
      pgSummary: 'Résumé pour la page d\'accueil du site : « ' + pg.chapo.slice(0, 90) + (pg.chapo.length > 90 ? '…' : '') + ' »',
      askReviewFn: () => this.askReview(),
      goPub: () => { this.setPub({ slug: pg.slug }); this.go('webpub'); },
      backToIntranet: () => this.go('intranet'),

      pubTitle: pg.title, pubRub: rub.label, pubPath: rub.path,
      pubSlug: f.slug || pg.slug,
      onPubSlug: (e) => this.setPub({ slug: e.target.value }),
      pubUrlPreview: rub.path + '/' + (f.slug || pg.slug),
      pubDate: f.date, onPubDate: (e) => this.setPub({ date: e.target.value }),
      pubVisOpts: ['Tous les salariés', 'Adhérents connectés', 'Élus et mandatés'].map((v) => ({
        label: v, bg: f.vis === v ? 'var(--acBg)' : 'var(--surf2)', fg: f.vis === v ? 'var(--acTx)' : 'var(--ink5)',
        go: () => this.setPub({ vis: v })
      })),
      pubMsg: f.msg, onPubMsg: (e) => this.setPub({ msg: e.target.value }),
      pubAttach: sw2(f.attach).bg, pubAttachL: sw2(f.attach).left, pubAttachToggle: () => this.setPub({ attach: !f.attach }),
      pubNotify: sw2(f.notify).bg, pubNotifyL: sw2(f.notify).left, pubNotifyToggle: () => this.setPub({ notify: !f.notify }),
      pubHome: sw2(f.home).bg, pubHomeL: sw2(f.home).left, pubHomeToggle: () => this.setPub({ home: !f.home }),
      pubReady: !!pg.review, pubBlocked: !pg.review,
      sendPub: () => this.sendToWebmaster(),
      webmasterName: 'Marc Lefèvre — webmaster intranet',
      webmasterMail: 'webmaster@' + this.siteOf(this.pageSite(pg)).host,
      pubChecklist: [
        { label: 'HTML validé', ok: 'Balises sémantiques, aucun style en ligne' },
        { label: 'Feuille de style du site', ok: 'intranet-2026.css — classes up-* reconnues' },
        { label: 'Données personnelles', ok: 'Aucun nom de salarié détecté dans la page' }
      ],

      webQueue: queue,
      webQueueEmpty: queue.length === 0,
      queueSummary: queue.length + ' demande(s) de publication · file interne partagée avec le webmaster',

      wcSiteTabs: this.siteDefs().map((s) => {
        const on = s.id === wcId;
        return {
          label: s.label, host: s.host,
          bg: on ? 'var(--inkSurf)' : 'var(--surface)', fg: on ? '#FFFFFF' : 'var(--ink3)',
          sub: on ? 'rgba(255,255,255,.66)' : 'var(--ink6)', bd: on ? 'var(--inkSurf)' : 'var(--bd)',
          go: () => this.setState({ wcSite: s.id })
        };
      }),
      wcSiteLabel: this.siteOf(wcId).label,
      wcSiteHost: this.siteOf(wcId).host,
      wcInherit: !!wc.inherit,
      wcInheritBg: wc.inherit ? 'var(--ok)' : 'var(--bd2)',
      wcInheritLeft: wc.inherit ? '23px' : '3px',
      wcToggleInherit: () => this.setWc({ inherit: !wc.inherit }),
      wcInheritNote: wc.inherit
        ? 'Les couleurs et la police de titre suivent l\'identité de l\'organisation définie dans Réglages · Identité de marque. Modifier l\'identité met ce site à jour.'
        : 'Ce site a sa propre charte, indépendante de l\'identité de l\'organisation.',
      wcCustom: true,
      wcColorNote: wc.inherit ? 'Couleurs et police reprises de l\'identité de l\'organisation. En choisir une autre détache la charte de ce site.' : 'Charte propre à ce site.',
      wcBrandNote: 'Identité de l\'organisation : ' + brandLabel,
      wcGoBrand: () => this.go('params'),
      wcAccents: ['#DC2626', '#E11D48', '#2563EB', '#059669', '#7C3AED', '#475569', '#0F766E', '#F97316'].map((col) => ({
        color: col, bd: String(wc.accent).toLowerCase() === col.toLowerCase() ? '#111827' : 'transparent',
        go: () => this.setWc({ accent: col })
      })),
      wcHeads: ['#1F2937', '#1E293B', '#14532D', '#1E3A8A', '#4C1D95', '#7F1D1D', '#111827', '#3F3F46'].map((col) => ({
        color: col, bd: String(wc.head).toLowerCase() === col.toLowerCase() ? '#111827' : 'transparent',
        go: () => this.setWc({ head: col })
      })),
      wcNavs: [
        { id: 'inline', label: 'Navigation claire' },
        { id: 'bar', label: 'Bandeau de couleur' }
      ].map((x) => ({
        label: x.label, bg: wc.nav === x.id ? 'var(--acBg)' : 'var(--surf2)', fg: wc.nav === x.id ? 'var(--acTx)' : 'var(--ink5)',
        go: () => this.setWc({ nav: x.id })
      })),
      wcRadii: [
        { id: 'net', label: 'Angles nets' },
        { id: 'doux', label: 'Arrondis doux' },
        { id: 'rond', label: 'Très arrondis' }
      ].map((x) => ({
        label: x.label, bg: wc.radius === x.id ? 'var(--acBg)' : 'var(--surf2)', fg: wc.radius === x.id ? 'var(--acTx)' : 'var(--ink5)',
        go: () => this.setWc({ radius: x.id })
      })),
      wcLogoSrc: (() => { const l = this.siteLogo(wcId); return l.src; })(),
      wcLogoHasImg: (() => { const l = this.siteLogo(wcId); return !!l.src; })(),
      wcLogoEl: (() => {
        const l = this.siteLogo(wcId);
        if (!l.src) return null;
        return React.createElement('img', {
          src: l.src, alt: 'Logo du site',
          style: { display: 'block', height: Math.round(40 * l.scale) + 'px', width: 'auto', maxWidth: '100%', objectFit: 'contain' }
        });
      })(),
      wcLogoFrom: 'Source : ' + this.siteLogo(wcId).from,
      wcLogoOwn: this.siteLogo(wcId).own,
      wcLogoCta: this.siteLogo(wcId).own ? 'Remplacer le logo de ce site' : 'Déposer un logo propre à ce site',
      onWcLogoFile: (e) => {
        const inp = e.target;
        const file = inp.files && inp.files[0];
        if (!file) return;
        if (!/^image\//.test(file.type)) { inp.value = ''; return this.flash('Format non reconnu — PNG, SVG ou JPEG attendu'); }
        if (file.size > 2 * 1024 * 1024) { inp.value = ''; return this.flash('Fichier trop lourd — 2 Mo maximum'); }
        const rd = new FileReader();
        rd.onload = () => { this.setWc({ logoSrc: rd.result, logo: true }); this.flash('Logo importé pour « ' + this.siteOf(wcId).label + ' »'); };
        rd.onerror = () => this.flash('Lecture du fichier impossible');
        rd.readAsDataURL(file);
        inp.value = '';
      },
      wcLogoClear: () => { this.setWc({ logoSrc: '' }); this.flash('Logo propre retiré — le site reprend celui de l\'identité'); },
      wcLogoScale: Number(wc.logoScale) || 100,
      wcLogoScaleLabel: (Number(wc.logoScale) || 100) + ' %',
      onWcLogoScale: (e) => this.setWc({ logoScale: Number(e.target.value) }),
      wcLogoScaleReset: () => this.setWc({ logoScale: 100 }),
      wcLogoBg: wc.logo ? 'var(--ok)' : 'var(--bd2)',
      wcLogoLeft: wc.logo ? '23px' : '3px',
      wcToggleLogo: () => this.setWc({ logo: !wc.logo }),
      wcGabarits: [
        { id: 'actu', label: 'Article' },
        { id: 'fiche', label: 'Fiche étroite' },
        { id: 'dense', label: 'Large' }
      ].map((x) => ({
        label: x.label, bg: wc.gabarit === x.id ? 'var(--acBg)' : 'var(--surf2)', fg: wc.gabarit === x.id ? 'var(--acTx)' : 'var(--ink5)',
        go: () => this.setWc({ gabarit: x.id, width: x.id === 'fiche' ? 640 : (x.id === 'dense' ? 900 : 760) })
      })),
      wcFonts: [
        { id: 'Philosopher, Georgia, serif', label: 'Philosopher' },
        { id: 'Georgia, "Times New Roman", serif', label: 'Georgia' },
        { id: 'system-ui, Segoe UI, Helvetica, sans-serif', label: 'Sans-serif système' }
      ].map((x) => ({
        label: x.label, bg: wc.titleFont === x.id ? 'var(--acBg)' : 'var(--surf2)', fg: wc.titleFont === x.id ? 'var(--acTx)' : 'var(--ink5)',
        go: () => this.setWc({ titleFont: x.id })
      })),
      wcWidth: wc.width + ' px de largeur de contenu',
      wcAccent: wc.accent, wcHead: wc.head, wcFont: wc.titleFont,
      wcNavBg: wc.nav === 'bar' ? wc.head : '#FFFFFF',
      wcNavFg: wc.nav === 'bar' ? 'rgba(255,255,255,.86)' : '#374151',
      wcRadPx: (wc.radius === 'net' ? 0 : (wc.radius === 'rond' ? 22 : 14)) + 'px',
      wcShowLogo: !!wc.logo,
      wcPreviewHasLogo: !!wc.logo && !!this.siteLogo(wcId).src,
      wcPreviewMono: !!wc.logo && !this.siteLogo(wcId).src,
      wcPreviewLogoEl: (() => {
        const l = this.siteLogo(wcId);
        if (!wc.logo || !l.src) return null;
        return React.createElement('img', { src: l.src, alt: '', style: { display: 'block', height: Math.round(30 * l.scale) + 'px', width: 'auto', maxWidth: '160px', objectFit: 'contain' } });
      })(),
      wcOrgName: (this.state.org || {}).nom || '',
      wcCssName: (wcId === 'public' ? 'site-public' : 'intranet') + '-2026.css',
      wcCss: this.pageCss(wcId).slice(0, 420) + '…',
      wcSaved: () => this.flash('Charte du site « ' + this.siteOf(wcId).label + ' » enregistrée — appliquée aux pages générées')
    };
  }

  renderVals() {
    const r = this.state.route;
    const f = this.state.flags;
    const anonLvl = this.state.anonLevel;
    const anonDef = this.anonLevelDefs().find(function (l) { return l.key === anonLvl; });
    const anon = this.maskText(this.state.anonQuery, anonLvl);
    const sheetDef = this.sheetDefs()[this.state.sheet];
    const vw = this.viewerData();
    const sw = (on) => ({ bg: on ? 'var(--ok)' : 'var(--bd2)', left: on ? '23px' : '3px' });
    const W = this.W();
    const nav = [
      { id: 'accueil', ic: ICONS.home, label: 'Accueil', m: true },
      { id: 'dossiers', ic: ICONS.folder, label: 'Dossiers', m: true },
      { id: 'reunions', ic: ICONS.mic, label: 'Réunions', m: true },
      { id: 'agenda', ic: ICONS.calendar, label: 'Agenda', m: true },
      { id: 'documents', ic: ICONS.file, label: 'Documents', m: false },
      { id: 'adherents', ic: ICONS.users, label: this.W().memberNav, m: false },
      { id: 'intranet', ic: ICONS.rocket, label: 'Intranet', m: false },
      { id: 'assistant', ic: ICONS.sparkles, label: 'Assistant', m: false },
      { id: 'messagerie', ic: ICONS.chat, label: 'Messages', m: false },
      { id: 'formations', ic: ICONS.grad, label: 'Formations', m: false },
      { id: 'communication', ic: ICONS.megaphone, label: 'Communication', m: false },
      { id: 'mobile', ic: ICONS.phone, label: 'Application mobile', m: false },
      { id: 'reporting', ic: ICONS.chart, label: 'Reporting', m: false },
      { id: 'raccourcis', ic: ICONS.link, label: 'Raccourcis', m: false },
      { id: 'params', ic: ICONS.settings, label: 'Réglages', m: true }
    ];
    const navOrdered = this.state.navOrder
      .map(function (id) { return nav.find(function (n) { return n.id === id; }); })
      .filter(Boolean)
      ;
    nav.filter((n) => this.state.navOrder.indexOf(n.id) < 0).forEach((n) => { const p = navOrdered.findIndex((x) => x.id === 'params'); navOrdered.splice(p < 0 ? navOrdered.length : p, 0, n); });

    /* ---- Réunions ---- */
    const rc = this.state.rec;
    const reu0 = this.curReunion() || {title:'Aucune réunion sélectionnée',type:'',date:'',dur:'',pv:'',markers:[],ordre:[],access:[],retention:0};
    const imp = this.state.audioImport;
    const recBars = [];
    for (let i = 0; i < 56; i++) {
      const idx = rc.wave.length > 56 ? rc.wave.length - 56 + i : i;
      const v = idx < rc.wave.length ? rc.wave[idx] : 0;
      const h = Math.max(3, Math.round(v * 74));
      recBars.push({
        key: 'b' + i,
        st: { flex: '1 1 0', minWidth: 0, height: h + 'px', borderRadius: '99px', background: v > .72 ? 'var(--danger)' : (v > .35 ? 'var(--acMid)' : 'rgba(255,255,255,.28)'), transition: 'height .09s linear' }
      });
    }
    const pvPill = { 'À rédiger': ['var(--acBg)', 'var(--acTx2)'], 'En relecture': ['var(--infoBg)', 'var(--infoTx2)'], 'Approuvé': ['var(--okBg)', 'var(--okTx)'], 'Archivé': ['var(--chip)', 'var(--ink4)'] };
    const audioTxt = function (x) {
      if (x.serverRecord && !x.audio) return {label:'Aucun audio associé à cette réunion',short:'Absent',fg:'var(--ink5)'};
      if (x.audio === 'destroyed') return { label: 'Audio détruit — PV archivé', short: 'Détruit', fg: 'var(--okTx)' };
      return { label: 'Audio local — destruction automatique non connectée', short: 'Local', fg: 'var(--acTx2)' };
    };
    const markerOf = function (id) { return MARKER_DEFS.find(function (m) { return m.id === id; }) || MARKER_DEFS[0]; };
    const impSteps = [
      { n: 1, label: 'Fichier lu sur l\'appareil' },
      { n: 2, label: 'Fichier prêt pour le stockage local' },
      { n: 3, label: 'Transcription non connectée' }
    ];

    /* ---- Espace Création de documents ---- */
    const chr = this.charteDef();
    const cdoc = this.curDoc();
    const dfmt = DOC_FORMATS[cdoc.format] || DOC_FORMATS.a4;
    const dz = !this.state.isDesktop && !this.state.mobileZoomManual ? Math.min(this.state.docZoom, Math.max(.1, ((this.state.viewportWidth || 390) - 90) / dfmt.w)) : (!this.state.isDesktop ? (this.state.mobileDocZoom || .72) : this.state.docZoom);
    const dens = chr.density === 'compact' ? .92 : (chr.density === 'confort' ? 1.1 : 1);
    const ts = dfmt.t * dens;
    const tfont = (DOC_FONTS[chr.titleFont] || DOC_FONTS.philosopher).css;
    const bfont = (DOC_FONTS[chr.bodyFont] || DOC_FONTS.inter).css;
    const ac = /^#[0-9a-fA-F]{6}$/.test(chr.accent) ? chr.accent : '#DC2626';
    const rgba = function (hex, a) {
      const n = parseInt(hex.slice(1), 16);
      return 'rgba(' + ((n >> 16) & 255) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + a + ')';
    };
    const pxv = function (v) { return (Math.round(v * 10) / 10) + 'px'; };
    const inner = dfmt.h - dfmt.pad * 2 - (chr.header ? 62 : 0) - (chr.footer ? 44 : 0);

    const self = this;
    const xstd = { accent: ac, accent2: ac, ink: chr.ink, paper: '#FFFFFF', head: tfont, body: bfont, hand: tfont, u: ts };
    const blockView = b => prepareClassicBlock(b,{chr,ts,tfont,bfont,ac,self});

    const estH = function (b) {
      const t = b.text || '';
      const lines = t.split('\n').filter(function (l) { return l.trim(); }).length || 1;
      if (b.type === 'tag') return 30 * ts;
      if (b.type === 'h1') return (34 + Math.ceil(t.length / (dfmt.cpl * .55)) * 30) * ts;
      if (b.type === 'h2') return 42 * ts;
      if (b.type === 'h3') return 34 * ts;
      if (b.type === 'p') return (12 + Math.max(1, Math.ceil(t.length / dfmt.cpl)) * 22) * ts;
      if (b.type === 'ul') return (12 + lines * 23) * ts;
      if (b.type === 'quote') return (30 + lines * 21) * ts;
      if (b.type === 'table') return (16 + lines * 29) * ts;
      const xh = self.extDocBlock(b.type);
      if (xh) return self.extSafe(xh.extId, 'hauteur ' + b.type, () => Number(xh.estimateHeight ? xh.estimateHeight(b) : 90) || 90, 90) * ts;
      if (CORE_DOC_TYPES.indexOf(b.type) < 0) return (12 + Math.max(1, Math.ceil(t.length / dfmt.cpl)) * 22) * ts;
      return 0;
    };

    const pageGroups = [[]];
    cdoc.blocks.forEach(function (b) {
      if (b.type === 'pagebreak') pageGroups.push([]);
      else pageGroups[pageGroups.length - 1].push(b);
    });
    if (pageGroups.length > 1 && !pageGroups[pageGroups.length - 1].length) pageGroups.pop();

    const xsty = self.extDocStyle(cdoc.style);
    let overflowPage = 0;
    const plannedPages = planDocumentPages(pageGroups,xsty ? (grp,i,count)=>self.extSafe(xsty.extId, 'style '+xsty.id,()=>xsty.render(self.extDocCtx(xsty,grp,cdoc,dfmt,chr,i,count)),null) : null,cdoc.format);
    const dpages = plannedPages.map(function (page, i) {
      const grp=page.blocks;
      const used = grp.reduce(function (s, b) { return s + estH(b); }, 0);
      if (used > inner && !overflowPage && !xsty) overflowPage = i + 1;
      const pgv = prepareClassicPage({dfmt,dz,chr,ts,tfont,bfont,ac,grp,blockView,i,count:plannedPages.length});
      if (xsty && page.styled) {
        const xel = self.extSafe(xsty.extId, 'style ' + xsty.id, () => xsty.render(self.extDocCtx(xsty, grp, cdoc, dfmt, chr, i, plannedPages.length)), null);
        if (xel) {
          pgv.isExt = true; pgv.extEl = xel; pgv.showHeader = false; pgv.showFooter = false; pgv.blocks = [];
          pgv.st = Object.assign({}, pgv.st, { padding: 0 });
          pgv.bodySt = { display: 'none' };
        }
      }
      return pgv;
    });

    const statusPill = { Brouillon: ['var(--chip)', 'var(--ink4)'], Relu: ['var(--infoBg)', 'var(--infoTx2)'], 'Signé': ['var(--okBg)', 'var(--okTx)'], 'Diffusé': ['var(--acBg)', 'var(--acTx2)'] };
    const docSrc = this.state.docSrcDraft === null || this.state.docSrcDraft === undefined ? this.blocksToMd(cdoc.blocks) : this.state.docSrcDraft;
    const tabOf = { adhimport: 'adherents', adherent: 'adherents', adhmsg: 'adherents', contacts: 'params', unii: 'params', extensions: 'params', formations: 'formations', webgen: 'intranet', webedit: 'intranet', webpub: 'intranet', webqueue: 'intranet', webcharte: 'intranet', iasecu: 'params', dossier: 'dossiers', nouveau: 'dossiers', pieces: 'dossiers', sondage: 'sondages', sondages: 'sondages', newpoll: 'sondages', tract: 'documents', documents: 'documents', docedit: 'documents', reunions: 'reunions', record: 'reunions', reunion: 'reunions', thread: 'messagerie', marque: 'params', apikey: 'params', memoire: 'params', profil: 'params', prefs: 'params', securite: 'params', rgpd: 'params', membres: 'params', offline: 'params', onboarding: 'params', admin: 'params', signature: 'params' };
    const activeTab = tabOf[r] || r;

    const d = this.currentDossier();
    const statusLabels = STATUS_LABELS;
    const drag = this.state.drag;
    const cols = [
      { id: 'todo', label: STATUS_LABELS.todo, dot: 'var(--danger2)' },
      { id: 'doing', label: STATUS_LABELS.doing, dot: 'var(--ac)' },
      { id: 'done', label: STATUS_LABELS.done, dot: 'var(--ok)' }
    ];

    const cachedCount = Object.keys(this.state.cached).filter((k) => this.state.cached[k]).length;
    const allPolls = this.state.pollsData;
    const poll = allPolls.find((p) => p.id === this.state.pollId) || allPolls[0];
    const np = this.state.np;
    const npTargetDefs = [
      { id: 'all', label: 'Tous les salariés', meta: '416 salariés · tous établissements', count: 416 },
      { id: 'site', label: 'Site de Valenciennes', meta: '248 salariés · production et logistique', count: 248 },
      { id: 'cat', label: 'Ouvriers et employés', meta: '301 salariés · hors cadres', count: 301 },
      { id: 'union', label: 'Adhérents du syndicat', meta: '87 adhérents à jour de cotisation', count: 87 }
    ];
    const npTarget = npTargetDefs.find((t) => t.id === np.target) || npTargetDefs[0];
    const npCloseDefs = [
      { id: '2', label: '48 heures', hint: 'Clôture le 28 août à 18 h — utile avant une séance imminente.' },
      { id: '7', label: '7 jours', hint: 'Clôture le 2 septembre à 18 h — juste avant la séance NAO.' },
      { id: '14', label: '14 jours', hint: 'Clôture le 9 septembre à 18 h — laisse le temps aux équipes en congés.' }
    ];
    const npClose = npCloseDefs.find((c) => c.id === np.close) || npCloseDefs[1];
    const npFilled = np.options.map((o) => o.trim()).filter((o) => o);
    const npTitleOk = np.title.trim().length > 8;
    const npOptionsOk = npFilled.length >= 2;
    const npReady = npTitleOk && npOptionsOk;

    const extStyle = { PDF: { bg: 'var(--dangerBg)', color: 'var(--ac2)' }, ZIP: { bg: 'var(--priBg)', color: 'var(--pri)' }, XLS: { bg: 'var(--okBg)', color: 'var(--ok)' }, IMG: { bg: 'var(--infoBg)', color: 'var(--info)' } };
    const pieceList = this.state.pieces[d.id] || [];
    const piece = pieceList.find((p) => p.id === this.state.pieceId) || pieceList[0] || null;
    const up = this.state.upload;

    const repDefs = {
      year: {
        summary: 'Du 1er janvier au 26 août 2026 · 416 salariés · 24 élus',
        kpis: [
          { label: 'Dossiers traités', value: '84', delta: '+18 % vs 2025', deltaColor: 'var(--ok)' },
          { label: 'Dossiers clos', value: '71', delta: '85 % de résolution', deltaColor: 'var(--ok)' },
          { label: 'Délai moyen', value: '9 j', delta: '−3 j vs 2025', deltaColor: 'var(--ok)' },
          { label: 'Participation sondages', value: '72 %', delta: '+9 pts', deltaColor: 'var(--ok)' }
        ],
        months: [['Jan', 9, 8], ['Fév', 11, 9], ['Mar', 8, 8], ['Avr', 13, 10], ['Mai', 10, 9], ['Juin', 12, 11], ['Juil', 14, 12], ['Août', 7, 4]],
        themes: [['Salaires et primes', 26, '31 %'], ['Santé et sécurité', 21, '25 %'], ['Temps de travail', 15, '18 %'], ['Discipline et sanctions', 12, '14 %'], ['Égalité et discriminations', 10, '12 %']],
        rows: [
          { label: 'Réunions CSE', meta: '8 ordinaires, 2 extraordinaires', value: '10' },
          { label: 'Séances de négociation', meta: 'NAO, télétravail, égalité pro', value: '6' },
          { label: 'Sondages diffusés', meta: '72 % de participation moyenne', value: '9' },
          { label: 'Consultations de l\'assistant', meta: '96 % sourcées convention ou code', value: '1 240' },
          { label: 'Heures de délégation', meta: 'sur 1 920 h de crédit annuel', value: '1 412' }
        ]
      },
      rolling: {
        summary: 'Septembre 2025 → août 2026 · glissant · 416 salariés',
        kpis: [
          { label: 'Dossiers traités', value: '112', delta: '+14 % en glissant', deltaColor: 'var(--ok)' },
          { label: 'Dossiers clos', value: '94', delta: '84 % de résolution', deltaColor: 'var(--ok)' },
          { label: 'Délai moyen', value: '10 j', delta: 'stable', deltaColor: 'var(--ink5)' },
          { label: 'Participation sondages', value: '69 %', delta: '+4 pts', deltaColor: 'var(--ok)' }
        ],
        months: [['Sep', 10, 9], ['Oct', 12, 10], ['Nov', 9, 9], ['Déc', 7, 8], ['Jan', 9, 8], ['Fév', 11, 9], ['Mar', 8, 8], ['Avr', 13, 10], ['Mai', 10, 9], ['Juin', 12, 11], ['Juil', 14, 12], ['Août', 7, 4]],
        themes: [['Salaires et primes', 34, '30 %'], ['Santé et sécurité', 28, '25 %'], ['Temps de travail', 20, '18 %'], ['Discipline et sanctions', 17, '15 %'], ['Égalité et discriminations', 13, '12 %']],
        rows: [
          { label: 'Réunions CSE', meta: '12 ordinaires, 3 extraordinaires', value: '15' },
          { label: 'Séances de négociation', meta: 'dont 4 séances NAO', value: '9' },
          { label: 'Sondages diffusés', meta: '69 % de participation moyenne', value: '13' },
          { label: 'Consultations de l\'assistant', meta: 'quota mutualisé à 56 %', value: '1 864' },
          { label: 'Heures de délégation', meta: 'sur 1 920 h de crédit annuel', value: '1 780' }
        ]
      },
      mandat: {
        summary: 'Mandat 2024–2028 · 2 ans et 5 mois écoulés · 3 établissements',
        kpis: [
          { label: 'Dossiers traités', value: '268', delta: 'depuis mars 2024', deltaColor: 'var(--ink5)' },
          { label: 'Dossiers clos', value: '241', delta: '90 % de résolution', deltaColor: 'var(--ok)' },
          { label: 'Délai moyen', value: '11 j', delta: '−5 j depuis 2024', deltaColor: 'var(--ok)' },
          { label: 'Accords signés', value: '7', delta: '2 en cours', deltaColor: 'var(--acTx)' }
        ],
        months: [['T1 24', 18, 15], ['T2 24', 22, 20], ['T3 24', 19, 18], ['T4 24', 24, 22], ['T1 25', 26, 24], ['T2 25', 29, 27], ['T3 25', 25, 24], ['T4 25', 28, 26], ['T1 26', 28, 25], ['T2 26', 35, 30], ['T3 26', 14, 10]],
        themes: [['Salaires et primes', 82, '31 %'], ['Santé et sécurité', 67, '25 %'], ['Temps de travail', 48, '18 %'], ['Discipline et sanctions', 38, '14 %'], ['Égalité et discriminations', 33, '12 %']],
        rows: [
          { label: 'Réunions CSE', meta: 'depuis le début du mandat', value: '29' },
          { label: 'Accords signés', meta: 'télétravail, égalité pro, NAO 2025…', value: '7' },
          { label: 'Sondages diffusés', meta: '71 % de participation moyenne', value: '31' },
          { label: 'Salariés reçus en permanence', meta: 'hors sollicitations informelles', value: '204' },
          { label: 'Élus formés SSCT', meta: 'sur 24 élus au total', value: '11' }
        ]
      }
    };
    const useDefs = {
      year: {
        summary: 'Année 2026 · 24 sièges · 3 établissements',
        kpis: [
          { label: 'Élus actifs', value: '21 / 24', delta: '88 % des sièges', deltaColor: 'var(--ok)' },
          { label: 'Sessions', value: '4 812', delta: '+22 % vs 2025', deltaColor: 'var(--ok)' },
          { label: 'Durée moyenne', value: '9 min', delta: '+1 min', deltaColor: 'var(--ink5)' },
          { label: 'Usage mobile', value: '64 %', delta: '+9 pts', deltaColor: 'var(--ok)' }
        ],
        modules: [['Dossiers', 1560, '+18 %'], ['Assistant IA', 1180, '+41 %'], ['Réunions', 620, '+7 %'], ['Documents', 540, '+12 %'], ['Sondages', 410, '−3 %'], ['Intranet', 290, 'nouveau'], ['Messagerie', 212, '+5 %']],
        weeks: [['S31', 62, 40], ['S32', 55, 34], ['S33', 71, 38], ['S34', 84, 45], ['S35', 78, 41], ['S36', 92, 49], ['S37', 88, 44], ['S38', 96, 52]],
        quota: '1 864 appels sur 3 300 (56 %)',
        ai: [
          { label: 'Requêtes à l\'assistant', meta: 'dont 612 depuis un dossier', value: '1 864' },
          { label: 'Réponses sourcées', meta: 'article ou convention cité', value: '93 %' },
          { label: 'Reformulations de courrier', meta: 'ton combatif dans 38 % des cas', value: '406' },
          { label: 'Temps estimé économisé', meta: 'base 12 min par requête aboutie', value: '312 h' }
        ],
        anon: [['Standard', 51], ['RH (noms + matricules)', 34], ['RPS (masquage maximal)', 15]],
        prod: [
          { label: 'Courriers et tracts générés', meta: '186 diffusés, 74 archivés', value: '260' },
          { label: 'Comptes rendus de réunion', meta: '92 % relus par un pair', value: '48' },
          { label: 'Pages intranet publiées', meta: '9 en attente du webmaster', value: '34' },
          { label: 'Sondages lancés', meta: '69 % de participation moyenne', value: '13' },
          { label: 'Pièces déposées au coffre', meta: '4,2 Go chiffrés', value: '1 042' },
          { label: 'Signatures électroniques', meta: 'toutes horodatées', value: '87' }
        ],
        top: [
          { initials: 'SM', name: 'Sophie Marchand', meta: 'Secrétaire · 46 dossiers, 312 requêtes IA', value: '812 sess.' },
          { initials: 'KB', name: 'Karim Benali', meta: 'Trésorier · 28 dossiers, 141 requêtes IA', value: '504 sess.' },
          { initials: 'LT', name: 'Léa Thibault', meta: 'Référente SSCT · 24 dossiers', value: '431 sess.' },
          { initials: 'MR', name: 'Marc Rossi', meta: 'Communication · 22 pages intranet', value: '388 sess.' },
          { initials: 'AN', name: 'Aline Noury', meta: 'Suppléante · 11 dossiers', value: '196 sess.' }
        ],
        health: [
          { label: 'Synchronisations hors ligne', meta: '2 conflits résolus manuellement', value: '1 284', color: '#111827' },
          { label: 'Taux de synchro réussie', meta: 'sur les 90 derniers jours', value: '99,7 %', color: 'var(--ok)' },
          { label: 'Latence médiane de l\'assistant', meta: 'première ligne de réponse', value: '1,8 s', color: '#111827' },
          { label: 'Incidents déclarés', meta: '1 indisponibilité de 22 min en mai', value: '3', color: 'var(--acTx)' },
          { label: 'Connexions bloquées (MFA)', meta: 'aucune compromission constatée', value: '6', color: 'var(--acTx)' }
        ]
      }
    };
    useDefs.rolling = Object.assign({}, useDefs.year, {
      summary: '12 derniers mois · septembre 2025 à août 2026',
      kpis: [
        { label: 'Élus actifs', value: '22 / 24', delta: '92 % des sièges', deltaColor: 'var(--ok)' },
        { label: 'Sessions', value: '6 940', delta: '+19 % en glissant', deltaColor: 'var(--ok)' },
        { label: 'Durée moyenne', value: '9 min', delta: 'stable', deltaColor: 'var(--ink5)' },
        { label: 'Usage mobile', value: '61 %', delta: '+6 pts', deltaColor: 'var(--ok)' }
      ],
      quota: '2 640 appels sur 4 800 (55 %)'
    });
    useDefs.mandat = Object.assign({}, useDefs.year, {
      summary: 'Mandat 2024–2028 · 2 ans et 5 mois écoulés',
      kpis: [
        { label: 'Élus actifs', value: '24 / 24', delta: 'tous connectés au moins 1 fois', deltaColor: 'var(--ok)' },
        { label: 'Sessions', value: '16 380', delta: 'depuis mars 2024', deltaColor: 'var(--ink5)' },
        { label: 'Durée moyenne', value: '8 min', delta: '−1 min depuis 2024', deltaColor: 'var(--ok)' },
        { label: 'Usage mobile', value: '58 %', delta: '+21 pts', deltaColor: 'var(--ok)' }
      ],
      quota: '5 910 appels depuis l\'ouverture'
    });
    const useRaw = useDefs[this.state.repPeriod] || useDefs.year;
    const useModMax = Math.max.apply(null, useRaw.modules.map((m) => m[1]));
    const useWeekMax = Math.max.apply(null, useRaw.weeks.map((w) => Math.max(w[1], w[2])));
    const useAnonTot = useRaw.anon.reduce(function (t, a) { return t + a[1]; }, 0);
    const use = {
      summary: useRaw.summary, kpis: useRaw.kpis, quota: useRaw.quota,
      ai: useRaw.ai, prod: useRaw.prod, top: useRaw.top, health: useRaw.health,
      modules: useRaw.modules.map((m) => ({
        label: m[0], value: m[1].toLocaleString('fr-FR'), trend: m[2],
        trendColor: m[2].indexOf('−') === 0 ? 'var(--ac2)' : (m[2] === 'nouveau' ? 'var(--pri)' : 'var(--ok)'),
        width: Math.round((m[1] / useModMax) * 100) + '%'
      })),
      weeks: useRaw.weeks.map((w) => ({
        label: w[0], mobH: Math.round((w[1] / useWeekMax) * 100) + '%', deskH: Math.round((w[2] / useWeekMax) * 100) + '%'
      })),
      anon: useRaw.anon.map((a) => ({ label: a[0], value: a[1] + ' %', width: Math.round((a[1] / useAnonTot) * 100) + '%' }))
    };
    const repRaw = repDefs[this.state.repPeriod] || repDefs.year;
    const repMax = Math.max.apply(null, repRaw.months.map((m) => Math.max(m[1], m[2])));
    const repThemeMax = Math.max.apply(null, repRaw.themes.map((t) => t[1]));
    const rep = {
      summary: repRaw.summary, kpis: repRaw.kpis, rows: repRaw.rows,
      months: repRaw.months.map((m) => ({ label: m[0], openH: Math.round((m[1] / repMax) * 100) + '%', doneH: Math.round((m[2] / repMax) * 100) + '%' })),
      themes: repRaw.themes.map((t) => ({ label: t[0], value: t[1] + ' dossiers · ' + t[2], width: Math.round((t[1] / repThemeMax) * 100) + '%' }))
    };
    const q = this.state.query.trim().toLowerCase();
    const searchPool = this.state.dossiers.map((x) => ({ kind: 'Dossier', title: x.title, meta: x.tag + ' · ' + statusLabels[x.status], go: () => this.go('dossier', { dossierId: x.id }) }))
      .concat(allPolls.map((p) => ({ kind: 'Sondage', title: p.title, meta: p.status + ' · ' + p.participation, go: () => this.go('sondage', { pollId: p.id }) })))
      .concat(this.state.docs.map((x) => ({ kind: 'Document', title: x.title, meta: x.status || '', go: () => this.openDoc(x.id) })))
      .concat((this.state.aiConvs || []).map((x) => ({ kind: 'Réponse IA', title: x.title || '', meta: x.origin || 'Assistant', go: () => { this.convOpen(x.id); this.go('assistant'); } })))
      .concat([
        { kind: 'Document', title: 'Convention collective Métallurgie 2026', meta: 'Base documentaire · hors ligne', go: () => this.openViewer('doc', 'cc') },
        { kind: 'Document', title: 'Accord télétravail 2024', meta: 'Base documentaire · PDF', go: () => this.openViewer('doc', 'tt') },
        { kind: 'Document', title: 'PV réunion CSE — juillet 2026', meta: 'Base documentaire · adopté', go: () => this.openViewer('doc', 'pv') },
        { kind: 'Document', title: 'Règlement intérieur du CSE', meta: 'Base documentaire · version 2', go: () => this.openViewer('doc', 'reg') },
        { kind: 'Document', title: 'Code du travail — extraits CSE', meta: 'Base documentaire · Légifrance', go: () => this.openViewer('doc', 'cdt') },
        { kind: 'Réponse IA', title: 'Obligations en cas de signalement de harcèlement', meta: 'Assistant · 22 août', go: () => this.ask("Quelles sont mes obligations en cas de signalement de harcèlement ?") }
      ]);
    const results = q ? searchPool.filter((x) => (x.title + ' ' + x.kind + ' ' + x.meta).toLowerCase().indexOf(q) > -1) : searchPool.slice(0, 5);

    const notifs = [
      { id: 'n1', title: 'Accident Atelier B — accusé de réception attendu', body: 'Escalade automatique dans 3 h si aucun élu ne prend le dossier.', time: '10 min', urgent: true, go: () => this.go('dossier', { dossierId: 'accident' }) },
      { id: 'n2', title: 'Sondage NAO : 75 % de participation', body: '312 réponses sur 416 salariés.', time: '1 h', urgent: false, go: () => this.go('sondage', { pollId: 'nao' }) },
      { id: 'n3', title: 'Échéance légale — dossier inaptitude', body: 'Réponse de la DRH attendue sous 3 jours.', time: 'hier', urgent: false, go: () => this.go('dossier', { dossierId: 'inaptitude' }) },
      { id: 'n4', title: 'Nouvelle version de la convention collective', body: 'Avenant salaires de branche intégré à la base documentaire.', time: '2 j', urgent: false, go: () => this.openViewer('doc', 'cc') }
    ];

    const sigDoc = (this.state.sigSnapshot && this.state.sigSnapshot.id === this.state.sig.docId ? this.state.sigSnapshot : null) || SIGDOCS.find((x) => x.id === this.state.sig.docId) || SIGDOCS[0];
    const sigDone = this.state.signed[this.state.sig.docId] || null;

    const sourcing = sw(f.sourcing);
    const visible = sw(f.visible);

    return Object.assign(this.webVals(), {
      profileDataText:"Cette maquette conserve vos saisies (dossiers, "+this.W().memberMany+", événements, identité de marque) dans le navigateur, sur cet appareil uniquement. Rien n'est envoyé à un serveur.",profileSessionText:'Ouverte depuis iPhone 15 — Valenciennes. La déconnexion purge le cache local chiffré.',userInitials:'SM',userRole:'Déléguée syndicale',profileRole:'Déléguée syndicale · Secrétaire de section',
      userName: this.props.userName ?? 'Sophie Marchand',
      orgName: this.state.org.nom || (this.props.orgName ?? 'CSE Métallurgie — Site de Valenciennes'),
      showAiDisclaimer: this.props.showAiDisclaimer ?? true,
      goIaSecu: () => this.go('iasecu'),
      isDesktop: this.state.isDesktop,
      isMobile: !this.state.isDesktop,
      showBack: this.state.history.length > 0,
      goBack: () => this.back(),
      toast: this.state.toast,
      hasToast: !!this.state.toast,
      dismissToast: () => { clearTimeout(this.t3); this.setState({ toast: '' }); },
      resetDemo: () => this.resetDemo(),

      isAccueil: r === 'accueil', isDossiers: r === 'dossiers', isDossier: r === 'dossier', isNouveau: r === 'nouveau',
      isAssistant: r === 'assistant', isSondages: r === 'sondages', isSondage: r === 'sondage', isTract: r === 'tract',
      isDocs: r === 'documents', isDocEdit: r === 'docedit',
      isAgenda: r === 'agenda',
      isRaccourcis: r === 'raccourcis', sc: this.scVals(),
      ag: this.agVals(),
      isReunions: r === 'reunions', isRecord: r === 'record', isReunion: r === 'reunion',

      reunionsSummary: this.state.reunions.length + ' séances au registre · ' + this.state.reunions.filter(function (x) { return x.pv !== 'Approuvé'; }).length + ' PV en cours, ' + this.state.reunions.filter(function (x) { return x.audio === 'kept'; }).length + ' enregistrements référencés',
      reunionsCount: this.state.reunions.length + ' séance' + (this.state.reunions.length > 1 ? 's' : ''),
      goRecord: () => this.go('record'),
      backToReunions: () => { this.releaseMic(); this.go('reunions'); },
      reunionList: this.state.reunions.map((x) => {
        const at = audioTxt(x);
        return {
          type: x.type, date: x.date, dur: x.dur, title: x.title, pv: x.pv,
          audioLabel: at.label, audioFg: at.fg,
          pillBg: (pvPill[x.pv] || pvPill['À rédiger'])[0], pillFg: (pvPill[x.pv] || pvPill['À rédiger'])[1],
          open: () => this.go('reunion', { reunionId: x.id })
        };
      }),

      noImport: !imp,
      hasImport: !!imp,
      importName: imp ? imp.name : '',
      importSize: imp ? imp.size : '',
      importDone: !!(imp && imp.done),
      importSteps: impSteps.map(function (s) {
        const done = imp && imp.step >= s.n && s.n !== 3;
        return { label: s.label, mark: done ? '✓' : s.n, fg: done ? 'var(--okTx)' : 'var(--ink5)', dotBg: done ? 'var(--okChip)' : 'var(--bd2)', dotFg: done ? 'var(--okTx)' : 'var(--ink5)' };
      }),
      onAudioFile: (e) => { const f = e.target.files && e.target.files[0]; this.importAudioFile(f); },
      confirmImportBtn: () => this.confirmImport(),
      cancelImport: () => { clearInterval(this.impTimer); this._audioImportFile = null; this.setState({ audioImport: null }); },

      recConsent: rc.phase === 'consent',
      recAsking: rc.phase === 'asking',
      recSimNow: () => this.forceSimulated(),
      recCancelAsk: () => { this.recAborted = true; clearTimeout(this.askTimer); this.releaseMic(); this.recPatch({ phase: 'consent' }); },
      recActive: rc.phase === 'live' || rc.phase === 'paused' || rc.phase === 'done',
      recRunning: rc.phase === 'live',
      recPaused: rc.phase === 'paused',
      recStoppable: rc.phase === 'live' || rc.phase === 'paused',
      recDone: rc.phase === 'done',
      recMarkable: rc.phase === 'live' || rc.phase === 'paused',
      recErr: rc.err,
      recType: rc.type + (rc.sim ? ' · simulé' : ''),
      recClock: this.clock(rc.t),
      recBars: recBars,
      recDot: rc.phase === 'live' ? 'var(--danger)' : (rc.phase === 'paused' ? 'var(--acMid)' : '#86EFAC'),
      recDotAnim: rc.phase === 'live' ? 'pulseDot 1s infinite' : 'none',
      recStateLabel: rc.phase === 'live' ? 'Enregistrement en cours' : (rc.phase === 'paused' ? 'En pause' : 'Enregistrement terminé'),
      recTypes: REUNION_TYPES.map((t) => {
        const on = rc.type === t;
        return { label: t, on: on, ring: on ? 'var(--ac)' : 'var(--bd2)', bg: on ? 'var(--acBg)' : '#FFFFFF', fg: on ? 'var(--acTx2)' : 'var(--ink4)', go: () => this.recPatch({ type: t }) };
      }),
      recChecks: [
        { k: 'c1', label: 'Les personnes présentes ont été informées de l\'enregistrement', hint: 'À annoncer en ouverture de séance, avant le premier mot consigné.' },
        { k: 'c2', label: 'La séance ne s\'y est pas opposée', hint: 'Un refus, même d\'une seule personne, interdit l\'enregistrement — prise de notes uniquement.' }
      ].map((c) => {
        const on = !!rc[c.k];
        return {
          label: c.label, hint: c.hint, on: on, mark: on ? '✓' : '',
          bg: on ? 'var(--okBg)' : 'var(--surf2)', border: on ? 'var(--okBd2)' : 'var(--chip)',
          boxBorder: on ? 'var(--ok)' : 'var(--bd2)', boxBg: on ? 'var(--ok)' : '#FFFFFF',
          toggle: () => this.recPatch({ [c.k]: !on })
        };
      }),
      recPolicy: [
        { text: 'Le fichier reste dans ce navigateur, sans chiffrement applicatif ni téléversement audio.' },
        { text: 'La transcription audio et l’extraction automatique ne sont pas connectées.' },
        { text: 'La destruction automatique et sa certification restent à connecter.' },
        { text: 'Chaque écoute est inscrite au journal d\'accès, consultable par les élus.' }
      ],
      recBlocked: !(rc.c1 && rc.c2),
      recCursor: rc.c1 && rc.c2 ? 'pointer' : 'not-allowed',
      recBtnBg: rc.c1 && rc.c2 ? 'var(--ac2)' : 'var(--bd2)',
      recBtnFg: rc.c1 && rc.c2 ? '#FFFFFF' : 'var(--ink6)',
      recBtnLabel: rc.c1 && rc.c2 ? 'Ouvrir le micro et enregistrer' : 'Confirmez les deux points ci-dessus',
      startRec: () => { if (rc.c1 && rc.c2) this.startRecording(); },
      pauseRec: () => this.pauseRecording(),
      resumeRec: () => this.resumeRecording(),
      stopRec: () => this.stopRecording(),
      saveRec: () => this.saveRecording(),
      discardRec: () => this.discardRecording(),
      markerBtns: MARKER_DEFS.map((m) => ({
        label: m.label, aria: 'Poser un marqueur ' + m.label,
        bg: m.bg, fg: m.color, border: m.bg === 'var(--chip)' ? 'var(--bd2)' : m.bg,
        go: () => this.addMarker(m.id)
      })),
      recMarkCount: rc.markers.length + ' marqueur' + (rc.markers.length > 1 ? 's' : ''),
      recHasMarks: rc.markers.length > 0,
      recNoMarks: rc.markers.length === 0,
      recMarks: rc.markers.slice().reverse().map((m) => {
        const def = markerOf(m.kind);
        return { time: this.clock(m.t), label: def.label, fg: def.color, bg: def.bg };
      }),

      reu: {
        type: reu0.type, title: reu0.title, date: reu0.date, dur: reu0.dur, pv: reu0.pv,
        toAsst: () => this.toAssistant({ origin: 'Réunions', route: 'reunion', params: { reunionId: reu0.id }, title: reu0.type + ' — ' + reu0.title, ctx: 'Séance : ' + reu0.type + ' · ' + reu0.title + ' · ' + reu0.date + ' · ' + reu0.dur + '\nOrdre du jour :\n' + ((reu0.ordre || []).join('\n') || 'non renseigné') + '\nMarqueurs :\n' + reu0.markers.map((m) => this.clock(m.t) + ' · ' + m.kind + ' : ' + m.note).join('\n') }),
        markCount: reu0.markers.length,
        hasAudio: reu0.audio === 'kept',
        isDestroyed: reu0.audio === 'destroyed',
        audioShort: audioTxt(reu0).short,
        audioFg: audioTxt(reu0).fg,
        hasOrdre: reu0.ordre.length > 0,
        ordre: reu0.ordre.map(function (o, i) { return { n: (i + 1) + '.', text: o }; }),
        retentionBadge: 'Conservation locale',
        retentionText: 'L’enregistrement est conservé dans ce navigateur. Aucune échéance de destruction automatique n’est actuellement appliquée.',
        retentionPct: Math.max(4, Math.min(100, Math.round((reu0.retention / 30) * 100))) + '%',
        destroyedWhen: reu0.destroyed ? reu0.destroyed.when : '',
        proofs: reu0.destroyed ? [
          { label: 'Certificat de destruction horodaté', detail: reu0.destroyed.cert + ' — PDF signé, opposable en cas de contestation' },
          { label: 'Empreinte SHA-256 de l\'audio détruit', detail: reu0.destroyed.hash },
          { label: 'Écriture au registre RGPD', detail: 'Traitement « enregistrement de séance » — suppression consignée automatiquement' },
          { label: 'Notification aux participants', detail: '9 personnes informées de la destruction le lendemain de l\'approbation' },
          { label: 'Journal d\'accès figé', detail: reu0.access.length + ' écoute(s) consignée(s) avant destruction' }
        ] : [],
        hasMarkers: reu0.markers.length > 0,
        noMarkers: reu0.markers.length === 0,
        markers: reu0.markers.map((m) => {
          const def = markerOf(m.kind);
          return {
            time: this.clock(m.t), note: m.note, label: def.label, fg: def.color, bg: def.bg,
            go: () => reu0.audio === 'destroyed' ? this.flash('Audio détruit — seule la citation du PV subsiste') : this.listenAudio(reu0,m.t)
          };
        }),
        hasAccess: reu0.access.length > 0,
        access: reu0.access.slice(),
        extractState: reu0.audio === 'destroyed'
          ? 'Extraction terminée et versée au PV approuvé. La transcription a été détruite avec l\'audio.'
          : 'Transcription non connectée. Les marqueurs peuvent servir à préparer le PV ; le contenu audio n’est pas analysé.',
        pvCta: reu0.pvDoc ? 'Ouvrir le PV' : (reu0.pv === 'Approuvé' ? 'Consulter le PV archivé' : 'Rédiger le PV depuis les marqueurs'),
        writePv: () => {
          if (reu0.pvDoc) { this.openDoc(reu0.pvDoc); return; }
          this.pvFromReunion(reu0);
        },
        listen: () => this.listenAudio(reu0),
        cert: () => this.flash('Aucun certificat réel disponible pour cette réunion de démonstration')
      },
      extractFamilies: [
        { text: 'Décisions — objet, sens de la décision, base juridique invoquée' },
        { text: 'Votes — pour, contre, abstention, résultat et quorum' },
        { text: 'Engagements — qui, quoi, échéance, poussés en dossiers suivis' },
        { text: 'Points en suspens — renvoyés à l\'ordre du jour de la séance suivante' }
      ],


      docsSummary: this.state.docs.length + ' documents dans l\'espace de la section · charte ' + chr.emetteur + ' appliquée automatiquement',
      docCountLabel: this.state.docs.length + ' document' + (this.state.docs.length > 1 ? 's' : ''),
      docModels: DOC_MODELS.map((m) => ({
        label: m.label, desc: m.desc, meta: m.meta,
        d: ICONS[m.ic][0], d2: ICONS[m.ic][1],
        create: () => this.createFromModel(m.id)
      })),
      docList: this.state.docs.map((x) => ({
        title: x.title,
        meta: (DOC_FORMATS[x.format] || DOC_FORMATS.a4).label + ' · ' + this.modelOf(x.model).label + ' · modifié ' + x.updated,
        status: x.status,
        pillBg: (statusPill[x.status] || statusPill.Brouillon)[0],
        pillFg: (statusPill[x.status] || statusPill.Brouillon)[1],
        accent: ac,
        open: () => this.openDoc(x.id),
        del: this.askDel('doc-' + x.id, 'Supprimer', () => {
          this.setState((s) => {
            const rest = s.docs.filter((y) => y.id !== x.id);
            return { docs: rest, docId: s.docId === x.id ? (rest[0] || {}).id || '' : s.docId, docSrcDraft: null };
          });
          this.flash('Document supprimé — récupérable 30 jours dans la corbeille');
        })
      })),
      goAiDoc: () => { this.setState({ tract: 'empty' }); this.go('tract'); },

      mobileHistory: !!this.state.mobileHistory,
      toggleMobileHistory: () => this.setState({ mobileHistory: !this.state.mobileHistory }),
      mobileTools: !!this.state.mobileTools,
      toggleMobileTools: () => this.setState({ mobileTools: !this.state.mobileTools }),
      mobileFilters: !!this.state.mobileFilters,
      toggleMobileFilters: () => this.setState({ mobileFilters: !this.state.mobileFilters }),
      mobileAdmin: !!this.state.mobileAdmin,
      toggleMobileAdmin: () => this.setState({ mobileAdmin: !this.state.mobileAdmin }),
      mobilePreview: !!this.state.mobilePreview,
      mobileDocEditing: !this.state.mobilePreview,
      mobileDocEdit: () => this.setState({ mobilePreview: false }),
      mobileDocPreview: () => this.setState({ mobilePreview: true }),
      mobileDocFit: () => { if (!this.state.isDesktop) return this.setState({ mobileZoomManual: false }); const width = document.getElementById('docPrint')?.clientWidth; if (width > 0) this.setState({ docZoom: Math.min(1, Math.max(.1, (width - 2) / dfmt.w)) }); },
      mobileNav: navOrdered.concat([{ id: 'sondages', label: 'Sondages' }, { id: 'offline', label: 'Hors ligne' }]).map((n) => ({ label: n.label, go: () => { document.querySelectorAll('.mobile-menu[open]').forEach((el) => el.removeAttribute('open')); this.go(n.id); } })),
      docTitle: cdoc.title,
      onDocTitle: (e) => this.patchDoc({ title: e.target.value }),
      backToDocs: () => this.go('documents'),
      docCols: this.state.isDesktop ? 'minmax(320px, 400px) minmax(0, 1fr)' : 'minmax(0, 1fr)',
      docPrint: () => {
        this.syncPageSize(cdoc.format);
        this.flash('Aperçu avant impression — ' + dpages.length + ' page' + (dpages.length > 1 ? 's' : '') + ' au format ' + dfmt.label);
        if (typeof window !== 'undefined') setTimeout(function () { window.print(); }, 500);
      },
      docSign: () => this.signDocument(cdoc),
      docDiffuse: () => { this.patchDoc({ status: 'Diffusé' }); this.openSheet('diffuse'); },

      docTabs: [{ id: 'contenu', label: 'Contenu' }, { id: 'charte', label: 'Charte graphique' }].concat(this.extItems('docStyles').length ? [{ id: 'style', label: 'Style' }] : []).map((t) => {
        const on = this.state.docTab === t.id;
        return { label: t.label, on: on, bg: on ? '#FFFFFF' : 'transparent', fg: on ? '#111827' : 'var(--ink5)', sh: on ? '0 1px 3px hsl(var(--shC) / .12)' : 'none', go: () => this.setState({ docTab: t.id }) };
      }),
      docTabContent: this.state.docTab === 'contenu' || (this.state.docTab === 'style' && !this.extItems('docStyles').length),
      docTabStyle: this.state.docTab === 'style' && this.extItems('docStyles').length > 0,
      dsx: this.extDocStyleVals(cdoc, dfmt, chr),
      docTabCharte: this.state.docTab === 'charte',

      docModes: [{ id: 'blocks', label: 'Blocs' }, { id: 'source', label: 'Markdown' }].map((m) => {
        const on = this.state.docMode === m.id;
        return {
          label: m.label, on: on, bg: on ? '#111827' : 'transparent', fg: on ? '#FFFFFF' : 'var(--ink5)',
          go: () => this.setState({ docMode: m.id, docSrcDraft: null })
        };
      }),
      docModeBlocks: this.state.docMode === 'blocks',
      docModeSource: this.state.docMode === 'source',
      docSource: docSrc,
      onDocSource: (e) => {
        const v = e.target.value;
        this.setState({ docSrcDraft: v });
        const nb = this.mdToBlocks(v);
        const keep = {};
        this.curDoc().blocks.forEach((x) => { if (x.img) (keep[x.type] = keep[x.type] || []).push(x.img); });
        if (Object.keys(keep).length) nb.forEach((x) => { const q = keep[x.type]; if (q && q.length) x.img = q.shift(); });
        this.patchDoc({ blocks: nb });
      },

      blockInserts: ['h1', 'h2', 'p', 'ul', 'quote', 'table', 'tag', 'pagebreak'].map((t) => ({
        label: BLOCK_DEFS[t].label === 'Saut de page' ? 'Saut de page' : BLOCK_DEFS[t].label.replace('Badge de rubrique', 'Badge'),
        aria: 'Ajouter un bloc ' + BLOCK_DEFS[t].label.toLowerCase(),
        add: () => this.addBlock(t)
      })).concat(this.extItems('docBlocks').map((d) => ({ label: d.label, aria: 'Ajouter un bloc ' + String(d.label).toLowerCase(), add: () => this.addBlock(d.type) }))),
      docBlocks: cdoc.blocks.map((b, i) => {
        const def = BLOCK_DEFS[b.type] || this.extDocBlock(b.type) || (CORE_DOC_TYPES.indexOf(b.type) < 0 ? Object.assign({}, BLOCK_DEFS.p, { label: 'Bloc « ' + b.type + ' » (extension inactive)', hint: 'Affiché comme un paragraphe tant que l\'extension est désactivée. Le contenu est conservé.' }) : BLOCK_DEFS.p);
        const isBreak = b.type === 'pagebreak';
        return {
          id: b.id, typeLabel: def.label, text: b.text, ph: def.ph, rows: def.rows,
          aria: def.label + ', bloc ' + (i + 1) + ' sur ' + cdoc.blocks.length,
          hint: def.hint || '', editable: !isBreak, isBreak: isBreak,
          border: isBreak ? 'var(--bd2)' : 'var(--chip)', bg: isBreak ? 'var(--surf2)' : '#FFFFFF',
          labelFg: isBreak ? 'var(--ink5)' : 'var(--acTx2)',
          onText: (e) => {
            const v = e.target.value;
            this.setBlocks(cdoc.blocks.map((x) => (x.id === b.id ? Object.assign({}, x, { text: v }) : x)));
          },
          up: () => this.moveBlock(b.id, -1),
          down: () => this.moveBlock(b.id, 1),
          del: () => this.setBlocks(cdoc.blocks.filter((x) => x.id !== b.id)),
          canImg: !!(this.extDocBlock(b.type) || {}).accepts,
          hasImg: !!b.img, imgBg: b.img ? 'url("' + b.img + '") center / cover' : 'none',
          imgLabel: b.img ? 'Changer l\'image' : 'Déposer une image',
          onImg: (e) => this.extReadImage(e, (src) => this.setBlocks(this.curDoc().blocks.map((x) => (x.id === b.id ? Object.assign({}, x, { img: src }) : x)))),
          delImg: () => this.setBlocks(cdoc.blocks.map((x) => { if (x.id !== b.id) return x; const y = Object.assign({}, x); delete y.img; return y; }))
        };
      }),

      charteAccent: chr.accent,
      onAccentHex: (e) => this.charteSet({ accent: e.target.value }),
      accentSwatches: ['#DC2626', '#EA580C', '#B91C1C', '#1D4ED8', '#15803D', '#111827'].map((hex) => {
        const on = chr.accent.toUpperCase() === hex;
        return { hex: hex, on: on, aria: 'Couleur d\'accent ' + hex, ring: on ? '#111827' : 'transparent', sh: on ? '0 0 0 2px #FFFFFF inset' : 'none', go: () => this.charteSet({ accent: hex }) };
      }),
      inkSwatches: [{ hex: '#111827', label: 'Noir encre' }, { hex: '#1F2937', label: 'Gris ardoise' }, { hex: '#312E29', label: 'Brun chaud' }].map((s) => {
        const on = chr.ink === s.hex;
        return { hex: s.hex, label: s.label, on: on, aria: 'Couleur du texte : ' + s.label, ring: on ? 'var(--ac)' : 'var(--bd2)', go: () => this.charteSet({ ink: s.hex }) };
      }),
      fontOptions: Object.keys(DOC_FONTS).map((id) => ({ id: id, label: DOC_FONTS[id].label })),
      charteTitleFont: chr.titleFont,
      charteBodyFont: chr.bodyFont,
      onTitleFont: (e) => this.charteSet({ titleFont: e.target.value }),
      onBodyFont: (e) => this.charteSet({ bodyFont: e.target.value }),
      densityOpts: [{ id: 'compact', label: 'Compact' }, { id: 'standard', label: 'Standard' }, { id: 'confort', label: 'Confort' }].map((o) => {
        const on = chr.density === o.id;
        return { label: o.label, on: on, ring: on ? 'var(--ac)' : 'var(--bd2)', bg: on ? 'var(--acBg)' : '#FFFFFF', fg: on ? 'var(--acTx2)' : 'var(--ink4)', go: () => this.charteSet({ density: o.id }) };
      }),
      charteLogo: chr.logo,
      charteLogoSt: { display: 'block', width: '80px', height: '40px', backgroundImage: chr.logo ? 'url("' + chr.logo + '")' : 'none', backgroundSize: 'contain', backgroundRepeat: 'no-repeat', backgroundPosition: 'center' },
      charteHasLogo: !!chr.logo,
      charteNoLogo: !chr.logo,
      docLogoStorageHint: 'PNG ou SVG, fond transparent de préférence. Le fichier reste sur l’appareil.',
      docsLogoCta: chr.logo ? 'Remplacer' : 'Choisir un logo',
      docsLogoHint: chr.logo
        ? 'Repris dans l\'en-tête de tous les documents créés : courriers, tracts, comptes rendus, bulletins. Modifiable document par document dans l\'onglet Charte graphique.'
        : 'PNG ou SVG à fond transparent. Une fois choisi, il apparaît dans l\'en-tête de tous les documents créés.',
      canUseBrandLogo: (() => { const b = this.activeBrand(); const l = b.logoLight || ''; return !!l && l !== chr.logo; })(),
      useBrandLogo: () => {
        const l = this.activeBrand().logoLight;
        if (!l) return this.flash('Aucun logo d\'identité de marque défini');
        this.charteSet({ logo: l });
        this.flash('Logo de la marque appliqué à tous les documents');
      },
      clearLogo: () => this.charteSet({ logo: '' }),
      onLogoFile: (e) => {
        const inp = e.target;
        const file = inp.files && inp.files[0];
        if (!file) return;
        if (!/^image\//.test(file.type)) { inp.value = ''; return this.flash('Format non reconnu — PNG, SVG ou JPEG attendu'); }
        if (file.size > 2 * 1024 * 1024) { inp.value = ''; return this.flash('Fichier trop lourd — 2 Mo maximum'); }
        const rd = new FileReader();
        rd.onload = () => { this.charteSet({ logo: rd.result }); this.flash('Logo importé — appliqué à tous les documents'); };
        rd.onerror = () => this.flash('Lecture du fichier impossible');
        rd.readAsDataURL(file);
        inp.value = '';
      },
      charteSwitches: [
        { key: 'header', label: 'Afficher l\'en-tête' },
        { key: 'footer', label: 'Afficher le pied de page' },
        { key: 'caps', label: 'Titres en majuscules' }
      ].map((s) => {
        const on = !!chr[s.key];
        const t = () => this.charteSet({ [s.key]: !on });
        return {
          label: s.label, on: on, bg: on ? ac : 'var(--bd2)', left: on ? '22px' : '3px', toggle: t,
          key: (ev) => { if (ev.key === ' ' || ev.key === 'Enter') { ev.preventDefault(); t(); } }
        };
      }),
      charteIdentOverride: !!(this.state.charte || {}).emetteurOverride,
      charteResetIdent: () => this.charteResetIdent(),
      charteFields: [
        { key: 'emetteur', label: 'Nom de l\'émetteur' },
        { key: 'section', label: 'Section / établissement' },
        { key: 'email', label: 'Email de contact' },
        { key: 'phone', label: 'Téléphone' }
      ].map((f) => ({ label: f.label, value: chr[f.key], onChange: (e) => this.charteSet({ [f.key]: e.target.value }) })),

      formatOpts: ['a4', 'wide', 'a5'].map((id) => {
        const on = cdoc.format === id;
        return { label: DOC_FORMATS[id].label, on: on, bg: on ? '#111827' : 'transparent', fg: on ? '#FFFFFF' : 'var(--ink4)', go: () => { this.patchDoc({ format: id }); this.syncPageSize(id); } };
      }),
      zoomOpts: [{ v: .5, label: '50 %' }, { v: .72, label: '72 %' }, { v: 1, label: '100 %' }].map((o) => {
        const on = Math.abs(dz - o.v) < .01;
        return { label: o.label, on: on, aria: 'Zoom ' + o.label, bg: on ? 'var(--acBg)' : 'transparent', fg: on ? 'var(--acTx2)' : 'var(--ink5)', go: () => this.setState(this.state.isDesktop ? { docZoom: o.v } : { mobileDocZoom: o.v, mobileZoomManual: true }) };
      }),
      pageCountLabel: dpages.length + (dpages.length > 1 ? ' pages' : ' page') + ' · ' + dfmt.label,
      docPages: dpages,
      docOverflow: overflowPage > 0,
      overflowMsg: 'Le contenu de la page ' + overflowPage + ' dépasse la hauteur imprimable. Ajoutez un saut de page ou passez la densité en « compact ».',

      adh: this.adhVals(),
      isExtensions: r === 'extensions', ext: r === 'extensions' ? this.extVals() : { list: [], sources: [], orphan: [], testRes: [] }, isNotifs: r === 'notifs', isSearch: r === 'recherche', isParams: r === 'params', isProfil: r === 'profil',
      isPrefs: r === 'prefs', isSecurite: r === 'securite', isIaSecu: r === 'iasecu',
      iaSecu: this.iaSecuVals(), isRgpd: r === 'rgpd', isMembres: r === 'membres', isApikey: r === 'apikey', isMemoire: r === 'memoire', mem: this.memVals(),
      isMessagerie: r === 'messagerie', isThread: r === 'thread', isOffline: r === 'offline', isOnboarding: r === 'onboarding', isAdmin: r === 'admin', isSignature: r === 'signature', isContacts: r === 'contacts', isFormations: r === 'formations', isCommunication: r === 'communication', com: this.comVals(), isMobApp: r === 'mobile', mob: this.mobVals(), isUniiCfg: r === 'unii', unii: this.uniiVals(activeTab, r), fm: r === 'formations' ? this.fmVals() : { tabs: [], iaTypes: [], iaSections: [], parcours: [], formats: [], genCats: [], genModes: [], gen: [], how: [], sessions: [], setup: { sugg: [], durs: [], levels: [], roles: [] }, s: { plan: [], m: { points: [], choices: [] }, retenir: [], chat: [], del: {} } },
      ctp: this.ctpVals(), ctm: this.ctmVals(), grm: this.grmVals(), fwm: this.fwmVals(), dpm: this.dpmVals(),
      sbFull: !this.state.navMini, sbMini: !!this.state.navMini, sbW: this.state.navMini ? '78px' : '264px', sbPad: this.state.navMini ? '22px 12px' : '24px 18px',
      sbJust: this.state.navMini ? 'center' : 'flex-start', sbItemPad: this.state.navMini ? '11px' : '11px 14px',
      sbToggle: () => this.setState((s) => ({ navMini: !s.navMini })), mainMaxW: this.state.navMini ? '1680px' : '1180px',

      wa: this.waVals(),
      convo: this.convoVals(),
      th: this.thVals(),
      messageAck: '✓✓', messagingFooter: 'Messagerie locale de démonstration',
      msgDraft: this.state.msgDraft,
      onMsg: (e) => this.setState({ msgDraft: e.target.value }),
      onMsgKey: (e) => { if (e.key === 'Enter') this.sendMsgNow(); },
      sendMsg: () => this.sendMsgNow(),
      attach: () => {
        const id = 'p' + Date.now();
        const item = { id: id, name: 'Capture conversation ' + new Date().toLocaleDateString('fr-FR') + '.pdf', ext: 'PDF', size: '86 Ko', by: 'Sophie M.', date: "aujourd'hui", v: 1, note: 'Export du fil de discussion joint au dossier, chiffré avant envoi.' };
        this.setState((s) => {
          const map = Object.assign({}, s.pieces);
          map[d.id] = [item].concat(map[d.id] || []);
          return { pieces: map, pieceId: id };
        });
        this.go('pieces');
        this.flash('Pièce chiffrée et jointe au dossier « ' + d.title + ' »');
      },

      notAuthed: !this.state.authed && !this.state.adminAuthed,
      authed: this.state.authed && !this.state.adminAuthed,
      adminAuthed: this.state.adminAuthed,
      adm: this.admVals(),
      plan: this.planVals(),
      authIsAdmin: !this.state.authed && !!this.state.auth.admin,
      authAdminShortcut: () => this.setAuth({ email: 'admin@uniion.fr', pwd: '', err: '', step: 'id', admin: true }),
      authStepId: !this.state.authed && !this.state.adminAuthed && this.state.auth.step === 'id',
      authStepSso: !this.state.authed && this.state.auth.step === 'sso',
      authStepMfa: !this.state.authed && !this.state.adminAuthed && this.state.auth.step === 'mfa',
      authEmail: this.state.auth.email,
      authPwd: this.state.auth.pwd,
      authCode: this.state.auth.code,
      authErr: this.state.auth.err,
      authHasErr: !!this.state.auth.err,
      authDemoCode: '402913', authCodeHelp: 'Démonstration : le code valide est 402913.',
      authMfaHint: this.state.auth.sso
        ? 'Annuaire fédération authentifié. Confirmez avec le code de votre application d\'authentification.'
        : 'Code à 6 chiffres envoyé sur iPhone 15 — Sophie (application uniion).',
      authCells: Array.from({ length: 6 }, (_, i) => {
        const ch = this.state.auth.code.charAt(i);
        return { char: ch || '', bg: ch ? 'var(--acBg)' : 'var(--surf2)', border: ch ? 'var(--acMid)' : 'var(--chip)' };
      }),
      onAuthEmail: (e) => this.setAuth({ email: e.target.value, err: '' }),
      onAuthPwd: (e) => this.setAuth({ pwd: e.target.value, err: '' }),
      onAuthKey: (e) => { if (e.key === 'Enter') this.submitId(); },
      onAuthCode: (e) => this.setAuth({ code: e.target.value.replace(/[^0-9]/g, '').slice(0, 6), err: '' }),
      onAuthCodeKey: (e) => { if (e.key === 'Enter') this.submitMfa(); },
      authSubmitId: () => this.submitId(),
      authSubmitMfa: () => this.submitMfa(),
      authSso: () => this.setAuth({ step: 'sso', err: '', sso: true }),
      authSsoConfirm: () => this.setAuth({ step: 'mfa', err: '', code: '' }),
      authCancel: () => this.setAuth({ step: 'id', code: '', err: '', sso: false }),
      authResend: () => { this.setAuth({ err: '' }); this.flash('Nouveau code envoyé sur iPhone 15 — Sophie'); },
      authPasskey: () => { this.setAuth({ code: '402913', err: '' }); this.flash('Clé de sécurité reconnue — code pré-rempli'); },
      authForgot: () => this.openSheet('reset'),
      logout: () => {
        this.recAborted = true; this.releaseMic(); this.stopPlayback();
        this.setState({ authed: false, route: 'accueil', history: [], auth: { step: 'id', email: this.state.auth.email, pwd: '', code: '', err: '', sso: false } });
        if (typeof window !== 'undefined') window.scrollTo(0, 0);
      },

      previewOpen: this.state.previewOpen,
      closePreview: () => this.setState({ previewOpen: false }),
      previewSign: () => this.flash('Signature des pièces jointes non connectée — aucun document envoyé'),

      isSignatureNav: r === 'signature',
      goSignature: () => this.go('signature'),
      signable: this.state.docType !== 'Tract',
      signTargetLabel: 'Envoyer à la signature — ' + (this.state.docType === 'Courrier' ? 'courrier de saisine' : 'PV du CSE'),
      goSignDoc: () => this.signGeneratedDocument(),
      sigOrigin: this.state.sigOrigin,
      sigHasOrigin: !!this.state.sigOrigin,
      sigTitle: 'Signature du document',
      sigSummary: 'Simulation locale de signature — aucune certification eIDAS ni transmission externe.',
      sigDocs: (this.state.sigSnapshot ? [this.state.sigSnapshot].concat(SIGDOCS) : SIGDOCS).map((sd) => ({
        label: sd.label, selected: this.state.sig.docId === sd.id, idle: this.state.sig.docId !== sd.id,
        go: () => this.setSig({ docId: sd.id, consent: false })
      })),
      sigRef: sigDoc.ref,
      sigDocTitle: sigDoc.title,
      sigBody1: sigDoc.p1,
      sigBody2: sigDoc.p2,
      sigOtherState: sigDone ? 'Notifiée — signature attendue sous 8 jours' : 'En attente de la signature des élus',
      sigName: this.state.sig.name,
      onSigName: (e) => this.setSig({ name: e.target.value }),
      sigStyles: [
        { id: 'script', label: 'Manuscrite' },
        { id: 'serif', label: 'Italique' },
        { id: 'print', label: 'Capitales' }
      ].map((st) => ({
        label: st.label, selected: this.state.sig.style === st.id, idle: this.state.sig.style !== st.id,
        go: () => this.setSig({ style: st.id })
      })),
      sigIsScript: this.state.sig.style === 'script',
      sigIsSerif: this.state.sig.style === 'serif',
      sigIsPrint: this.state.sig.style === 'print',
      sigConsent: this.state.sig.consent,
      sigConsentMark: this.state.sig.consent ? '✓' : '',
      sigConsentBg: this.state.sig.consent ? 'var(--acBg)' : '#FFFFFF',
      sigConsentBorder: this.state.sig.consent ? 'var(--acMid)' : 'var(--bd2)',
      sigConsentBox: this.state.sig.consent ? 'var(--ac)' : 'var(--bd2)',
      sigConsentFill: this.state.sig.consent ? 'var(--ac)' : '#FFFFFF',
      sigToggleConsent: () => this.setSig({ consent: !this.state.sig.consent }),
      sigSigned: !!sigDone,
      sigUnsigned: !sigDone,
      sigCanSign: !sigDone && this.state.sig.consent && this.state.sig.name.trim().length > 2,
      sigBlocked: !sigDone && !(this.state.sig.consent && this.state.sig.name.trim().length > 2),
      sigWhyBlocked: () => this.flash(this.state.sig.name.trim().length > 2 ? 'Cochez la mention de consentement pour signer' : 'Renseignez le nom à apposer'),
      sigStamp: sigDone ? sigDone.stamp : '',
      sigCert: sigDone ? [
        { label: 'Signataire', value: sigDone.name },
        { label: 'Horodatage qualifié', value: sigDone.stamp },
        { label: 'Empreinte SHA-256', value: sigDone.hash },
        { label: 'Niveau', value: 'Avancé eIDAS · 2e facteur vérifié' },
        { label: 'Journal probatoire', value: 'Scellé — conservation 10 ans' }
      ] : [],
      sigSigners: [
        { name: this.state.sig.name || 'Sophie Marchand', role: 'Secrétaire du CSE', initials: 'SM', avatarBg: 'linear-gradient(135deg, var(--ac), var(--ac2))', done: !!sigDone, self: true },
        { name: 'Jean-Paul Diallo', role: 'Élu titulaire — cosignataire', initials: 'JD', avatarBg: 'var(--ink4)', pending: true },
        { name: 'Direction des ressources humaines', role: 'Partie employeur', initials: 'DR', avatarBg: 'var(--ink6)', last: true }
      ].map((s) => {
        const st = s.done ? { l: 'Signé', bg: 'var(--okChip)', c: 'var(--okTx)' } : (s.self ? { l: 'À signer', bg: 'var(--acBg)', c: 'var(--acTx2)' } : (s.pending ? (sigDone ? { l: 'Notifié', bg: 'var(--acBg)', c: 'var(--acTx2)' } : { l: 'En attente', bg: 'var(--surf2)', c: 'var(--ink5)' }) : (sigDone ? { l: 'Notifiée', bg: 'var(--acBg)', c: 'var(--acTx2)' } : { l: 'Non notifiée', bg: 'var(--surf2)', c: 'var(--ink6)' })));
        return { name: s.name, role: s.role, initials: s.initials, avatarBg: s.avatarBg, statusLabel: st.l, statusBg: st.bg, statusColor: st.c };
      }),
      sigSign: () => {
        const name = this.state.sig.name.trim();
        const hash = Array.from({ length: 4 }, () => Math.random().toString(16).slice(2, 6)).join(' ').toUpperCase();
        const now = new Date();
        const stamp = now.toLocaleDateString('fr-FR') + ' à ' + now.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) + ' (UTC+2)';
        this.setState((s) => {
          const map = Object.assign({}, s.signed);
          map[s.sig.docId] = { name: name, stamp: stamp, hash: hash };
          return { signed: map };
        });
        this.flash('Document signé — certificat généré');
      },
      sigReset: () => {
        this.setState((s) => {
          const map = Object.assign({}, s.signed);
          delete map[s.sig.docId];
          return { signed: map, sig: Object.assign({}, s.sig, { consent: false }) };
        });
        this.flash('Signature annulée — annulation consignée au journal');
      },
      sigDownload: () => this.openSheet('signed'),
      sigNotify: () => this.flash('Cosignataires notifiés — relance automatique sous 4 jours'),


      autoBg: this.state.autoSync ? 'var(--ok)' : 'rgba(255,255,255,.25)',
      autoLeft: this.state.autoSync ? '23px' : '3px',
      toggleAuto: () => { this.setState({ autoSync: !this.state.autoSync }); this.flash(this.state.autoSync ? 'Synchronisation manuelle' : 'Synchronisation automatique activée'); },
      syncStatus: this.state.syncing ? 'Synchronisation en cours…' : ('Dernière synchronisation : ' + this.state.lastSync + ' · ' + cachedCount + ' document' + (cachedCount > 1 ? 's' : '') + ' en cache'),
      syncLabel: this.state.syncing ? 'Synchronisation…' : 'Tout synchroniser maintenant',
      syncAll: () => this.cacheLocalDocs(),
      cachedSummary: Object.keys(this.state.cached).filter(k => this.state.cached[k]).length + ' extraits conservés localement — PDF sources et démarrage hors connexion non disponibles',

      docs: DOCS.map((dc) => {
        const on = !!this.state.cached[dc.id];
        return {
          name: dc.name, meta: dc.meta,
          iconColor: on ? 'var(--acTx)' : 'var(--bd2)',
          action: on ? 'Hors ligne' : 'Télécharger',
          btnBg: on ? 'var(--okBg)' : '#FFFFFF', btnColor: on ? 'var(--okTx)' : 'var(--ink4)', btnBorder: on ? 'var(--okChip)' : 'var(--bd2)',
          go: () => this.cacheLocalDocs(dc.id),
          open: () => this.openViewer('doc', dc.id)
        };
      }),

      ...this.adminVals(),
      org: this.orgVals(),
      w: this.W(),
      navOrderRows: navOrdered.map((n, i) => ({
        label: n.label,
        d: n.ic[0], d2: n.ic[1],
        rank: (i + 1) + '',
        mobile: n.m ? 'Aussi dans la barre mobile' : 'Barre latérale seulement',
        upDisabled: i === 0, downDisabled: i === navOrdered.length - 1,
        upOp: i > 0 ? 1 : .3, downOp: i < navOrdered.length - 1 ? 1 : .3,
        up: () => this.navMove(n.id, -1),
        down: () => this.navMove(n.id, 1)
      })),
      navOrderCustom: this.state.navOrder.join(',') !== ['accueil','assistant','dossiers','messagerie','agenda','reunions','documents','formations','communication','mobile','adherents','intranet','reporting','raccourcis','params'].join(','),
      navOrderReset: () => { this.setState({ navOrder: ['accueil','assistant','dossiers','messagerie','agenda','reunions','documents','formations','communication','mobile','adherents','intranet','reporting','raccourcis','params'] }); this.flash('Ordre du menu réinitialisé'); },

      navItemsM: navOrdered.filter(function (n) { return n.m; }).map((n) => ({
        d: n.ic[0], d2: n.ic[1], label: n.label,
        active: activeTab === n.id, idle: activeTab !== n.id,
        go: () => this.go(n.id)
      })),
      navItems: navOrdered.map((n) => ({
        d: n.ic[0], d2: n.ic[1], label: n.label,
        active: activeTab === n.id, idle: activeTab !== n.id,
        go: () => this.go(n.id)
      })),

      query: this.state.query,
      onQuery: (e) => this.setState({ query: e.target.value, route: 'recherche', history: this.state.route === 'recherche' ? this.state.history : this.state.history.concat([this.state.route]) }),
      onQueryKey: (e) => { if (e.key === 'Enter') this.go('recherche'); },
      goSearch: () => { if (this.state.route !== 'recherche') this.go('recherche'); },
      searchSummary: q ? (results.length + ' résultat(s) pour « ' + this.state.query.trim() + ' »') : 'Dossiers, sondages, documents et réponses IA passées.',
      searchResults: results,
      noResults: results.length === 0,

      hasUnread: this.state.unread,
      goNotifs: () => this.go('notifs'),
      notifications: notifs.map((n) => {
        const read = this.state.notifRead[n.id] || !this.state.unread;
        return {
          title: n.title, body: n.body, time: n.time,
          dot: read ? 'var(--bd2)' : (n.urgent ? 'var(--danger2)' : 'var(--ac)'),
          border: read ? 'var(--chip)' : (n.urgent ? 'var(--dangerBd2)' : 'var(--acBd)'),
          go: () => { const nr = Object.assign({}, this.state.notifRead); nr[n.id] = true; this.setState({ notifRead: nr }); n.go(); }
        };
      }),
      markAllRead: () => { this.setState({ unread: false }); this.flash('Notifications marquées comme lues'); },

      caseHomeHint:'1 échéance légale cette semaine',caseHighlightLabel:'Urgent',caseHighlightTime:'il y a 10 min',caseHighlightTitle:'Accident Atelier B',caseHighlightBody:'Enquête CSSCT déclenchée. Accusé de réception attendu sous 4 h.',
      openCount: this.state.dossiers.filter((x) => x.status !== 'done').length,
      dossierCount: this.state.dossiers.length,
      goDossiers: () => this.go('dossiers'),
      goNouveau: () => this.go('nouveau'),
      goAssistant: () => this.go('assistant'),
      goProfil: () => this.go('profil'),
      goAccident: () => this.go('dossier', { dossierId: 'accident' }),
      goNao: () => this.go('sondage', { pollId: 'nao' }),

      quickActions: [
        { d: ICONS.sparkles[0], label: 'Assistant IA', go: () => this.go('assistant') },
        { d: ICONS.folder[0], d2: ICONS.folder[1], label: 'Dossiers', go: () => this.go('dossiers') },
        { d: ICONS.chart[0], d2: ICONS.chart[1], label: 'Sondages', go: () => this.go('sondages') },
        { d: ICONS.mic[0], d2: ICONS.mic[1], label: 'Réunions', go: () => this.go('reunions') },
        { d: ICONS.file[0], d2: ICONS.file[1], label: 'Documents', go: () => this.go('documents') },
        { d: ICONS.rocket[0], d2: ICONS.rocket[1], label: 'Intranet', go: () => this.go('intranet') },
        { d: ICONS.calendar[0], d2: ICONS.calendar[1], label: 'Agenda', go: () => this.go('agenda') },
        { d: ICONS.users[0], d2: ICONS.users[1], label: W.memberNav, go: () => this.go('adherents') },
        { d: ICONS.chart[0], d2: ICONS.chart[1], label: 'Bilan de mandat', go: () => this.go('reporting') },
        { d: ICONS.wifioff[0], d2: ICONS.wifioff[1], label: 'Hors ligne', go: () => this.go('offline') },
        { d: ICONS.chat[0], d2: ICONS.chat[1], label: 'Messages', go: () => this.go('messagerie') },
        { d: ICONS.grad[0], d2: ICONS.grad[1], label: 'Formations', go: () => this.go('formations') },
        { d: ICONS.megaphone[0], d2: ICONS.megaphone[1], label: 'Communication', go: () => this.go('communication') },
        { d: ICONS.phone[0], d2: ICONS.phone[1], label: 'Application mobile', go: () => this.go('mobile') }
      ],

      ...prepareCaseHome(this.state.dossiers,(route,patch)=>this.go(route,patch)),

      agenda: this.agendaHome(),

      columns: prepareCaseColumns(this,cols,drag,NO_CLICK_UNTIL,UNII_ACTS),

      dragging: !!drag,
      dragCard: drag || { title: '', tag: '', desc: '', who: '', due: '' },
      dragStyle: drag ? {
        position: 'fixed',
        left: (drag.x - drag.offX) + 'px',
        top: (drag.y - drag.offY) + 'px',
        width: drag.w + 'px',
        zIndex: 95,
        pointerEvents: 'none',
        background: '#FFFFFF',
        border: '1px solid var(--acMid)',
        borderRadius: '16px',
        padding: '15px',
        transform: 'rotate(2.5deg) scale(1.03)',
        boxShadow: '0 28px 50px -18px hsl(var(--shC) / .45)'
      } : { display: 'none' },

      newTitle: this.state.newTitle,
      newDesc: this.state.newDesc,
      onNewTitle: (e) => this.setState({ newTitle: e.target.value }),
      onNewDesc: (e) => this.setState({ newDesc: e.target.value }),
      tagOptions: ['Juridique', 'Harcèlement', 'CSSCT', 'ASC / Noël', 'Négociation'].map((t) => ({
        label: t, selected: this.state.newTag === t, idle: this.state.newTag !== t,
        go: () => this.setState({ newTag: t })
      })),
      createDossier: () => {
        const title = this.state.newTitle.trim() || 'Nouveau dossier sans titre';
        const id = 'new-' + Date.now();
        const item = {
          id: id, tag: this.state.newTag, status: 'todo', due: '15 j', owner: 'Sophie M.',
          title: title, desc: this.state.newDesc.trim() || 'Contexte à compléter.',
          long: this.state.newDesc.trim() || 'Contexte à compléter.',
          ask: title,
          timeline: [{ date: "Aujourd'hui", title: 'Dossier créé', body: 'Créé par Sophie Marchand depuis le mobile.' }]
        };
        this.setState((s) => ({ dossiers: [item].concat(s.dossiers), newTitle: '', newDesc: '' }));
        this.go('dossier', { dossierId: id });
        this.flash('Dossier créé et assigné à vous');
      },

      dossier: {
        tag: d.tag, title: d.title, long: d.long, due: d.due, owner: d.owner,
        statusLabel: statusLabels[d.status], timeline: d.timeline,
        onTitle: (e) => this.patchDossier(d.id, { title: e.target.value }),
        onLong: (e) => this.patchDossier(d.id, { long: e.target.value }),
        onDue: (e) => this.patchDossier(d.id, { due: e.target.value }),
        editing: this.state.dosEdit,
        reading: !this.state.dosEdit,
        edit: () => this.setState({ dosEdit: true, delKey: '' }),
        done: () => { this.setState({ dosEdit: false }); this.flash('Dossier mis à jour'); },
        del: this.askDel('dos-' + d.id, 'Supprimer le dossier', () => {
          this.setState((s) => {
            const rest = s.dossiers.filter((x) => x.id !== d.id);
            return { dossiers: rest, dossierId: (rest[0] || {}).id || '', dosEdit: false };
          });
          this.go('dossiers');
          this.flash('Dossier supprimé — suppression consignée au journal');
        })
      },
      noteDraft: this.state.noteDraft,
      onNote: (e) => this.setState({ noteDraft: e.target.value }),
      onNoteKey: (e) => { if (e.key === 'Enter') this.addNoteNow(); },
      addNote: () => this.addNoteNow(),

      isPieces: r === 'pieces',
      pieceCount: pieceList.length,
      goPieces: () => this.go('pieces', { pieceId: (pieceList[0] || {}).id }),
      piecesSummary: d.title + ' · ' + pieceList.length + ' pièce' + (pieceList.length > 1 ? 's' : '') + ' locale' + (pieceList.length > 1 ? 's' : ''),
      pieces: pieceList.map((p) => {
        const st = extStyle[p.ext] || extStyle.PDF;
        const sel = piece && p.id === piece.id;
        return {
          name: p.name, ext: p.ext, version: 'v' + p.v,
          meta: p.size + ' · ajouté par ' + p.by + ' le ' + p.date,
          iconBg: st.bg, iconColor: st.color,
          bg: sel ? 'var(--acBg)' : '#FFFFFF', border: sel ? 'var(--acMid)' : 'var(--chip)',
          go: () => this.setState({ pieceId: p.id })
        };
      }),
      noPieces: pieceList.length === 0,
      hasPiece: !!piece,
      piece: piece ? {
        name: piece.name, ext: piece.ext,
        iconColor: (extStyle[piece.ext] || extStyle.PDF).color,
        meta: 'Version ' + piece.v + ' · ' + piece.size + ' · ' + piece.by + ' · ' + piece.date,
        previewNote: piece.note,
        versions: Array.from({ length: piece.maxVersion || piece.v }, (_, i) => (piece.maxVersion || piece.v) - i).map((n) => ({
          label: 'v' + n,
          color: n === piece.v ? 'var(--acTx)' : 'var(--ink6)',
          meta: n === piece.v ? 'Version courante · ' + piece.date : 'Remplacée · ' + piece.by,
          action: n === piece.v ? 'Télécharger' : 'Restaurer',
          restore: () => this.pieceFile(d.id,piece,n,n !== piece.v,false)
        }))
      } : { name: '', ext: '', meta: '', previewNote: '', versions: [] },
      openPiece: () => piece && this.pieceFile(d.id,piece,piece.v,false,true),
      piecePreviewText: this.state.piecePreviewText || '', piecePreviewBinary: !!this.state.piecePreviewUrl,
      newVersion: () => this.startUpload(true),
      pickFile: () => this.startUpload(false),
      attachToDoc: () => { this.setState({ docType: 'Courrier' }); this.go('tract'); },
      deletePiece: async () => {
        if (!piece) return;
        try { for (let n=1;n<=(piece.maxVersion || piece.v);n++) await window.uniionFiles.remove('piece:'+d.id+':'+piece.id+':'+n); } catch(e) { return this.flash('Suppression interrompue : '+e.message); }
        this.setState((s) => {
          const map = Object.assign({}, s.pieces);
          map[d.id] = (map[d.id] || []).filter((x) => x.id !== piece.id);
          return { pieces: map, pieceId: (map[d.id][0] || {}).id };
        });
        this.flash('Pièce et fichiers locaux supprimés');
      },
      uploading: !!up,
      uploadName: up ? up.name : '',
      uploadPct: up ? up.pct + ' %' : '',
      uploadWidth: up ? up.pct + '%' : '0%',
      uploadStatus: up ? (up.pct < 100 ? 'Enregistrement local…' : 'Fichier enregistré localement') : '',
      dchatMsgs: this.dchatFor(d),
      dchatTyping: this.state.dchatTyping,
      dchatDraft: this.state.dchatDraft,
      onDchat: (e) => this.setState({ dchatDraft: e.target.value }),
      onDchatKey: (e) => { if (e.key === 'Enter') this.dchatAsk(this.state.dchatDraft); },
      dchatSend: () => this.dchatAsk(this.state.dchatDraft),
      dchatToAsst: () => this.toAssistant({ origin: 'Dossiers', route: 'dossier', params: { dossierId: d.id }, dossierId: d.id, title: d.title, ctx: this.dossierContext(d), messages: this.dchatFor(d).filter((m) => m.source !== 'Contexte du dossier chargé').map((m) => (m.isUser ? { isUser: true, text: m.text } : { isBot: true, source: m.source, text: m.text })) }),
      dchatContext: [
        { label: d.tag || 'Dossier' },
        { label: 'Échéance ' + (d.due || 'libre') },
        { label: pieceList.length + ' pièce' + (pieceList.length > 1 ? 's' : '') },
        { label: 'Niveau ' + this.levelForDossier(d).toUpperCase().replace('STANDARD', 'standard') }
      ],
      dchatPrivacy: 'Masquage heuristique avant envoi · traitement via votre compte ChatGPT.',
      dchatSuggest: [
        { label: 'Quels textes s\'appliquent ici ?' },
        { label: 'Quels délais dois-je respecter ?' },
        { label: 'Que demander à la direction ?' },
        { label: 'Résume l\'historique en 5 lignes' }
      ].map((s) => ({ label: s.label, go: () => this.dchatAsk(s.label) })),

      askAboutDossier: () => this.requestAi(
        d.ask + '\n\nContexte du dossier : ' + this.dossierContext(d),
        this.levelForDossier(d),
        { pieces: pieceList.length, origin: 'Dossier · ' + d.title }
      ),
      goCourrier: () => { this.setState({ docType: 'Courrier', tract: 'empty', prompt: 'Courrier de saisine à la direction — ' + d.title + '. Rappeler l\'obligation de prévention et demander une enquête paritaire.' }); this.go('tract'); },
      advanceLabel: d.status === 'done' ? 'Réouvrir le dossier' : 'Faire avancer le dossier',
      advance: () => {
        const next = d.status === 'todo' ? 'doing' : (d.status === 'doing' ? 'done' : 'todo');
        this.patchDossier({ status: next, due: next === 'done' ? 'Clos' : d.due });
        this.flash('Dossier déplacé vers « ' + statusLabels[next] + ' »');
      },
      elus: ELUS.map((e) => {
        const short = e.name.split(' ')[0] + ' ' + e.name.split(' ')[1].charAt(0) + '.';
        return {
          name: e.name, initials: e.initials, role: e.role, weight: e.ssct ? '700' : '500',
          selected: d.owner === short, idle: d.owner !== short,
          go: () => { this.patchDossier({ owner: short }); this.flash(e.name + ' est désormais référent'); }
        };
      }),

      messages: this.state.messages.map((m, i) => (!m.isBot ? m : Object.assign({}, m, {
        canMemo: !m.memoDone && !m.memoSuggest && m.source !== 'Contexte importé' && i > 0,
        memoDone: !!m.memoDone,
        hasSuggest: !!m.memoSuggest,
        memo: () => { const t = String(m.text || '').split(/\n\s*Sources/)[0].trim().slice(0, 280); if (this.memAdd(t, 'Sujets en cours', 'Retenu depuis une réponse')) this.msgPatch(i, { memoDone: true }); },
        memoAccept: () => { if (this.memAdd(m.memoSuggest, 'Sujets en cours', 'Proposé par l’assistant')) this.msgPatch(i, { memoSuggest: '', memoDone: true }); },
        memoReject: () => this.msgPatch(i, { memoSuggest: '' })
      }))),
      memShort: this.memVals().short,
      goMem: () => { this.setState({ asstFull: false }); this.go('memoire'); },
      asst: this.asstVals(),
      tractToAsst: () => this.toAssistant({ origin: 'Documents', route: 'tract', title: (this.state.docType || 'Document') + (String(this.state.prompt || '').trim() ? ' — ' + String(this.state.prompt).trim().slice(0, 50) : ''), ctx: 'Générateur de documents · type : ' + this.state.docType + ' · ton : ' + this.state.tone + '\nPoints clés : ' + (this.state.prompt || 'non renseignés') + (this.state.docGen ? '\nDocument déjà généré : ' + JSON.stringify(this.state.docGen).slice(0, 1500) : '') }),
      typing: this.state.typing,
      input: this.state.input,
      onInput: (e) => this.setState({ input: e.target.value }),
      onKey: (e) => { if (e.key === 'Enter') this.ask(this.state.input); },
      send: () => this.requestAi(this.state.input),
      presets: [
        { label: 'Signalement de harcèlement', go: () => this.requestAi("Quelles sont mes obligations en cas de signalement de harcèlement ? Marie Dupont (matricule 18432), service logistique de Valenciennes, met en cause Karim son N+1.", 'rps', { pieces: 3, origin: 'Assistant' }) },
        { label: 'Informations dues en NAO', go: () => this.requestAi("Quelles informations la direction doit-elle fournir en NAO ?") },
        { label: 'Enquête après accident', go: () => this.ask("Comment mener une enquête CSSCT après un accident du travail ?") },
        { label: 'Budget ASC', go: () => this.ask("Comment est encadré le budget ASC ?") }
      ],

      isMarque: r === 'marque',
      brandProduct: this.activeBrand().product,
      ...(() => {
        const b = this.activeBrand();
        const src = (b.mode === 'dark' ? (b.logoDark || b.logoLight) : b.logoLight) || 'uniion-logo.png';
        const custom = src !== 'uniion-logo.png';
        const k = Math.min(3, Math.max(0.6, this.brandScaleOf(b, b.mode === 'dark' && b.logoDark ? 'logoDark' : 'logoLight') / 100));
        const el = (px, maxW) => React.createElement('img', {
          src: src, alt: b.product || 'logo',
          style: { display: 'block', height: Math.round(px * k) + 'px', width: 'auto', maxWidth: '100%', objectFit: 'contain', objectPosition: 'left center' }
        });
        return {
          brandLogoSrc: src,
          brandHasCustomLogo: custom,
          brandDefaultLogo: !custom,
          brandLogoFilter: (b.mode === 'dark' && !custom) ? 'brightness(0) invert(1)' : 'none',
          brandLogoH26: Math.round(26 * k) + 'px',
          brandLogoH22: Math.round(22 * k) + 'px',
          brandLogoEl26: custom ? el(26, 168) : null,
          brandLogoEl22: custom ? el(22, 140) : null,
          brandLogoEl20: custom ? el(20, 130) : null
        };
      })(),
      ...(() => {
        const d = this.state.brandDraft;
        const scope = this.state.brandScope;
        const v = (k) => this.brandScopeValue(k);
        const tokens = this.brandTokens(Object.assign({}, d, scope === 'org' ? {} : (d.sites[scope] || {})));
        const clean = JSON.stringify(this.state.brand) === JSON.stringify(d);
        const ac = this.hexToHsl(v('accent'));
        const lum = (hex) => {
          const h = hex.replace('#', '');
          const c = [0, 2, 4].map((i) => { const x = parseInt(h.slice(i, i + 2), 16) / 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); });
          return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
        };
        const ratio = (1.05) / (lum(v('accent')) + 0.05);
        const selBorder = (on) => on ? '1.5px solid var(--ac)' : '1px solid var(--bd)';
        const selBg = (on) => on ? 'var(--acBg)' : 'var(--surface)';
        return {
          brandStatus: clean
            ? 'Identité publiée · aucune modification en attente'
            : 'Brouillon non publié — prévisualisez puis publiez pour l\'appliquer aux 24 sièges',
          brandClean: clean,
          brandPublishCursor: clean ? 'not-allowed' : 'pointer',
          brandPublishBg: clean ? 'var(--chip)' : 'linear-gradient(to right, var(--ac), var(--ac2))',
          brandPublishFg: clean ? 'var(--ink5)' : '#FFFFFF',
          brandPreviewOn: this.state.brandPreview,
          brandPreviewOff: !this.state.brandPreview,
          brandTogglePreview: () => this.setState((s) => ({ brandPreview: !s.brandPreview })),
          brandReset: () => { this.setState({ brandDraft: this.state.brand, brandPreview: false }); this.flash('Brouillon réinitialisé sur l\'identité publiée'); },
          brandPublish: () => { if (!clean) this.publishBrand(); },
          brandScopes: [{ id: 'org', label: 'Organisation' }, { id: 'Valenciennes', label: 'Valenciennes' }, { id: 'Douai', label: 'Douai' }, { id: 'Siège', label: 'Siège' }].map((s) => ({
            label: s.label, selected: scope === s.id, idle: scope !== s.id, go: () => this.setState({ brandScope: s.id })
          })),
          brandScopeNote: scope === 'org'
            ? 'Réglage de référence. Les établissements en héritent, sauf surcharge explicite.'
            : 'Surcharge pour ' + scope + ' — les champs laissés tels quels continuent d\'hériter de l\'organisation.',
          brandPresets: BRAND_PRESETS.map((p) => ({
            label: p.label, desc: p.desc, accent: p.accent, accent2: p.accent2,
            selected: v('preset') === p.id, border: selBorder(v('preset') === p.id), bg: selBg(v('preset') === p.id),
            go: () => this.patchBrandDraft({ preset: p.id, accent: p.accent, accent2: p.accent2 })
          })),
          brandAccent: v('accent'),
          brandAccent2: v('accent2'),
          onBrandAccent: (e) => this.patchBrandDraft({ accent: e.target.value, preset: 'perso' }),
          onBrandAccent2: (e) => this.patchBrandDraft({ accent2: e.target.value, preset: 'perso' }),
          brandRamp: ['--acBg2', '--acBg', '--acBd', '--acMid', '--ac', '--ac2', '--acTx2', '--acDeep'].map((k) => ({ name: k.replace('--', ''), color: tokens[k] })),
          brandContrast: ratio >= 4.5
            ? 'Contraste du texte blanc sur la couleur principale : ' + ratio.toFixed(1) + ':1 — conforme AA.'
            : 'Contraste du texte blanc sur la couleur principale : ' + ratio.toFixed(1) + ':1 — insuffisant pour du petit texte. Les libellés sur fond coloré utilisent la nuance foncée dérivée (teinte ' + Math.round(ac.h) + '°).',
          brandModes: [
            { id: 'light', label: 'Clair', note: 'Par défaut, adapté à l\'impression.', swatch: 'var(--surf2)' },
            { id: 'dark', label: 'Sombre', note: 'Réunions du soir, écrans en salle.', swatch: '#151A22' }
          ].map((m) => ({
            label: m.label, note: m.note, swatch: m.swatch, selected: v('mode') === m.id,
            border: selBorder(v('mode') === m.id), bg: selBg(v('mode') === m.id),
            go: () => this.patchBrandDraft({ mode: m.id })
          })),
          brandFonts: FONT_PAIRS.map((p) => ({
            label: p.label, note: p.note, titleFont: p.title, selected: v('fonts') === p.id,
            border: selBorder(v('fonts') === p.id), bg: selBg(v('fonts') === p.id),
            go: () => this.patchBrandDraft({ fonts: p.id })
          })),
          brandLogos: [
            { k: 'logoLight', label: 'Logo — fond clair', tile: 'var(--surface)' },
            { k: 'logoDark', label: 'Logo — fond sombre', tile: 'var(--inkSurf)' },
            { k: 'mono', label: 'Monogramme carré', tile: 'var(--surf2)' },
            { k: 'logoIntranet', label: 'Logo intranet', tile: 'var(--surf2)', opt: true },
            { k: 'logoPublic', label: 'Logo site public', tile: 'var(--surf2)', opt: true }
          ].map((l) => {
            const src = v(l.k);
            const scPre = this.brandScaleOf(Object.assign({}, DEFAULT_BRAND, { logoScale: v('logoScale'), logoScales: v('logoScales') }), l.k);
            const tileEl = src ? React.createElement('img', {
              src: src, alt: l.label,
              style: { display: 'block', maxWidth: '100%', height: Math.round(40 * Math.min(3, Math.max(0.6, scPre / 100))) + 'px', objectFit: 'contain', objectPosition: 'center' }
            }) : null;
            const sc = this.brandScaleOf(Object.assign({}, DEFAULT_BRAND, { logoScale: v('logoScale'), logoScales: v('logoScales') }), l.k);
            return {
              label: l.label, tile: l.tile, src: src || '', hasImg: !!src,
              scale: sc, scaleLabel: sc + ' %', scaleId: 'brandScale-' + l.k,
              onScale: (e) => this.patchBrandDraft({ logoScales: Object.assign({}, v('logoScales') || {}, { [l.k]: Number(e.target.value) }) }),
              scaleReset: () => this.patchBrandDraft({ logoScales: Object.assign({}, v('logoScales') || {}, { [l.k]: 100 }) }),
              isMono: l.k === 'mono' && !src,
              cta: src ? 'Remplacer' : (l.opt ? 'Facultatif — déposer' : 'Déposer un fichier'),
              onFile: (e) => {
                const inp = e.target;
                const file = inp.files && inp.files[0];
                if (!file) return;
                if (!/^image\//.test(file.type)) { inp.value = ''; return this.flash('Format non reconnu — PNG, SVG ou JPEG attendu'); }
                if (file.size > 2 * 1024 * 1024) { inp.value = ''; return this.flash('Fichier trop lourd — 2 Mo maximum'); }
                const rd = new FileReader();
                rd.onload = () => {
                  this.patchBrandDraft({ [l.k]: rd.result });
                  this.setState({ brandPreview: true });
                  this.flash(l.label + ' importé — aperçu activé, publiez pour l\'appliquer');
                };
                rd.onerror = () => this.flash('Lecture du fichier impossible');
                rd.readAsDataURL(file);
                inp.value = '';
              },
              clear: () => this.patchBrandDraft({ [l.k]: '' }),
              el: tileEl
            };
          }),
          brandDarkNoLogo: v('mode') === 'dark' && !v('logoDark'),
          brandLogoScale: Number(v('logoScale')) || 100,
          brandLogoScaleLabel: (Number(v('logoScale')) || 100) + ' %',
          onBrandLogoScale: (e) => this.patchBrandDraft({ logoScale: Number(e.target.value) }),
          brandLogoScaleReset: () => this.patchBrandDraft({ logoScale: 100 }),
          brandInitials: v('initials'),
          onBrandInitials: (e) => this.patchBrandDraft({ initials: e.target.value.toUpperCase().slice(0, 3) }),
          brandLoginBg: 'linear-gradient(150deg, ' + tokens['--inkSurf'] + ', ' + tokens['--acDeep'] + ' 55%, ' + v('accent2') + ')',
          brandNavGhosts: [1, 2, 3, 4],
          brandIntranetOn: !!v('intranetInherit'),
          brandIntranetBg: v('intranetInherit') ? 'var(--ok)' : 'var(--bd2)',
          brandIntranetLeft: v('intranetInherit') ? '23px' : '3px',
          brandToggleIntranet: () => this.patchBrandDraft({ intranetInherit: !v('intranetInherit') }),
          brandGoCharte: () => this.go('webcharte'),
          brandLog: this.state.brandLog
        };
      })(),
      isReporting: r === 'reporting',
      repIsCse: this.state.repTab === 'cse',
      repIsUsage: this.state.repTab === 'usage',
      repTabs: [
        { id: 'cse', label: 'Bilan de mandat' },
        { id: 'usage', label: 'Utilisation de l\'application' }
      ].map((t) => ({
        label: t.label, selected: this.state.repTab === t.id, idle: this.state.repTab !== t.id,
        go: () => this.setState({ repTab: t.id })
      })),
      repSummary: this.state.repTab === 'usage' ? use.summary : rep.summary,
      useKpis: use.kpis,
      useModules: use.modules,
      useWeeks: use.weeks,
      useAiQuota: use.quota,
      useAiRows: use.ai,
      useAnon: use.anon,
      useProd: use.prod,
      useTop: use.top,
      useHealth: use.health,
      useExportPdf: () => { this.flash('Rapport d\'usage généré — aperçu PDF'); if (typeof window !== 'undefined') setTimeout(function () { window.print(); }, 400); },
      useExportXls: () => this.openSheet('exportRep'),
      useGoAdmin: () => this.go('membres'),
      repPeriods: [
        { id: 'year', label: 'Année 2026' },
        { id: 'rolling', label: '12 derniers mois' },
        { id: 'mandat', label: 'Mandat 2024–2028' }
      ].map((p) => ({
        label: p.label, selected: this.state.repPeriod === p.id, idle: this.state.repPeriod !== p.id,
        go: () => this.setState({ repPeriod: p.id })
      })),
      repKpis: rep.kpis,
      repMonths: rep.months,
      repThemes: rep.themes,
      repRows: rep.rows,
      repExportPdf: () => { this.flash('Bilan de mandat généré — aperçu PDF'); if (typeof window !== 'undefined') setTimeout(function () { window.print(); }, 400); },
      repExportXls: () => this.openSheet('exportRep'),
      repShare: () => this.flash('Lien de consultation copié — valable 30 jours'),

      isNewPoll: r === 'newpoll',
      npSteps: [
        { n: '1', label: 'Question & réponses' },
        { n: '2', label: 'Cible & clôture' },
        { n: '3', label: 'Relecture & diffusion' }
      ].map((s, i) => {
        const n = i + 1;
        const active = np.step === n;
        const doneStep = np.step > n;
        return {
          n: doneStep ? '✓' : s.n, label: s.label,
          bg: active ? 'var(--acBg)' : '#FFFFFF', border: active ? 'var(--acMid)' : 'var(--chip)',
          numBg: active ? 'linear-gradient(135deg, var(--ac), var(--ac2))' : (doneStep ? 'var(--okChip)' : 'var(--chip)'),
          numColor: active ? '#FFFFFF' : (doneStep ? 'var(--ok)' : 'var(--ink6)'),
          color: active ? 'var(--acTx2)' : 'var(--ink5)',
          go: () => { if (n < np.step || (n === 2 && npReady)) this.setNp({ step: n }); }
        };
      }),
      npStep1: np.step === 1, npStep2: np.step === 2, npStep3: np.step === 3,
      npTitle: np.title,
      onNpTitle: (e) => this.setNp({ title: e.target.value }),
      npTypes: [
        { id: 'unique', label: 'Choix unique' },
        { id: 'multi', label: 'Choix multiples' },
        { id: 'ouinon', label: 'Oui / Non' }
      ].map((t) => ({
        label: t.label, selected: np.type === t.id, idle: np.type !== t.id,
        go: () => this.setNp(t.id === 'ouinon' ? { type: t.id, options: ['Oui', 'Non'] } : { type: t.id })
      })),
      npOptions: np.options.map((v, i) => ({
        n: String(i + 1), value: v, placeholder: 'Réponse ' + (i + 1),
        onChange: (e) => { const o = np.options.slice(); o[i] = e.target.value; this.setNp({ options: o }); },
        remove: () => { const o = np.options.slice(); o.splice(i, 1); this.setNp({ options: o.length ? o : [''] }); }
      })),
      addOption: () => this.setNp({ options: np.options.concat(['']) }),
      suggestOptions: () => this.suggestPollOptions(),
      npTargets: npTargetDefs.map((t) => ({
        label: t.label, meta: t.meta, selected: np.target === t.id, idle: np.target !== t.id,
        go: () => this.setNp({ target: t.id })
      })),
      npCloses: npCloseDefs.map((c) => ({
        label: c.label, selected: np.close === c.id, idle: np.close !== c.id,
        go: () => this.setNp({ close: c.id })
      })),
      npCloseHint: npClose.hint,
      npRemindBg: np.remind ? 'var(--ok)' : 'var(--bd2)',
      npRemindLeft: np.remind ? '23px' : '3px',
      toggleRemind: () => this.setNp({ remind: !np.remind }),
      npPreviewTitle: np.title.trim() || 'Quelle priorité pour la NAO 2027 ?',
      npPreviewOptions: (npFilled.length ? npFilled : ['Revalorisation générale', 'Prime exceptionnelle', 'Semaine de 4 jours']).map((o) => ({ label: o })),
      npPreviewShape: np.type === 'multi' ? '4px' : '99px',
      npPreviewFooter: npTarget.count + ' salariés concernés · clôture dans ' + npClose.label.toLowerCase() + ' · anonyme',
      npChecks: [
        { ok: npTitleOk, label: 'Question claire et non orientée', detail: npTitleOk ? 'Formulation neutre, aucune mention nominative.' : 'La question est trop courte pour être comprise sans contexte.' },
        { ok: npOptionsOk, label: npFilled.length + ' réponses proposées', detail: npOptionsOk ? 'Une option « autre » permet d\'éviter les réponses forcées.' : 'Il faut au moins deux réponses possibles.' },
        { ok: true, label: 'Anonymat garanti', detail: 'Aucun identifiant salarié stocké — conforme à la délibération CNIL sur les consultations syndicales.' },
        { ok: true, label: 'Base légale : intérêt légitime', detail: 'Consultation liée au mandat CSE, mention d\'information incluse dans l\'invitation.' }
      ].map((c) => ({
        label: c.label, detail: c.detail, mark: c.ok ? '✓' : '!',
        bg: c.ok ? 'var(--okChip)' : 'var(--warnBg)', color: c.ok ? 'var(--ok)' : 'var(--warnTx)'
      })),
      npModLabel: np.mod === 'draft' ? 'Brouillon' : (np.mod === 'review' ? 'En relecture' : 'Validé'),
      npModBg: np.mod === 'approved' ? 'var(--okChip)' : (np.mod === 'review' ? 'var(--warnBg)' : 'var(--chip)'),
      npModColor: np.mod === 'approved' ? 'var(--ok)' : (np.mod === 'review' ? 'var(--warnTx)' : 'var(--ink5)'),
      npModHint: np.mod === 'draft'
        ? 'Deux élus doivent valider le sondage avant diffusion (règle de l\'organisation).'
        : (np.mod === 'review' ? 'En attente de la seconde validation. Diffusion bloquée jusque-là.' : 'Validé par deux élus — la diffusion est débloquée.'),
      npValidators: [
        { name: 'Sophie Marchand', initials: 'SM', state: 'Autrice', color: 'var(--ink5)' },
        { name: 'Jean-Paul Diallo', initials: 'JD', state: np.mod === 'draft' ? 'Non sollicité' : (np.mod === 'review' ? 'En attente' : 'A validé'), color: np.mod === 'approved' ? 'var(--ok)' : (np.mod === 'review' ? 'var(--warnTx)' : 'var(--ink6)') },
        { name: 'Karim Belkacem', initials: 'KB', state: np.mod === 'draft' ? 'Non sollicité' : (np.mod === 'review' ? 'En attente' : 'A validé'), color: np.mod === 'approved' ? 'var(--ok)' : (np.mod === 'review' ? 'var(--warnTx)' : 'var(--ink6)') }
      ],
      npCanReview: np.mod === 'draft', npAwaiting: np.mod === 'review', npApproved: np.mod === 'approved',
      npSendReview: () => {
        this.setNp({ mod: 'review' });
        this.flash('Envoyé en relecture à 2 élus');
        clearTimeout(this.t5);
        this.t5 = setTimeout(() => { this.setNp({ mod: 'approved' }); this.flash('Validé par Jean-Paul D. et Karim B.'); }, 2200);
      },
      npSimulateApproval: () => this.flash('Rappel envoyé aux relecteurs'),
      npAudienceCount: npTarget.count,
      npPublish: () => this.publishPoll(npTarget, npClose, npFilled),
      npHasPrev: np.step > 1, npHasNext: np.step < 3,
      npNextLabel: np.step === 1 ? 'Continuer vers la diffusion' : 'Continuer vers la relecture',
      npNext: () => {
        if (np.step === 1) {
          if (!npTitleOk) { this.flash('Formulez une question de plus de 8 caractères'); return; }
          if (!npOptionsOk) { this.flash('Ajoutez au moins deux réponses'); return; }
        }
        this.setNp({ step: np.step + 1 });
      },
      npPrev: () => this.setNp({ step: np.step - 1 }),
      npSaveDraft: () => {
        const title = (np.title || '').trim() || 'Sondage sans titre';
        const id = this.state.draftId || ('draft-' + Date.now());
        const opts = (np.options || []).filter(function (o) { return (o || '').trim(); });
        const draft = {
          id: id, title: title, status: 'Brouillon',
          meta: 'Étape ' + np.step + ' sur 3 · ' + (opts.length || 0) + ' réponse(s) rédigée(s)',
          participation: 'Non diffusé', width: '0%',
          insightTitle: 'Brouillon en cours',
          insight: 'Ce sondage n\'a pas encore été diffusé. Reprenez la rédaction pour le publier.',
          results: (opts.length ? opts : ['Réponse à rédiger']).map(function (o) { return { label: o, pct: '—', width: '2%' }; }),
          draft: { step: np.step, title: np.title, type: np.type, options: np.options, target: np.target, close: np.close, remind: np.remind, mod: np.mod }
        };
        this.setState((s) => ({
          draftId: id,
          pollsData: s.pollsData.some(function (p) { return p.id === id; })
            ? s.pollsData.map(function (p) { return p.id === id ? draft : p; })
            : [draft].concat(s.pollsData)
        }));
        this.go('sondages');
        this.flash('Brouillon enregistré — repris depuis Sondages');
      },

      polls: allPolls.map((p) => ({
        del: this.askDel('poll-' + p.id, 'Supprimer', () => {
          this.setState((s) => {
            const rest = s.pollsData.filter((x) => x.id !== p.id);
            return { pollsData: rest, pollId: s.pollId === p.id ? (rest[0] || {}).id || '' : s.pollId };
          });
          this.flash('Sondage supprimé');
        }),
        title: p.title, meta: p.meta, status: p.status, participation: p.participation, width: p.width,
        badgeBg: p.status === 'Clos' ? 'var(--chip)' : (p.draft ? 'var(--priBg)' : 'var(--acBg)'),
        badgeColor: p.status === 'Clos' ? 'var(--ink5)' : (p.draft ? 'var(--pri)' : 'var(--acTx)'),
        go: () => {
          if (p.draft) {
            this.setState({ np: Object.assign({}, p.draft), draftId: p.id });
            this.go('newpoll');
            this.flash('Brouillon repris à l\'étape ' + p.draft.step);
            return;
          }
          this.go('sondage', { pollId: p.id });
        }
      })),
      newPoll: () => { this.setState({ np: { step: 1, title: '', type: 'unique', options: ['', ''], target: 'all', close: '7', remind: true, mod: 'draft' } }); this.go('newpoll'); },
      poll: poll,
      goTractFromPoll: () => { this.setState({ docType: 'Tract', tract: 'empty' }); this.go('tract'); },
      relaunch: () => this.openSheet('relaunch', { count: '104' }),

      docTypes: ['Tract', 'Courrier', 'Ordre du jour'].map((t) => ({
        label: t, selected: this.state.docType === t, idle: this.state.docType !== t,
        go: () => this.setState({ docType: t, tract: 'empty' })
      })),
      tones: ['Combatif', 'Pédagogique', 'Institutionnel'].map((t) => ({
        label: t, selected: this.state.tone === t, idle: this.state.tone !== t,
        go: () => this.setState({ tone: t, tract: this.state.tract === 'ready' ? 'ready' : 'empty' })
      })),
      prompt: this.state.prompt,
      onPrompt: (e) => this.setState({ prompt: e.target.value }),
      tractReady: this.state.tract === 'ready',
      tractEmpty: this.state.tract !== 'ready',
      generateLabel: this.state.tract === 'loading' ? 'Génération en cours…' : 'Générer le document',
      generate: () => this.genDocLlm(),
      doc: this.buildDoc(),
      genTrace: [
        { n: '1', label: 'Prompt anonymisé transmis', detail: 'Noms, matricules et établissement remplacés par des jetons avant l\'appel.' },
        { n: '2', label: 'Rédaction par le modèle', detail: 'Le modèle travaille sur des jetons — il n\'a jamais vu d\'identité.' },
        { n: '3', label: 'Signature recollée localement', detail: 'Le pied de courrier est réinséré côté client, après la génération.' }
      ],
      printDoc: () => { this.flash('PDF prêt — ouverture de l\'aperçu'); if (typeof window !== 'undefined') setTimeout(function () { window.print(); }, 400); },
      diffuse: () => this.openSheet('diffuse'),

      settings: [
        { d: ICONS.sparkles[0], d2: ICONS.sparkles[1], title: 'Identité de marque', badge: 'Marque blanche', desc: 'Couleur principale, logos, typographie, mode sombre. Publication à l\'organisation ou par établissement.', go: () => this.go('marque') },
        { d: ICONS.user[0], d2: ICONS.user[1], title: 'Profil & mandat', badge: 'Élue titulaire', desc: 'Identité, informations de l\'organisation, convention collective, mandats, visibilité des coordonnées.', go: () => this.go('profil') },
        { d: ICONS.bell[0], d2: ICONS.bell[1], title: 'Notifications', badge: 'Push + email', desc: 'Granularité par module, plages « ne pas déranger », escalade des alertes urgentes.', go: () => this.go('prefs') },
        { d: ICONS.users[0], d2: ICONS.users[1], title: 'Contacts & groupes', badge: this.allContacts().length + ' contacts', desc: 'Annuaire de la messagerie (élus, adhérents, externes), groupes de discussion, membres et administrateurs.', go: () => this.go('contacts') },
        { d: ICONS.sparkles[0], title: 'Mémoire de l\'assistant', badge: (this.state.aiMem || []).filter((x) => x.on).length + ' actifs', desc: 'Réponses sourcées retenues sur le serveur pour votre compte et cette organisation. Droits revérifiés.', go: () => this.go('memoire') },
        { d: ICONS.sparkles[0], title: 'Actions d\'unii', badge: this.state.plan === 'p1' ? 'Dès Élu 2.0' : UNII_ACTS.filter((a) => this.uniiCfgOf(a).on).length + ' actives', desc: 'Actions proposées par unii dans chaque module, rôles autorisés, pastilles de suggestion.', go: () => this.go('unii') },
        { d: ICONS.rocket[0], d2: ICONS.rocket[1], title: 'Extensions', badge: this.extAll().length + ' installée' + (this.extAll().length > 1 ? 's' : ''), desc: 'Modules complémentaires : styles de documents et tracts, thèmes et sections de pages web. Activation, contenus autorisés, auto-test.', go: () => this.go('extensions') },
        { d: ICONS.sparkles[0], title: 'Configuration IA', badge: 'Admin', desc: 'Passerelle serveur, approbation et activation de la recette fictive.', go: () => this.go('apikey') },
        { d: ICONS.lock[0], d2: ICONS.lock[1], title: 'Sécurité', badge: 'MFA actif', desc: 'Double authentification, appareils connectés, journal d\'audit.', go: () => this.go('securite') },
        { d: ICONS.shield[0], d2: ICONS.shield[1], title: 'Confidentialité & RGPD', badge: 'Conforme', desc: 'Registre des traitements, purge automatique, export de vos données.', go: () => this.go('rgpd') },
        { d: ICONS.users[0], d2: ICONS.users[1], title: 'Organisation & membres', badge: '24 sièges', desc: 'Membres, commissions, statuts et invitations.', go: () => this.go('membres') },
        { d: ICONS.chart[0], d2: ICONS.chart[1], title: 'Espace admin', badge: 'Back-office', desc: 'Tableau de bord organisation, activité par commission, facturation.', go: () => this.go('admin') },
        { d: ICONS.wifioff[0], d2: ICONS.wifioff[1], title: 'Mode hors ligne', badge: cachedCount + ' en cache', desc: 'Extraits conservés dans ce navigateur, sans chiffrement applicatif.', go: () => this.go('offline') },
        { d: ICONS.rocket[0], d2: ICONS.rocket[1], title: 'Prise en main', badge: Object.keys(this.state.onb).filter((k) => this.state.onb[k]).length + '/4 étapes', desc: 'Convention collective, commissions, invitation des élus, alertes.', go: () => this.go('onboarding') }
      ],

      profileFields: [
        { label: 'Mandat', value: 'Élue titulaire · 2024 — 2028' },
        { label: 'Fonction', value: 'Secrétaire du CSE' },
        { label: 'Organisation', value: this.state.org.nom },
        { label: 'Convention collective', value: this.state.org.idcc },
        { label: 'Commissions', value: 'Négociation · SSCT' }
      ],
      visibleBg: visible.bg, visibleLeft: visible.left,
      toggleVisible: () => { this.toggle('visible'); this.flash(f.visible ? 'Coordonnées masquées' : 'Coordonnées visibles des élus'); },
      stats: [
        { value: '12', label: 'dossiers clos' },
        { value: '38', label: 'questions IA' },
        { value: '5', label: 'documents générés' },
        { value: '2', label: 'sondages lancés' }
      ],
      profileSignatureName: this.signatureLines()[0], profileSignatureRole: this.signatureLines()[1], profileSignatureEmail: this.signatureLines()[2],
      toast_saved: () => { this.openSheet('editSignature'); this.setState({ sheetText: this.signatureLines().join('\n') }); },

      prefRows: [
        { key: 'push', label: 'Notifications push', desc: 'Alertes urgentes et résultats de sondage sur mobile.' },
        { key: 'email', label: 'Résumé par email', desc: 'Digest quotidien à 8 h.' },
        { key: 'sms', label: 'SMS pour les urgences', desc: 'Uniquement accidents du travail et droits d\'alerte.' },
        { key: 'dnd', label: 'Ne pas déranger 20 h — 7 h', desc: 'Les alertes urgentes passent malgré tout.' },
        { key: 'escalade', label: 'Escalade automatique', desc: 'Si une alerte urgente reste sans accusé de réception sous 4 h.' }
      ].map((p) => {
        const s = sw(f[p.key]);
        return { label: p.label, desc: p.desc, on: !!f[p.key], bg: s.bg, left: s.left, go: () => this.toggle(p.key) };
      }),

      secRows: [
        { key: 'mfa', label: 'Double authentification (MFA)', desc: 'Obligatoire pour les rôles admin.' },
        { key: 'bio', label: 'Verrouillage biométrique', desc: 'Face ID à l\'ouverture de l\'app.' },
        { key: 'sso', label: 'SSO fédération (OIDC)', desc: 'Connexion via l\'annuaire de l\'union.' }
      ].map((p) => {
        const s = sw(f[p.key]);
        return { label: p.label, desc: p.desc, on: !!f[p.key], bg: s.bg, left: s.left, go: () => this.toggle(p.key) };
      }),
      devices: this.state.devices.map((dv) => ({
        name: dv.name, meta: dv.meta,
        go: () => { this.setState((s) => ({ devices: s.devices.filter((x) => x.id !== dv.id) })); this.flash(dv.name + ' déconnecté'); }
      })),
      noDevices: this.state.devices.length === 0,
      auditLog: [
        { date: '25 août · 08 h 22', what: 'Accès au dossier « Accident Atelier B »', who: 'Jean-Paul Diallo' },
        { date: '24 août · 19 h 04', what: 'Document généré (tract NAO)', who: 'Sophie Marchand' },
        { date: '23 août · 17 h 45', what: 'Pièces ajoutées au dossier harcèlement', who: 'Sophie Marchand' },
        { date: '22 août · 11 h 12', what: 'Changement de rôle : Cabinet Berger → lecture seule', who: 'Sophie Marchand' }
      ],
      exportAudit: () => this.openSheet('exportAudit'),

      retention: [
        { label: 'Dossiers clos', value: '5 ans' },
        { label: 'Messages chiffrés', value: '2 ans' },
        { label: 'Logs d\'usage IA', value: '12 mois' },
        { label: 'Votes de sondage', value: 'Anonymes, non liés' }
      ],
      registre: [
        { name: 'Suivi des dossiers salariés', base: 'Base légale : mission de représentation du personnel · données minimisées' },
        { name: 'Messagerie interne des élus', base: 'Base légale : intérêt légitime · chiffrement de bout en bout' },
        { name: 'Consultations IA', base: 'Base légale : consentement · non réutilisées pour l\'entraînement' }
      ],
      exportData: () => this.openSheet('exportData'),
      requestErase: () => this.flash('Demande d\'effacement transmise au DPO'),

      providers: [
        { name: 'Offre mutualisée uniion', meta: 'Incluse dans l’abonnement · Claude Sonnet', id: 'uniion' },
        { name: 'Anthropic — Claude', meta: 'Clé propre à l’organisation · UE', id: 'anthropic' },
        { name: 'Mistral — Large', meta: 'Clé propre · hébergement France', id: 'mistral' }
      ].map((p) => ({
        name: p.name, meta: p.meta,
        selected: this.state.provider === p.id, idle: this.state.provider !== p.id,
        go: () => { this.setState({ provider: p.id, keySaved: false }); this.flash(p.name + ' sélectionné'); }
      })),
      llm: this.llmConnVals(),
      keyDisplay: this.state.keyRevealed ? 'sk-ant-api03-7Yq2XbF4nR9tLmZk8pWvA1' : '•••• •••• •••• •••• 8pWvA1',
      keyToggleLabel: this.state.keyRevealed ? 'Masquer' : 'Afficher',
      toggleKey: () => this.setState({ keyRevealed: !this.state.keyRevealed }),
      saveLabel: this.state.keySaved ? '✓ Clé enregistrée' : 'Enregistrer la clé API',
      saveKey: () => { this.setState({ keySaved: true }); this.flash('Clé chiffrée et enregistrée'); },
      revokeKey: () => { this.setState({ keySaved: false, keyRevealed: false }); this.flash('Clé révoquée — bascule sur l\'offre mutualisée'); },
      usage: [
        { label: 'Assistant juridique', value: '1 240 requêtes', width: '74%' },
        { label: 'Génération de documents', value: '312 requêtes', width: '38%' },
        { label: 'Recherche légale', value: '96 requêtes', width: '14%' }
      ],
      prudenceLabel: this.state.prudence,
      prudenceWidth: this.state.prudence === 'Élevée' ? '82%' : (this.state.prudence === 'Moyenne' ? '52%' : '24%'),
      prudenceSteps: ['Basse', 'Moyenne', 'Élevée'].map((p) => ({
        label: p,
        bg: this.state.prudence === p ? 'var(--acBg)' : '#FFFFFF',
        color: this.state.prudence === p ? 'var(--acTx)' : 'var(--ink5)',
        go: () => this.setState({ prudence: p })
      })),
      sourcingBg: sourcing.bg, sourcingLeft: sourcing.left,
      toggleSourcing: () => { this.toggle('sourcing'); this.flash(f.sourcing ? 'Sourçage désactivé' : 'Sourçage obligatoire réactivé'); },

      invitation: this.invitationVals(),
      sheetOpen: !!this.state.sheet,
      sheetTitle: (sheetDef || {}).title,
      sheetSub: (sheetDef || {}).sub,
      sheetOptLabel: (sheetDef || {}).optLabel || '',
      sheetOptions: ((sheetDef || {}).options || []).map((o, i) => ({
        label: o.label, hint: o.hint,
        selected: this.state.sheetOpt === i, idle: this.state.sheetOpt !== i,
        pick: () => this.setState({ sheetOpt: i })
      })),
      sheetHasChecks: !!((sheetDef || {}).checks),
      sheetChecks: ((sheetDef || {}).checks || []).map((label, i) => ({
        label: label,
        on: this.state.sheetChecks.indexOf(i) > -1,
        off: this.state.sheetChecks.indexOf(i) === -1,
        toggle: () => this.setState((s) => ({
          sheetChecks: s.sheetChecks.indexOf(i) > -1 ? s.sheetChecks.filter(function (x) { return x !== i; }) : s.sheetChecks.concat([i])
        }))
      })),
      sheetHasField: !!((sheetDef || {}).field),
      sheetFieldLabel: (sheetDef || {}).field,
      sheetPlaceholder: (sheetDef || {}).placeholder,
      sheetText: this.state.sheetText,
      onSheetText: (e) => this.setState({ sheetText: e.target.value, sheetErr: '' }),
      sheetErr: this.state.sheetErr,
      sheetHasErr: !!this.state.sheetErr,
      sheetConfirmLabel: (sheetDef || {}).confirm,
      sheetForm: !!this.state.sheet && !this.state.sheetDone,
      sheetDone: this.state.sheetDone,
      sheetDoneTitle: (sheetDef || {}).doneTitle,
      sheetDoneLines: (this.state.sheet === 'exportRep' && this.state.sheetFileName ? [this.state.sheetFileName, 'Téléchargement lancé dans ce navigateur.'] : ((sheetDef || {}).doneLines || [])).map(function (t) { return { text: t }; }),
      sheetIsFile: !!((sheetDef || {}).file),
      sheetDoneAction: (sheetDef || {}).doneAction,
      sheetConfirm: () => this.confirmSheet(),
      sheetClose: () => this.setState({ sheet: '', sheetErr: '' }),
      sheetFollow: () => {
        const g = (sheetDef || {}).doneGo;
        this.setState({ sheet: '', sheetErr: '' });
        if (g === 'auth') {
          this.setState((s) => ({ authed: false, auth: Object.assign({}, s.auth, { step: 'id', pwd: '', code: '', err: '', sso: false }) }));
          if (typeof window !== 'undefined') window.scrollTo(0, 0);
          return;
        }
        if (g) this.go(g);
      },

      openReset: () => this.openSheet('reset'),
      openInvite: () => this.openSheet('invite'),
      openDiffuse: () => this.openSheet('diffuse'),
      openRelaunch: () => this.openSheet('relaunch', { count: '104' }),
      openSigned: () => this.openSheet('signed'),
      openExportRep: () => this.openSheet('exportRep'),
      openExportAudit: () => this.openSheet('exportAudit'),
      openExportData: () => this.openSheet('exportData'),

      isViewer: r === 'viewer',
      viewer: vw,
      viewerIsEvent: this.state.viewerKind === 'event',
      viewerIsDoc: this.state.viewerKind === 'doc',
      viewerAsk: () => this.requestAi('Que dit ce document sur ce point ? Référence : ' + (vw.title || ''), 'standard', { origin: 'Document · ' + (vw.title || '') }),
      viewerAttach: () => this.attachViewer(vw),
      viewerDownload: () => this.openSheet('signed'),
      viewerCached: !!this.state.cached[this.state.viewerId],
      viewerCacheLabel: this.state.cached[this.state.viewerId] ? 'Disponible hors ligne' : 'Rendre disponible hors ligne',
      viewerCache: () => this.cacheLocalDocs(this.state.viewerId),
      viewerAgenda: () => { this.setState({ docType: 'Ordre du jour', tract: 'empty' }); this.go('tract'); },

      anonOpen: this.state.anonOpen,
      anonOriginal: this.state.anonQuery,
      anonMasked: anon.masked,
      anonTags: anon.tags,
      anonTagCount: anon.tags.length + ' entité' + (anon.tags.length > 1 ? 's' : '') + ' détectée' + (anon.tags.length > 1 ? 's' : ''),
      anonNoTag: anon.tags.length === 0,
      anonOrigin: this.state.anonOrigin,
      anonLevelLabel: (anonDef || {}).label,
      anonLevelDesc: (anonDef || {}).desc,
      anonPiecesLabel: (anonDef || {}).pieces,
      anonPieceSummary: anonLvl === 'rps'
        ? 'Aucun résumé de pièce transmis. Le modèle raisonne sur les faits et les dates relatives saisis par l\'élu.'
        : (anonLvl === 'rh'
          ? '« 3 échanges internes entre [SALARIÉE A] et [COLLÈGUE B — lien N+1] sur 9 jours, ton dénigrant, 2 en présence de témoins. »'
          : '« Pièce de 4 pages, tableau de chiffres budgétaires, aucune donnée nominative. »'),
      anonPiecesCount: this.state.anonPieces,
      anonHasPieces: this.state.anonPieces > 0,
      anonIsRps: anonLvl === 'rps',
      anonClearAllowed: anonLvl === 'standard' && !anon.residual.length,
      anonResidual: anon.residual.length > 0,
      anonResidualWords: anon.residual.join(', '),
      anonLevels: this.anonLevelDefs().map((l) => ({
        label: l.label, desc: l.desc,
        selected: anonLvl === l.key, idle: anonLvl !== l.key,
        go: () => this.setState({ anonLevel: l.key })
      })),
      anonRaise: () => { this.setState({ anonLevel: anonLvl === 'standard' ? 'rh' : 'rps' }); this.flash('Niveau relevé — masquage renforcé'); },
      anonCancel: () => this.setState({ anonOpen: false }),
      anonConfirm: () => this.confirmAnon(),
      anonSendClear: () => this.flash('Envoi en clair — journalisé et notifié au DPO'),
      aiCallCount: this.state.aiCalls + ' appels',
      aiErrOpen: !!this.state.aiErr,
      aiErrText: this.state.aiErr,
      aiHasRetry: !!this._aiRetry,
      aiRetry: () => { const f = this._aiRetry; this._aiRetry = null; this.setState({ aiErr: '' }); if (f) f(); },
      aiErrClose: () => { this._aiRetry = null; this.setState({ aiErr: '' }); },
      anonLevelPillLabel: 'Niveau ' + ((anonDef || {}).label || ''),
      dossierLevelLabel: 'Niveau ' + this.levelForDossier(d).toUpperCase().replace('STANDARD', 'standard'),
      dossierLevelNote: this.levelForDossier(d) === 'rps' ? 'Masquage maximal · pièces jamais transmises' : (this.levelForDossier(d) === 'rh' ? 'Masquage nominatif + matricules' : 'Masquage léger — aucun nom détecté'),
      anonFootprints: [
        { fp: '7f3a91c1', meta: 'Niveau RPS · 5 entités masquées · 26/08 14 h 12' },
        { fp: '2b7cd430', meta: 'Niveau RH sensible · 3 entités masquées · 25/08 09 h 41' },
        { fp: 'e40a17b9', meta: 'Niveau standard · 1 entité masquée · 24/08 18 h 05' }
      ]
    });
  }

  startUpload(isVersion) {
    if (this.state.upload) return;
    const did = this.state.dossierId;
    const existing = isVersion ? (this.state.pieces[did] || []).find(p => p.id === this.state.pieceId) : null;
    const input = document.createElement('input'); input.type = 'file';
    input.style.display = 'none'; document.body.appendChild(input);
    input.onchange = () => { const file = input.files[0]; input.remove(); if (file) this.storePiece(file, did, existing); };
    input.oncancel = () => input.remove();
    input.click();
  }
  async storePiece(file, did, existing) {
    if (!file.size) return this.flash('Le fichier est vide');
    if (file.size > 25 * 1048576) return this.flash('Fichier trop volumineux — limite de 25 Mo');
    const id = existing ? existing.id : 'u'+Date.now();
    const version = existing ? (existing.maxVersion || existing.v)+1 : 1;
    this.setState({upload:{name:file.name,pct:0}});
    try {
      await window.uniionFiles.put('piece:'+did+':'+id+':'+version,file);
      const item = Object.assign({},existing || {},{id:id,name:file.name,ext:(file.name.split('.').pop() || 'FILE').toUpperCase(),size:Math.ceil(file.size/1024)+' Ko',by:'Utilisateur local',date:new Date().toLocaleDateString('fr-FR'),v:version,maxVersion:version,note:'Fichier conservé dans ce navigateur — sans chiffrement applicatif.'});
      this.setState(s => ({pieces:Object.assign({},s.pieces,{[did]:existing ? (s.pieces[did] || []).map(p => p.id===id ? item : p) : [item].concat(s.pieces[did] || [])}),upload:null,pieceId:id}));
      this.flash('Fichier enregistré localement');
    } catch(e) { this.setState({upload:null}); this.flash('Fichier non enregistré : '+e.message); }
  }
  async pieceFile(did,piece,n,restore,preview) {
    try {
      const blob = await window.uniionFiles.get('piece:'+did+':'+piece.id+':'+n) || (piece.content && new Blob([piece.content],{type:'text/plain'}));
      if (!blob) throw new Error('Fichier de démonstration : aucun contenu téléchargeable');
      if (restore) {
        this.setState(s => ({pieces:Object.assign({},s.pieces,{[did]:(s.pieces[did] || []).map(p => p.id===piece.id ? Object.assign({},p,{v:n}) : p)})}));
        return this.flash('Version v'+n+' restaurée');
      }
      if (preview) {
        if (this._pieceUrl) URL.revokeObjectURL(this._pieceUrl);
        if (!/^(application\/pdf|image\/(png|jpeg|gif|webp)|text\/plain)$/.test(blob.type)) return this.flash('Aperçu indisponible pour ce format — utilisez Télécharger');
        if (blob.type === 'text/plain') { this.setState({previewOpen:true,piecePreviewUrl:'',piecePreviewText:await blob.text()}); return; }
        this._pieceUrl=URL.createObjectURL(blob);
        this.setState({previewOpen:true,piecePreviewUrl:this._pieceUrl,piecePreviewText:''});
        setTimeout(() => { const frame = document.getElementById('local-piece-frame'); if (frame && this.state.previewOpen) frame.src = this._pieceUrl; }, 0); return;
      }
      window.uniionFiles.download(blob,blob.name || piece.name);
    } catch(e) { this.flash(e.message); }
  }

  setNp(patch) {
    this.setState((s) => ({ np: Object.assign({}, s.np, patch) }));
  }

  publishPoll(target, close, options) {
    const np = this.state.np;
    const id = 'p' + Date.now();
    const poll = {
      id: id, title: np.title.trim(), status: 'En cours', participation: '0 % de participation', width: '2%',
      meta: '0 réponse sur ' + target.count + ' salariés · vote anonyme · ' + close.hint.replace('Clôture', 'clôture').replace(/ —.*/, ''),
      insightTitle: 'Diffusion en cours',
      insight: 'Le sondage vient d\'être ouvert. Les premiers résultats apparaîtront ici dès les premières réponses ; un tract pourra en être généré directement.',
      results: options.map((o) => ({ label: o, pct: '—', width: '2%' }))
    };
    this.setState((s) => ({
      pollsData: [poll].concat(s.pollsData.filter((p) => p.id !== s.draftId)),
      draftId: ''
    }));
    this.go('sondage', { pollId: id });
    this.flash('Sondage diffusé à ' + target.count + ' salariés (push + QR code)');
  }

  
  
  
  
  

  


  /* ---- Formations ---- */
  fmNMods(d) { return { 15: 3, 30: 4, 60: 5, 120: 6, 180: 7 }[d] || 4; }
  fmDurLabel(d) { return d < 60 ? d + ' min' : (d / 60) + ' h'; }
  fmGuessDur(s) { s = String(s || ''); if (/2 jours|3 jours|5 jours/.test(s)) return 180; if (/1 jour/.test(s)) return 120; if (/1\/2|0,5/.test(s)) return 60; return 30; }
  fmPrefill(theme, dur) {
    this.setState((s) => ({ fmTab: 'unii', fmSessId: null, fmSetup: Object.assign({}, s.fmSetup, { theme: theme, dur: dur || s.fmSetup.dur }) }));
    if (typeof window !== 'undefined') window.scrollTo(0, 0);
    this.flash('Thème repris — ajustez le temps et lancez la session');
  }
  fmRequest(key, title) {
    const on = !!(this.state.fmReq || {})[key];
    this.setState((s) => ({ fmReq: Object.assign({}, s.fmReq, { [key]: on ? false : { title: title, createdAt: new Date().toISOString(), status: 'Préparée localement' } }) }));
    this.flash(on ? 'Demande retirée' : 'Demande de session « ' + title + ' » enregistrée localement — envoi au bureau non connecté');
  }
  fmPatch(id, fn) { this.setState((s) => ({ fmSessions: (s.fmSessions || []).map((x) => (x.id === id ? Object.assign({}, x, fn(x)) : x)) })); }
  curFm() { return (this.state.fmSessions || []).find((x) => x.id === this.state.fmSessId) || null; }
  fmLocalPlan(theme, st, n) {
    const T = ['Poser le cadre', 'Ce que prévoient les textes', 'Les acteurs et leurs rôles', 'La méthode pas à pas', 'Cas pratique syndical', 'Outils et modèles', 'Mon plan d\'action'];
    const per = Math.max(5, Math.round(st.dur / n));
    return {
      title: theme, intro: 'Voici un parcours type en ' + n + ' modules pour aborder « ' + theme + ' ». Avancez à votre rythme : chaque module se termine par un exercice et une question de contrôle.',
      modules: T.slice(0, n).map((x, k) => ({
        title: x, minutes: per, objectif: 'Savoir ' + (k === 0 ? 'situer les enjeux de « ' + theme + ' » dans votre mandat' : x.toLowerCase() + ' appliqué(e) à « ' + theme + ' »') + '.',
        points: [
          { h: 'L\'essentiel', text: 'Repérez ce qui relève du mandat de représentant du personnel, ce qui relève de l\'employeur, et les documents qui font foi dans votre entreprise : accords, convention collective, règlement intérieur, PV du CSE.' },
          { h: 'Le bon réflexe', text: 'Toujours laisser une trace écrite : question inscrite à l\'ordre du jour, courrier daté, réponse consignée au PV. C\'est ce qui vous permettra d\'agir ensuite.' }
        ],
        exemple: 'Lors d\'une réunion du CSE, un élu soulève le sujet sans document à l\'appui : la direction répond oralement et rien n\'est acté. La fois suivante, la question est écrite et transmise trois jours avant : la réponse figure au PV.',
        exercice: 'En trois phrases, décrivez comment ce sujet se pose aujourd\'hui dans votre entreprise et ce que vous aimeriez obtenir.',
        quiz: { q: 'Quel est le premier réflexe d\'un élu pour sécuriser une demande ?', choices: ['En parler oralement à la pause', 'La formaliser par écrit et la faire consigner', 'Attendre que la direction en parle', 'Publier directement un tract'], answer: 1, explain: 'L\'écrit et l\'inscription au PV créent une trace opposable et datée.' }
      })),
      retenir: ['Identifier les textes applicables avant d\'agir', 'Toujours formaliser par écrit', 'S\'appuyer sur le collectif et le PV du CSE'],
      sources: 'Parcours type généré localement — à compléter avec le corpus de votre organisation.'
    };
  }
  async fmStart() {
    const st = this.state.fmSetup;
    const theme = String(st.theme || '').trim();
    if (!theme) return this.flash('Choisissez ou saisissez un thème');
    if (this.offTopic(theme + ' ' + (st.goal || ''))) return this.flash('Thème hors du périmètre syndical — reformulez');
    const n = this.fmNMods(st.dur);
    const raw = 'Thème : ' + theme + '\nDurée totale : ' + st.dur + ' minutes\nNiveau : ' + st.level + '\nRôle de l\'apprenant : ' + st.role + (st.goal ? '\nObjectif personnel : ' + st.goal : '') + '\nNombre de modules : ' + n;
    const mk = this.maskText(raw, this.detectLevel(raw));
    this.setState((s) => ({ fmBusy: true, aiCalls: s.aiCalls + 1 }));
    const SYS = "Tu es unii, formateur pédagogue pour des représentants du personnel et des syndicalistes français. Tu conçois une session d'autoformation à suivre seul à l'écran, très pédagogique : progression du simple au complexe, phrases courtes, vocabulaire expliqué, exemples tirés de la vie d'un CSE ou d'une section syndicale.\n"
      + "Règles : adapte la profondeur au niveau et au rôle indiqués. Répartis exactement la durée totale entre les modules (champ minutes, la somme doit égaler la durée). Chaque module : un objectif opérationnel ; 2 à 4 points de cours (h = intitulé court, text = 50 à 100 mots) ; un exemple concret ; un exercice d'application court avec une consigne claire ; un quiz à 4 choix avec une seule bonne réponse et son explication. Ne cite que des articles présents dans le corpus fourni ou dont tu es certain ; sinon écris « référence à vérifier ». Le texte est anonymisé : conserve les jetons entre crochets. Vouvoiement, texte brut sans markdown. Tu restes dans le périmètre syndical, droit du travail et usage de l'IA dans le mandat.\n"
      + "Réponds uniquement par un objet JSON : {\"title\": \"titre de la session\", \"intro\": \"2 phrases d'accueil\", \"modules\": [{\"title\": \"\", \"minutes\": 10, \"objectif\": \"\", \"points\": [{\"h\": \"\", \"text\": \"\"}], \"exemple\": \"\", \"exercice\": \"\", \"quiz\": {\"q\": \"\", \"choices\": [\"\", \"\", \"\", \"\"], \"answer\": 0, \"explain\": \"\"}}], \"retenir\": [\"3 à 5 idées clés\"], \"sources\": \"références utilisées\"}";
    let data = null, ai = true;
    try { if (mk.residual && mk.residual.length) throw new Error('filtre'); data = await this.llmJson(SYS, mk.masked + '\n\nCorpus de référence :\n' + this.aiCorpus(), 6000); } catch (e) { ai = false; }
    if (!data || !Array.isArray(data.modules) || !data.modules.length) { data = this.fmLocalPlan(theme, st, n); ai = false; }
    const um = (s) => (mk.tags || []).reduce((acc, x) => acc.split(x.token).join(x.clear), this.plain(s));
    const mods = data.modules.slice(0, 8).map((m) => {
      const qz = m.quiz || {};
      const ch = (Array.isArray(qz.choices) ? qz.choices : []).map(um).filter(Boolean).slice(0, 4);
      return {
        title: um(m.title) || 'Module', minutes: Math.max(3, parseInt(m.minutes, 10) || Math.round(st.dur / n)), objectif: um(m.objectif),
        points: (Array.isArray(m.points) ? m.points : []).map((p) => ({ h: um(p.h), text: um(p.text) })).filter((p) => p.text).slice(0, 5),
        exemple: um(m.exemple), exercice: um(m.exercice) || 'Reformulez avec vos mots l\'idée principale de ce module.',
        quiz: { q: um(qz.q) || 'Quelle idée retenez-vous de ce module ?', choices: ch.length >= 2 ? ch : ['Oui', 'Non'], answer: Math.min(Math.max(0, parseInt(qz.answer, 10) || 0), Math.max(0, ch.length - 1)), explain: um(qz.explain) }
      };
    });
    const sess = { id: 'fs' + Date.now(), theme: theme, title: um(data.title) || theme, intro: um(data.intro), dur: st.dur, level: st.level, role: st.role, created: new Date().toLocaleDateString('fr-FR'), modules: mods, retenir: (Array.isArray(data.retenir) ? data.retenir : []).map(um).filter(Boolean), sources: um(data.sources), cur: 0, done: [], ans: {}, ex: {}, fb: {}, chat: [], finished: false, local: !ai };
    this.setState((s) => ({ fmBusy: false, fmSessions: [sess].concat(s.fmSessions || []), fmSessId: sess.id, fmChat: '' }));
    if (typeof window !== 'undefined') window.scrollTo(0, 0);
    this.flash(ai ? 'Parcours de ' + mods.length + ' modules prêt' : 'Parcours type chargé — IA indisponible');
  }
  fmReview() {
    const s = this.curFm(); if (!s || this.state.fmRevBusy) return;
    const i = s.cur, m = s.modules[i], ans = String((s.ex || {})[i] || '').trim();
    if (!ans) return this.flash('Rédigez d\'abord votre réponse');
    const mk = this.maskText(ans, this.detectLevel(ans));
    this.setState((st) => ({ fmRevBusy: true, aiCalls: st.aiCalls + 1 }));
    const SYS = "Tu es unii, formateur bienveillant et exigeant pour des élus du personnel. Tu corriges la réponse d'un apprenant à un exercice. Structure : ce qui est juste, ce qui manque ou est inexact, une piste concrète pour améliorer. 120 mots maximum, vouvoiement, texte brut. Conserve les jetons entre crochets.";
    this.llmText(SYS, 'Module : ' + m.title + '\nObjectif : ' + m.objectif + '\nExercice : ' + m.exercice + '\nRéponse de l\'apprenant (anonymisée) : ' + mk.masked + '\n\nCorpus :\n' + this.aiCorpus(), 700)
      .then((txt) => { const c = (mk.tags || []).reduce((acc, x) => acc.split(x.token).join(x.clear), this.plain(txt)); this.setState({ fmRevBusy: false }); this.fmPatch(s.id, (x) => ({ fb: Object.assign({}, x.fb, { [i]: c }) })); })
      .catch(() => { this.setState({ fmRevBusy: false }); this.fmPatch(s.id, (x) => ({ fb: Object.assign({}, x.fb, { [i]: 'Relecture indisponible pour le moment. Comparez votre réponse à l\'objectif du module et au cas concret, puis réessayez.' }) })); });
  }
  fmAsk() {
    const s = this.curFm(); const q = String(this.state.fmChat || '').trim();
    if (!s || !q || this.state.fmChatBusy) return;
    const m = s.modules[Math.min(s.cur, s.modules.length - 1)];
    if (this.offTopic(q)) { const off = this.offTopicReply(); this.setState({ fmChat: '' }); this.fmPatch(s.id, (x) => ({ chat: x.chat.concat([{ u: true, text: q }, { u: false, text: off.text }]) })); return; }
    const mk = this.maskText(q, this.detectLevel(q));
    this.setState((st) => ({ fmChat: '', fmChatBusy: true, aiCalls: st.aiCalls + 1 }));
    this.fmPatch(s.id, (x) => ({ chat: x.chat.concat([{ u: true, text: q }]) }));
    const SYS = "Tu es unii, formateur pour des élus du personnel. Tu réponds à une question posée pendant une session de formation, de façon pédagogique, en t'appuyant sur le module en cours et le corpus. 130 mots maximum, vouvoiement, texte brut, un exemple si utile.";
    this.llmText(SYS, 'Session : ' + s.title + '\nModule en cours : ' + m.title + ' — ' + m.objectif + '\nQuestion : ' + mk.masked + '\n\nCorpus :\n' + this.aiCorpus(), 700)
      .then((txt) => { const c = (mk.tags || []).reduce((acc, x) => acc.split(x.token).join(x.clear), this.plain(txt)); this.setState({ fmChatBusy: false }); this.fmPatch(s.id, (x) => ({ chat: x.chat.concat([{ u: false, text: c }]) })); })
      .catch((e) => { this.setState({ fmChatBusy: false }); this.fmPatch(s.id, (x) => ({ chat: x.chat.concat([{ u: false, text: 'Aucune réponse produite (' + (e && e.message ? e.message : e) + '). Réessayez.' }]) })); });
  }
  uniiCfgOf(a) { const c = (this.state.uniiCfg || {})[a.id] || {}; return { on: c.on === undefined ? true : !!c.on, roles: c.roles || a.roles }; }
  uniiAllowed(a) { const c = this.uniiCfgOf(a); return c.on && (!c.roles.length || c.roles.indexOf(this.state.uniiRole || 'ds') >= 0); }
  uniiItems(mod) {
    const S = this.state;
    if (mod === 'dossiers') return (S.dossiers || []).map((x) => ({ id: x.id, label: x.title }));
    if (mod === 'reunions') return (S.reunions || []).map((x) => ({ id: x.id, label: x.title }));
    if (mod === 'documents') return (S.docs || []).map((x) => ({ id: x.id, label: x.title }));
    if (mod === 'messagerie') return (S.convos || []).map((x) => ({ id: x.id, label: x.name }));
    if (mod === 'mobile') return this.mobList().map((x) => ({ id: x.id, label: x.title }));
    return [];
  }
  uniiRouteItem(r) { const S = this.state; return r === 'dossier' ? S.dossierId : r === 'reunion' ? S.reunionId : r === 'docedit' ? S.docId : r === 'thread' ? S.convoId : (r === 'mobile' && S.mobTab === 'edit') ? S.mobId : null; }
  uniiCtx(mod, itemId) {
    const S = this.state, W = this.W();
    const head = 'Organisation : ' + (W.synd ? 'section syndicale' : 'CSE') + '\nRôle de l\'utilisateur : ' + (UNII_ROLES.find((x) => x[0] === (S.uniiRole || 'ds')) || [])[1] + '\nDate du jour : 2 octobre 2026\nModule : ' + ((UNII_MODS.find((x) => x[0] === mod) || [])[1] || mod) + '\n';
    if (mod === 'dossiers') {
      const d = (S.dossiers || []).find((x) => x.id === itemId);
      if (d) return head + 'Dossier « ' + d.title + ' » — ' + d.tag + ', ' + (STATUS_LABELS[d.status] || d.status) + ', échéance ' + d.due + '\n' + (d.long || d.desc || '') + '\nChronologie :\n' + (d.timeline || []).map((e) => '- ' + e.date + ' — ' + e.title + ' : ' + e.body).join('\n');
      return head + 'Dossiers :\n' + (S.dossiers || []).map((x) => '- ' + x.title + ' (' + x.tag + ', ' + (STATUS_LABELS[x.status] || x.status) + ', échéance ' + x.due + ') : ' + (x.desc || '')).join('\n');
    }
    if (mod === 'reunions') {
      const x = (S.reunions || []).find((y) => y.id === itemId);
      if (x) return head + 'Réunion « ' + x.title + ' » — ' + x.type + ', ' + x.date + ', PV : ' + x.pv + '\nOrdre du jour :\n' + (x.ordre || []).map((o) => '- ' + o).join('\n') + '\nMarqueurs de séance :\n' + (x.markers || []).map((k) => '- ' + k.note).join('\n');
      return head + 'Réunions :\n' + (S.reunions || []).map((y) => '- ' + y.title + ' (' + y.type + ', ' + y.date + ', PV ' + y.pv + ')').join('\n');
    }
    if (mod === 'documents') {
      const x = (S.docs || []).find((y) => y.id === itemId);
      if (x) { const d = S.docId === x.id ? this.curDoc() : x; const bl = d.blocks || this.modelOf(d.model).blocks.map((b) => ({ type: b[0], text: b[1] })); return head + 'Document « ' + x.title + ' » — statut ' + x.status + this.extDocUniiLine(d) + '\n' + bl.map((b) => b.text).join('\n'); }
      return head + 'Documents :\n' + (S.docs || []).map((y) => '- ' + y.title + ' (' + y.status + ', ' + y.updated + ')').join('\n');
    }
    if (mod === 'messagerie') {
      const c = (S.convos || []).find((y) => y.id === itemId) || (S.convos || [])[0];
      return head + 'Fil « ' + (c ? c.name : '') + ' » :\n' + (c ? c.messages : []).slice(-12).map((mm) => '- ' + (mm.mine ? 'Moi' : mm.who) + ' : ' + mm.text).join('\n');
    }
    if (mod === 'agenda') return head + this.agendaContext();
    if (mod === 'mobile') {
      const p = this.mobList().find((x) => x.id === itemId);
      if (p) return head + 'Page de l\'application mobile FO\nTitre : ' + p.title + '\nType : ' + p.type + '\nPublic : ' + p.aud + '\nStatut : ' + p.status + '\nContenu :\n' + p.blocks.map((b) => '[' + MOB_KIND[b[0]] + '] ' + b[1]).join('\n') + (p.pushOn ? '\nNotification push : ' + (p.push || '(à rédiger)') : '');
      return head + 'Pages de l\'application mobile :\n' + this.mobList().map((x) => '- ' + x.title + ' (' + x.type + ', ' + x.status + ')').join('\n') + '\nPlan éditorial :\n' + this.comPlanList().map((x) => '- ' + x.date + ' — ' + x.title).join('\n') + '\nDossiers ouverts :\n' + (S.dossiers || []).filter((x) => x.status !== 'done').slice(0, 6).map((x) => '- ' + x.title).join('\n');
    }
    if (mod === 'communication') return head + 'Plan éditorial :\n' + this.comPlanList().map((p) => '- ' + p.date + ' — ' + p.title + ' (' + p.fmt + ', ' + p.st + ')').join('\n');
    if (mod === 'accueil') return head + 'Dossiers ouverts :\n' + (S.dossiers || []).filter((x) => x.status !== 'done').map((x) => '- ' + x.title + ' (échéance ' + x.due + ')').join('\n') + '\nRéunions :\n' + (S.reunions || []).slice(0, 4).map((y) => '- ' + y.title + ' (PV ' + y.pv + ')').join('\n') + '\nPublications à valider : ' + this.comPlanList().filter((p) => p.st === 'À valider').length;
    if (mod === 'adherents') { const l = S.adherents || []; return head + l.length + ' personnes au fichier, ' + l.filter((a) => a.statut === 'retard').length + ' en retard de cotisation, ' + l.filter((a) => a.statut === 'nouveau').length + ' nouvelles.'; }
    return head;
  }
  uniiSuggs(mod, r) {
    const S = this.state, out = [];
    const push = (id, text, itemId) => { const a = UNII_ACTS.find((x) => x.id === id); if (a && this.uniiAllowed(a)) out.push({ actId: id, text: text, itemId: itemId || null, mod: a.mod }); };
    const short = (due) => /\bh\b|\d+ h/.test(String(due || ''));
    if (mod === 'dossiers' || mod === 'accueil') (S.dossiers || []).filter((x) => x.status !== 'done' && short(x.due)).slice(0, 3).forEach((x) => push(r === 'dossier' && S.dossierId === x.id ? 'dos-delais' : 'dos-next', 'Échéance dans ' + x.due + ' · ' + x.title, x.id));
    if (mod === 'reunions') (S.reunions || []).filter((x) => x.pv === 'En relecture' || x.pv === 'À rédiger').slice(0, 2).forEach((x) => push('reu-dec', 'PV ' + x.pv.toLowerCase() + ' · ' + x.title, x.id));
    if (mod === 'documents') (S.docs || []).filter((x) => x.status === 'Brouillon').slice(0, 3).forEach((x) => push('doc-relire', 'Brouillon à relire · ' + x.title, x.id));
    if (mod === 'messagerie') (S.convos || []).filter((x) => x.unread > 0).slice(0, 2).forEach((x) => push('msg-sum', x.unread + ' non lu' + (x.unread > 1 ? 's' : '') + ' · ' + x.name, x.id));
    if (mod === 'communication') { const n = this.comPlanList().filter((p) => p.st === 'Idée').length; if (n) push('com-month', n + ' idée' + (n > 1 ? 's' : '') + ' à transformer en publication'); }
    if (mod === 'adherents') { const n = (S.adherents || []).filter((a) => a.statut === 'retard').length; if (n && this.W().showCotis) push('adh-relance', n + ' cotisation' + (n > 1 ? 's' : '') + ' en retard'); }
    if (mod === 'mobile') this.mobSuggs().forEach((x) => push(x.act, x.text, x.id));
    if (mod === 'accueil') push('acc-week', 'Votre point de la semaine est prêt');
    return out;
  }
  uniiOpen(o) {
    const S = this.state, mod = o.mod;
    const patch = { uniiOpen: true };
    if (S.uniiMod !== mod) Object.assign(patch, { uniiMod: mod, uniiMsgs: [], uniiItem: null, uniiIn: '' });
    if (o.itemId) patch.uniiItem = o.itemId;
    this.setState(patch); if (o.actId) setTimeout(() => this.uniiRun(o.actId), 0);
  }
  uniiRun(actId, free) {
    const S = this.state; if (S.uniiBusy) return;
    if (S.plan === 'p1') return this.flash('unii est inclus à partir de l\'offre Élu 2.0');
    const mod = S.uniiMod, a = actId ? UNII_ACTS.find((x) => x.id === actId) : null;
    const items = this.uniiItems(mod), itemId = this.uniiRouteItem(S.route) || S.uniiItem || (items[0] || {}).id || null;
    const useItem = a ? a.scope === 'item' : !!this.uniiRouteItem(S.route) || !!S.uniiItem;
    const ctx = this.uniiCtx(mod, useItem ? itemId : null);
    const q = a ? a.ask : String(free || '').trim(); if (!q) return;
    const label = a ? a.label : q;
    const mk = this.maskText(ctx + '\n\nDemande : ' + q, 'rps');
    if (mk.residual.length) return this.flash('Envoi refusé — un identifiant échappe au filtre');
    const unmask = (s) => (mk.tags || []).reduce((acc, tg) => acc.split(tg.token).join(tg.clear), String(s || '')).trim();
    const itemLabel = useItem ? ((items.find((x) => x.id === itemId) || {}).label || '') : '';
    this.setState((s) => ({ uniiBusy: true, uniiIn: '', aiCalls: (s.aiCalls || 0) + 1, uniiMsgs: (s.uniiMsgs || []).concat([{ u: true, text: label + (itemLabel ? ' — ' + itemLabel : '') }]) }));
    const SYS = "Tu es unii, l'assistant IA intégré à chaque module de uniion, l'application des élus CSE et des représentants syndicaux français. Tu aides l'utilisateur à se servir du module où il se trouve, à partir du contexte fourni. Réponds en français, vouvoiement, texte brut sans markdown (tirets autorisés), 220 mots maximum, directement exploitable. Tu proposes, l'élu valide : n'affirme jamais avoir envoyé, modifié ou supprimé quoi que ce soit. N'invente aucun fait, chiffre ou date absent du contexte ; écris [à compléter]. Le texte est anonymisé : conserve les jetons entre crochets.";
    const clean = (s) => String(s || '').replace(/`+/g, '').replace(/\*\*|__/g, '').replace(/^\s*#+\s*/gm, '').replace(/^(\s*)[*•]\s+/gm, '$1- ').trim();
    const done = (txt0, local) => { const txt = clean(txt0); this.setState((s) => ({ uniiBusy: false, uniiMsgs: (s.uniiMsgs || []).concat([{ u: false, text: txt, local: !!local, actId: a ? a.id : null, apply: a ? a.apply || null : null, itemId: useItem ? itemId : null, q: label }]) })); };
    this.llmText(SYS, mk.masked, 900).then((r) => { if (!String(r || '').trim()) throw new Error('vide'); done(unmask(r)); })
      .catch(() => done((a ? 'Trame de départ pour « ' + a.label + ' » :\n- ' + a.desc + '\n- Points à compléter avec les éléments du ' + ((UNII_MODS.find((x) => x[0] === mod) || [])[1] || 'module').toLowerCase() + '\n- Relisez avant toute diffusion' : 'Je n\'ai pas pu joindre le modèle. Reformulez ou réessayez dans un instant.'), true));
  }
  uniiApply(mm) {
    const txt = String(mm.text || '').trim(); if (!txt) return;
    if (mm.apply === 'timeline' && mm.itemId) {
      this.setState((s) => ({ dossiers: s.dossiers.map((d) => (d.id === mm.itemId ? Object.assign({}, d, { timeline: (d.timeline || []).concat([{ date: '2 oct. · ' + new Date().toTimeString().slice(0, 5).replace(':', ' h '), title: 'unii — ' + mm.q, body: txt.slice(0, 900) }]) }) : d)) }));
      return this.flash('Ajouté à la chronologie du dossier');
    }
    if (mm.apply === 'docinsert' && mm.itemId) {
      const S = this.state, base = S.docs.find((x) => x.id === mm.itemId); if (!base) return;
      const d = base.blocks ? base : Object.assign({}, base, { blocks: this.modelOf(base.model).blocks.map((b, i) => ({ id: base.id + '-b' + i, type: b[0], text: b[1] })) });
      const add = txt.split(/\n\s*\n/).map((p, i) => ({ id: d.id + '-u' + Date.now() + i, type: 'p', text: p.trim() })).filter((b) => b.text);
      this.setState((s) => ({ docs: s.docs.map((x) => (x.id === d.id ? Object.assign({}, x, { blocks: d.blocks.concat(add), updated: 'à l\'instant' }) : x)), docSrcDraft: null }));
      return this.flash('Proposition insérée à la fin du document — à relire');
    }
    if ((mm.apply === 'mobpage' || mm.apply === 'mobreplace') && mm.itemId) {
      const bl = this.mobParse(txt); if (!bl.length) return;
      this.mobPatch(mm.itemId, (p) => ({ blocks: mm.apply === 'mobreplace' ? bl : p.blocks.concat(bl) }));
      return this.flash(mm.apply === 'mobreplace' ? 'Contenu de la page remplacé — à relire' : bl.length + ' bloc' + (bl.length > 1 ? 's' : '') + ' ajouté' + (bl.length > 1 ? 's' : '') + ' à la page — à relire');
    }
    if (mm.apply === 'mobpush' && mm.itemId) {
      const l = txt.split('\n').map((x) => x.replace(/^[-•\d.)\s]+/, '').replace(/^["«\s]+|["»\s]+$/g, '').trim()).filter((x) => x.length > 10)[0] || '';
      if (!l) return;
      this.mobPatch(mm.itemId, () => ({ pushOn: true, push: l.slice(0, 120) }));
      return this.flash('Notification push mise à jour');
    }
    if (mm.apply === 'complan') {
      const lines = txt.split('\n').map((l) => l.replace(/^[-•\d.\s]+/, '').trim()).filter((l) => l.length > 8).slice(0, 6);
      this.comSetPlan((l) => l.concat(lines.map((x, i) => ({ id: 'c' + Date.now() + i, date: '2026-11-' + String(3 + i * 5).padStart(2, '0'), title: x.slice(0, 110), fmt: 'Post réseau social', canal: this.comCanaux()[0], obj: 'Informer', st: 'Idée' }))));
      return this.flash(lines.length + ' idée' + (lines.length > 1 ? 's' : '') + ' ajoutée' + (lines.length > 1 ? 's' : '') + ' au plan éditorial');
    }
  }
  uniiVals(tab, r) {
    const S = this.state, W = this.W();
    const mod = UNII_MODS.some((x) => x[0] === tab) ? tab : null;
    const locked = S.plan === 'p1', pillsOn = S.uniiPills !== false;
    const modLabel = mod ? (mod === 'adherents' ? W.memberNav : UNII_MODS.find((x) => x[0] === mod)[1]) : '';
    const suggs = mod && !locked && pillsOn ? this.uniiSuggs(mod, r) : [];
    const pm = S.uniiMod || mod;
    const items = pm ? this.uniiItems(pm) : [];
    const routeItem = this.uniiRouteItem(S.route);
    const itemId = routeItem || S.uniiItem || (items[0] || {}).id || null;
    const acts = pm ? UNII_ACTS.filter((a) => a.mod === pm) : [];
    const allowed = acts.filter((a) => this.uniiAllowed(a));
    const hidden = acts.filter((a) => this.uniiCfgOf(a).on && !this.uniiAllowed(a)).length;
    const roleLabel = (UNII_ROLES.find((x) => x[0] === (S.uniiRole || 'ds')) || [])[1];
    const applyLabel = { timeline: 'Ajouter à la chronologie', docinsert: 'Insérer dans le document', complan: 'Ajouter au plan éditorial', mobpage: 'Insérer dans la page', mobreplace: 'Remplacer le contenu', mobpush: 'Utiliser comme notification' };
    const msgs = (S.uniiMsgs || []).map((mm) => ({
      u: !!mm.u, b: !mm.u, text: mm.text, local: !!mm.local, canCopy: true, canContinue: true,
      canApply: !mm.u && !!mm.apply && (mm.apply === 'complan' || !!mm.itemId), applyLabel: applyLabel[mm.apply] || '', apply: () => this.uniiApply(mm),
      copy: () => { try { navigator.clipboard.writeText(mm.text); } catch (e) {} this.flash('Réponse copiée'); },
      cont: () => { this.setState({ uniiOpen: false }); this.toAssistant({ ctx: this.uniiCtx(pm, mm.itemId), origin: 'unii · ' + modLabel, title: mm.q || modLabel, route: S.route, messages: [{ isUser: true, text: mm.q }, { isBot: true, source: 'unii · ' + modLabel, text: mm.text }] }); }
    }));
    const swOf = (on) => ({ swBg: on ? 'var(--ok)' : 'var(--bd2)', swLeft: on ? '21px' : '3px' });
    const setCfg = (id, p) => this.setState((s) => { const c = Object.assign({}, s.uniiCfg || {}); c[id] = Object.assign({}, c[id] || {}, p); return { uniiCfg: c }; });
    const cfgMods = UNII_MODS.map((m) => {
      const list = UNII_ACTS.filter((a) => a.mod === m[0]);
      return {
        label: m[0] === 'adherents' ? W.memberNav : m[1], n: list.filter((a) => this.uniiCfgOf(a).on).length + ' / ' + list.length + ' actives', lot: ['dossiers', 'reunions', 'documents'].indexOf(m[0]) >= 0,
        acts: list.map((a) => {
          const c = this.uniiCfgOf(a);
          return Object.assign({
            id:a.id, label: a.label, desc: a.desc, on: c.on, toggle: () => setCfg(a.id, { on: !c.on }), tglLabel: c.on ? 'Désactiver' : 'Activer',
            scope: a.scope === 'item' ? 'Sur un élément' : 'Sur le module', hasApply: !!a.apply, applyLabel: applyLabel[a.apply] || '',
            allBg: !c.roles.length ? 'var(--acBg)' : 'var(--surface)', allFg: !c.roles.length ? 'var(--acTx)' : 'var(--ink5)', allBd: !c.roles.length ? 'var(--acBd)' : 'var(--bd2)', allGo: () => setCfg(a.id, { roles: [] }),
            roles: UNII_ROLES.map((rr) => { const on = c.roles.indexOf(rr[0]) >= 0; return { label: rr[1], bg: on ? 'var(--acBg)' : 'var(--surface)', fg: on ? 'var(--acTx)' : 'var(--ink5)', bd: on ? 'var(--acBd)' : 'var(--bd2)', go: () => setCfg(a.id, { roles: on ? c.roles.filter((x) => x !== rr[0]) : c.roles.concat([rr[0]]) }) }; }),
            rowOp: c.on ? '1' : '.55'
          }, swOf(c.on));
        })
      };
    });
    const nOn = UNII_ACTS.filter((a) => this.uniiCfgOf(a).on).length;
    return {
      enabled: !!mod, locked: locked, unlocked: !locked,
      btnLabel: 'unii', nSugg: suggs.length, hasSugg: suggs.length > 0,
      open: () => (S.uniiOpen ? this.setState({ uniiOpen: false }) : this.uniiOpen({ mod: mod || 'accueil' })),
      isOpen: !!S.uniiOpen, close: () => this.setState({ uniiOpen: false }),
      suggs: suggs.map((sg) => ({ text: sg.text, go: () => this.uniiOpen({ mod: sg.mod, itemId: sg.itemId, actId: sg.actId }) })),
      showStrip: suggs.length > 0 && r !== 'dossiers' && r !== 'assistant',
      ctxLabel: (pm ? (pm === 'adherents' ? W.memberNav : (UNII_MODS.find((x) => x[0] === pm) || [])[1]) : 'Accueil'),
      roleLabel: roleLabel,
      hasItems: items.length > 0 && !routeItem, itemOpts: items.map((x) => ({ v: x.id, label: x.label })), itemId: itemId || '', onItem: (e) => this.setState({ uniiItem: e.target.value }),
      itemFixed: !!routeItem, itemFixedLabel: routeItem ? ((items.find((x) => x.id === routeItem) || {}).label || '') : '',
      acts: allowed.map((a) => ({ disabled: !!S.uniiBusy, label: a.label, desc: a.desc, go: () => this.uniiRun(a.id) })), noActs: !allowed.length,
      hasHidden: hidden > 0, hiddenLabel: hidden + ' action' + (hidden > 1 ? 's' : '') + ' réservée' + (hidden > 1 ? 's' : '') + ' à d\'autres rôles',
      panelSuggs: (pm ? this.uniiSuggs(pm, r) : []).filter(() => pillsOn).map((sg) => ({ text: sg.text, go: () => this.uniiOpen({ mod: sg.mod, itemId: sg.itemId, actId: sg.actId }) })),
      hasPanelSuggs: pillsOn && !locked && !!pm && this.uniiSuggs(pm, r).length > 0,
      msgs: msgs, hasMsgs: msgs.length > 0, busy: !!S.uniiBusy,
      sendLabel: 'Envoyer', input: S.uniiIn || '', onIn: (e) => this.setState({ uniiIn: e.target.value }),
      onKey: (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); this.uniiRun(null, S.uniiIn); } },
      send: () => this.uniiRun(null, S.uniiIn),
      clear: () => this.setState({ uniiMsgs: [] }),
      goCfg: () => { this.setState({ uniiOpen: false }); this.go('unii'); },
      goPlans: () => { this.setState({ uniiOpen: false }); this.go('profil'); },
      cfg: {
        mods: cfgMods, count: nOn + ' actions actives sur ' + UNII_ACTS.length,
        planName: (PLANS.find((p) => p.id === S.plan) || PLANS[0]).nom, planOk: !locked,
        pillsOn: pillsOn, pillsSw: swOf(pillsOn), togglePills: () => this.setState({ uniiPills: !pillsOn }),
        roles: UNII_ROLES.map((rr) => { const on = (S.uniiRole || 'ds') === rr[0]; return { label: rr[1], on: on, bg: on ? 'linear-gradient(to right, var(--ac), var(--ac2))' : 'var(--surface)', fg: on ? '#FFFFFF' : 'var(--ink4)', bd: on ? 'transparent' : 'var(--bd2)', go: () => this.setState({ uniiRole: rr[0], uniiMsgs: [] }) }; }),
        custom: !!S.uniiCfg && Object.keys(S.uniiCfg).length > 0,
        reset: () => { this.setState({ uniiCfg: {} }); this.flash('Actions d\'unii réinitialisées'); }
      }
    };
  }
  comSeedKey() { return this.W().synd ? 'synd' : 'cse'; }
  mobList() { return this.state.mobPages || MOB_SEED; }
  mobSet(fn) { this.setState((s) => ({ mobPages: fn(s.mobPages || MOB_SEED) })); }
  mobPatch(id, fn) { this.mobSet((l) => l.map((p) => (p.id === id ? Object.assign({}, p, fn(p), { updated: 'à l\'instant' }) : p))); }
  mobSpace() { const W = this.W(); return W.synd ? 'Section syndicale FO' : 'Élus FO du CSE'; }
  mobSuggs() {
    const out = [];
    this.mobList().forEach((p) => {
      const txt = p.blocks.map((b) => b[1]).join(' ');
      if (p.status === 'Brouillon' && txt.length < 220) out.push({ id: p.id, act: 'mob-page', text: 'Page à compléter · ' + p.title, short: 'À compléter' });
      else if (p.pushOn && !p.push) out.push({ id: p.id, act: 'mob-push', text: 'Notification push à rédiger · ' + p.title, short: 'Push à rédiger' });
      else if (p.status === 'En relecture') out.push({ id: p.id, act: 'mob-check', text: 'À vérifier avant validation FO · ' + p.title, short: 'À vérifier' });
    });
    return out;
  }
  mobParse(txt) {
    return String(txt || '').replace(/\r/g, '').split(/\n\s*\n|\n(?=#)/).map((x) => x.trim()).filter(Boolean).slice(0, 10).map((x) => {
      const l = x.replace(/\*\*/g, '');
      if (/^#+\s*/.test(l)) return ['h', l.replace(/^#+\s*/, '')];
      if (/^\[?(bouton|cta)\]?\s*:/i.test(l)) return ['btn', l.replace(/^\[?(bouton|cta)\]?\s*:\s*/i, '')];
      if (l.length < 70 && !/[.!?:]$/.test(l) && l.indexOf('\n') < 0) return ['h', l];
      return ['p', l.replace(/^[-•]\s*/gm, '• ')];
    }).filter((b) => b[1]);
  }
  mobNew(tpl) {
    const id = 'mp' + Date.now();
    this.mobSet((l) => [{ id: id, title: tpl.type === 'Actualité' ? 'Nouvelle actualité' : tpl.type, type: tpl.type, status: 'Brouillon', aud: 'Tous les salariés', views: 0, updated: 'à l\'instant', pushOn: false, push: '', blocks: tpl.blocks.map((b) => b.slice()) }].concat(l));
    this.setState({ mobTab: 'edit', mobId: id, mobSubj: '' });
  }
  mobGenerate() {
    const S = this.state, p = this.mobList().find((x) => x.id === S.mobId); if (!p || S.mobBusy) return;
    if (S.plan === 'p1') return this.flash('unii est inclus à partir de l\'offre Élu 2.0');
    const subj = String(S.mobSubj || '').trim();
    if (!subj && p.blocks.length < 2) return this.flash('Décrivez en quelques mots ce que la page doit dire');
    const raw = 'Page de l\'application mobile FO\nÉmetteur : ' + this.mobSpace() + '\nType : ' + p.type + '\nPublic : ' + p.aud + '\nTitre actuel : ' + p.title + '\nÉléments fournis : ' + (subj || p.blocks.map((b) => b[1]).join(' / '));
    const mk = this.maskText(raw, this.detectLevel(raw));
    if (mk.residual.length) return this.flash('Envoi refusé — un identifiant échappe au filtre');
    this.setState((s) => ({ mobBusy: true, aiCalls: (s.aiCalls || 0) + 1 }));
    const SYS = "Tu es unii, assistant de communication de représentants Force Ouvrière (FO). Tu rédiges des pages publiées dans l'application mobile FO, lues sur téléphone par des salariés pressés. Règles : titre de 60 caractères maximum, paragraphes de trois lignes maximum, une idée par bloc, sigles expliqués, ton respectueux et factuel, aucune attaque nominative, aucune donnée personnelle, n'invente ni chiffre, ni date, ni lieu, ni contact absents de la demande (écris [à compléter]). Réponds UNIQUEMENT en JSON : {\"titre\": string, \"blocs\": [{\"type\": \"h\"|\"p\"|\"info\"|\"btn\", \"texte\": string}], \"push\": string (90 caractères max)}. 3 à 6 blocs, terminer par un bloc btn.";
    const unmask = (x) => { let o = String(x || ''); (mk.map || []).forEach((m) => { o = o.split(m[0]).join(m[1]); }); return o; };
    this.llmJson(SYS, mk.masked, 1000).then((r) => {
      if (!r || !Array.isArray(r.blocs) || !r.blocs.length) throw new Error('vide');
      const bl = r.blocs.filter((b) => b && MOB_KIND[b.type] && b.texte).map((b) => [b.type, unmask(b.texte)]);
      this.mobPatch(p.id, (q) => ({ title: unmask(r.titre || q.title).slice(0, 90), blocks: bl, push: q.push || unmask(r.push || '').slice(0, 120) }));
      this.setState({ mobBusy: false }); this.flash('Page proposée par unii — relisez avant envoi');
    }).catch(() => {
      const tpl = MOB_TPL.find((x) => x.type === p.type) || MOB_TPL[0];
      this.mobPatch(p.id, () => ({ blocks: (subj ? [['p', subj]] : []).concat(tpl.blocks.map((b) => b.slice())) }));
      this.setState({ mobBusy: false }); this.flash('Trame type chargée — IA indisponible');
    });
  }
  mobVals() {
    const S = this.state, W = this.W(), tab = S.mobTab || 'list', list = this.mobList();
    const pill = (on) => ({ bg: on ? 'var(--acBg)' : 'var(--surface)', fg: on ? 'var(--acTx)' : 'var(--ink4)', bd: on ? 'var(--acBd)' : 'var(--bd2)' });
    const segv = (on) => ({ bg: on ? 'var(--surface)' : 'transparent', fg: on ? 'var(--ink)' : 'var(--ink5)', sh: on ? '0 1px 3px rgba(0,0,0,.08)' : 'none' });
    const sg = this.mobSuggs(), pillsOn = S.uniiPills !== false && S.plan !== 'p1';
    const p = list.find((x) => x.id === S.mobId) || list[0];
    const isEdit = tab === 'edit' && !!p;
    const ask = (actId) => this.uniiOpen({ mod: 'mobile', itemId: p ? p.id : null, actId: actId });
    const tabs = [['list', 'Mes pages · ' + list.length], ['edit', isEdit ? 'Éditeur · ' + p.title.slice(0, 28) + (p.title.length > 28 ? '…' : '') : 'Éditeur']].map((x) => { const on = (isEdit ? 'edit' : 'list') === x[0]; return { label: x[1], on: on, bg: on ? 'linear-gradient(to right, var(--ac), var(--ac2))' : 'transparent', fg: on ? '#FFFFFF' : 'var(--ink4)', go: () => this.setState({ mobTab: x[0], mobId: S.mobId || (list[0] || {}).id }) }; });
    const online = list.filter((x) => x.status === 'En ligne');
    let e = { types: [], auds: [], blocks: [], adds: [], acts: [], steps: [] };
    if (isEdit) {
      const si = MOB_ST.indexOf(p.status), c = MOB_ST_C[p.status] || MOB_ST_C.Brouillon;
      const setB = (fn) => this.mobPatch(p.id, (q) => ({ blocks: fn(q.blocks.slice()) }));
      const ADV = { 'Brouillon': ['Envoyer en relecture', 'En relecture', 'Page envoyée en relecture à un second membre'], 'En relecture': ['Relecture validée — soumettre à FO', 'Validation FO', 'Page soumise à la validation de la fédération FO'], 'Validation FO': ['Simuler la validation FO', 'En ligne', 'Page en ligne dans l\'application FO'], 'En ligne': ['Retirer de l\'application', 'Brouillon', 'Page retirée de l\'application'] };
      const NOTE = { 'Brouillon': 'Seuls les membres de votre organisation voient ce brouillon. Envoyez-le en relecture quand il est prêt.', 'En relecture': 'Un second membre relit la page : exactitude, ton, données personnelles.', 'Validation FO': 'La fédération FO vérifie la conformité à la charte de l\'application avant mise en ligne (48 h ouvrées en moyenne).', 'En ligne': 'La page est visible dans l\'espace « ' + this.mobSpace() + ' » de l\'application FO. Toute modification repasse par la relecture.' };
      const adv = ADV[p.status] || ADV.Brouillon;
      e = {
        title: p.title, onTitle: (ev) => this.mobPatch(p.id, () => ({ title: ev.target.value })), titleView: p.title || 'Titre de la page',
        status: p.status, stBg: c[0], stFg: c[1], type: p.type, spaceName: this.mobSpace(),
        audView: 'Visible par : ' + p.aud.toLowerCase() + ' · mis à jour ' + p.updated,
        types: MOB_TPL.map((x) => Object.assign({ label: x.type, on: p.type === x.type, go: () => this.mobPatch(p.id, () => ({ type: x.type })) }, pill(p.type === x.type))),
        auds: MOB_AUD.map((x) => Object.assign({ label: x, on: p.aud === x, go: () => this.mobPatch(p.id, () => ({ aud: x })) }, segv(p.aud === x))),
        blocks: p.blocks.map((b, i) => ({ kind: MOB_KIND[b[0]], x: b[1], rows: b[0] === 'p' ? 3 : (b[0] === 'h' || b[0] === 'btn' ? 1 : 2), isH: b[0] === 'h', isP: b[0] === 'p', isInfo: b[0] === 'info', isContact: b[0] === 'contact', isBtn: b[0] === 'btn',
          on: (ev) => { const v = ev.target.value; setB((l) => { l[i] = [b[0], v]; return l; }); },
          up: () => setB((l) => { if (i > 0) { const t0 = l[i - 1]; l[i - 1] = l[i]; l[i] = t0; } return l; }),
          down: () => setB((l) => { if (i < l.length - 1) { const t0 = l[i + 1]; l[i + 1] = l[i]; l[i] = t0; } return l; }),
          del: () => setB((l) => l.filter((_, j) => j !== i)) })),
        adds: Object.keys(MOB_KIND).map((k) => ({ label: MOB_KIND[k], go: () => setB((l) => l.concat([[k, k === 'btn' ? 'En savoir plus' : '']])) })),
        subj: S.mobSubj || '', onSubj: (ev) => this.setState({ mobSubj: ev.target.value }),
        subjPh: W.synd ? 'Ex. Point d\'étape NAO : la direction propose 0,8 %, nous demandons 5 % et un rattrapage des bas coefficients. Prochaine réunion le 15 octobre.' : 'Ex. Billetterie de fin d\'année : ouverture le 9 octobre, 30 % pris en charge par le CSE, réservation dans l\'appli jusqu\'au 30 novembre.',
        busy: !!S.mobBusy, genLabel: S.mobBusy ? 'unii rédige…' : 'Générer la page',
        gen: () => this.mobGenerate(),
        acts: [['mob-short', 'Adapter au mobile'], ['mob-push', 'Proposer la notification']].map((a) => ({ label: a[1], go: () => ask(a[0]) })),
        pushOn: !!p.pushOn, swBg: p.pushOn ? 'var(--ok)' : 'var(--bd2)', swLeft: p.pushOn ? '21px' : '3px',
        togglePush: () => this.mobPatch(p.id, (q) => ({ pushOn: !q.pushOn })),
        push: p.push || '', onPush: (ev) => this.mobPatch(p.id, () => ({ push: ev.target.value.slice(0, 120) })),
        pushCount: (p.push || '').length + ' / 120 caractères', pushView: p.push || 'Votre notification apparaîtra ici.',
        steps: MOB_ST.map((s, i) => ({ label: s, bar: i <= si ? 'linear-gradient(to right, var(--ac), var(--ac2))' : 'var(--bd)', fg: i === si ? 'var(--ink)' : 'var(--ink5)', fw: i === si ? '700' : '500' })),
        stepNote: NOTE[p.status], advLabel: adv[0],
        advance: () => { if (adv[1] === 'Validation FO' || adv[1] === 'En relecture') { if (!p.title.trim() || !p.blocks.length) return this.flash('Ajoutez un titre et du contenu avant l\'envoi'); if (p.pushOn && !p.push) return this.flash('Rédigez la notification push ou désactivez-la'); } this.mobPatch(p.id, () => ({ status: adv[1], views: adv[1] === 'En ligne' ? 0 : p.views })); this.flash(adv[2]); },
        check: () => ask('mob-check')
      };
    }
    return {
      intro: 'Créez les pages de votre organisation publiées dans l\'application mobile FO : actualités, permanences, contacts, droits. Les ' + (W.synd ? 'adhérents et salariés' : 'salariés') + ' les retrouvent dans l\'espace « ' + this.mobSpace() + ' ». unii rédige, vous validez, la fédération publie.',
      kpis: [[online.length, 'pages en ligne'], [list.filter((x) => x.status !== 'En ligne').length, 'en préparation'], [online.reduce((a, x) => a + (x.views || 0), 0), 'vues ce mois']].map((k) => ({ v: String(k[0]), l: k[1] })),
      tabs: tabs, isList: !isEdit, isEdit: isEdit,
      spaceLabel: 'Espace « ' + this.mobSpace() + ' » dans l\'application FO',
      pages: list.map((x) => {
        const c = MOB_ST_C[x.status] || MOB_ST_C.Brouillon, s = pillsOn ? sg.find((y) => y.id === x.id) : null;
        return { title: x.title, type: x.type, status: x.status, stBg: c[0], stFg: c[1],
          meta: x.aud + ' · ' + x.blocks.length + ' bloc' + (x.blocks.length > 1 ? 's' : '') + ' · mis à jour ' + x.updated + (x.status === 'En ligne' ? ' · ' + x.views + ' vues' : ''),
          hasSugg: !!s, suggText: s ? s.text : '', suggShort: s ? s.short : '',
          sugg: () => s && this.uniiOpen({ mod: 'mobile', itemId: x.id, actId: s.act }),
          edit: () => this.setState({ mobTab: 'edit', mobId: x.id, mobSubj: '' }),
          del: this.askDel('mob-' + x.id, 'Supprimer', () => { this.mobSet((l) => l.filter((y) => y.id !== x.id)); this.flash('Page supprimée'); }) };
      }),
      tpls: MOB_TPL.map((x) => ({ label: x.type, desc: x.desc, go: () => this.mobNew(x) })),
      askIdeas: () => this.uniiOpen({ mod: 'mobile', actId: 'mob-ideas' }),
      back: () => this.setState({ mobTab: 'list' }),
      e: e
    };
  }
  comPlanList() { return this.state.comPlan || COM_SEED[this.comSeedKey()]; }
  comSetPlan(fn) { this.setState((s) => ({ comPlan: fn(s.comPlan || COM_SEED[this.comSeedKey()]) })); }
  comCanaux() { const W = this.W(); return ['Intranet', W.synd ? 'E-mail aux adhérents' : 'E-mail aux salariés', W.synd ? 'Page de la section' : 'Page du CSE', 'LinkedIn', 'Affichage sur site', 'Application uniion']; }
  comFallback(f) {
    const W = this.W(), inst = W.synd ? 'votre section' : 'votre CSE', who = W.synd ? 'vos représentants syndicaux' : 'vos élus';
    const sujet = String(f.sujet || '').trim();
    const ap = { Informer: 'Une question ? Passez nous voir ou écrivez-nous depuis l\'application.', 'Fédérer': 'Inscrivez-vous dès maintenant, on compte sur vous.', Valoriser: 'Toutes les infos et les réservations sur l\'intranet.', Engager: 'Répondez en deux minutes depuis l\'application.' };
    return {
      titre: sujet || 'Votre information du mois',
      accroche: (f.obj === 'Informer' ? 'Ce qu\'il faut retenir, en clair.' : f.obj === 'Engager' ? 'Votre avis fait la différence.' : f.obj === 'Valoriser' ? 'Ce que ' + inst + ' fait pour vous.' : 'Un rendez-vous pour se retrouver.'),
      corps: sujet + ' : ' + who + ' vous résument l\'essentiel. Trois points à retenir, les dates utiles et ce que cela change pour vous au quotidien. [Complétez avec les éléments du dossier ou du PV.]',
      appel: ap[f.obj] || ap.Informer,
      visuel: f.fmt === 'Affiche / flyer' ? 'Format A3 vertical, titre en très gros, une seule date mise en avant, logo de l\'instance en pied.' : 'Photo d\'équipe ou pictogramme simple, titre court en surimpression, couleurs de l\'identité.',
      local: true
    };
  }
  comGenerate() {
    const S = this.state, f = Object.assign({ fmt: 'Post réseau social', obj: 'Informer', ton: 'Direct', canal: this.comCanaux()[0], sujet: '' }, S.comF);
    const sujet = String(f.sujet || '').trim();
    if (!sujet) return this.flash('Décrivez le sujet de la publication');
    const W = this.W();
    const raw = 'Format : ' + f.fmt + '\nCanal : ' + f.canal + '\nObjectif : ' + f.obj + '\nTon : ' + f.ton + '\nÉmetteur : ' + (W.synd ? 'section syndicale' : 'CSE (élus du comité social et économique)') + '\nPublic : ' + (W.synd ? 'salariés et adhérents' : 'salariés de l\'entreprise') + '\nSujet et éléments : ' + sujet;
    const mk = this.maskText(raw, this.detectLevel(raw));
    if (mk.residual.length) return this.flash('Envoi refusé — un identifiant échappe au filtre');
    this.setState((s) => ({ comBusy: true, aiCalls: (s.aiCalls || 0) + 1 }));
    const SYS = "Tu es unii, chargé de communication pour des élus de CSE et des représentants syndicaux français. Tu écris pour des salariés qui n'ont pas le temps : phrases courtes, concret, utile. Vocabulaire juste du CSE : élus, salariés, réunion plénière, procès-verbal (PV), activités sociales et culturelles (ASC), budget de fonctionnement, NAO, BDESE, commission SSCT ; explique tout sigle à sa première occurrence. Règles : neutralité et respect, aucune attaque nominative de la direction ni de salariés, aucune donnée personnelle, n'invente ni chiffre ni date absents de la demande (écris [à compléter]). Adapte la longueur au format (post : 60 à 110 mots ; article ou newsletter : 150 à 250 mots ; affiche : 25 mots maximum ; script vidéo : 6 à 8 plans courts ; sondage : intro et 3 questions). Le texte est anonymisé : conserve les jetons entre crochets. Texte brut sans markdown. Réponds uniquement par un objet JSON : {\"titre\":\"…\",\"accroche\":\"…\",\"corps\":\"…\",\"appel\":\"appel à l'action\",\"visuel\":\"conseil de visuel en une phrase\"}";
    this.llmJson(SYS, mk.masked, 1200).then((r) => {
      if (!r || !r.corps) throw new Error('vide');
      this.setState({ comBusy: false, comOut: { titre: String(r.titre || sujet), accroche: String(r.accroche || ''), corps: String(r.corps), appel: String(r.appel || ''), visuel: String(r.visuel || '') } });
      this.flash('Proposition prête — relisez avant diffusion');
    }).catch(() => { this.setState({ comBusy: false, comOut: this.comFallback(f) }); this.flash('Trame type chargée — IA indisponible'); });
  }
  comToPlan() {
    const S = this.state, o = S.comOut; if (!o) return;
    const f = Object.assign({ fmt: 'Post réseau social', obj: 'Informer', canal: this.comCanaux()[0] }, S.comF);
    const date = f.date || '2026-10-16';
    if (S.comEditId) {
      this.comSetPlan((l) => l.map((x) => (x.id === S.comEditId ? Object.assign({}, x, { title: o.titre || x.title, fmt: f.fmt, canal: f.canal, obj: f.obj, date: date, content: o, st: x.st === 'Idée' || x.st === 'Brouillon' ? 'À valider' : x.st }) : x)));
      this.flash('Publication mise à jour dans le plan éditorial');
    } else {
      this.comSetPlan((l) => l.concat([{ id: 'c' + Date.now(), date: date, title: o.titre, fmt: f.fmt, canal: f.canal, obj: f.obj, st: 'À valider', content: o }]));
      this.flash('Ajouté au plan éditorial — à valider par le bureau');
    }
    this.setState({ comTab: 'plan', comOut: null, comEditId: null, comF: {} });
  }
  comVals() {
    const S = this.state, W = this.W(), tab = S.comTab || 'plan', sk = this.comSeedKey();
    const pill = (on) => ({ bg: on ? 'var(--acBg)' : 'var(--surface)', fg: on ? 'var(--acTx)' : 'var(--ink4)', bd: on ? 'var(--acBd)' : 'var(--bd2)' });
    const segv = (on) => ({ bg: on ? 'var(--surface)' : 'transparent', fg: on ? 'var(--ink)' : 'var(--ink5)', sh: on ? '0 1px 3px rgba(0,0,0,.08)' : 'none' });
    const plan = this.comPlanList().slice().sort((a, b) => (a.date < b.date ? -1 : 1));
    const flt = S.comFilter || 'Tous';
    const WD = ['Dim.', 'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.'], MO = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    const f = Object.assign({ fmt: 'Post réseau social', obj: 'Informer', ton: 'Direct', canal: this.comCanaux()[0], sujet: '', date: new Date().toISOString().slice(0, 10) }, S.comF);
    const setF = (p) => this.setState((s) => ({ comF: Object.assign({}, s.comF, p) }));
    const tabs = [['plan', 'Plan éditorial', plan.length], ['atelier', 'Atelier de contenus', 0], ['pole', 'Pôle communication', 0]].map((x) => { const on = tab === x[0]; return { label: x[1], n: x[2], hasN: !!x[2], on: on, bg: on ? 'linear-gradient(to right, var(--ac), var(--ac2))' : 'transparent', fg: on ? '#FFFFFF' : 'var(--ink4)', nBg: on ? 'rgba(255,255,255,.22)' : 'var(--surf2)', go: () => this.setState({ comTab: x[0] }) }; });
    const rows = plan.filter((x) => flt === 'Tous' || x.st === flt).map((x) => {
      const d = new Date(x.date + 'T12:00:00'), c = COM_ST_C[x.st] || COM_ST_C['Idée'];
      const nx = COM_ST[(COM_ST.indexOf(x.st) + 1) % COM_ST.length];
      return {
        day: String(d.getDate()), wd: WD[d.getDay()], mo: MO[d.getMonth()], title: x.title, meta: x.fmt + ' · ' + x.canal, obj: x.obj, st: x.st, stBg: c[0], stFg: c[1],
        hasContent: !!x.content, excerpt: x.content ? String(x.content.accroche || x.content.corps || '').slice(0, 140) : '',
        next: () => { this.comSetPlan((l) => l.map((y) => (y.id === x.id ? Object.assign({}, y, { st: nx }) : y))); this.flash('« ' + x.title + ' » → ' + nx); },
        nextLabel: 'Passer à « ' + nx + ' »',
        write: () => this.setState({ comTab: 'atelier', comEditId: x.id, comOut: x.content || null, comF: { fmt: COM_FMT.indexOf(x.fmt) >= 0 ? x.fmt : 'Post réseau social', canal: x.canal, obj: x.obj, ton: 'Direct', sujet: x.title, date: x.date } }),
        writeLabel: x.content ? 'Ouvrir le texte' : 'Rédiger avec unii',
        del: this.askDel('com-' + x.id, 'Retirer', () => { this.comSetPlan((l) => l.filter((y) => y.id !== x.id)); this.flash('Publication retirée du plan'); })
      };
    });
    const cnt = (s) => plan.filter((x) => x.st === s).length;
    const o = S.comOut, editing = !!S.comEditId;
    const fsel = S.comFormule || 'premium';
    const req = S.comReq;
    return {
      tabs: tabs, isPlan: tab === 'plan', isAtelier: tab === 'atelier', isPole: tab === 'pole',
      intro: W.synd ? 'Planifiez, rédigez et diffusez la communication de la section vers les salariés et les adhérents. unii accélère l\'écriture, l\'équipe uniion peut prendre le relais.' : 'Planifiez, rédigez et diffusez la communication des élus vers les salariés : comptes rendus de plénière, ASC, NAO, temps forts. unii accélère l\'écriture, l\'équipe uniion peut prendre le relais.',
      filters: ['Tous'].concat(COM_ST).map((s) => Object.assign({ label: s === 'Tous' ? 'Tout · ' + plan.length : s + ' · ' + cnt(s), on: flt === s, go: () => this.setState({ comFilter: s }) }, pill(flt === s))),
      rows: rows, noRows: !rows.length,
      toValidate: cnt('À valider'), hasToValidate: cnt('À valider') > 0, toValidateLabel: cnt('À valider') + ' publication' + (cnt('À valider') > 1 ? 's' : '') + ' en attente de validation du bureau',
      moments: COM_MOMENTS[sk].map((m) => ({ label: m, add: () => { this.comSetPlan((l) => l.concat([{ id: 'c' + Date.now(), date: '2026-10-30', title: m, fmt: 'Post réseau social', canal: this.comCanaux()[0], obj: 'Informer', st: 'Idée' }])); this.flash('« ' + m + ' » ajouté au plan en idée'); }, write: () => this.setState({ comTab: 'atelier', comEditId: null, comOut: null, comF: { sujet: m } }) })),
      newPost: () => this.setState({ comTab: 'atelier', comEditId: null, comOut: null, comF: {} }),
      resetPlan: () => { this.setState({ comPlan: null, comFilter: 'Tous' }); this.flash('Plan éditorial d\'exemple restauré'); },
      planCustom: !!S.comPlan,
      f: {
        editing: editing, heading: editing ? 'Rédiger une publication du plan' : 'Nouvelle publication',
        fmts: COM_FMT.map((x) => Object.assign({ label: x, on: f.fmt === x, go: () => setF({ fmt: x }) }, pill(f.fmt === x))),
        objs: COM_OBJ.map((x) => Object.assign({ label: x[0], hint: x[1], on: f.obj === x[0], go: () => setF({ obj: x[0] }) }, segv(f.obj === x[0]))),
        objHint: (COM_OBJ.find((x) => x[0] === f.obj) || COM_OBJ[0])[1],
        tons: ['Direct', 'Chaleureux', 'Institutionnel'].map((x) => Object.assign({ label: x, on: f.ton === x, go: () => setF({ ton: x }) }, segv(f.ton === x))),
        canaux: this.comCanaux().map((x) => Object.assign({ label: x, on: f.canal === x, go: () => setF({ canal: x }) }, pill(f.canal === x))),
        sujet: f.sujet, onSujet: (e) => setF({ sujet: e.target.value }),
        sujetPh: W.synd ? 'Ex. Compte rendu de la réunion CSE du 29 septembre : nos trois interventions sur les horaires d\'équipe et la prime d\'intéressement.' : 'Ex. Résumé de la plénière du 29 septembre : budget ASC 2027 voté, nouvelle mutuelle au 1er janvier, prochaine réunion le 27 octobre.',
        sugg: COM_MOMENTS[sk].slice(0, 5).map((m) => ({ label: m, go: () => setF({ sujet: m }) })),
        date: f.date, onDate: (e) => setF({ date: e.target.value }),
        busy: !!S.comBusy, genLabel: S.comBusy ? 'unii rédige…' : (o ? 'Proposer une autre version' : 'Rédiger avec unii'), gen: () => this.comGenerate(),
        cancel: () => this.setState({ comTab: 'plan', comEditId: null, comOut: null, comF: {} })
      },
      hasOut: !!o, noOut: !o && !S.comBusy, outBusy: !!S.comBusy,
      out: o ? {
        titre: o.titre, onTitre: (e) => { const v = e.target.value; this.setState((s) => ({ comOut: Object.assign({}, s.comOut, { titre: v }) })); },
        accroche: o.accroche, onAccroche: (e) => { const v = e.target.value; this.setState((s) => ({ comOut: Object.assign({}, s.comOut, { accroche: v }) })); },
        corps: o.corps, onCorps: (e) => { const v = e.target.value; this.setState((s) => ({ comOut: Object.assign({}, s.comOut, { corps: v }) })); },
        appel: o.appel, onAppel: (e) => { const v = e.target.value; this.setState((s) => ({ comOut: Object.assign({}, s.comOut, { appel: v }) })); },
        visuel: o.visuel, hasVisuel: !!o.visuel, local: !!o.local,
        meta: f.fmt + ' · ' + f.canal + ' · ' + f.obj,
        toPlan: () => this.comToPlan(), toPlanLabel: editing ? 'Mettre à jour dans le plan' : 'Ajouter au plan éditorial',
        copy: () => { const txt = [o.titre, o.accroche, o.corps, o.appel].filter(Boolean).join('\n\n'); try { navigator.clipboard.writeText(txt); } catch (e) {} this.flash('Texte copié'); },
        pole: () => { this.flash('Texte transmis au pôle communication uniion pour mise en forme — retour sous 48 h ouvrées'); }
      } : { titre: '', accroche: '', corps: '', appel: '', visuel: '' },
      formules: COM_FORMULES.map((x) => { const on = fsel === x.id; return { name: x.name, promise: x.promise, rows: x.rows.map((r) => ({ k: r[0], v: r[1] })), plus: x.plus, on: on, bd: on ? 'var(--ac)' : 'var(--bd)', bg: on ? 'var(--acBg)' : 'var(--surface)', btnLabel: on ? 'Formule choisie ✓' : 'Choisir ' + x.name, btnBg: on ? 'linear-gradient(to right, var(--ac), var(--ac2))' : 'var(--surf2)', btnFg: on ? '#FFFFFF' : 'var(--ink3)', dedicated: x.id !== 'essentiel', go: () => this.setState({ comFormule: x.id }) }; }),
      socle: ['Calendrier éditorial mensuel', 'Visuels et contenus créés pour vous', 'Messages adaptés à vos salariés', 'Image de votre mandat sécurisée : hébergement en France, conformité RGPD', 'Interlocuteur dédié (sauf formule Essentiel)'].map((x) => ({ t: x })),
      inclus: ['Réseaux sociaux pilotés', 'Calendrier éditorial', 'Contenus et visuels', 'Modération', 'Reporting', 'Vidéos et témoignages', 'Animation de communauté', 'Veille e-réputation'].map((x) => ({ t: x })),
      supports: COM_SUPPORTS.map((x, k) => ({ n: '0' + (k + 1), t: x[0], d: x[1] })),
      approche: COM_OBJ.map((x) => ({ t: x[0], d: x[1] })),
      formuleName: (COM_FORMULES.find((x) => x.id === fsel) || {}).name,
      note: S.comNote || '', onNote: (e) => this.setState({ comNote: e.target.value }),
      notePh: W.synd ? 'Vos temps forts : NAO, campagne d\'adhésion, élections professionnelles, AG…' : 'Vos temps forts : billetterie de fin d\'année, chèques de Noël, journée bien-être, élections professionnelles…',
      hasReq: !!req, noReq: !req,
      reqLine: req ? 'Formule ' + req.formule + ' · demande du ' + req.at : '',
      reqNote: req ? req.note : '', hasReqNote: !!(req && req.note),
      send: () => { const n = (COM_FORMULES.find((x) => x.id === fsel) || {}).name; this.setState({ comReq: { formule: n, note: String(S.comNote || '').trim(), at: '2 octobre 2026' }, comNote: '' }); this.flash('Demande transmise au pôle communication uniion — rappel sous 48 h ouvrées'); },
      reqEdit: () => this.setState({ comReq: null, comNote: (req && req.note) || '' }),
      people: W.synd ? 'représentants syndicaux' : 'élus'
    };
  }
  fmVals() {
    const S = this.state, tab = S.fmTab || 'ia';
    const q = String(S.fmQ || '').trim().toLowerCase();
    const req = S.fmReq || {};
    const hit = (s) => !q || s.toLowerCase().indexOf(q) >= 0;
    const pill = (on) => ({ bg: on ? 'var(--acBg)' : 'var(--surface)', fg: on ? 'var(--acTx)' : 'var(--ink4)', bd: on ? 'var(--acBd)' : 'var(--bd2)' });
    const nIa = FM_IA.reduce((n, s) => n + s.items.length, 0);
    const tabs = [['ia', 'Catalogue IA', nIa], ['gen', 'Formations généralistes', FM_GEN.length], ['unii', 'Se former avec unii', (S.fmSessions || []).length]].map((x) => { const on = tab === x[0]; return { label: x[1], n: x[2], hasN: !!x[2], on: on, bg: on ? 'linear-gradient(to right, var(--ac), var(--ac2))' : 'transparent', fg: on ? '#FFFFFF' : 'var(--ink4)', nBg: on ? 'rgba(255,255,255,.22)' : 'var(--surf2)', go: () => this.setState({ fmTab: x[0], fmQ: '' }) }; });
    const ty = S.fmType || 'Tous';
    const iaSections = FM_IA.map((s, si) => ({ num: s.num, title: s.title, sub: s.sub, items: s.items.map((it, ii) => ({ it: it, k: 'ia' + si + '-' + ii })).filter((x) => (ty === 'Tous' || x.it.type === ty) && hit(x.it.title + ' ' + x.it.pub + ' ' + x.it.obj.join(' '))).map((x) => {
      const c = FM_TYPE_C[x.it.type] || ['var(--chip)', 'var(--ink4)'];
      return { type: x.it.type, typeBg: c[0], typeFg: c[1], dur: x.it.dur, title: x.it.title, pub: x.it.pub, obj: x.it.obj.map((o) => ({ t: o })), reqLabel: req[x.k] ? 'Demande locale ✓' : 'Demander une session', reqFg: req[x.k] ? 'var(--okTx)' : 'var(--ink3)', req: () => this.fmRequest(x.k, x.it.title), unii: () => this.fmPrefill(x.it.title + ' — ' + x.it.obj.join(' ; '), this.fmGuessDur(x.it.dur)) };
    }) })).filter((s) => s.items.length);
    const cat = S.fmCat || 'Toutes', mode = S.fmMode || 'all';
    const cats = ['Toutes'].concat(FM_GEN.map((g) => g.cat).filter((v, i, a) => a.indexOf(v) === i));
    const gen = FM_GEN.map((g, gi) => ({ g: g, k: 'gen' + gi })).filter((x) => (cat === 'Toutes' || x.g.cat === cat) && (mode === 'all' || (mode === 'oblig' && x.g.oblig) || (mode === 'inter' && x.g.mode.indexOf('INTER') >= 0) || (mode === 'intra' && x.g.mode === 'INTRA')) && hit(x.g.title + ' ' + x.g.desc + ' ' + x.g.cat));
    const st = S.fmSetup || {};
    const setSt = (p) => this.setState((s) => ({ fmSetup: Object.assign({}, s.fmSetup, p) }));
    const segv = (on) => ({ bg: on ? 'var(--surface)' : 'transparent', fg: on ? 'var(--ink)' : 'var(--ink5)' });
    const nM = this.fmNMods(st.dur);
    const sessions = (S.fmSessions || []).map((x) => { const d = (x.done || []).filter(Boolean).length; return { title: x.title, meta: x.created + ' · ' + this.fmDurLabel(x.dur) + ' · ' + x.level + (x.finished ? ' · terminée' : ' · module ' + (x.cur + 1) + '/' + x.modules.length), pct: (x.finished ? 100 : Math.round(d / x.modules.length * 100)) + '%', open: () => this.setState({ fmSessId: x.id, fmChat: '' }), del: this.askDel('fs-' + x.id, 'Supprimer', () => this.setState((s) => ({ fmSessions: s.fmSessions.filter((y) => y.id !== x.id) }))) }; });
    const sess = this.curFm();
    const out = {
      tabs: tabs, isIa: tab === 'ia', isGen: tab === 'gen', isUnii: tab === 'unii', showSearch: tab !== 'unii',
      q: S.fmQ || '', onQ: (e) => this.setState({ fmQ: e.target.value }),
      iaTypes: ['Tous', 'Sensibilisation', 'Atelier', 'Atelier métier', 'Cas pratique', 'Parcours avancé'].map((x) => Object.assign({ label: x, on: ty === x, go: () => this.setState({ fmType: x }) }, pill(ty === x))),
      iaSections: iaSections, iaNone: !iaSections.length,
      parcours: FM_PARCOURS.map((p) => ({ lvl: p.lvl, name: p.name, items: p.items.join(' · '), unii: () => this.fmPrefill('Parcours ' + p.lvl + ' ' + p.name + ' : ' + p.items.join(', '), 120) })),
      formats: FM_FORMATS.map((f) => ({ a: f[0], b: f[1], c: f[2] })),
      genCats: cats.map((x) => Object.assign({ label: x, on: cat === x, go: () => this.setState({ fmCat: x }) }, pill(cat === x))),
      genModes: [['all', 'Tous formats'], ['oblig', 'Obligatoires · agréées DREETS'], ['inter', 'Inter-entreprises possible'], ['intra', 'Intra uniquement']].map((x) => Object.assign({ label: x[1], on: mode === x[0], go: () => this.setState({ fmMode: x[0] }) }, pill(mode === x[0]))),
      gen: gen.map((x) => ({ cat: x.g.cat, title: x.g.title, dur: x.g.dur, mode: x.g.mode, desc: x.g.desc, oblig: x.g.oblig, reqLabel: req[x.k] ? 'Demande locale ✓' : 'Demander une session', reqFg: req[x.k] ? 'var(--okTx)' : 'var(--ink3)', req: () => this.fmRequest(x.k, x.g.title), unii: () => this.fmPrefill(x.g.title + ' — ' + x.g.desc, this.fmGuessDur(x.g.dur)) })),
      genNone: !gen.length, genCount: gen.length + ' formation' + (gen.length > 1 ? 's' : '') + ' · ' + FM_GEN.filter((g) => g.oblig).length + ' obligatoires agréées DREETS',
      busy: !!S.fmBusy, busyLabel: 'Parcours de ' + nM + ' modules sur « ' + (st.theme || '') + ' », calibré pour ' + this.fmDurLabel(st.dur || 30) + ' au niveau ' + (st.level || '') + '. Vos informations sont anonymisées avant l\'envoi.',
      showSetup: tab === 'unii' && !S.fmBusy && !sess, inSession: !S.fmBusy && !!sess,
      setup: {
        theme: st.theme || '', onTheme: (e) => setSt({ theme: e.target.value }),
        sugg: FM_SUGG.map((x) => ({ label: x, go: () => setSt({ theme: x }) })),
        durs: [15, 30, 60, 120, 180].map((d) => Object.assign({ label: this.fmDurLabel(d), on: st.dur === d, go: () => setSt({ dur: d }) }, segv(st.dur === d))),
        levels: ['Découverte', 'Intermédiaire', 'Confirmé'].map((l) => Object.assign({ label: l, on: st.level === l, go: () => setSt({ level: l }) }, segv(st.level === l))),
        roles: ['Élu·e CSE', 'Secrétaire', 'Trésorier·e', 'Élu·e SSCT', 'Délégué·e syndical·e', 'Référent·e harcèlement', 'Adhérent·e'].map((r) => Object.assign({ label: r, on: st.role === r, go: () => setSt({ role: r }) }, pill(st.role === r))),
        goal: st.goal || '', onGoal: (e) => setSt({ goal: e.target.value }),
        start: () => this.fmStart(), startLabel: 'Démarrer la session', plan: nM + ' modules · environ ' + Math.round((st.dur || 30) / nM) + ' min chacun'
      },
      how: [
        'Choisissez un thème — librement ou depuis un catalogue — et le temps dont vous disposez.',
        'unii construit un parcours adapté à votre niveau et à votre rôle, découpé en modules courts.',
        'Chaque module : cours, cas concret, exercice relu par unii et quiz de contrôle.',
        'À la fin : synthèse à retenir et attestation de suivi. Votre progression est sauvegardée.'
      ].map((x, k) => ({ n: k + 1, t: x })),
      sessions: sessions, noSessions: !sessions.length
    };
    if (sess) {
      const N = sess.modules.length, i = Math.min(sess.cur, N - 1), md = sess.modules[i];
      const done = (sess.done || []).filter(Boolean).length;
      const a = (sess.ans || {})[i], answered = a !== undefined && a !== null, ok = answered && a === md.quiz.answer;
      const quizTot = Object.keys(sess.ans || {}).length, quizOk = Object.keys(sess.ans || {}).filter((k) => sess.ans[k] === (sess.modules[k] || {}).quiz.answer).length;
      out.s = {
        title: sess.title, meta: this.fmDurLabel(sess.dur) + ' · ' + sess.level + ' · ' + sess.role, pct: (sess.finished ? 100 : Math.round(done / N * 100)) + '%', local: !!sess.local,
        intro: sess.intro || '', showIntro: i === 0 && !!sess.intro && !done,
        plan: sess.modules.map((m, k) => { const on = k === i && !sess.finished, dn = !!sess.done[k]; return { title: m.title, min: m.minutes + ' min', mark: dn ? '✓' : String(k + 1), bg: on ? 'var(--acBg)' : 'transparent', dotBg: dn ? 'var(--ok)' : (on ? 'var(--ac)' : 'var(--surf2)'), dotFg: dn || on ? '#FFFFFF' : 'var(--ink5)', w: on ? '700' : '500', go: () => this.fmPatch(sess.id, () => ({ cur: k, finished: false })) }; }),
        notDone: !sess.finished, finished: !!sess.finished,
        m: {
          n: 'Module ' + (i + 1) + ' sur ' + N + ' · ' + md.minutes + ' min', title: md.title, objectif: md.objectif, points: md.points, hasEx: !!md.exemple, exemple: md.exemple, exercice: md.exercice,
          exDraft: (sess.ex || {})[i] || '', onEx: (e) => { const v = e.target.value; this.fmPatch(sess.id, (x) => ({ ex: Object.assign({}, x.ex, { [i]: v }) })); },
          review: () => this.fmReview(), reviewLabel: S.fmRevBusy ? 'Relecture en cours…' : 'Faire relire par unii', fb: (sess.fb || {})[i] || '', hasFb: !!(sess.fb || {})[i],
          quizQ: md.quiz.q,
          choices: md.quiz.choices.map((c, ci) => { const good = ci === md.quiz.answer, mine = ci === a; return { label: String.fromCharCode(65 + ci) + '.  ' + c, bg: answered ? (good ? 'var(--okBg)' : (mine ? 'var(--dangerBg)' : 'var(--surface)')) : 'var(--surface)', bd: answered ? (good ? 'var(--ok)' : (mine ? 'var(--dangerTx2)' : 'var(--bd)')) : 'var(--bd2)', fg: 'var(--ink2)', go: () => { if (!answered) this.fmPatch(sess.id, (x) => ({ ans: Object.assign({}, x.ans, { [i]: ci }) })); } }; }),
          answered: answered, verdict: ok ? 'Bonne réponse' : 'Pas tout à fait', vFg: ok ? 'var(--okTx)' : 'var(--dangerTx2)', vBg: ok ? 'var(--okBg)' : 'var(--dangerBg)', explain: md.quiz.explain || ''
        },
        hasPrev: i > 0, prev: () => this.fmPatch(sess.id, (x) => ({ cur: Math.max(0, x.cur - 1) })),
        nextLabel: i === N - 1 ? 'Terminer la session' : 'Module suivant →',
        next: () => { this.fmPatch(sess.id, (x) => { const dn = x.done.slice(); dn[i] = true; return i === N - 1 ? { done: dn, finished: true } : { done: dn, cur: i + 1 }; }); if (typeof window !== 'undefined') window.scrollTo(0, 0); },
        score: 'Quiz : ' + quizOk + ' bonne' + (quizOk > 1 ? 's' : '') + ' réponse' + (quizOk > 1 ? 's' : '') + ' sur ' + quizTot + ' · ' + N + ' modules suivis · ' + this.fmDurLabel(sess.dur),
        retenir: (sess.retenir.length ? sess.retenir : sess.modules.map((m) => m.objectif)).map((x) => ({ t: x })), sources: sess.sources || '', hasSources: !!sess.sources,
        attest: () => this.downloadAttestation(sess),
        restart: () => this.fmPatch(sess.id, () => ({ cur: 0, finished: false })),
        quit: () => this.setState({ fmSessId: null }),
        toCat: () => this.setState({ fmSessId: null, fmTab: 'gen', fmQ: '' }),
        chat: (sess.chat || []).map((c) => ({ isU: !!c.u, isB: !c.u, text: c.text })),
        chatDraft: S.fmChat || '', onChat: (e) => this.setState({ fmChat: e.target.value }), onChatKey: (e) => { if (e.key === 'Enter') this.fmAsk(); }, sendChat: () => this.fmAsk(), chatBusy: !!S.fmChatBusy
      };
    } else out.s = { plan: [], m: { points: [], choices: [] }, retenir: [], chat: [] };
    return out;
  }

  /* ---- Messagerie : contacts, groupes, diffusions ---- */
  
  allContacts() {
    const own = this.state.contacts || CONTACTS;
    const adh = (this.state.adherents || []).map((a) => { const n = (a.prenom || '') + ' ' + (a.nom || ''); return { id: 'adh-' + a.id, adhId: a.id, name: n.trim(), initials: a.initials || this.initialsOf(n), role: a.poste || 'Adhérent·e', cat: 'adherent', tel: a.tel || '', email: a.email || '' }; });
    return own.concat(adh);
  }
  
  hashIdx(s, n) { let h = 0; String(s || '').split('').forEach((ch) => { h = (h * 31 + ch.charCodeAt(0)) >>> 0; }); return h % n; }
  initialsOf(name) { const p = String(name || '').trim().split(/\s+/).filter(Boolean); if (!p.length) return '?'; return ((p[0][0] || '') + (p.length > 1 ? p[p.length - 1][0] : (p[0][1] || ''))).toUpperCase(); }
  
  nowTime() { const d = new Date(); return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'); }
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  /*@method:cases:msgToDossier*/
  
  
  
  swv(on) { return { bg: on ? 'var(--ac)' : 'var(--bd2)', left: on ? '23px' : '3px' }; }

  
  
  ctmVals() {
    const e = this.state.ctEdit;
    if (!e) return { open: false, del: {}, cats: [] };
    const set = (p) => this.setState((s) => ({ ctEdit: Object.assign({}, s.ctEdit, p) }));
    return {
      open: true, title: e.id ? 'Modifier le contact' : 'Nouveau contact',
      name: e.name, role: e.role, tel: e.tel, email: e.email,
      onName: (ev) => set({ name: ev.target.value }), onRole: (ev) => set({ role: ev.target.value }), onTel: (ev) => set({ tel: ev.target.value }), onEmail: (ev) => set({ email: ev.target.value }),
      showCats: !e.me,
      cats: [['elu', 'Équipe & élus'], ['externe', 'Contact externe']].map((k) => ({ label: k[1], on: e.cat === k[0], bg: e.cat === k[0] ? 'var(--surface)' : 'transparent', fg: e.cat === k[0] ? 'var(--ink)' : 'var(--ink5)', go: () => set({ cat: k[0] }) })),
      canDel: !!e.id && !e.me,
      del: this.askDel('ct-' + e.id, 'Supprimer', () => this.deleteContact(e.id)),
      msg: () => { const id = e.id; this.setState({ ctEdit: null }); this.openDirect(id); },
      save: () => this.saveContact(), close: () => this.setState({ ctEdit: null }),
      saveLabel: e.id ? 'Enregistrer' : 'Ajouter le contact'
    };
  }
  
  ctpVals() {
    const q = String(this.state.ctQ || '').trim().toLowerCase();
    const cat = this.state.ctCat || 'all';
    const all = this.allContacts();
    const groups = this.state.convos.map((c) => this.cvFull(c)).filter((c) => c.kind === 'group');
    const gOf = (id) => groups.filter((g) => g.memberIds.indexOf(id) >= 0).map((g) => g.name);
    const list = all.filter((x) => (cat === 'all' || x.cat === cat) && (!q || (x.name + ' ' + x.role + ' ' + gOf(x.id).join(' ')).toLowerCase().indexOf(q) >= 0));
    return {
      q: this.state.ctQ || '', onQ: (e) => this.setState({ ctQ: e.target.value }),
      cats: [['all', 'Tous'], ['elu', 'Équipe & élus'], ['adherent', 'Adhérents'], ['externe', 'Externes']].map((k) => { const on = cat === k[0]; return { label: k[1] + ' · ' + all.filter((x) => k[0] === 'all' || x.cat === k[0]).length, on: on, bg: on ? 'var(--acBg)' : 'var(--surface)', fg: on ? 'var(--acTx)' : 'var(--ink4)', bd: on ? 'var(--acBd)' : 'var(--bd2)', go: () => this.setState({ ctCat: k[0] }) }; }),
      rows: list.map((x) => { const gs = gOf(x.id); return { name: x.name + (x.me ? ' (vous)' : ''), initials: x.initials, avatarBg: AV_BG[this.hashIdx(x.id, AV_BG.length)], role: x.role, catLabel: CT_CATS[x.cat], coords: [x.tel, x.email].filter(Boolean).join(' · ') || 'aucune coordonnée', groups: 'Groupes : ' + gs.join(', '), hasGroups: gs.length > 0, notMe: !x.me, msg: () => this.openDirect(x.id), edit: () => this.openContactEdit(x.id), editLabel: x.adhId ? 'Fiche adhérent' : 'Modifier' }; }),
      noRows: !list.length,
      gCount: groups.length + ' groupe' + (groups.length > 1 ? 's' : ''),
      groups: groups.filter((g) => !q || g.name.toLowerCase().indexOf(q) >= 0).map((g) => ({ name: g.name, initials: g.initials, avatarBg: g.avatarBg, meta: g.memberIds.length + ' membres · admin : ' + g.admins.map((id) => (id === 'c-me' ? 'vous' : ((this.contactById(id) || {}).name || '').split(' ')[0])).join(', '), open: () => this.openConvo(g.id), edit: () => this.openGroupEdit(g.id) })),
      newContact: () => this.openContactEdit(null), newGroup: () => this.openGroupEdit(null),
      back: () => this.go('params'),
      toLists: () => { this.setState({ adhTab: 'groupes' }); this.go('adherents'); }
    };
  }

  signGeneratedDocument() {
    const doc = this.buildDoc();
    const blocks = [{type:'p',text:doc.p1},{type:'p',text:doc.p2},{type:'h2',text:doc.listTitle}].concat((doc.items || []).map(x => ({type:'p',text:x.text})), [{type:'p',text:doc.footer}]);
    this.signDocument({id:'generated-' + Date.now(),title:doc.title,blocks:blocks});
  }
  signDocument(doc) {
    const content = this.blocksToMd(doc.blocks || []);
    const snapshot = { id: doc.id, label: doc.title, title: doc.title, ref: 'Document · ' + doc.id, p1: content, p2: '' };
    this.setState({ sigSnapshot: snapshot, sigOrigin: 'Document · ' + doc.title, sig: Object.assign({}, this.state.sig, { docId: doc.id, consent: false }) });
    this.go('signature');
  }
  
  attachViewer(vw) {
    const dossier = this.currentDossier(); if (!dossier) { this.flash('Créez un dossier avant de joindre ce document'); return; }
    const id = 'piece-' + Date.now();
    const item = {id:id, name:vw.title, ext:'TXT', size:'Document local', by:'Vous', date:new Date().toLocaleDateString('fr-FR'), v:1, content:[vw.title,vw.meta,vw.body,vw.text,JSON.stringify(vw)].filter(Boolean).join('\n'), note:'Document rattaché depuis le lecteur'};
    this.setState((s) => ({pieces:Object.assign({},s.pieces,{[dossier.id]:[item].concat(s.pieces[dossier.id] || [])}),pieceId:id}));
    this.go('pieces'); this.flash('Document joint au dossier « ' + dossier.title + ' »');
  }
  async suggestPollOptions() {
    const title = String(this.state.np.title || '').trim();
    if (title.length < 9) { this.flash('Renseignez la question avant de demander des propositions'); return; }
    if (this._pollBusy) return; this._pollBusy = true;
    const type = this.state.np.type;
    this.flash('Propositions en cours…');
    try {
      const r = await this.llmJson('Propose des réponses neutres, distinctes et pertinentes à une question de sondage. JSON uniquement : {"options":["...","..."]}. De 2 à 6 options courtes. Pas de faits inventés.', title, 350);
      const options = [...new Set((Array.isArray(r.options) ? r.options : []).filter((x) => typeof x === 'string').map((x) => x.trim()).filter(Boolean))].slice(0,6);
      if (options.length < 2) throw new Error('Réponse de sondage invalide');
      if (this.state.np.title !== title || this.state.np.type !== type) { this.flash('Question modifiée — relancez les propositions'); return; }
      this.setNp({options:options}); this.flash(options.length + ' réponses proposées par l’assistant — modifiables');
    } catch(e) { this.aiFail('Propositions du sondage', e, () => this.suggestPollOptions()); }
    finally { this._pollBusy = false; }
  }
  async downloadReport(option) {
    const format = ['xlsx','csv','pdf'][option] || 'xlsx';
    const sheets = [
      {name:'Synthèse',rows:[['Rubrique','Valeur'],['Période',this.state.repPeriod],['Dossiers',this.state.dossiers.length],['Documents',this.state.docs.length],['Sondages',this.state.pollsData.length]]},
      {name:'Dossiers',rows:[['Catégorie','Statut','Échéance']].concat(this.state.dossiers.map((d) => [d.tag,d.status,d.due]))},
      {name:'Sondages',rows:[['Statut','Participation']].concat(this.state.pollsData.map((p) => [p.status,p.participation]))},
      {name:'Documents',rows:[['Modèle','Statut','Format']].concat(this.state.docs.map((d) => [d.model,d.status,d.format]))}
    ];
    const filename = 'bilan-uniion-' + new Date().toISOString().slice(0,10) + '.' + format;
    await this.downloadLocal({format:format, filename:filename, title:'Bilan de mandat — données locales', sheets:sheets});
    this.setState({sheetFileName:filename});
  }
  async downloadAttestation(sess) {
    try {
      await this.downloadLocal({format:'pdf',filename:'attestation-formation.pdf',title:'Attestation de suivi — prototype local',lines:[sess.title, 'Durée : '+this.fmDurLabel(sess.dur), 'Date : '+new Date().toLocaleDateString('fr-FR'), 'Modules parcourus : '+(sess.done || []).filter(Boolean).length+'/'+sess.modules.length, 'Cette attestation de parcours ne constitue pas une certification professionnelle.']});
      this.flash('Attestation de suivi téléchargée');
    } catch(e) { this.flash('Téléchargement impossible : '+e.message); }
  }
  async downloadLocal(data) {
    if (!window.uniionLocal || !window.uniionLocal.download) throw new Error('Serveur local requis pour cet export');
    await window.uniionLocal.download(data);
  }

  validDate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value || '')) return false;
    const d = new Date(value + 'T12:00:00Z');
    return !isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
  }
  csvRows(text, sep) {
    const rows = []; let row = [], cell = '', quoted = false, closed = false, error = '';
    for (let i = 0; i < text.length; i++) {
      const c = text[i];
      if (quoted) { if (c === '"') { if (text[i+1] === '"') { cell += '"'; i++; } else { quoted = false; closed = true; } } else cell += c; }
      else if (c === '"' && !cell && !closed) quoted = true;
      else if (c === sep) { row.push(cell); cell = ''; closed = false; }
      else if (c === '\n' || c === '\r') { if (c === '\r' && text[i+1] === '\n') i++; row.push(cell); if (row.some(x => x.trim())) rows.push(row); row = []; cell = ''; closed = false; }
      else { if (closed && c.trim()) error = 'Caractère après un champ entre guillemets'; cell += c; }
    }
    if (quoted) error = 'Guillemets non fermés';
    row.push(cell); if (row.some(x => x.trim())) rows.push(row);
    return { rows: rows.length ? rows : [['']], error: error };
  }
  signatureLines() { return this.state.profileSignature || ['Sophie Marchand', 'Déléguée syndicale — Section de Valenciennes', 'sophie.marchand@cse-valenciennes.fr']; }

  
}


Object.assign(Component.prototype,theme);
Object.assign(Component.prototype,cases);
Object.assign(Component.prototype,contacts);
Object.assign(Component.prototype,navigation);
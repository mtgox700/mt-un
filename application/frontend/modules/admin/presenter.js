import {DOCS} from '../../generated/constants.js';
export function createAdminPresenter(store,ports,readContext){const context={get state(){return {...readContext(),...store.read()}},setState:p=>store.update(p),...ports};return Object.freeze({adminVals(){return (function(){return {
      onbSummary: Object.keys(this.state.onb).filter((k) => this.state.onb[k]).length + ' étape(s) sur 4 terminées — 5 minutes suffisent',
      onbWidth: (Object.keys(this.state.onb).filter((k) => this.state.onb[k]).length * 25) + '%',
      onbSteps: [
        { key: 'convention', title: 'Convention collective', desc: 'Métallurgie (IDCC 3248) — sert de source à l\'Assistant Juridique.', action: 'Modifier', act: () => this.flash('Convention collective confirmée') },
        { key: 'commissions', title: 'Créer vos commissions', desc: 'Négociation, SSCT, ASC, formation — chacune avec sa messagerie dédiée.', action: 'Créer les 4 commissions', act: () => this.flash('4 commissions créées') },
        { key: 'membres', title: 'Inviter les élus', desc: 'Invitation par lien ou import CSV pour les grandes fédérations.', action: 'Importer un CSV', act: () => { this.setState({importMembers:true}); this.clearCsv(); this.go('adhimport'); } },
        { key: 'notifs', title: 'Régler vos alertes', desc: 'Canaux, plages « ne pas déranger » et escalade des urgences.', action: 'Configurer', act: () => this.go('prefs') }
      ].map((s) => {
        const done = this.state.onb[s.key];
        return {
          title: s.title, desc: s.desc, action: done ? 'Terminé — revoir' : s.action,
          mark: done ? '✓' : '·',
          border: done ? 'var(--okChip)' : 'var(--chip)',
          badgeBg: done ? 'var(--okChip)' : 'var(--surf2)', badgeColor: done ? 'var(--okTx)' : 'var(--ink6)',
          btnBg: done ? 'var(--surf2)' : 'linear-gradient(to right, var(--ac), var(--ac2))', btnColor: done ? 'var(--ink4)' : '#FFFFFF',
          go: () => { if (s.key !== 'membres') { const o = Object.assign({}, this.state.onb); o[s.key] = true; this.setState({ onb: o }); } s.act(); }
        };
      }),

      adminScope: this.state.site + ' · 24 sièges · plan Fédération',
      sites: ['Tous les sites', 'Valenciennes', 'Douai', 'Siège'].map((s) => ({
        label: s, selected: this.state.site === s, idle: this.state.site !== s,
        go: () => this.selectSite(s)
      })),
      kpis: (() => {
        const m = this.state.site === 'Tous les sites' ? 1 : (this.state.site === 'Valenciennes' ? 0.6 : (this.state.site === 'Douai' ? 0.3 : 0.1));
        const rnd = (n) => String(Math.max(1, Math.round(n * m)));
        return [
          { label: 'Élus actifs', value: rnd(24), delta: '+2 ce mois', deltaColor: 'var(--ok)' },
          { label: 'Dossiers ouverts', value: rnd(17), delta: '−4 vs juillet', deltaColor: 'var(--ok)' },
          { label: 'Participation sondages', value: '72 %', delta: '+9 pts', deltaColor: 'var(--ok)' },
          { label: 'Requêtes IA', value: rnd(1648), delta: 'quota à 56 %', deltaColor: 'var(--acTx)' }
        ];
      })(),
      commissionStats: [
        { label: 'Négociation', value: '9 dossiers · 412 messages', width: '86%' },
        { label: 'SSCT', value: '6 dossiers · 260 messages', width: '58%' },
        { label: 'ASC', value: '4 dossiers · 148 messages', width: '36%' },
        { label: 'Formation', value: '2 dossiers · 61 messages', width: '18%' }
      ],
      adminLinks: [
        { label: 'Gestion des membres', meta: this.state.members.length + ' comptes · ' + this.state.members.filter(m => m.status === 'Invité').length + ' invitation en attente', go: () => this.go('membres') },
        { label: 'Bibliothèque documentaire', meta: DOCS.length + ' documents · versions suivies', go: () => this.go('offline') },
        { label: 'Configuration IA', meta: 'Fournisseur, clé API, quotas', go: () => this.go('apikey') },
        { label: 'Prise en main de l\'organisation', meta: 'Checklist de configuration', go: () => this.go('onboarding') },
        { label: 'Bilan & reporting CSE', meta: 'Statistiques de mandat, export PDF et Excel', go: () => this.go('reporting') },
        { label: 'Facturation & sièges', meta: '24 sièges · prochaine échéance 01/09', go: () => this.flash('Facture d\'août disponible (PDF)') }
      ],

      memberSummary: this.state.members.length + ' membres · 4 commissions · plan Fédération',
      orgStats: [
        { value: '24', label: 'sièges du plan' },
        { value: String(this.state.members.filter((m) => m.status === 'Actif').length), label: 'membres actifs' },
        { value: '4', label: 'commissions' },
        { value: String(this.state.members.filter(m => m.status === 'Invité').length), label: 'invitation en attente' }
      ],
      members: this.state.members.map((m) => ({
        name: m.name, initials: m.initials, role: m.role, last: m.last, status: m.status,
        statusBg: m.status === 'Actif' ? 'var(--okChip)' : (m.status === 'Invité' ? 'var(--acBg)' : 'var(--chip)'),
        statusColor: m.status === 'Actif' ? 'var(--okTx)' : (m.status === 'Invité' ? 'var(--acTx)' : 'var(--ink5)'),
        action: m.status === 'Suspendu' ? 'Réactiver' : (m.status === 'Invité' ? 'Relancer' : 'Suspendre'),
        go: () => {
          if (m.status === 'Invité') { this.flash('Invitation renvoyée à ' + m.name); return; }
          const next = m.status === 'Actif' ? 'Suspendu' : 'Actif';
          this.setState((s) => ({ members: s.members.map((x) => x.id === m.id ? Object.assign({}, x, { status: next }) : x) }));
          this.flash(m.name + ' — ' + (next === 'Actif' ? 'réactivé' : 'suspendu'));
        },
        del: this.askDel('mem-' + m.id, 'Retirer', () => {
          this.setState((s) => ({ members: s.members.filter((x) => x.id !== m.id) }));
          this.flash(m.name + ' — accès révoqué');
        })
      })),
      invite: () => this.openSheet('invite'),

};}).call(context)}});}

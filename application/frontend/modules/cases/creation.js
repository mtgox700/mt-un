export function createCaseCreation(store,ports){const context={get state(){return store.read()},setState:p=>store.update(p),...ports};Object.assign(context,{buildDossier(o) {
    if (this.state.dosBusy) return;
    const raw = String(o.long || '').slice(0, 5000);
    const m = this.maskText(raw, this.detectLevel(raw));
    const TAGS = ['Juridique', 'Harcèlement', 'CSSCT', 'ASC / Noël', 'Négociation'];
    const fin = (ai) => {
      const unmask = (s) => (m.tags || []).reduce((acc, t) => acc.split(t.token).join(t.clear), String(s || '')).trim();
      const id = 'new-' + Date.now();
      const tag = ai && TAGS.indexOf(ai.tag) >= 0 ? ai.tag : 'Juridique';
      const steps = ai && Array.isArray(ai.steps) ? ai.steps.map(unmask).filter(Boolean).slice(0, 6) : [];
      const t = (ai && unmask(ai.title)) || o.title;
      const item = {
        id: id, tag: tag, status: 'todo', due: (ai && String(ai.due || '').slice(0, 12)) || '15 j', owner: 'Sophie M.',
        title: t, desc: (ai && unmask(ai.desc)) || o.desc, long: o.long, ask: t,
        timeline: o.timeline.slice(0, 1).concat(steps.length ? [{ date: "Aujourd'hui", title: 'Plan d’action proposé par unii', body: steps.map((x) => '· ' + x).join('\n') }] : []).concat(o.timeline.slice(1))
      };
      this.setState((s) => ({ dosBusy: false, dossiers: [item].concat(s.dossiers), dchats: o.dchat ? Object.assign({}, s.dchats, { [id]: o.dchat }) : s.dchats }));
      this.closeAssistant();
      if (o.onId) o.onId(id);
      this.go('dossier', { dossierId: id });
      this.flash(ai ? 'Dossier créé et qualifié par unii — ' + tag : 'Dossier créé avec le contexte (qualification IA indisponible)');
    };
    if (m.residual.length) { fin(null); return; }
    this.setState({ dosBusy: true });
    this.flash('unii qualifie le dossier…');
    const SYS = "Tu qualifies un nouveau dossier de permanence d'une section syndicale française (CSE) à partir d'échanges ou de messages. Conserve tels quels les jetons entre crochets. N'invente aucun fait.\nRéponds uniquement par un objet JSON : {\"title\": \"intitulé court et factuel, 70 caractères max\", \"tag\": \"Juridique | Harcèlement | CSSCT | ASC / Noël | Négociation (une seule valeur)\", \"desc\": \"la situation en deux phrases\", \"due\": \"échéance relative courte, ex. 8 j\", \"steps\": [\"prochaine étape concrète\"]} — 3 à 5 étapes, chacune avec son délai légal s'il existe.";
    this.llmJson(SYS, 'Matière du dossier (anonymisée) :\n' + m.masked, 700).then(fin).catch(() => fin(null));
  },msgToNewDossier(p) {
    this.setState({ dosPick: null });
    this.buildDossier({
      title: 'Suivi — ' + p.text.slice(0, 50), desc: 'Dossier ouvert depuis un message de « ' + p.conv + ' ».',
      long: 'Fil « ' + p.conv + ' »\n' + p.who + ' (' + p.time + ') : ' + p.text,
      timeline: [{ date: "Aujourd'hui", title: 'Dossier créé depuis la messagerie', body: 'Message de ' + p.who + ' dans « ' + p.conv + ' ».' }, { date: "Aujourd'hui", title: 'Message versé au dossier', body: p.who + ' (' + p.time + ') : ' + p.text }]
    });
  }});return Object.freeze({buildDossier:context.buildDossier.bind(context),msgToNewDossier:context.msgToNewDossier.bind(context)});}

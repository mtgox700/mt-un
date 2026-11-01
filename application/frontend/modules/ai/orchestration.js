export function createAIOrchestration(store,ports){const context={get state(){return store.read()},setState:p=>store.update(p),...ports};Object.assign(context,{threadUniiRun(instr) {
    const ask = String(instr || '').replace(/@unii\b/ig, '').trim() || 'Analyse ces échanges et dis-moi ce qu’il faut en retenir.';
    if (this.state.thBusy) return;
    const ctx = this.threadUniiContext();
    const conversationId = this.curConvo().id;
    if (this.offTopic(ask)) { const off = this.offTopicReply(); this.uniiPush({ ask: ask, ctxLabel: ctx.label, text: off.text }, conversationId); return; }
    const m = this.maskText(ctx.raw + '\n\nConsigne : ' + ask, this.detectLevel(ctx.raw + ' ' + ask));
    if (m.residual.length) { this.flash('Envoi refusé — un identifiant échappe au filtre'); return; }
    this.setState({thBusy:true,thAsk:ask}); this.countCall();
    const SYS = "Tu es unii, l'assistant IA intégré à la messagerie chiffrée d'une section syndicale française (CSE). Tu travailles pour l'élue qui te sollicite, sur les extraits de conversation qu'elle t'a transmis, et tu suis strictement sa consigne.\n"
      + "Règles : texte brut sans markdown, vouvoiement, 160 mots maximum hors section Sources. Les identités sont remplacées par des jetons entre crochets : conserve-les tels quels. Tu restes dans le périmètre syndical et droit du travail ; hors périmètre, tu refuses en une phrase. Si la consigne demande une réponse à envoyer, rédige directement le message prêt à poster, au ton du fil, sans section Sources dans le message lui-même mais en la plaçant après une ligne « --- ».";
    this.llmText(SYS, 'Extraits de la messagerie et consigne (anonymisés) :\n' + m.masked + '\n\nCorpus documentaire :\n' + this.aiCorpus(), 800).then((txt) => {
      const clear = (m.tags || []).reduce((acc, t) => acc.split(t.token).join(t.clear), this.plain(txt));
      this.uniiPush({ ask: ask, ctxLabel: ctx.label, text: clear, ctx: m.masked, reid: m.tags.length ? m.tags.length + ' entité' + (m.tags.length > 1 ? 's' : '') + ' masquée' + (m.tags.length > 1 ? 's' : '') + ' à l’envoi, ré-identifiée' + (m.tags.length > 1 ? 's' : '') + ' à l’écran' : '' }, conversationId);
    }).catch((e) => {
      this.uniiPush({ ask: ask, ctxLabel: ctx.label, text: 'Aucune réponse produite (' + (e && e.message ? e.message : e) + '). Réessayez.', failed: true }, conversationId);
    });
  },async llmJson(system, user, max) {
    const raw = await this.llmText(system, user, max);
    const i = raw.indexOf('{');
    const j = raw.lastIndexOf('}');
    if (i < 0 || j <= i) throw new Error('réponse illisible, JSON attendu');
    try { return JSON.parse(raw.slice(i, j + 1)); } catch (e) { throw new Error('JSON invalide renvoyé par le modèle'); }
  }});return Object.freeze({threadUniiRun:context.threadUniiRun.bind(context),llmJson:context.llmJson.bind(context)});}

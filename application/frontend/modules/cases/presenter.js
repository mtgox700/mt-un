// Case board presentation; the host supplies navigation and interaction ports.
export function prepareCaseColumns(controller,cols,drag,noClickUntil,uniiActs){
return {columns: cols.map((c, ci) => {
        const all = controller.state.dossiers.filter((x) => x.status === c.id);
        const cards = drag ? all.filter((x) => x.id !== drag.id) : all;
        const isTarget = !!drag && drag.col === c.id;
        const ghostAt = isTarget ? (drag.idx < 0 || drag.idx > cards.length ? cards.length : drag.idx) : -1;
        const items = [];
        cards.forEach((x, i) => {
          if (i === ghostAt) items.push({ isGhost: true, h: drag.h + 'px' });
          const grabbed = controller.state.grabbed === x.id;
          items.push({
            id: x.id, isCard: true, grabbed: grabbed, notGrabbed: !grabbed,
            tag: x.tag, title: x.title, desc: x.desc, who: (x.owner || 'S').slice(0, 2).toUpperCase(), due: x.due,
            go: () => {
              if (Date.now() < noClickUntil) return;
              controller.go('dossier', { dossierId: x.id });
            },
            grabLabel: grabbed
              ? 'Carte saisie : ' + x.title + '. Flèches gauche et droite pour la déplacer, Espace pour déposer.'
              : x.title + '. Espace pour saisir la carte, ou glissez-la.',
            down: (e) => controller.cardPointerDown(x.id, e),
            keydown: (e) => controller.cardKey(x.id, e),
            uniiTip: (controller.state.plan !== 'p1' && controller.state.uniiPills !== false && x.status !== 'done' && /\d+ h/.test(String(x.due || '')) && controller.uniiAllowed(uniiActs.find((a) => a.id === 'dos-next'))) ? 'unii · suite à donner' : '',
            hasUniiTip: (controller.state.plan !== 'p1' && controller.state.uniiPills !== false && x.status !== 'done' && /\d+ h/.test(String(x.due || '')) && controller.uniiAllowed(uniiActs.find((a) => a.id === 'dos-next'))),
            uniiGo: () => { if (Date.now() < noClickUntil) return; controller.uniiOpen({ mod: 'dossiers', itemId: x.id, actId: 'dos-next' }); },
            askAi: () => {
              if (Date.now() < noClickUntil) return;
              const open = controller.state.cardAi === x.id;
              controller.setState({ cardAi: open ? null : x.id, dchatDraft: '', aiErr: '' });
              if (!open) controller.flash('Assistant chargé avec le contexte de « ' + x.title + ' »');
            },
            aiOpen: controller.state.cardAi === x.id,
            aiClose: () => controller.setState({ cardAi: null }),
            aiLevel: 'niveau ' + controller.levelForDossier(x).toUpperCase(),
            aiMsgs: controller.state.cardAi === x.id ? controller.dchatFor(x) : [],
            aiTyping: controller.state.cardAi === x.id && controller.state.dchatTyping,
            aiDraft: controller.state.dchatDraft,
            onAiDraft: (e) => controller.setState({ dchatDraft: e.target.value }),
            onAiKey: (e) => { if (e.key === 'Enter') controller.dchatAsk(controller.state.dchatDraft, x); },
            aiSend: () => controller.dchatAsk(controller.state.dchatDraft, x),
            aiSuggest: [
              { label: 'Quels textes s\'appliquent ici ?' },
              { label: 'Quels délais dois-je respecter ?' },
              { label: 'Quelle suite donner ?' }
            ].map((s) => ({ label: s.label, go: () => controller.dchatAsk(s.label, x) })),
            aiPrivacy: 'Masquage heuristique avant envoi · traitement via votre compte ChatGPT.',
            aiLabel: 'Interroger l\'assistant sur « ' + x.title + ' »',
            canLeft: ci > 0, canRight: ci < cols.length - 1,
            leftLabel: 'Déplacer « ' + x.title + ' » vers ' + (cols[ci - 1] || {}).label,
            rightLabel: 'Déplacer « ' + x.title + ' » vers ' + (cols[ci + 1] || {}).label,
            moveLeft: () => controller.moveCard(x.id, -1),
            moveRight: () => controller.moveCard(x.id, 1)
          });
        });
        if (ghostAt === cards.length) items.push({ isGhost: true, h: drag.h + 'px' });
        return {
          id: c.id, label: c.label, dot: c.dot, count: '(' + all.length + ')',
          empty: items.length === 0,
          items: items,
          fxStyle: {
            borderRadius: '22px',
            transition: 'opacity .18s ease, outline-color .18s ease',
            outline: '2px solid ' + (isTarget ? 'var(--ac)' : 'transparent'),
            outlineOffset: '3px',
            opacity: drag && !isTarget ? 0.45 : 1
          }
        };
      }),}.columns;
}
export function prepareCaseHome(rows,go){const open=rows.filter(x=>x.status!=='done');return {openCount:open.length,dossierCount:rows.length,homeDossiers:open.slice(0,3).map(x=>({title:x.title,meta:x.tag+' · échéance '+x.due,go:()=>go('dossier',{dossierId:x.id})}))};}

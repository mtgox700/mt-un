// Server-backed recipe proposals. Source text and results never enter legacy state.
export function attachAIActions(c,request,organization){
 const label='Relire les extraits fictifs';
 const names={case:'Dossier',document:'Document',message:'Message'};
 const kinds={dossiers:'case',documents:'document',messagerie:'message',accueil:'workspace',params:'workspace',reunions:'reunions',agenda:'agenda',communication:'communication',mobile:'mobile',formations:'formations',adherents:'adherents',sondages:'sondages',intranet:'intranet',reporting:'reporting',raccourcis:'raccourcis'};
 let epoch=0,current=null,selected=null,source=null,timer=null,notice='',busy=false,draft='',catalog=[],choices=[],settings={manage:false,roles:[],settings:[]};
 const call=(action,data={})=>request('/identity/ai/assistant',{organization_id:organization,action,...data});
 const paint=()=>c.setState({});
 const stop=()=>c.flash('Action non disponible dans la recette : aucun texte transmis ni contenu métier modifié.');
 function clear(){epoch++;clearTimeout(timer);timer=null;const id=current;current=null;busy=false;selected=null;source=null;draft='';notice='';if(id)request('/identity/ai/cancel',{organization_id:organization,request_id:id}).catch(()=>{});paint();}
 function choose(mod,item){
  const kind=kinds[mod];
  if(kind==='case')return item||c.state.route==='dossier'?{kind,id:item||c.state.dossierId}:null;
  if(kind==='document')return item||c.state.route==='docedit'?{kind,id:item||c.state.docId}:null;
  if(kind==='message'&&c.state.route==='thread'){
   const cv=c.curConvo(),sel=c.state.thSel||[];
   if(sel.length>1)return null;
   const m=sel.length?cv.messages[sel[0]]:cv.messages?.at(-1);
   return m?.seq?{kind,id:cv.id,seq:String(m.seq)}:null;
  }
  if(kind==='workspace')return {kind,id:organization};
  const selected=item||({reunions:c.state.reunionId,agenda:c.state.agEvtId,mobile:c.state.mobId,communication:c.state.comEditId,formations:c.state.fmSessId,adherents:c.state.adhId,sondages:c.state.pollId,intranet:c.state.pageId}[mod]);
  return kind&&selected?{kind,id:selected}:null;
 }
 function schedule(){clearTimeout(timer);if(selected){timer=setTimeout(refresh,10000);timer.unref?.();}}
 async function refresh(){const stamp=epoch,id=selected?.id;if(!id)return;
  try{const row=await call('read',{id});if(stamp!==epoch||selected?.id!==id)return;selected=row;}
  catch{if(stamp!==epoch)return;selected=null;draft='';notice='Proposition retirée : source modifiée, accès retiré ou service indisponible.';}
  if(stamp===epoch){paint();schedule();}
 }
 async function run(actionId=null){
  if(busy){const ref=source;clear();source=ref;notice='Demande annulée. Aucune réponse tardive affichée.';paint();return;}
  const ref=source;if(!ref?.id)return stop();
  clear();source=ref;const stamp=epoch,id=crypto.randomUUID();current=id;busy=true;notice='Contrôle de la source fictive et génération…';paint();
  try{
   // Flush document drafts through their own service; a changed certified version fails closed.
   if(ref.kind==='document')await c.flushDocuments?.();else if(c.flushBusiness)await c.flushBusiness();
   if(stamp!==epoch)return;
   const r=await request('/identity/ai/actions',{organization_id:organization,request_id:id,action:actionId||ref.kind+'-excerpts',source:ref});
   if(stamp!==epoch||current!==id)return;
   if(r.state!=='succeeded'||!r.persistent)throw Error('Enregistrement non confirmé.');
   const row=await call('read',{id});if(stamp!==epoch||current!==id)return;selected=row;draft=row.response?.mode==='business-draft'?row.response.text:'';notice='';
  }catch{if(stamp===epoch&&current===id)notice='Aucune proposition disponible : source non certifiée, droits modifiés ou service indisponible. Aucune relance automatique.';}
  finally{if(stamp===epoch&&current===id){current=null;busy=false;paint();schedule();}}
 }
 async function runFree(question){
  if(busy||!String(question||'').trim())return;
  const prior=selected,ref=source;clear();source=ref;const stamp=epoch,id=crypto.randomUUID();current=id;busy=true;notice='Conversation privée · vérification des sources…';paint();
  try{const scope=await request('/identity/ai/chat',{organization_id:organization,action:'status'});if(stamp!==epoch)return;if(!scope.allowed)throw Error();
   if(c.flushBusiness)await c.flushBusiness();if(ref?.kind==='document')await c.flushDocuments?.();if(stamp!==epoch)return;
   const result=await request('/identity/ai/chat',{organization_id:organization,request_id:id,question,sources:ref?[ref]:[],parent:prior?.response?.mode==='conversation'?prior.id:null});if(stamp!==epoch||current!==id)return;if(!result.persistent)throw Error();
   const row=await call('read',{id});if(stamp!==epoch||current!==id)return;selected=row;draft='';notice='';
  }catch{if(stamp===epoch)notice='Conversation indisponible : organisation fictive, droits et versions requis. Aucune relance automatique.';}
  finally{if(stamp===epoch){current=null;busy=false;paint();schedule();}}
 }
 async function loadSettings(){const stamp=epoch;try{const r=await request('/identity/ai/actions',{organization_id:organization,action:'settings',payload:{}});if(stamp!==epoch)return;settings={manage:!!r.manage,roles:r.roles||[],settings:r.settings||[]};paint();}catch{if(stamp===epoch){settings={manage:false,roles:[],settings:[]};paint();}}}
 async function configure(id,patch){if(!settings.manage)return stop();const cfg=settings.settings.find(x=>x.id===id);if(!cfg)return;const stamp=epoch;try{await request('/identity/ai/actions',{organization_id:organization,action:'configure',payload:{id,version:cfg.version,enabled:cfg.enabled,roles:cfg.roles,...patch}});if(stamp!==epoch)return;await loadSettings();}catch{if(stamp===epoch)c.flash('Configuration refusée ou version modifiée.');}}
 async function loadActions(){const stamp=epoch;try{const r=await request('/identity/ai/actions',{organization_id:organization,action:'catalog'});if(stamp!==epoch)return;catalog=r.actions||[];await loadSettings();if(stamp!==epoch)return;choices=(r.sources||[]).filter(x=>x.ref.kind===(kinds[c.state.uniiMod]||'document'));notice='Choisissez une source certifiée et une action. La réponse sera un brouillon privé à relire.';paint();}catch{if(stamp===epoch){notice='Catalogue indisponible ou droits insuffisants.';paint();}}}
 c.uniiOpen=(o={})=>{clear();catalog=[];choices=[];const mod=o.mod||({dossier:'dossiers',docedit:'documents',thread:'messagerie'}[c.state.route])||c.state.route;source=o.source||choose(mod,o.itemId);c.setState({uniiOpen:true,uniiMod:mod,uniiItem:o.itemId||null,uniiMsgs:[],uniiBusy:false});notice=source?.id?'Recette fictive : source sélectionnée. Chargez les actions métier pour préparer un brouillon à relire.':'Chargez le catalogue puis choisissez une source fictive certifiée. Chaque action utilise une source de son module.';if(o.actId)return c.uniiRun(o.actId);};
 c.uniiRun=async(id,free)=>{if(free)return runFree(free);const stamp=epoch;if(!catalog.length)await loadActions();if(stamp!==epoch)return;const a=catalog.find(a=>a.id===id&&a.mod===c.state.uniiMod);if(a)return run(id);return stop();};
 async function changeDraft(action){
  if(!selected||selected.response?.mode!=='business-draft'||busy)return stop();
  if(action!=='edit'&&draft!==selected.response.text){notice='Enregistrez vos corrections avant la relecture ou l’application.';paint();return;}
  if(action==='apply'&&selected.response.module==='dossiers'&&c.state.dosEdit){notice='Terminez la modification du dossier avant d’appliquer le brouillon.';paint();return;}
  const row=selected,stamp=epoch;busy=true;paint();
  try{
   if(action==='apply'){if(row.response.module==='documents')await c.flushDocuments?.();else if(c.flushBusiness)await c.flushBusiness();}
   if(stamp!==epoch)return;
   const result=await request('/identity/ai/drafts',{organization_id:organization,action,id:row.id,version:row.version,...(action==='edit'?{text:draft}:{})});
   if(stamp!==epoch)return;
   if(action==='apply'){
    selected=null;draft='';notice='Brouillon appliqué à la version '+result.version+'. Aucune publication effectuée.';
    if(result.kind==='document')await c.refreshDocuments?.();
    if(result.kind==='case')await c.refreshCases?.();
    if(result.kind?.startsWith('mobile-'))await c.refreshBusiness?.('mobile');
    if(result.kind==='communication-plan')await c.refreshBusiness?.('communication');
   }else{const fresh=await call('read',{id:row.id});if(stamp!==epoch)return;selected=fresh;draft=selected.response.text;notice='';}
  }catch{if(stamp===epoch){selected=null;draft='';notice='Modification refusée ou résultat non confirmé. Vérifiez les droits, les sources et les versions.';}}
  finally{if(stamp===epoch){busy=false;paint();schedule();}}
 }
 c.openAIDraft=async id=>{const stamp=epoch;try{const row=await call('read',{id});if(stamp!==epoch)return;if(row.response?.mode!=='business-draft'||row.response.snapshot?.length!==1)return stop();const {fingerprint,...ref}=row.response.snapshot[0];c.uniiOpen({mod:row.response.module,source:ref});selected=row;draft=row.response.text;notice='';paint();schedule();}catch{if(stamp===epoch)stop();}};
 c.uniiApply=()=>selected?changeDraft(selected.response.reviewed?'apply':'review'):stop();
 c.threadUniiRun=instr=>{c.uniiOpen({mod:'messagerie'});if(instr)return runFree(instr);};
 c.dchatAsk=question=>{c.uniiOpen({mod:'dossiers'});return runFree(question||c.state.dchatDraft);};
 // Close legacy generators before their fallback code can manufacture local success.
 for(const name of ['genDocLlm','genPageLlm','pvFromReunion','fmStart','fmReview','fmAsk','mobGenerate','comGenerate','suggestPollOptions'])c[name]=stop;
 c.toAssistant=async()=>{const id=selected?.id;if(!id)return stop();await c.go('assistant');if(c.state.route==='assistant')await c.openAIResponse(id);};
 c.runAssistant=question=>c.requestAi(question);
 c.threadToDossier=async()=>{if(busy)return;c.uniiOpen({mod:'messagerie'});if(!source)return stop();
  const stamp=epoch;await runFree('Prépare un dossier privé à partir de ce message précis. Distingue les faits, les demandes et les points à compléter, sans inventer de décision.');
  // runFree clears its own state once; navigation or cancellation increments it again.
  if(epoch!==stamp+1||!selected||selected.response?.mode!=='conversation')return;
  const row=selected,ready=epoch;busy=true;paint();try{const result=await call('create_case',{id:row.id,version:row.version});if(epoch!==ready)return;await c.refreshCases?.();if(epoch!==ready)return;await c.go('dossier',{dossierId:result.id});c.flash('Dossier privé créé depuis le message sélectionné ; ses restrictions sont conservées.');}catch{if(epoch===ready){notice='Création refusée : vérifiez les droits et les sources.';busy=false;paint();}}
 };
 let assigningRole=null;
 const sheets=c.sheetDefs?.bind(c),confirmRole=c.confirmSheet?.bind(c);
 if(sheets)c.sheetDefs=()=>{const defs=sheets();return {...defs,aiRole:{title:'Attribuer un rôle métier',sub:'Permission de gestion des habilitations requise. Aucune auto-attribution.',field:'Adresse du membre',placeholder:'membre@exemple.fr',optLabel:'Action',options:[{label:'Attribuer le rôle',hint:assigningRole||''},{label:'Retirer le rôle',hint:assigningRole||''}],confirm:'Enregistrer',doneTitle:'Rôle enregistré',doneLines:['La décision est auditée sur le serveur.'],doneAction:'Fermer'}};};
 if(confirmRole)c.confirmSheet=async()=>{if(c.state.sheet!=='aiRole')return confirmRole();const stamp=epoch;try{await request('/identity/ai/actions',{organization_id:organization,action:'assign_role',payload:{email:c.state.sheetText,role:assigningRole,enabled:c.state.sheetOpt===0}});if(stamp!==epoch)return;c.setState({sheetDone:true,sheetErr:''});await loadSettings();}catch{if(stamp===epoch)c.setState({sheetErr:'Attribution refusée : vérifiez le membre et vos habilitations. Vous ne pouvez pas modifier vos propres rôles.'});}};
 const original=c.uniiVals.bind(c);
 c.uniiVals=(...args)=>{
  const v=original(...args),row=selected,response=row?.response,nativeMinutes=!response&&source?.kind==='reunions'?c.businessRecords?.('reunions').find(x=>x.id===source.id):null;
  const text=response?(notice?notice+'\n\n':'')+(response.mode==='business-draft'?(response.reviewed?'BROUILLON RELU — ':'BROUILLON À RELIRE — ')+response.actionLabel+'\n\n':'')+response.text+'\n\n'+response.excerpts.map(e=>`[${e.source}/${e.passage}] ${e.title} · ${e.location} · version ${e.version}`).join('\n')+'\nProposition privée — citations vérifiées ; suggestions à relire. Aucune diffusion autorisée.':nativeMinutes?.minutes?'PROJET DE PV — version '+nativeMinutes.version+' — à relire avant diffusion\n\n'+nativeMinutes.minutes:notice;
  const close=()=>{clear();c.setState({uniiOpen:false});};
  return {...v,locked:false,unlocked:true,suggs:[],hasSugg:false,showStrip:false,panelSuggs:[],hasPanelSuggs:false,hasHidden:false,
   open:()=>c.state.uniiOpen?close():c.uniiOpen(),close,clear:()=>{const ref=source;clear();source=ref;notice='Proposition retirée de ce panneau ; historique serveur conservé.';paint();},
   ctxLabel:'Recette fictive · '+(names[source?.kind]||'source requise'),roleLabel:'Droits vérifiés par le serveur',itemFixed:!!source?.id,itemFixedLabel:source?.kind==='message'?'Message '+source.seq:'Source sélectionnée',hasItems:choices.length>0,itemOpts:[{v:'',label:'Choisir une source certifiée'},...choices.map((x,i)=>({v:String(i),label:x.title}))],itemId:String(choices.findIndex(x=>JSON.stringify(x.ref)===JSON.stringify(source))),onItem:e=>{if(e.target.value==='')return;const ref=choices[Number(e.target.value)]?.ref;if(ref){clear();source=ref;notice='Source sélectionnée : '+choices[Number(e.target.value)].title;paint();}},
   acts:[...(source?.id?[{disabled:busy&&!current,label:current?'Annuler la demande':busy?'Enregistrement…':label,desc:'Extraits vérifiés de la source sélectionnée.',go:()=>run()}]:[]),{disabled:busy,label:'Charger les actions métier',desc:'Catalogue serveur et sources fictives autorisées.',go:loadActions},...catalog.filter(a=>a.mod===c.state.uniiMod).map(a=>({disabled:busy||!source?.id,label:a.label,desc:a.desc+' · Brouillon à relire',go:()=>run(a.id)}))],noActs:false,
   msgs:text?[{u:false,b:true,text,local:false,canApply:response?.mode==='business-draft'&&(!response.reviewed||['dos-next','dos-sum','dos-delais','dos-mail','doc-relire','doc-simpl','com-month','mob-page','mob-short','mob-push'].includes(response.action)),applyLabel:response?.reviewed?(response.module==='documents'?'Insérer dans ce document':response.module==='dossiers'?'Ajouter à ce dossier':'Appliquer à ce brouillon'):'Marquer le brouillon comme relu',apply:c.uniiApply,canContinue:!!row,canCopy:false,copy:stop,cont:c.toAssistant}]:[],hasMsgs:!!text,busy,input:draft,onIn:e=>{draft=e.target.value;paint();},onKey:e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();selected?.response?.mode==='business-draft'?changeDraft('edit'):runFree(draft);}},send:()=>selected?.response?.mode==='business-draft'?changeDraft('edit'):runFree(draft),inputPlaceholder:response?.mode==='business-draft'?'Corriger ce brouillon privé avant relecture':'Votre question — données fictives uniquement',sendLabel:response?.mode==='business-draft'?'Enregistrer les corrections du brouillon':'Envoyer',
   cfg:{...v.cfg,count:settings.settings.filter(a=>a.enabled).length+' actions actives',planName:'Recette locale autorisée',planOk:true,pillsOn:false,pillsSw:{swBg:'var(--bd2)',swLeft:'3px'},togglePills:stop,roles:(v.cfg?.roles||[]).map((r,i)=>({...r,go:()=>{assigningRole=['secretaire','tresorier','titulaire','suppleant','ds','ssct'][i];c.openSheet('aiRole');},on:settings.roles.includes(['secretaire','tresorier','titulaire','suppleant','ds','ssct'][i])})),custom:true,reset:()=>loadSettings(),mods:v.cfg?.mods?.map(m=>({...m,lot:false,n:settings.manage?'Configuration serveur de l’organisation':'Configuration serveur · lecture seule',acts:m.acts.map(a=>{const cfg=settings.settings.find(x=>x.id===a.id)||{enabled:false,roles:[],version:0};return {...a,on:cfg.enabled,allGo:()=>configure(a.id,{roles:[]}),allBg:cfg.roles.length?'var(--surface)':'var(--acBg)',rowOp:cfg.enabled?'1':'.55',swBg:cfg.enabled?'var(--ok)':'var(--bd2)',swLeft:cfg.enabled?'21px':'2px',tglLabel:cfg.enabled?'Désactiver':'Activer',toggle:()=>configure(a.id,{enabled:!cfg.enabled}),roles:(a.roles||[]).map((r,i)=>{const role=['secretaire','tresorier','titulaire','suppleant','ds','ssct'][i],on=cfg.roles.includes(role);return {...r,bg:on?'var(--acBg)':'var(--surface)',go:()=>configure(a.id,{roles:on?cfg.roles.filter(x=>x!==role):[...cfg.roles,role]})};}),desc:a.desc+' · Droits et version contrôlés côté serveur.'};})}))}};

 };
 const menu=c.msgActs?.bind(c);if(menu)c.msgActs=(cv,m)=>[...menu(cv,m),...(cv.serverMessage&&m.seq?[{label:'Relire avec unii — recette fictive',go:()=>{c.setState({waMenu:null});c.uniiOpen({mod:'messagerie',source:{kind:'message',id:cv.id,seq:String(m.seq)}});}}]:[])];
 const th=c.thVals?.bind(c);if(th)c.thVals=()=>({...th(),toAsst:()=>c.uniiOpen({mod:'messagerie'}),presets:[{label,text:label,go:()=>c.uniiOpen({mod:'messagerie'})}]});
 const render=c.renderVals.bind(c);c.renderVals=()=>{const v=render();return {...v,dossierLevelLabel:'Recette fictive',dossierLevelNote:'Masquage partiel · aucune garantie d’anonymisation exhaustive',dchatContext:[{label:'Source relue par le serveur'}],dchatSuggest:[{label,go:()=>c.uniiOpen({mod:'dossiers'})}],goAiDoc:()=>c.uniiOpen({mod:'documents'}),askAboutDossier:()=>c.uniiOpen({mod:'dossiers'}),dchatToAsst:()=>c.uniiOpen({mod:'dossiers'}),
  dchatSend:()=>c.dchatAsk(c.state.dchatDraft),onDchatKey:e=>{if(e.key==='Enter')c.dchatAsk(c.state.dchatDraft);},dchatMsgs:[{isBot:true,source:'unii · recette fictive',text:'Relisez les extraits autorisés dans le panneau unii. Aucun ajout automatique au dossier.'}],dchatPrivacy:'Une source certifiée, contrôlée avant et après chaque appel.',
  settings:v.settings?.map(x=>x.title==="Actions d’unii"||x.title==="Actions d'unii"?{...x,badge:'Recette fictive'}:x),
  columns:v.columns?.map(col=>({...col,items:col.items.map(card=>({...card,askAi:()=>c.uniiOpen({mod:'dossiers',itemId:card.id}),uniiGo:()=>c.uniiOpen({mod:'dossiers',itemId:card.id}),hasUniiTip:false}))}))};};
 for(const name of ['go','back','clearIdentity','onAuthenticated','componentWillUnmount']){const old=c[name]?.bind(c);if(old)c[name]=(...args)=>{clear();draft='';c.setState({uniiOpen:false});if(name==='componentWillUnmount'&&typeof document!=='undefined')document.removeEventListener('visibilitychange',hide);const result=old(...args);if(name==='go'&&args[0]==='unii')Promise.resolve(result).then(loadSettings);return result;};}
 const hide=()=>{if(document.hidden){clear();c.setState({uniiOpen:false});}};
 if(typeof document!=='undefined')document.addEventListener('visibilitychange',hide);
 return {run,runFree,refresh,clear,loadActions,changeDraft,loadSettings};
}

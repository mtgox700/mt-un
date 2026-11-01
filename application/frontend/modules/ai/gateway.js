// S08 A/B: server-controlled fixtures and certified fictitious source context only.
export function attachAIGateway(c,request,organization){
 let epoch=0,current=null,policy=null,status='Chargement de la politique IA…',message='',loading=false,policyRun=0;
 let watched=null,watchTimer=null,accounting=null;
 const states={pending:"En attente",running:"En cours",succeeded:"Réussie",failed:"Échouée avant restitution",cancelled:"Annulée",uncertain:"Résultat incertain — aucune relance automatique"};
 async function refreshRuns(){
  const stamp=epoch;
  try{const r=await request("/identity/ai/runs",{organization_id:organization});if(stamp!==epoch)return;accounting=r;}
  catch{if(stamp!==epoch)return;accounting=null;}
  paint();
 }
 const call=(action,payload={})=>request('/identity/ai',{organization_id:organization,action,payload});
 const paint=()=>c.setState({});
 async function refresh(){
  const stamp=epoch,run=++policyRun;
  try{const p=await call('status');if(stamp!==epoch||run!==policyRun)return;policy=p;status=p.ready?'Recette fictive autorisée':'Connecteur non activé';}
  catch{if(stamp!==epoch||run!==policyRun)return;policy=null;status='Configuration indisponible ou accès refusé';}
  paint();
 }
 async function change(action,enabled){
  if(!policy)return;
  cancel();const stamp=epoch;
  try{await call(action,{enabled,version:action==='approve'?policy.providerVersion:policy.activationVersion,...(action==='activate'?{providerVersion:policy.providerVersion}:{})});if(stamp!==epoch)return;await refresh();if(stamp!==epoch)return;message='Configuration enregistrée sur le serveur.';}
  catch{if(stamp!==epoch)return;message='Modification refusée ou version modifiée. Actualisez la configuration.';await refresh();}
  paint();
 }
 function cancel(){
  if(watchTimer)clearTimeout(watchTimer);watchTimer=null;watched=null;
  const id=current;epoch++;current=null;loading=false;
  if(id)request('/identity/ai/cancel',{organization_id:organization,request_id:id}).catch(()=>{});
  message=id?'Demande annulée. Aucun résultat ne sera affiché.':'';paint();
 }
 async function test(){
  if(loading){cancel();return;}
  cancel();const stamp=epoch,id=crypto.randomUUID();current=id;loading=true;message='Test fictif en cours…';paint();
  try{
   const r=await request('/identity/ai/generate',{organization_id:organization,request_id:id,fixture:'connection'});
   if(stamp!==epoch||current!==id)return;
   if(r.scope!=='fixture-only'||typeof r.text!=='string'||!r.text.trim())throw Error('Réponse invalide.');
   message='Réponse reçue — recette fictive : '+r.text;
  }catch(e){if(stamp!==epoch||current!==id)return;message=e?.message||'Aucune réponse produite.';}
  finally{if(stamp===epoch&&current===id){current=null;loading=false;paint();await refreshRuns();}}
 }
 const contextCall=(action,extra={})=>request('/identity/ai/context',{organization_id:organization,action,...extra});
 async function validateContext(){
  if(!watched)return;
  const snapshot=watched,stamp=epoch;
  try{await contextCall('check',{snapshot});}
  catch{if(stamp===epoch&&snapshot===watched){cancel();message='Contexte retiré : source modifiée, accès retiré ou vérification indisponible.';paint();}return;}
  if(stamp===epoch&&snapshot===watched){watchTimer=setTimeout(validateContext,10000);watchTimer.unref?.();}
 }
 function watch(snapshot){watched=snapshot;watchTimer=setTimeout(validateContext,10000);watchTimer.unref?.();}
 async function contextFlow(generate=false){
  if(loading){cancel();return;}
  cancel();const stamp=epoch,id=crypto.randomUUID();current=id;loading=true;
  message=generate?'Lecture et synthèse des sources fictives…':'Vérification des sources fictives…';paint();
  try{
   const catalog=await contextCall('catalog');if(stamp!==epoch||current!==id)return;
   if(!catalog.sources?.length)throw Error('Aucune source fictive autorisée et inchangée.');
   const preview=await contextCall('preview',{sources:catalog.sources});if(stamp!==epoch||current!==id)return;
   let r=preview;
   if(generate){r=await request('/identity/ai/generate',{organization_id:organization,request_id:id,sources:catalog.sources});if(stamp!==epoch||current!==id)return;if(r.mode!=='verified-excerpts'||!Array.isArray(r.excerpts)||!r.excerpts.length)throw Error('Citations non vérifiables.');}
   await contextCall('check',{snapshot:r.snapshot});if(stamp!==epoch||current!==id)return;
   const labels=generate?r.excerpts.map(e=>`[${e.source}/${e.passage}] ${e.title} · ${e.location} · version ${e.version}`).join('\n'):preview.citations.map(e=>`[${e.source}] ${e.title} · version ${e.version}`).join('\n');
   const text=generate?r.text:preview.sources.map(s=>s.passages.map(p=>`[${s.source}/${p.id}] ${p.text}`).join('\n')).join('\n\n');
   message=(generate?'Extraits vérifiés — recette fictive':'Contexte autorisé — aperçu local')+'\n'+text+'\n\nSources :\n'+labels+'\nMasquage partiel ; aucune diffusion autorisée.';
   watch(r.snapshot);
  }catch(e){if(stamp!==epoch||current!==id)return;message=e?.message||'Contexte indisponible.';}
  finally{if(stamp===epoch&&current===id){current=null;loading=false;paint();await refreshRuns();}}
 }
 const hide=()=>{if(typeof document!=='undefined'&&document.hidden)cancel();};
 if(typeof document!=='undefined')document.addEventListener('visibilitychange',hide);
 c.llmLocal=()=>null;c.llmSource=()=>policy?.ready?'server':'none';
 c.llmText=async()=>{throw Error('Texte libre indisponible. Utilisez les extraits fictifs de l’Assistant ou du panneau unii.');};
 c.aiCorpus=()=>'';
 c.llmConnVals=()=>({pillBg:'var(--acBg)',pillFg:'var(--acTx)',status,note:'ChatGPT via Codex local. Recette fictive uniquement ; aucune donnée métier transmise. Le test utilise les limites du compte connecté. '+(accounting?.runs?.length?'Dernière exécution : '+(states[accounting.runs[0].state]||'Indisponible')+'.':''),
  canReview:!!policy?.canReview,hasKey:!!policy?.canReview&&!!policy?.approved,
  save:()=>change('approve',true),forget:()=>change('approve',false),
  models:[{label:'Actualiser le suivi',bg:'var(--surf2)',fg:'var(--ink3)',go:refreshRuns},{label:'Actualiser la politique',bg:'var(--surf2)',fg:'var(--ink3)',go:async()=>{await refresh();await refreshRuns();}},{label:'Vérifier le contexte fictif',bg:'var(--surf2)',fg:'var(--ink3)',go:()=>contextFlow(false)},{label:'Résumer le contexte fictif',bg:'var(--surf2)',fg:'var(--ink3)',go:()=>contextFlow(true)}],
  testLabel:loading?'Annuler le test':'Tester la connexion',testMsg:message,test});
 const render=c.renderVals.bind(c);c.renderVals=()=>({...render(),llm:c.llmConnVals(),
  providers:[{selected:!!policy?.ready,idle:!policy?.ready,name:'ChatGPT / Codex local',meta:'Recette fictive · approbation globale et activation locale distinctes',go:refresh}],
  keyDisplay:policy?.enabled?'Activation enregistrée'+(policy.ready?'':' — nouvelle approbation requise'):'Désactivé pour cette organisation',
  keyToggleLabel:'Actualiser',toggleKey:refresh,saveLabel:'Activer la recette fictive',
  saveKey:()=>policy?.canActivate?change('activate',true):c.flash('Administration de l’organisation requise.'),
  revokeKey:()=>policy?.canActivate?change('activate',false):c.flash('Administration de l’organisation requise.'),
  aiCallCount:accounting?'Quota de recette : '+accounting.dailyLimit+' demandes/jour UTC':'Suivi indisponible',usage:[{label:'Réservées ou engagées',value:accounting?String(accounting.reservedOrDispatched):'Indisponible',width:accounting?Math.min(100,100*accounting.reservedOrDispatched/accounting.dailyLimit)+'%':'0%'},{label:'Disponibles aujourd’hui',value:accounting?String(accounting.remaining):'Indisponible',width:'0%'},{label:'Jetons / coût',value:'Inconnus',width:'0%'}],
  sourcingBg:'var(--chip)',sourcingLeft:'3px',prudenceLabel:'Test fictif uniquement',prudenceWidth:'0%',prudenceSteps:[],toggleSourcing:()=>c.flash('Aucune recherche juridique raccordée dans ce lot.')});
 const go=c.go.bind(c);c.go=async(route,...args)=>{if(route!==c.state.route)cancel();const r=await go(route,...args);if(c.state.route==='apikey'){await refresh();await refreshRuns();}return r;};
 const back=c.back?.bind(c);if(back)c.back=(...args)=>{cancel();return back(...args);};
 const clear=c.clearIdentity?.bind(c);c.clearIdentity=()=>{cancel();policy=null;accounting=null;status='Connexion requise';message='';clear?.();};
 const unmount=c.componentWillUnmount?.bind(c);c.componentWillUnmount=()=>{cancel();if(typeof document!=='undefined')document.removeEventListener('visibilitychange',hide);unmount?.();};
 return {refresh,test,cancel,change,contextFlow,validateContext,refreshRuns};
}

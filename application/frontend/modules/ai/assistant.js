// Private server history: response text stays outside legacy persisted controller state.
export function attachAssistant(c,request,organization){
 const prompt='Résumer le contexte fictif';
 let epoch=0,refreshId=0,items=[],memories=[],selected=null,pref={enabled:false,version:0},busy=false,current=null,timer=null,notice='Recette fictive uniquement : posez votre question. Aucun contenu métier réel ne doit être saisi.',draft='';
 const call=(action,data={})=>request('/identity/ai/assistant',{organization_id:organization,action,...data});
 const paint=()=>c.setState({});
 const visible=()=>['assistant','memoire'].includes(c.state.route);
 function clear(){
  epoch++;refreshId++;if(timer)clearTimeout(timer);timer=null;
  const id=current;current=null;busy=false;items=[];memories=[];selected=null;draft='';pref={enabled:false,version:0};
  if(id)request('/identity/ai/cancel',{organization_id:organization,request_id:id}).catch(()=>{});
  notice='Recette fictive uniquement : posez votre question. Aucun contenu métier réel ne doit être saisi.';paint();
 }
 function schedule(){if(timer)clearTimeout(timer);if(visible()){timer=setTimeout(refresh,10000);timer.unref?.();}}
 async function refresh(){
  const stamp=epoch,run=++refreshId;
  try{
   const r=await call('list');if(stamp!==epoch||run!==refreshId)return;
   const fresh=r.memories||[];let chosen=null;
   for(const row of r.items){
    if(row.id===selected?.id){const detail=await call('read',{id:row.id});if(stamp!==epoch||run!==refreshId)return;if(row.id===selected?.id)chosen=detail;}
   }
   if(selected&&!chosen)notice='Réponse retirée : source modifiée, accès retiré ou réponse archivée.';
   items=r.items;pref=r.memory;memories=fresh;selected=chosen;paint();
  }catch{if(stamp!==epoch||run!==refreshId)return;items=[];memories=[];selected=null;pref={enabled:false,version:0};notice='Historique indisponible ou accès retiré. Aucun contenu conservé à l’écran.';paint();}
  if(stamp===epoch&&run===refreshId)schedule();
 }
 async function open(id){
  clear();const stamp=epoch;notice='Vérification des sources…';paint();
  try{const item=await call('read',{id});if(stamp!==epoch)return;selected=item;notice='';await refresh();}
  catch{if(stamp!==epoch)return;notice='Réponse indisponible : les droits et versions de toutes les sources doivent rester valides.';paint();}
 }
 async function generate(text=prompt){
  if(busy){clear();notice='Demande annulée. Aucun résultat tardif ne sera affiché.';paint();return;}
  if(typeof text!=='string'||!text.trim())return;
  const prior=selected;
  clear();const stamp=epoch,id=crypto.randomUUID();current=id;busy=true;notice='Lecture des sources fictives autorisées…';paint();
  try{
   let result;
   if(text===prompt){
    const catalog=await request('/identity/ai/context',{organization_id:organization,action:'catalog'});if(stamp!==epoch)return;
    if(!catalog.sources?.length)throw Error('Aucune source fictive autorisée.');
    result=await call('generate',{request_id:id,sources:catalog.sources});
   }else{
    const scope=await request('/identity/ai/chat',{organization_id:organization,action:'status'});if(stamp!==epoch)return;
    if(!scope?.allowed)throw Error('Conversation libre non activée : organisation de recette fictive requise.');
    const sources=(prior?.response?.snapshot||[]).map(({fingerprint,...ref})=>ref);
    result=await request('/identity/ai/chat',{organization_id:organization,request_id:id,question:text,sources,parent:prior?.response?.mode==='conversation'?prior.id:null});
   }
   if(stamp!==epoch||current!==id)return;
   if(result.state!=='succeeded'||!result.persistent)throw Error('Enregistrement non confirmé.');
   // Never display an un-revalidated completion, even from this same session.
   const item=await call('read',{id});if(stamp!==epoch||current!==id)return;
   selected=item;notice='';
  }catch(e){if(stamp!==epoch||current!==id)return;notice=e?.message||'Aucune réponse disponible. Aucune relance automatique.';}
  finally{if(stamp===epoch&&current===id){busy=false;current=null;paint();await refresh();}}
 }
 async function mutate(action,data){
  const stamp=epoch;
  try{await call(action,data);if(stamp!==epoch)return;await refresh();}
  catch{if(stamp!==epoch)return;selected=null;memories=[];items=[];notice='Modification refusée ou version périmée. Actualisez l’historique.';paint();}
 }
 const pin=item=>item&&mutate('remember',{id:item.id,version:item.version,enabled:!item.remembered});
 c.openAIResponse=open;
 c.convSync=()=>{};c.memPrompt=()=>'';c.convHistoryText=()=>'';
 c.setState({aiConvs:[],aiConvId:null,aiMem:[],aiMemOn:false,messages:[],input:'',typing:false});
 c.convNew=()=>{clear();refresh();};c.convOpen=open;
 c.convDel=id=>{const row=items.find(x=>x.id===id);if(row)return mutate('archive',{id,version:row.version});};
 c.memAdd=()=>{c.flash('Mémorisez une réponse sourcée avec son bouton Mémoriser.');return false;};
 c.ask=generate;c.requestAi=generate;
 c.toAssistant=()=>{c.go('assistant');c.flash('Import métier à raccorder au lot E. Utilisez les sources fictives certifiées.');};
 c.convIntake=()=>{clear();notice='Décrivez une situation fictive, ses faits, dates et questions. La réponse reste privée et doit être relue.';paint();};
 c.convToDossier=async()=>{if(!selected)return c.flash('Sélectionnez une réponse enregistrée.');const row=selected,stamp=epoch;try{const result=await call('create_case',{id:row.id,version:row.version});if(stamp!==epoch)return;await c.refreshCases?.();await c.go('dossier',{dossierId:result.id});c.flash('Dossier privé créé ; l’accès reste conditionné à toutes les sources.');}catch{if(stamp===epoch)c.flash('Création refusée : droits, réponse ou sources à vérifier.');}};
 const layout=c.asstVals.bind(c);
 c.asstVals=()=>({...layout(),convTitle:selected?(selected.response?.title||selected.response?.actionLabel||'Synthèse fictive vérifiée'):'Recette fictive — historique serveur privé',originLabel:'Assistant',hasBack:false,
  newConv:c.convNew,newIntake:c.convIntake,toDossier:c.convToDossier,count:items.length+' demandes accessibles (50 max.)',empty:!items.length,
  filters:[{label:'Actualiser',bg:'var(--surf2)',fg:'var(--ink4)',go:refresh},...(selected?.response?.mode==='business-draft'?[{label:'Reprendre le brouillon',bg:'var(--acBg)',fg:'var(--acTx)',go:()=>c.openAIDraft?.(selected.id)}]:[])],
  convs:items.map(x=>({title:x.title||'Synthèse fictive vérifiée',origin:'Assistant',when:new Date(x.created*1000).toLocaleString('fr-FR'),n:'1 demande',oBg:'var(--acBg)',oFg:'var(--acTx)',bg:x.id===selected?.id?'var(--acBg)':'transparent',bd:'var(--bd)',open:()=>open(x.id),del:()=>c.convDel(x.id)}))});
 c.memVals=()=>({on:pref.enabled,swBg:pref.enabled?'var(--ok)':'var(--bd2)',swLeft:pref.enabled?'23px':'3px',
  toggleAll:()=>mutate('configure',{enabled:!pref.enabled,version:pref.version}),
  statusLine:pref.enabled?'Sources mémorisées relues avec les droits actuels avant chaque synthèse fictive.':'Mémoire suspendue : aucune source ajoutée aux prochaines synthèses.',
  short:pref.enabled?'Mémoire · '+memories.length:'Mémoire suspendue',cats:[],draft:'',onDraft:()=>{},add:()=>c.go('assistant'),
  groups:memories.length?[{label:'Réponses fictives retenues',count:memories.length,items:memories.map(x=>({text:x.response.text,meta:'Toutes les sources restent requises · version '+x.version,notEditing:true,editing:false,
   on:true,swBg:'var(--ok)',swLeft:'21px',textFg:'var(--ink)',toggle:()=>pin(x),edit:async()=>{await c.go('assistant');await open(x.id);},del:()=>pin(x)}))}]:[],
  empty:!memories.length,hasAny:false,open:()=>c.go('memoire')});
 const render=c.renderVals.bind(c);
 c.renderVals=()=>{
  const base=render();const response=selected?.response;
  const messages=response?[{isUser:true,text:response.question||response.actionLabel||prompt},{isBot:true,source:response.mode==='conversation'?'Conversation privée · à vérifier':response.mode==='business-draft'?'Brouillon métier · à relire':'Extraits vérifiés · recette fictive',text:response.text+'\n\n'+response.excerpts.map(e=>`[${e.source}/${e.passage}] ${e.title} · ${e.location} · version ${e.version}`).join('\n')+'\nAucune diffusion autorisée.',canMemo:!selected.remembered,memoDone:selected.remembered,memo:()=>pin(selected)}]:[{isBot:true,source:'Assistant · recette fictive',text:notice}];
  return {...base,settings:base.settings?.map(x=>x.title==="Mémoire de l'assistant"?{...x,badge:"Serveur privé"}:x),messages,typing:busy,input:draft,onInput:e=>{draft=e.target.value;paint();},onKey:e=>{if(e.key==='Enter')generate(draft);},send:()=>generate(draft),
   mem:c.memVals(),memShort:c.memVals().short,asst:c.asstVals(),anonLevels:[{selected:true,idle:false,label:'Masquage partiel · données fictives',desc:'Contrôles serveur, pas de garantie d’anonymisation exhaustive.',go:()=>{}}],
   presets:[{label:busy?'Annuler la demande':prompt,go:()=>generate(prompt)},{label:'Actualiser l’historique',go:refresh}]};
 };
 const go=c.go.bind(c);c.go=async(route,...args)=>{if(route!==c.state.route)clear();const result=await go(route,...args);if(visible())await refresh();return result;};
 const back=c.back?.bind(c);if(back)c.back=async(...args)=>{clear();const result=await back(...args);if(visible())await refresh();return result;};
 const identity=c.clearIdentity?.bind(c);c.clearIdentity=()=>{clear();identity?.();};
 const authenticated=c.onAuthenticated?.bind(c);c.onAuthenticated=()=>{clear();authenticated?.();};
 const hide=()=>{if(typeof document!=='undefined'&&document.hidden)clear();};
 if(typeof document!=='undefined')document.addEventListener('visibilitychange',hide);
 const unmount=c.componentWillUnmount?.bind(c);c.componentWillUnmount=()=>{clear();if(typeof document!=='undefined')document.removeEventListener('visibilitychange',hide);unmount?.();};
 return {refresh,open,generate,clear,mutate};
}

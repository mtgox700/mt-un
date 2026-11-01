// Server search and source-bound transfers; asynchronous results stay in their identity/context.
export function attachMessageDiscovery(c,{api,read,epoch,own}){
 let searchRun=0,searchTimer=null,searchRows=[],searchNext=null,searchBusy=false,searchError='';
 let form=null,targetRun=0,targetRows=[],targetNext=null,targetBusy=false;
 const active=()=>c.state.waPane!=='contacts'&&!!String(c.state.waQ||'').trim();
 const changed=()=>c.setState({});
 const resetSearch=()=>{searchRun++;clearTimeout(searchTimer);searchRows=[];searchNext=null;searchBusy=false;searchError='';};
 async function search(more=false){
  const q=String(c.state.waQ||'').trim();if(!q)return resetSearch();
  if(more&&(!searchNext||searchBusy))return;
  const stamp=epoch(),run=++searchRun,before=more?searchNext:null;searchBusy=true;searchError='';
  if(!more){searchRows=[];searchNext=null;}changed();
  try{const r=await api('search',{query:q,...(before?{before}:{})});if(stamp!==epoch()||run!==searchRun||q!==String(c.state.waQ||'').trim())return;
   searchRows=more?[...searchRows,...r.rows.filter(x=>!searchRows.some(y=>y.id===x.id))]:r.rows;searchNext=r.next;
  }catch(e){if(stamp===epoch()&&run===searchRun){searchRows=[];searchNext=null;searchError='Recherche refusée ou indisponible. Réessayez.';}}
  finally{if(stamp===epoch()&&run===searchRun){searchBusy=false;changed();}}
 }
 const wa=c.waVals.bind(c);c.waVals=()=>{const v=wa(),query=active();return {...v,qPh:c.state.waPane==='contacts'?v.qPh:'Rechercher dans tous les messages autorisés',onQ:e=>{v.onQ(e);if(c.state.waPane==='contacts')return;resetSearch();if(String(e.target.value).trim()){searchBusy=true;const stamp=epoch();searchTimer=setTimeout(()=>{if(stamp===epoch())search();},300);}changed();},clearQ:()=>{resetSearch();v.clearQ();},...(query?{filters:[],rows:searchRows.map(r=>({name:r.name,initials:r.name.slice(0,2).toUpperCase(),avatarBg:'linear-gradient(135deg, #334155, #0F172A)',preview:r.message.text+(r.message.file?' · '+r.message.file.name:''),prefix:r.message.who+' : ',time:new Date(r.message.created).toLocaleString('fr-FR'),mineTick:false,hasUnread:false,bg:'transparent',timeFg:'var(--ink6)',timeW:'400',muted:false,pinned:false,isBc:false,go:()=>c.openConvo(r.conversation,r.message.seq)})),noRows:!searchRows.length,noRowsText:searchBusy?'Recherche en cours…':searchError||'Aucun message autorisé ne correspond à cette recherche.'}: {})};};
 const render=c.renderVals.bind(c);c.renderVals=()=>{const v=render();return {...v,...(active()?{messagingMoreLabel:'Autres résultats',messagingMore:!!searchNext&&!searchBusy,messagingMoreGo:()=>search(true)}:{}),messageRecent:!!c.curConvo()?.focused,messageRecentGo:()=>read(c.curConvo().id)};};
 c.searchMessages=search;
 const close=()=>{form=null;targetRun++;targetRows=[];targetNext=null;targetBusy=false;c.setState({fwdMsg:null,fwdSel:[],fwdQ:''});};
 async function targets(more=false){
  if(!form||(more&&(!targetNext||targetBusy)))return;
  const current=form,stamp=epoch(),run=++targetRun,q=String(c.state.fwdQ||''),before=more?targetNext:null;targetBusy=true;
  if(!more){targetRows=[];targetNext=null;}changed();
  try{const r=await api('targets',{query:q,...(before?{before}:{})});if(stamp!==epoch()||current!==form||run!==targetRun)return;
   const rows=r.rows.filter(x=>x.id!==form.id);targetRows=more?[...targetRows,...rows.filter(x=>!targetRows.some(y=>y.id===x.id))]:rows;targetNext=r.next;
  }catch{if(stamp===epoch()&&current===form&&run===targetRun){targetRows=[];targetNext=null;form.error='Discussions accessibles indisponibles.';}}
  finally{if(stamp===epoch()&&current===form&&run===targetRun){targetBusy=false;changed();}}
 }
 c.openServerForward=async(cv,m)=>{const stamp=epoch(),id=cv.id;
  c.setState({waMenu:null});
  try{const r=await api('locate',{id,seq:m.seq});if(stamp!==epoch()||c.curConvo()?.id!==id)return;
   const fresh=r.messages.find(x=>x.seq===m.seq);if(!fresh)return;
   form={id,seq:m.seq,text:fresh.text+(fresh.file?' · '+fresh.file.name:''),who:fresh.who,name:r.name,clientId:crypto.randomUUID(),busy:false,error:'',pending:null};
   c.setState({fwdMsg:{serverReference:true},fwdSel:[],fwdQ:''});await targets();
  }catch{if(stamp===epoch()&&c.curConvo()?.id===id){await read(id);c.flash('Transfert refusé : le message source doit rester accessible.');}}
 };
 c.doForward=async()=>{if(!form||form.busy)return;const current=form,stamp=epoch();
  const selection=[...(form.pending||c.state.fwdSel||[])].sort();if(!selection.length||selection.length>20){form.error='Sélectionnez de 1 à 20 discussions.';changed();return;}
  form.pending=selection;form.busy=true;form.error='';changed();
  try{await api('forward',{id:form.id,seq:form.seq,clientId:form.clientId,targets:selection});if(stamp!==epoch()||form!==current)return;close();c.flash('Référence transférée. Les droits du message source restent obligatoires.');}
  catch(e){if(stamp===epoch()&&form===current){form.error=e.status===403?'Transfert refusé : vérifiez les accès source et destination.':'Résultat non confirmé. Réessayez cette même sélection pour éviter les doublons.';if(e.status===403)form.pending=null;}}
  finally{if(stamp===epoch()&&form===current){form.busy=false;changed();}}
 };
 const fwm=c.fwmVals?.bind(c)||(()=>({open:false}));c.fwmVals=()=>!form?fwm():({open:true,title:'Transférer le message',head:form.who+' · '+form.name,text:form.text,notice:'Référence protégée : seuls les destinataires qui ont encore accès au message source pourront la lire.',error:form.error,q:c.state.fwdQ||'',onQ:e=>{if(form.busy||form.pending)return;c.setState({fwdQ:e.target.value});targets();},rows:targetRows.map(r=>{const on=(c.state.fwdSel||[]).includes(r.id);return {name:r.name,initials:r.name.slice(0,2).toUpperCase(),avatarBg:'var(--ac)',sub:r.kind==='group'?'Groupe':'Discussion privée',on,boxBg:on?'var(--ac)':'var(--surface)',boxBd:on?'var(--ac)':'var(--bd2)',check:on?'✓':'',toggle:()=>{if(form.busy||form.pending)return;const sel=c.state.fwdSel||[];c.setState({fwdSel:on?sel.filter(x=>x!==r.id):[...sel,r.id]});}};}),count:targetBusy?'Chargement…':(form.pending||c.state.fwdSel||[]).length+' discussion(s) sélectionnée(s)',more:!!targetNext&&!targetBusy,moreGo:()=>targets(true),send:()=>c.doForward(),close,busy:form.busy,sendLabel:form.busy?'Transfert…':form.pending?'Réessayer':'Transférer'});
 const menu=c.msgActs.bind(c);c.msgActs=(cv,m)=>{const stamp=epoch();return menu(cv,m).map(a=>own(cv)&&a.label==='Transférer — indisponible'?{label:'Transférer',go:()=>stamp===epoch()&&c.curConvo()?.id===cv.id&&c.openServerForward(cv,m)}:a);};
 const clear=c.clearIdentity?.bind(c);c.clearIdentity=()=>{resetSearch();close();clear?.();};
 c.invalidateMessageDiscovery=()=>{resetSearch();if(form)close();};
 const go=c.go.bind(c);c.go=async(route,...args)=>{const stamp=epoch();c.invalidateMessageDiscovery();const result=await go(route,...args);if(stamp===epoch()&&['messagerie','thread'].includes(route)&&active())await search();return result;};
}

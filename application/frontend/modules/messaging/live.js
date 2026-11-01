// In-memory live projection only. SSE cookies stay HttpOnly; no browser JWT/cache.
export function attachMessageLive(c,{api,organization,epoch,own,conversation,clear,load},env=globalThis){
 let stream=null,run=0,cursor='',revisions=new Map(),notices=[],timer=null,readBusy=false,readKey='',activeId=null,lease=null,connectionStatus='';
 const changed=()=>c.setState({});
 const invalidate=()=>{c.invalidateMessageDiscovery?.();c.closeMessageFilePreview?.();c.setState({waReply:null,waMenu:null,waInfo:false,grEdit:null,thSel:[],thQuote:''});};
 function stop(){run++;stream?.close();stream=null;clearTimeout(timer);clearTimeout(lease);cursor='';activeId=null;}
 function closed(reason='Synchronisation interrompue. Reconnexion en cours…'){connectionStatus=reason;cursor='';invalidate();clear();notices=[];revisions.clear();readKey='';changed();}
 async function acknowledge(){
  const cv=c.curConvo();if(readBusy||!own(cv)||c.state.route!=='thread'||env.document?.visibilityState==='hidden'||(env.document?.hasFocus&&!env.document.hasFocus()))return;
  const el=c.waRef?.current;if(el&&el.scrollHeight-el.scrollTop-el.clientHeight>40)return;
  const seq=cv.messages?.at(-1)?.seq;if(!seq)return;
  const key=cv.id+':'+seq;if(key===readKey)return;
  const stamp=epoch(),ticket=run;readBusy=true;
  try{await api('read',{id:cv.id,seq});if(stamp===epoch()&&ticket===run)readKey=key;}catch{ /* Retry on next focus/update; never fake a read. */ }
  finally{readBusy=false;}
 }
 async function consume(state,ticket,stamp){
  if(ticket!==run||stamp!==epoch())return;
  if(state.cursor===cursor)return;
  const next=new Map(state.conversations.map(x=>[x.id,x.revision]));
  const differs=state.conversations.some(x=>revisions.get(x.id)!==x.revision)||[...revisions.keys()].some(x=>!next.has(x));
  connectionStatus='';cursor=state.cursor;revisions=next;
  // Replace, never merge a revoked projection. Old pages are invalidated on change.
  const current=c.curConvo(),id=current?.id;
  c.setState(s=>({convos:s.convos.filter(x=>!own(x)||next.has(x.id)).map(x=>{const row=state.conversations.find(r=>r.id===x.id);return row?{...x,unread:row.unread}:x;})}));
  if(differs)invalidate();
  if(activeId&&state.thread===null){c.invalidateMessageAccess?.();closed('Accès à cette discussion retiré.');c.setState({route:'messagerie',convoId:null});}
  else if(state.thread&&c.state.route==='thread'&&(id===state.thread.id||(!id&&activeId===state.thread.id))){
   const row=conversation(state.thread);
   c.setState(s=>({convoId:row.id,convos:[...s.convos.filter(x=>x.id!==row.id),row]}));
  }
  notices=state.notices||[];
  const r=state.listing;
  const keepId=state.thread&&c.state.route==='thread'?c.state.convoId:null;
  if(r)c.setState(s=>({convos:[...s.convos.filter(x=>!own(x)||x.id===keepId),...r.rows.filter(x=>x.id!==keepId).map(conversation)]}));
  changed();
  if(differs&&c.state.waQ?.trim()&&c.state.waPane!=='contacts'&&['thread','messagerie'].includes(c.state.route))await c.searchMessages?.();
  await acknowledge();
 }
 function connect(){
  if(!env.EventSource)return;
  const target=c.state.route==='thread'?(own(c.curConvo())?c.curConvo().id:activeId):null;
  stop();const ticket=run,stamp=epoch();activeId=target;
  const query=new URLSearchParams({organization,...(activeId?{id:activeId,...(c.curConvo()?.focused?{at:c.curConvo().focused}:{})}:{}),...(cursor?{cursor}:{})});
  stream=new env.EventSource('/identity/messaging/events?'+query);
  const renew=()=>{clearTimeout(lease);lease=setTimeout(()=>{if(ticket===run){closed();stream?.close();connect();}},25000);};renew();
  stream.addEventListener('heartbeat',renew);
  let queue=Promise.resolve();
  stream.addEventListener('state',e=>{renew();queue=queue.then(()=>consume(JSON.parse(e.data),ticket,stamp)).catch(()=>{if(ticket===run){closed();}});});
  stream.addEventListener('revoked',()=>{if(ticket===run){stop();c.invalidateMessageAccess?.();closed('Accès aux messages retiré ou session expirée.');}});
  stream.addEventListener('unavailable',()=>{if(ticket===run){closed();}});
  stream.onerror=()=>{if(ticket===run){closed();}}; // EventSource reconnects, resume ID is sent by the browser.
 }
 const authenticated=c.onAuthenticated?.bind(c);c.onAuthenticated=()=>{authenticated?.();connect();};
 const go=c.go.bind(c);c.go=async(...args)=>{stop();const result=await go(...args);if(!['connexion','mfa','login'].includes(c.state.route))connect();return result;};
 const oldClear=c.clearIdentity?.bind(c);c.clearIdentity=()=>{stop();notices=[];revisions.clear();readKey='';oldClear?.();};
 const update=c.componentDidUpdate?.bind(c);c.componentDidUpdate=(...args)=>{update?.(...args);clearTimeout(timer);timer=setTimeout(acknowledge,200);};
 const focus=()=>acknowledge();env.addEventListener?.('focus',focus);env.addEventListener?.('scroll',focus,true);env.document?.addEventListener?.('visibilitychange',focus);
 const unmount=c.componentWillUnmount?.bind(c);c.componentWillUnmount=()=>{stop();env.removeEventListener?.('focus',focus);env.removeEventListener?.('scroll',focus,true);env.document?.removeEventListener?.('visibilitychange',focus);unmount?.();};
 const wa=c.waVals?.bind(c);if(wa)c.waVals=()=>{const v=wa();return {...v,...(v.noRows&&connectionStatus?{noRowsText:connectionStatus}:{})};};
 const render=c.renderVals.bind(c);c.renderVals=()=>{const v=render();return {...v,messagingStatus:connectionStatus||v.messagingStatus,hasUnread:notices.length>0||v.hasUnread,markAllRead:async()=>{const stamp=epoch();try{await api('read_all',{});if(stamp!==epoch())return;notices=[];changed();await v.markAllRead?.();}catch{c.flash?.('Lecture des messages non enregistrée.');}},notifications:[...notices.map(n=>({title:n.title,body:'Nouveau message',time:new Date(n.created).toLocaleString('fr-FR'),dot:'var(--ac)',border:'var(--acBd)',go:()=>c.openConvo(n.conversation,n.seq)})),...(v.notifications||[])]};};
 c.syncMessageLive=()=>{if(stream)connect();};
 c.connectMessageLive=connect;c.acknowledgeMessages=acknowledge;
}

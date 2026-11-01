import {attachMessageLive} from './live.js';
import {attachMessageDiscovery} from './discovery.js';
import {attachMessageFiles} from './files.js';
import {attachMessagingMembers} from './members.js';
// The module retains only an in-memory projection; all operations use authorized RPCs.
export function attachMessaging(c,request,organization){
 let epoch=0,loadRun=0,threadRun=0,navigationRun=0,contacts=[],status='',listNext=null,listBusy=false,threadBusy=false,sending=false,creating=false;
 const drafts=new Map(),pending=new Map();let scrollRestore=null;
 const didUpdate=c.componentDidUpdate?.bind(c);if(didUpdate)c.componentDidUpdate=(...args)=>{didUpdate(...args);if(scrollRestore&&c.waRef?.current){const el=c.waRef.current;el.scrollTop=scrollRestore.top+el.scrollHeight-scrollRestore.height;scrollRestore=null;}};
 const own=x=>x?.serverMessage===true;
 const api=(action,payload={})=>request('/identity/messaging',{organization_id:organization,action,payload});
 const message=m=>({...m,time:new Date(m.created).toLocaleString('fr-FR')});
 const conversation=r=>({...r,serverMessage:true,kind:r.kind||'direct',initials:r.name.slice(0,2).toUpperCase(),avatarBg:'linear-gradient(135deg, #334155, #0F172A)',memberIds:(r.memberRows||[]).map(x=>x.me?'c-me':x.id),admins:(r.memberRows||[]).filter(x=>x.admin).map(x=>x.me?'c-me':x.id),members:r.kind==='group'?(r.memberRows||[]).length+' membres':'Discussion privée',unread:r.unread||0,messages:r.messages.map(message)});
 const clear=()=>{c.invalidateMessageDiscovery?.();contacts=[];listNext=null;c.setState({convos:c.state.convos.filter(x=>String(x.id).startsWith('convocation-')),convoId:null,waReply:null,waMenu:null,thSel:[],thQuote:'',fwdMsg:null,grEdit:null});};
 const failed=(e)=>{clear();status=e?.status===403?'Accès à la messagerie refusé.':'Messagerie indisponible. Réessayez depuis Messages.';if(c.state.route==='thread')c.setState({route:'messagerie'});c.flash(status);};
 const unavailable=()=>c.flash('Action indisponible dans ce lot de messagerie.');
 async function load(more=false){
  if(more&&(!listNext||listBusy))return false;
  const stamp=epoch,run=++loadRun,before=more?listNext:null;listBusy=true;status='Chargement des discussions…';
  if(!more)clear();else c.setState({});
  try{
   const [r,people]=await Promise.all([api('list',before?{before}:{}),api('participants')]);
   if(stamp!==epoch||run!==loadRun)return false;
   contacts=people;listNext=r.next;status='';
   const existing=more?c.state.convos.filter(own):[];
   c.setState({convos:[...c.state.convos.filter(x=>!own(x)),...existing,...r.rows.filter(x=>!existing.some(y=>y.id===x.id)).map(conversation)]});
   return true;
  }catch(e){if(stamp===epoch&&run===loadRun)failed(e);return false;}
  finally{if(stamp===epoch&&run===loadRun){listBusy=false;c.setState({});}}
 }
 async function read(id,more=false,at=null){
  if(more&&threadBusy)return false;
  const stamp=epoch,run=++threadRun,previous=c.state.convos.find(x=>x.id===id);
  const before=more?previous?.next:null;
  if(more&&!before)return false;
  threadBusy=true;status='Chargement des messages…';c.setState({});
  try{
   const r=await api(at?'locate':'get',{id,...(at?{seq:at}:before?{before}:{})});
   if(stamp!==epoch||run!==threadRun)return false;
   const row=conversation(r);
   if(more){row.focused=previous.focused;row.messages=[...row.messages,...previous.messages.filter(x=>!row.messages.some(y=>y.id===x.id))];const el=c.waRef?.current;if(el)scrollRestore={top:el.scrollTop,height:el.scrollHeight};}
   c.setState({convos:[...c.state.convos.filter(x=>x.id!==id),row],thSel:[],waMenu:null,waReply:null});status='';if(!more&&c.state.route==='thread'&&c.state.convoId===id)c.syncMessageLive?.();return true;
  }catch(e){if(stamp===epoch&&run===threadRun)failed(e);return false;}
  finally{if(stamp===epoch&&run===threadRun){threadBusy=false;c.setState({});}}
 }
 const go=c.go.bind(c);
 c.go=async(route,params)=>{
  const stamp=epoch,navigation=++navigationRun;
  if(route!=='thread')threadRun++;
  if(route==='messagerie'){const loaded=await load();if(stamp!==epoch||navigation!==navigationRun)return false;if(!loaded)return go(route,params);}
  if(route==='thread'&&!String(params?.convoId||c.state.convoId).startsWith('convocation-')){
   const id=params?.convoId||c.state.convoId;
   if(!id||!(await read(id,false,params?.messageSeq)))return false;
  }
  if(stamp!==epoch||navigation!==navigationRun)return false;
  return go(route,params);
 };
 c.openConvo=async(id,messageSeq)=>{const stamp=epoch,old=c.curConvo();if(own(old))drafts.set(old.id,{text:c.state.msgDraft,reply:c.state.waReply});c.setState({waInfo:false,waMenu:null,waReply:null,thSel:[],thQuote:'',thSelMode:false,msgDraft:''});const result=await c.go('thread',{convoId:id,...(messageSeq?{messageSeq}:{})});if(stamp===epoch&&c.state.convoId===id){const d=drafts.get(id);c.setState({msgDraft:d?.text||'',waReply:d?.reply&&c.state.convos.find(x=>x.id===id)?.messages.some(m=>m.seq===d.reply.seq)?d.reply:null});}return result;};
 c.openDirect=async id=>{
  if(creating)return;const stamp=epoch;creating=true;
  try{
   if(!contacts.some(x=>x.id===id))return unavailable();
   const r=await api('create',{participant:id});if(stamp!==epoch)return;
   c.setState({waPane:'chats',waQ:''});await c.openConvo(r.id);
  }catch(e){if(stamp===epoch)failed(e);}finally{if(stamp===epoch)creating=false;}
 };
 const originalSend=c.sendMsgNow.bind(c);
 c.sendMsgNow=async()=>{
  const cv=c.curConvo();if(!own(cv))return String(cv?.id).startsWith('convocation-')?originalSend():unavailable();
  const text=String(c.state.msgDraft||'').trim();if(!text||sending)return;
  if(text.length>10000)return c.flash('Le message est limité à 10 000 caractères.');
  const replyTo=c.state.waReply?.seq,stamp=epoch,id=cv.id;
  const key=JSON.stringify([id,text,replyTo||null]);
  if(!pending.has(key))pending.set(key,globalThis.crypto.randomUUID());
  sending=true;c.setState({});
  try{
   const m=message(await api('send',{id,clientId:pending.get(key),text,...(replyTo?{replyTo}:{})}));
   if(stamp!==epoch)return;
   pending.delete(key);if(drafts.get(id)?.text?.trim()===text)drafts.delete(id);
   c.setState(s=>({convos:s.convos.map(x=>x.id!==id?x:{...x,messages:[...x.messages.filter(y=>y.id!==m.id),m]}),
    ...(s.convoId===id&&String(s.msgDraft||'').trim()===text?{msgDraft:'',waReply:null}:{})}));
   c.flash('Message enregistré');
  }catch(e){if(stamp===epoch){if(e.status===403)failed(e);else c.flash('Envoi non confirmé. Réessayez le même message : la reprise évite les doublons.');}}
  finally{if(stamp===epoch){sending=false;c.setState({});}}
 };
 const priorWa=c.waVals.bind(c);
 c.waVals=()=>{
  const v=priorWa(),active=own(c.curConvo()),valid=c.state.convos.some(x=>x.id===c.state.convoId);
  return {...v,showChat:v.showChat&&valid,showList:v.showList||!valid,showEmpty:v.showEmpty||(!valid&&!!c.state.isDesktop),teamRows:contacts.filter(x=>(x.name+' '+x.role).toLowerCase().includes(String(c.state.waQ||'').toLowerCase())).map(x=>({name:x.name,initials:x.name.slice(0,2).toUpperCase(),role:x.role,avatarBg:'var(--ac)',go:()=>c.openDirect(x.id)})),adhRows:[],newGroup:unavailable,newBc:unavailable,newContact:unavailable,
   qPh:'Rechercher dans les discussions chargées',noRowsText:status||v.noRowsText,
   ...(active?{composerPh:'Votre message…',chatSub:'Discussion privée',info:{...v.info,canEditCt:false,del:{...v.info.del,label:'Suppression indisponible',act:unavailable},toggleMute:unavailable,togglePin:unavailable}}:{})};
 };
 const oldMenu=c.msgActs.bind(c);
 c.msgActs=(cv,m)=>!own(cv)?oldMenu(cv,m):[
  {label:'Répondre',go:()=>c.setState({waMenu:null,waReply:{who:m.who,text:m.text.slice(0,160),seq:m.seq}})},
  {label:'Informations',go:()=>{c.setState({waMenu:null});c.flash(m.who+' · '+new Date(m.created).toLocaleString('fr-FR'));}},
  {label:'Copier le texte',go:()=>{c.setState({waMenu:null});try{c.copyText(m.text);c.flash('Texte copié');}catch{c.flash('Copie impossible dans ce navigateur');}}},
  {label:'Transférer — indisponible',go:unavailable},
  {label:'Envoyer dans un dossier — indisponible',go:unavailable}
 ];
 for(const name of ['waDelete','doForward','threadUniiRun','threadToDossier','openGroupEdit','saveGroup','grRemove','grToggleAdmin']){
  const old=c[name]?.bind(c);c[name]=(...args)=>own(c.curConvo())||['openGroupEdit','saveGroup','doForward'].includes(name)?unavailable():old?.(...args);
 }
 const oldTh=c.thVals.bind(c);c.thVals=()=>{const v=oldTh();return own(c.curConvo())?{...v,toAsst:unavailable,presets:v.presets.map(x=>({...x,go:unavailable}))}:v;};
 const render=c.renderVals.bind(c);c.renderVals=()=>{const values=render();return {...values,attach:['messagerie','thread'].includes(c.state.route)?unavailable:values.attach,messageAck:'✓',messagingFooter:'Messages privés · stockage serveur',messagingMoreLabel:'Charger les discussions suivantes',messagingMore:!!listNext,messagingMoreGo:()=>load(true),messageMore:own(c.curConvo())&&!!c.curConvo().next,messageMoreGo:()=>read(c.curConvo().id,true),messagingStatus:status||(sending?'Enregistrement du message…':''),...(!String(c.curConvo()?.id).startsWith('convocation-')?{convocationNotice:'Discussion privée enregistrée sur le serveur. Accès réservé aux participants habilités.'}:{})};};
 const oldClear=c.clearIdentity?.bind(c);c.clearIdentity=()=>{epoch++;loadRun++;threadRun++;navigationRun++;pending.clear();drafts.clear();scrollRestore=null;sending=false;creating=false;threadBusy=false;listBusy=false;status='';clear();c.setState({msgDraft:''});oldClear?.();};
 const oldBack=c.back?.bind(c);if(oldBack)c.back=async()=>{await oldBack();if(c.state.route==='messagerie')await load();else if(c.state.route==='thread'&&own(c.curConvo()))await read(c.curConvo().id);};
 c.invalidateMessageAccess=()=>{drafts.clear();pending.clear();c.setState({msgDraft:''});};
 c.refreshMessaging=load;
 attachMessagingMembers(c,{api,read,contacts:()=>contacts,epoch:()=>epoch,own,unavailable});
 attachMessageFiles(c,{api,read,epoch:()=>epoch,own,organization});
 attachMessageDiscovery(c,{api,read,epoch:()=>epoch,own});
 attachMessageLive(c,{api,organization,epoch:()=>epoch,own,conversation,clear,load});
 clear();
 return {load,read};
}

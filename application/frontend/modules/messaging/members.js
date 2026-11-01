// Group moderation and historical access are separate capabilities from the server.
export function attachMessagingMembers(c,{api,read,contacts,epoch,own,unavailable}){
 let busy=false,busyEpoch=-1;
 const current=()=>c.curConvo();
 const scoped=(cv,fn)=>{const stamp=epoch();return()=>{if(stamp!==epoch()||current().id!==cv.id)return;return fn();};};
 const people=()=>{const map=new Map(contacts().map(x=>[x.id,x]));for(const m of current().memberRows||[])map.set(m.id,m);return [...map.values()];};
 const change=p=>c.setState(s=>({grEdit:{...s.grEdit,...p}}));
 const contactRow=(x,on,toggle)=>({name:x.name,initials:x.name.slice(0,2).toUpperCase(),role:x.role||'Membre',catLabel:'Participant',avatarBg:'var(--ac)',on,boxBg:on?'var(--ac)':'var(--surface)',boxBd:on?'var(--ac)':'var(--bd2)',check:on?'✓':'',toggle});
 async function mutate(action,payload,close=false){
  const stamp=epoch(),form=c.state.grEdit;if(busy&&busyEpoch===stamp)return false;busy=true;busyEpoch=stamp;c.setState({});
  try{
   const r=await api(action,payload);if(stamp!==epoch())return false;
   if(close&&c.state.grEdit===form)c.setState({grEdit:null,thSel:[],thSelMode:false,thUniiOpen:false});
   if(r.left){c.setState({convos:c.state.convos.filter(x=>x.id!==payload.id),convoId:null,waInfo:false});await c.go('messagerie');}
   else {await read(r.id);if(stamp!==epoch())return false;if(action==='group_create')await c.openConvo(r.id);}
   c.flash(action.startsWith('history_')?'Accès à l’historique enregistré':'Groupe enregistré');return true;
  }catch(e){
   if(stamp===epoch()){
    if(payload.id)await read(payload.id);
    if(stamp===epoch()){
     const error=e.status===429?'Trop de tentatives. Patientez avant de réessayer.':e.status===403?'Accès refusé ou version périmée. Fermez puis rouvrez le formulaire pour actualiser vos droits et les membres.':'Enregistrement non confirmé. Réessayez sans modifier le formulaire.';
     if(c.state.grEdit===form&&form)change({error});
     c.flash(error);
    }
   }
   return false;
  }finally{if(stamp===epoch()){busy=false;c.setState({});}}
 }
 c.openGroupEdit=async id=>{
  const stamp=epoch();let cv=id?c.state.convos.find(x=>x.id===id):null;
  if(id){if(!own(cv)||!cv.canManage)return unavailable();if(!(await read(id))||stamp!==epoch())return;cv=c.state.convos.find(x=>x.id===id);}
  c.setState({grQ:'',grEdit:{mode:'group',id:id||null,version:cv?.version,name:cv?.name||'',desc:cv?.desc||'',memberIds:(cv?.memberRows||[]).filter(x=>!x.me).map(x=>x.id),clientId:globalThis.crypto.randomUUID()}});
 };
 c.saveGroup=()=>{
  const g=c.state.grEdit;if(!g)return;
  if(g.mode==='history'||g.mode==='revoke'){
   if(g.memberIds.length!==1)return c.flash('Choisissez un participant.');
   return mutate(g.mode==='history'?'history_grant':'history_revoke',{id:g.id,version:g.version,period:g.memberIds[0],...(g.mode==='history'?{messages:g.messages}:{})},true);
  }
  if(!g.name.trim()||(!g.id&&!g.memberIds.length))return c.flash('Indiquez un nom et au moins un participant.');
  return mutate(g.id?'group_save':'group_create',{...(g.id?{id:g.id,version:g.version}:{clientId:g.clientId}),name:g.name.trim(),desc:g.desc,members:g.memberIds},true);
 };
 c.grToggleAdmin=(id,uid)=>{const cv=c.state.convos.find(x=>x.id===id),m=cv?.memberRows?.find(x=>x.id===uid);if(!cv?.canManage||!m||m.me)return unavailable();return mutate('member_role',{id,version:cv.version,participant:uid,admin:!m.admin});};
 c.grRemove=(id,uid)=>{const stamp=epoch(),cv=c.state.convos.find(x=>x.id===id);if(!cv?.canManage)return unavailable();c.openGroupEdit(id).then(()=>{if(stamp===epoch()&&c.state.grEdit?.id===id)change({memberIds:c.state.grEdit.memberIds.filter(x=>x!==uid)});});};
 c.waDelete=id=>{const cv=c.state.convos.find(x=>x.id===id);if(!own(cv)||cv.kind!=='group')return unavailable();return mutate('leave',{id,version:cv.version});};
 const history=(sequences,target=null,revoke=false)=>{
  const cv=current();if(!own(cv)||!cv.canHistory)return unavailable();
  if(!revoke&&!sequences.length)return c.flash('Sélectionnez au moins un message.');
  c.setState({grQ:'',waMenu:null,grEdit:{mode:revoke?'revoke':'history',id:cv.id,version:cv.version,name:'',desc:'',memberIds:target?[target.period]:[],messages:sequences,targets:(cv.memberRows||[]).filter(x=>!x.me)}});
 };
 const menu=c.msgActs.bind(c);c.msgActs=(cv,m)=>{const items=menu(cv,m);return own(cv)&&cv.canHistory?[...items,{label:'Ouvrir ce message à un membre',go:scoped(cv,()=>history([m.seq]))}]:items;};
 const th=c.thVals.bind(c);c.thVals=()=>{const v=th(),cv=current();return {...v,canOpenHistory:own(cv)&&!!cv.canHistory,openHistory:scoped(cv,()=>history((c.state.thSel||[]).map(i=>cv.messages[i]?.seq).filter(Boolean)))};};
 const wa=c.waVals.bind(c);c.waVals=()=>{
  const v=wa(),cv=current();if(!own(cv))return {...v,newGroup:()=>c.openGroupEdit(null)};
  const rows=cv.memberRows||[],isGroup=cv.kind==='group';
  return {...v,newGroup:()=>c.openGroupEdit(null),chatSub:isGroup?rows.length+' membres':'Discussion privée',
   info:{...v.info,isGroup,showMembers:isGroup||cv.canHistory,isDirect:!isGroup,name:cv.name,desc:cv.desc,hasDesc:!!cv.desc,sub:isGroup?'Groupe · '+rows.length+' membres':'Discussion privée',canEdit:isGroup&&cv.canManage,edit:()=>c.openGroupEdit(cv.id),addMembers:()=>c.openGroupEdit(cv.id),memberCount:rows.length+' membres',
    members:rows.map(x=>({name:x.me?'Vous':x.name,initials:x.name.slice(0,2).toUpperCase(),role:x.role,avatarBg:'var(--ac)',isAdmin:x.admin,canAct:cv.canManage&&!x.me,adminLabel:x.admin?'Retirer admin':'Nommer admin',toggleAdmin:()=>c.grToggleAdmin(cv.id,x.id),remove:()=>c.grRemove(cv.id,x.id),msg:()=>c.openDirect(x.id),canRevokeHistory:cv.canHistory&&!x.me&&x.historyCount>0,historyLabel:'Fermer '+x.historyCount+' accès historiques',revokeHistory:scoped(cv,()=>history([],x,true))})),
    del:isGroup?c.askDel('leave-'+cv.id,'Quitter le groupe',()=>c.waDelete(cv.id)):{...v.info.del,label:'Suppression indisponible',act:unavailable}}};
 };
 const original=c.grmVals?.bind(c);
 c.grmVals=()=>{
  const g=c.state.grEdit;if(!g||!['group','history','revoke'].includes(g.mode))return original?.()||{open:false,chips:[],cands:[]};
  const hist=g.mode!=='group',q=String(c.state.grQ||'').toLowerCase();
  const pool=hist?g.targets:people().filter(x=>!x.me);
  const id=x=>hist?x.period:x.id;
  const candidates=pool.filter(x=>!q||(x.name+' '+x.role).toLowerCase().includes(q));
  return {open:true,error:g.error||'',showDetails:!hist,title:g.mode==='revoke'?'Fermer une ouverture d’historique':hist?'Ouvrir les messages sélectionnés':g.id?'Membres & réglages du groupe':'Nouveau groupe',
   name:g.name,desc:g.desc,onName:e=>change({name:e.target.value}),onDesc:e=>change({desc:e.target.value}),
   q:c.state.grQ||'',onQ:e=>c.setState({grQ:e.target.value}),count:hist?(g.mode==='revoke'?'Retrait des ouvertures explicites':g.messages.length+' message(s) explicitement sélectionné(s)'):g.memberIds.length+' sélectionné(s) + vous',
   searchPlaceholder:hist?'Choisir un participant actuel…':'Ajouter un élu, un adhérent, un contact…',
   notice:g.mode==='revoke'?'Toutes les ouvertures explicites du participant choisi seront retirées. Les messages reçus depuis son arrivée restent accessibles.':hist?'L’ouverture concerne uniquement ce participant et sa période actuelle. Les pièces conservent leurs droits propres.':'Les nouveaux membres ne verront que les messages envoyés après leur arrivée.',
   hasChips:g.memberIds.length>0,chips:g.memberIds.map(uid=>({name:pool.find(x=>id(x)===uid)?.name||'Membre',rm:()=>change({memberIds:g.memberIds.filter(x=>x!==uid)})})),
   cands:candidates.map(x=>contactRow(x,g.memberIds.includes(id(x)),()=>change({memberIds:hist?[id(x)]:g.memberIds.includes(id(x))?g.memberIds.filter(v=>v!==id(x)):[...g.memberIds,id(x)]}))),
   save:()=>c.saveGroup(),close:()=>c.setState({grEdit:null}),saveLabel:busy&&busyEpoch===epoch()?'Enregistrement…':g.mode==='revoke'?'Confirmer le retrait':hist?'Confirmer l’ouverture':g.id?'Enregistrer':'Créer le groupe'};
 };
 return {mutate};
}

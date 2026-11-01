const immutableValues=new WeakSet();
function immutable(value){if(!value||typeof value!=='object'||immutableValues.has(value))return value;if(Array.isArray(value)){const copy=Object.freeze(value.map(immutable));immutableValues.add(copy);return copy;}if(Object.getPrototypeOf(value)!==Object.prototype)return value;const copy=Object.freeze(Object.fromEntries(Object.entries(value).map(([k,v])=>[k,immutable(v)])));immutableValues.add(copy);return copy;}
export const ownership=Object.freeze({
 documents:['docs','docId','docTab','docMode','docZoom','docSrcDraft','mobileDocZoom','mobileZoomManual'],
 agenda:['agenda','agMonth','agSel','agView','agTypeF','agEvtId','agNew','mobileAgView'],
 admin:['members','onb','importMembers','invitationDraft'],
 ai:['aiCalls'],
 messaging:['convos','convoId','msgDraft','waPane','waQ','waF','waInfo','waMenu','waReply','fwdMsg','fwdSel','fwdQ','thSel','thQuote','thSelMode','thBusy','thAsk','thUniiOpen','grEdit','grQ'],
 navigation:['route','history','navOrder','navMini'],
 cases:['dossiers','dossierId','noteDraft','dosEdit','dosBusy','dosPick','dosQ','dchats','pieces'],
 contacts:['correctionDraft','paymentDraft','chargeDraft','contacts','adherents','groupes','ctEdit','ctQ','ctCat','adhTab','adhSel','adhF','adhGName','adhEdit','adhDraft','gEditId','adhPage','adhImp','adhMsg','adhLog','adherentId'],
 theme:['brand','brandDraft','brandPreview','brandScope','brandTab','brandLog','charte','webCharte','wcSite','webSite']
});
export function createModuleStores(seed,onChange=()=>{}){
 const owners=new Map();for(const [id,keys]of Object.entries(ownership))for(const key of keys){if(owners.has(key))throw Error('Duplicate state owner');owners.set(key,id);}
 const states=new Map([...Object.keys(ownership),'compatibility'].map(id=>[id,{}]));
 for(const [key,value]of Object.entries(seed))states.get(owners.get(key)||'compatibility')[key]=immutable(value);
 for(const [id,value]of states)states.set(id,Object.freeze(value));let projection=null;
 const snapshot=()=>projection||(projection=Object.freeze(Object.assign({},...states.values())));
 function transact(partitions){const next=[];for(const [id,patch]of partitions){if(!states.has(id))throw Error('Unknown state module');if(!patch||typeof patch!=='object'||Array.isArray(patch))throw Error('Invalid state patch');for(const key of Object.keys(patch)){if(['__proto__','prototype','constructor'].includes(key)||(owners.get(key)||'compatibility')!==id)throw Error('Foreign state write denied');}next.push([id,Object.freeze({...states.get(id),...Object.fromEntries(Object.entries(patch).map(([k,v])=>[k,immutable(v)]))})]);}for(const [id,value]of next)states.set(id,value);projection=null;onChange();}
 const module=id=>{if(!states.has(id)||id==='compatibility')throw Error('Unknown public module');return Object.freeze({read:()=>states.get(id),update:patch=>transact([[id,typeof patch==='function'?patch(states.get(id)):patch]])});};
 const dispatchCompatibility=update=>{const patch=typeof update==='function'?update(snapshot()):update;if(!patch||typeof patch!=='object'||Array.isArray(patch))throw Error('Invalid compatibility patch');const grouped=new Map();for(const [key,value]of Object.entries(patch)){const id=owners.get(key)||'compatibility';if(!grouped.has(id))grouped.set(id,{});Object.defineProperty(grouped.get(id),key,{value,enumerable:true});}transact(grouped);};
 return Object.freeze({module,snapshot,dispatchCompatibility});
}

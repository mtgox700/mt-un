// Encrypted per-user/per-organization drafts. No automatic deletion of unsent bytes.
function open(){return new Promise((resolve,reject)=>{const r=indexedDB.open('uniion-audio-v1',2);r.onupgradeneeded=()=>{for(const name of ['keys','drafts','parts'])if(!r.result.objectStoreNames.contains(name))r.result.createObjectStore(name)};r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);r.onblocked=()=>reject(Error('Stockage audio occupé.'));});}
async function tx(store,mode,fn){const db=await open();return new Promise((resolve,reject)=>{const t=db.transaction(store,mode),r=fn(t.objectStore(store));t.oncomplete=()=>{db.close();resolve(r.result)};t.onerror=t.onabort=()=>{db.close();reject(t.error||r.error)}});}
async function key(scope){let k=await tx('keys','readonly',s=>s.get(scope));if(k)return k;k=await crypto.subtle.generateKey({name:'AES-GCM',length:256},false,['encrypt','decrypt']);try{await tx('keys','readwrite',s=>s.add(k,scope));return k}catch{return tx('keys','readonly',s=>s.get(scope));}}
export async function seal(key,scope,value){const iv=crypto.getRandomValues(new Uint8Array(12)),data=new TextEncoder().encode(JSON.stringify(value));return {iv,bytes:await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:new TextEncoder().encode(scope)},key,data)};}
export async function unseal(key,scope,record){const raw=await crypto.subtle.decrypt({name:'AES-GCM',iv:record.iv,additionalData:new TextEncoder().encode(scope)},key,record.bytes);return JSON.parse(new TextDecoder().decode(raw));}
export function confirmedLocalCopy(value,receipts){
 return value.saved===true&&Array.isArray(value.segments)&&value.segments.length>0&&value.segments.every(p=>receipts.some(r=>r.meeting===value.meeting&&r.request===p.request&&r.audio===p.audio));
}
export function audioVault(scope){
 let until=0;const unlocked=()=>{if(Date.now()>=until)throw Error('Accès local expiré ; reconnectez-vous pour renouveler. Brouillon conservé.');};
 return {unlock(hours=24){if(!Number.isInteger(hours)||hours<1||hours>168)throw Error('Durée locale invalide.');until=Date.now()+hours*3600000;},lock(){until=0;},
 async cleanup(receipts){
  unlocked();if(!Array.isArray(receipts))throw Error('Reçus serveur requis.');
  const rows=await tx('drafts','readonly',s=>s.getAll()),remove=[];
  for(const row of rows.filter(x=>x.scope===scope)){const value=await unseal(await key(scope),scope,row);if(confirmedLocalCopy(value,receipts))remove.push(value.request);}
  if(!remove.length)return 0;unlocked();const db=await open();
  await new Promise((resolve,reject)=>{const t=db.transaction(['drafts','parts'],'readwrite'),parts=t.objectStore('parts');for(const request of remove)t.objectStore('drafts').delete(scope+':'+request);const cursor=parts.openCursor();cursor.onsuccess=()=>{const c=cursor.result;if(!c)return;if(remove.some(request=>String(c.key).startsWith(scope+':'+request+':')))c.delete();c.continue();};t.oncomplete=()=>{db.close();resolve();};t.onerror=t.onabort=()=>{db.close();reject(t.error)};});return remove.length;
 },
 async read(options={}){unlocked();const rows=await tx('drafts','readonly',s=>s.getAll());for(const r of rows.filter(x=>x.scope===scope).sort((a,b)=>b.updatedAt-a.updatedAt)){const value=await unseal(await key(scope),scope,r);if(!value.saved&&(options.archivedOnly?value.archived:!value.archived))return value;}return null;},
 async save(value){const updatedAt=Date.now(),r=await seal(await key(scope),scope,{...value,updatedAt});await tx('drafts','readwrite',s=>s.put({...r,scope,updatedAt},scope+':'+value.request));},
 async savePart(request,index,content){const id=scope+':'+request+':'+index,k=await key(scope),existing=await tx('parts','readonly',s=>s.get(id));if(existing){if((await unseal(k,id,existing)).content!==content)throw Error('Segment local déjà écrit avec un autre contenu.');return;}const r=await seal(k,id,{content});await tx('parts','readwrite',s=>s.add(r,id));},
 async saveCapture(value,index,content){
  const id=scope+':'+value.request+':'+index,k=await key(scope),existing=await tx('parts','readonly',s=>s.get(id));
  if(existing&&(await unseal(k,id,existing)).content!==content)throw Error('Segment local divergent.');
  const updatedAt=Date.now(),part=existing||await seal(k,id,{content}),manifest=await seal(k,scope,{...value,updatedAt});
  const db=await open();await new Promise((resolve,reject)=>{const t=db.transaction(['parts','drafts'],'readwrite');if(!existing)t.objectStore('parts').add(part,id);t.objectStore('drafts').put({...manifest,scope,updatedAt},scope+':'+value.request);t.oncomplete=()=>{db.close();resolve();};t.onerror=t.onabort=()=>{db.close();reject(t.error||Error('Stockage local indisponible.'));};});
 },
 async readPart(request,index){unlocked();const id=scope+':'+request+':'+index,r=await tx('parts','readonly',s=>s.get(id));if(!r)throw Error('Segment local manquant ; sauvegarde non confirmée.');return (await unseal(await key(scope),id,r)).content;}};
}
// An origin-wide Web Lock prevents two tabs from modifying the same user's draft.
export async function draftLease(scope){
 if(!navigator.locks)throw Error('Verrouillage multi-onglets indisponible. Utilisez un navigateur compatible.');
 let release;const held=new Promise(resolve=>{release=resolve;});let ready;
 const acquired=new Promise((resolve,reject)=>{ready={resolve,reject};});
 navigator.locks.request('uniion-audio:'+scope,{ifAvailable:true},async lock=>{if(!lock){ready.reject(Error('Un autre onglet utilise les brouillons audio.'));return;}ready.resolve(release);await held;}).catch(ready.reject);
 return acquired;
}

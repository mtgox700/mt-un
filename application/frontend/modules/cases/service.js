export function createCasesService(store){return Object.freeze({
 list:()=>store.read().dossiers||[],
 patch(idOrPatch,value){const id=typeof idOrPatch==='string'?idOrPatch:store.read().dossierId;const patch=typeof idOrPatch==='string'?value:idOrPatch;if(!patch||typeof patch!=='object')return;store.update(s=>({dossiers:s.dossiers.map(d=>d.id===id?{...d,...patch}:d)}));},
 get:id=>(store.read().dossiers||[]).find(d=>d.id===id)||null
});}

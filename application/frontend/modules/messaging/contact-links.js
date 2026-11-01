export function createContactLinks(store,{describe}){return Object.freeze({
 rename(id,name,initials){store.update(s=>({convos:s.convos.map(c=>{const f=describe(c);return f.kind==='direct'&&f.contactId===id?{...c,name,initials}:c})}));},
 remove(id){store.update(s=>({convos:s.convos.filter(c=>{const f=describe(c);return !(f.kind==='direct'&&f.contactId===id)}).map(c=>{const f=describe(c);return f.kind==='group'&&f.memberIds.includes(id)?{...c,memberIds:f.memberIds.filter(x=>x!==id),admins:f.admins.filter(x=>x!==id)}:c})}));}
});}

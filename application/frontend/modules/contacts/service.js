export function createContactsService(store,{fallback=[]}={}){
 const initials=name=>{const parts=String(name||'').trim().split(/\s+/).filter(Boolean);return parts.length?((parts[0][0]||'')+(parts.length>1?parts.at(-1)[0]:(parts[0][1]||''))).toUpperCase():'?';};
 const matches=(a,f)=>{for(const [key,all]of [['ent','Toutes'],['etab','Tous'],['sect','Toutes'],['dir','Toutes'],['statut','Tous']])if(f[key]&&f[key]!==all&&a[key]!==f[key])return false;const q=(f.q||'').trim().toLowerCase();return !q||(a.prenom+' '+a.nom+' '+a.email+' '+a.poste).toLowerCase().includes(q);};
 const list=()=>{const s=store.read();return (s.contacts||fallback).concat((s.adherents||[]).map(a=>{const name=(a.prenom||'')+' '+(a.nom||'');return {id:'adh-'+a.id,adhId:a.id,name:name.trim(),initials:a.initials||initials(name),role:a.poste||'Adhérent·e',cat:'adherent',tel:a.tel||'',email:a.email||''};}));};
 return Object.freeze({list,get:id=>list().find(c=>c.id===id),members:g=>(store.read().adherents||[]).filter(a=>g.type==='fixe'?(g.ids||[]).includes(a.id):matches(a,g.crit||{}))});
}

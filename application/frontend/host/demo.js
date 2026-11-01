// Isolated fixture adapter: no persisted browser data and no backend connection.
(() => {
 const values=new Map();
 Object.defineProperty(window,'localStorage',{value:{getItem:k=>values.get(k)??null,setItem:(k,v)=>values.set(k,String(v)),removeItem:k=>values.delete(k),clear:()=>values.clear()}});
 window.fetch=async()=>{throw new Error('Démonstration S02 : service non raccordé');};
})();

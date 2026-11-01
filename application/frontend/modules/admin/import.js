export function createAdminImport(store,{go,flash,clearCsv}){return Object.freeze({active:()=>!!store.read().importMembers,importRows(valid){const context={get state(){return store.read()},setState:update=>{const p=typeof update==='function'?update(store.read()):update;const {adhImp,...own}=p;store.update(own);if(adhImp)clearCsv(adhImp)},go,flash};return (function(){
      const existing = new Set(this.state.members.map(m => String(m.email || '').toLowerCase()));
      const members = valid.filter(r => !existing.has(r.rec.email.toLowerCase())).map((r,i) => ({id:'member'+Date.now()+i,name:r.rec.prenom+' '+r.rec.nom,email:r.rec.email,initials:(r.rec.prenom[0]+r.rec.nom[0]).toUpperCase(),role:'Élu',last:'Import local — invitation non envoyée',status:'Invité'}));
      if (!members.length) return this.flash('Aucun nouveau membre à importer');
      this.setState(s => ({members:s.members.concat(members),onb:Object.assign({},s.onb,{membres:true}),importMembers:false,adhImp:{text:'',touched:false,fileName:''}}));
      this.go('membres'); return this.flash(members.length+' membres importés localement — invitations non envoyées');
    }).call(context)}});}

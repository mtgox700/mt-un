const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),path=require('path');
const root=path.resolve(__dirname,'../public/uniion App v3.dc.html');
const src=fs.readFileSync(root,'utf8').match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1];
let store={},timers=[],checks=[];
const sb={React:{createRef:()=>({})},DCLogic:class{props={};setState(p){Object.assign(this.state,typeof p==='function'?p(this.state):p)}},console,Date,Map,Set,Blob,URL,setTimeout:f=>(timers.push(f),timers.length),clearTimeout(){},setInterval:()=>1,clearInterval(){},window:{scrollTo(){},localStorage:{getItem:k=>store[k],setItem:(k,v)=>store[k]=v}}};
vm.createContext(sb);vm.runInContext(src+'\nglobalThis.C=Component; globalThis.csvCols=ADH_CSV_COLS;',sb);
function app(){const a=new sb.C();a.state=JSON.parse(JSON.stringify(a.state));a.flash=x=>a.notice=x;a.go=(r,p)=>a.setState({route:r,...p});return a;}
function check(name,fn){try{fn();checks.push({name,result:'PASS'});}catch(e){checks.push({name,result:'FAIL',detail:e.message});}}
function reload(a){store={};timers=[];a.persist();timers.splice(0).forEach(f=>f());const b=app();b.restore();return b;}
for(const [field,value,pattern] of [['nom','',/obligatoire/],['siret','123',/14 chiffres/],['email','err',/invalide/],['mandatFin','2020-01-01',/fin du mandat/]])check('Profil refuse '+field,()=>{let a=app();a.orgStartEdit();a.orgPatch(field,value);a.orgSave();assert.equal(a.state.orgEdit,true);assert.match(a.notice,pattern);});
check('Profil annulation',()=>{let a=app(),old=a.state.org.nom;a.orgStartEdit();a.orgPatch('nom','TEST');a.orgCancelEdit();assert.equal(a.state.org.nom,old);});
check('Profil sauvegarde et restauration',()=>{let a=app();a.orgStartEdit();a.orgPatch('sigle','TEST');a.orgSave();assert.equal(reload(a).state.org.sigle,'TEST');});
check('Contact nom requis',()=>{let a=app();a.openContactEdit();a.saveContact();assert.match(a.notice,/nom est requis/);});
check('Contact création et restauration',()=>{let a=app();a.openContactEdit();a.state.ctEdit.name='Test Recette';a.state.ctEdit.email='test@example.invalid';a.saveContact();assert(reload(a).state.contacts.some(x=>x.name==='Test Recette'));});
check('Groupe nom requis',()=>{let a=app();a.openGroupEdit();a.saveGroup();assert.match(a.notice,/nom au groupe/);});
check('Groupe membre requis',()=>{let a=app();a.openGroupEdit();a.state.grEdit.name='Test';a.saveGroup();assert.match(a.notice,/au moins un membre/);});
check('Groupe créé et restauré',()=>{let a=app();a.openGroupEdit();a.state.grEdit.name='Test';a.state.grEdit.memberIds=[a.allContacts().find(x=>x.id!=='c-me').id];a.saveGroup();assert(reload(a).state.convos.some(x=>x.name==='Test'&&x.kind==='group'));});
check('Fiche refuse courriel doublon',()=>{let a=app();a.adhStartEdit();a.adhPatchDraft('email',a.state.adherents[1].email);a.adhSaveEdit();assert.match(a.notice,/déjà rattaché/);});
check('Agenda création édition restauration',()=>{let a=app();a.agOpenNew('2026-10-23');a.agSetNew({title:'TEST',start:'09:00',end:'10:00'});a.agCreate();let id=a.state.agEvtId;a.agSetNew({editId:id,title:'MODIF',date:'2026-10-23',start:'10:00',end:'11:00',lieu:'Test',notes:'',type:'cse',visib:'elus'});a.agCreate();assert.equal(reload(a).state.agenda.find(x=>x.id===id).title,'MODIF');});
check('Agenda date impossible refusée',()=>{let a=app(),n=a.state.agenda.length;a.agOpenNew('2026-02-31');a.agSetNew({title:'TEST'});a.agCreate();assert.equal(a.state.agenda.length,n);});
check('Suppression adhérent exemple persiste',()=>{let a=app(),id=a.state.adherents[0].id;a.adhDelete(id);assert(!reload(a).state.adherents.some(x=>x.id===id));});
check('Suppression événement exemple persiste',()=>{let a=app(),id=a.state.agenda[0].id;a.agDelete(id);assert(!reload(a).state.agenda.some(x=>x.id===id));});
const row={prenom:'Test',nom:'Recette',email:'test@example.invalid',ent:'Métallurgie Valenciennes SA',etab:'Site de Valenciennes',sect:'Section Atelier',dir:'Production'};
function csv(rows){return sb.csvCols.map(x=>x.h).join(';')+'\n'+rows.map(r=>sb.csvCols.map(x=>r[x.k]||'').join(';')).join('\n');}
check('CSV valide importé et restauré',()=>{let a=app();a.state.adhImp={text:csv([row]),touched:true};a.runCsvImport();assert(reload(a).state.adherents.some(x=>x.email===row.email));});
check('CSV invalide refusé',()=>{let a=app();assert.equal(a.parseAdhCsv(csv([{...row,email:'invalide'}])).ok,0);});
check('CSV courriel @ seul refusé',()=>{let a=app();assert.equal(a.parseAdhCsv(csv([{...row,email:'@'}])).ok,0);});
check('CSV doublon exact refusé',()=>{let a=app();assert.equal(a.parseAdhCsv(csv([row,row])).ok,1);});
check('CSV doublon casse différente refusé',()=>{let a=app();assert.equal(a.parseAdhCsv(csv([row,{...row,email:row.email.toUpperCase()}])).ok,1);});
check('CSV champ cité avec séparateur conservé',()=>{let a=app(),r=a.parseAdhCsv(csv([{...row,nom:'"Recette; Test"'}]));assert.equal(r.ok,1);assert.equal(r.rows[0].rec.nom,'Recette; Test');});
check('Stockage corrompu ne plante pas',()=>{store={};let a=app();timers=[];a.persist();timers.splice(0).forEach(f=>f());for(let k in store)store[k]='{';assert.doesNotThrow(()=>app().restore());});
check('Authentification refuse mauvais courriel',()=>{let a=app();a.setAuth({email:'err',pwd:'demo'});a.submitId();assert.match(a.state.auth.err,/invalide/);});
check('MFA refuse mauvais code',()=>{let a=app();a.setAuth({code:'111111'});a.submitMfa();assert.equal(a.state.authed,false);assert.match(a.state.auth.err,/incorrect/);});
check('Relecture demandée ne marque pas déjà relue',()=>{let a=app();a.state.pageId=a.state.pages[0].id;a.askReview();assert.notEqual(a.curPage().status,'Relue');});
check('Brouillon marque ne modifie pas la marque active',()=>{let a=app(),before=JSON.stringify(a.state.brand);a.state.brandDraft=JSON.parse(before);a.state.brandScope='org';a.patchBrandDraft({accent:'#123456'});assert.equal(JSON.stringify(a.state.brand),before);});
check('Marque publiée conservée en stockage isolé',()=>{let a=app();a.state.brandDraft=JSON.parse(JSON.stringify(a.state.brand));a.state.brandScope='org';a.patchBrandDraft({accent:'#123456'});a.publishBrand();assert.equal(reload(a).state.brand.accent,'#123456');});
check('Action unii désactivée masquée',()=>{let a=app();a.state.uniiCfg={test:{on:false,roles:[]}};assert.equal(a.uniiAllowed({id:'test',roles:[]}),false);});
check('Action unii limitée au rôle',()=>{let a=app();a.state.uniiRole='elu';assert.equal(a.uniiAllowed({id:'test',roles:['ds']}),false);a.state.uniiRole='ds';assert.equal(a.uniiAllowed({id:'test',roles:['ds']}),true);});
fs.writeFileSync(path.join(__dirname,'resultats-logique.json'),JSON.stringify(checks,null,2));
console.log(checks.map(x=>x.result+' '+x.name+(x.detail?' — '+x.detail:'')).join('\n'));console.log(checks.filter(x=>x.result==='PASS').length+' réussis / '+checks.length+' ; échecs = constats à qualifier, sans modification de l’application.');
if(checks.some(x=>x.result==='FAIL')) process.exitCode=1;

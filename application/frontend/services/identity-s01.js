import {createPermissionsNavigation} from './permissions-navigation.js';
import {createS01MemberActions} from './members-s01.js';
// Organization-scoped identity. All writes are authorized again by Supabase.
export function attachS01Identity(controller,request,organizationId){
 let current=null,generation=0;
 const openOrganizations=createPermissionsNavigation(request,organizationId,url=>window.location.assign(url),()=>controller.flash('Accès à cette organisation refusé ou indisponible.'),{endpoint:'/identity/console',hash:'#organisations'});
 const openPermissions=createPermissionsNavigation(request,organizationId,url=>window.location.assign(url),message=>controller.flash(message));
 const empty=()=>controller.setState({members:[],contacts:[],adherents:[],groupes:[],convos:[]});
 const initials=s=>String(s||'?').slice(0,2).toUpperCase();
 async function refresh(){const run=++generation;current=null;empty();const p=await request('/identity/profile',{organization_id:organizationId});let d={members:[],invitations:[]};if(p.can_manage)d=await request('/identity/directory',{organization_id:organizationId});if(run!==generation)return;
 current={profile:p,directory:d};
 const members=d.members.map(m=>({...m,initials:initials(m.name),role:'Membre',last:m.email,status:m.revoked_at?'Retiré':m.suspended?'Suspendu':'Actif',kind:'member'}));
 const labels={pending:'Invité',accepted:'Acceptée',revoked:'Révoquée',expired:'Expirée'};
 const invitations=d.invitations.map(i=>({...i,name:i.email,initials:initials(i.email),role:'Invitation',last:'Créée le '+new Date(i.created_at).toLocaleDateString('fr-FR'),status:labels[i.status],kind:'invitation'}));
 controller.setState({members:[...members,...invitations],contacts:members.filter(m=>!m.revoked_at&&!m.suspended).map(m=>({...m,cat:'team',tel:''})),org:{...Object.fromEntries(Object.keys(controller.state.org).map(k=>[k,''])),type:'cse',...p.organization_details,nom:p.organization}});
 }
 const memberRows=createS01MemberActions(controller,request,organizationId,()=>current,refresh);
 const originalConfirm=controller.confirmSheet?.bind(controller);
 let saving=false;
 controller.confirmSheet=async()=>{
  if(controller.state.sheet!=='editSignature')return originalConfirm?.();
  if(saving)return;
  const lines=String(controller.state.sheetText||'').split(/\r?\n/).map(s=>s.trim());
  if(lines.length!==3||!lines[0]||!lines[1]||lines[2]!==current?.profile.email)return controller.setState({sheetErr:'Indiquez un nom, une fonction et votre courriel de connexion sur trois lignes.'});
  saving=true;
  try{await request('/identity/profile/save',{organization_id:organizationId,name:lines[0],role:lines[1],email:lines[2]});await refresh();controller.setState({sheetDone:true,sheetErr:''});controller.flash('Signature enregistrée');}
  catch(e){controller.setState({sheetErr:'Enregistrement refusé ou indisponible. Vos modifications restent dans le formulaire.'});}
  finally{saving=false;}
 };
 controller.orgSave=async()=>{
  if(saving)return;
  if(!current?.profile.can_edit_organization)return controller.flash('Permission de modification de l’organisation requise.');
  saving=true;
  try{await request('/identity/organization/save',{organization_id:organizationId,details:{...controller.state.orgDraft}});await refresh();controller.setState({orgEdit:false,orgDraft:null});controller.flash('Informations de l’organisation enregistrées');}
  catch(e){controller.flash('Enregistrement refusé : vérifiez les champs et votre habilitation.');}
  finally{saving=false;}
 };
 const render=controller.renderVals.bind(controller);
 controller.renderVals=()=>{const v=render(),p=current?.profile;const deny=()=>controller.flash('Action non raccordée aux droits réels.');return {...v,adminLinks:[...(v.adminLinks||[]),{label:'Organisations & partages',meta:'Espaces indépendants et partages explicites',go:openOrganizations},{label:'Droits & membres',meta:'Permissions métier et habilitations',go:openPermissions}],org:{...v.org,startEdit:()=>p?.can_edit_organization?controller.orgStartEdit():controller.flash('Permission de modification de l’organisation requise.'),types:(v.org?.types||[]).map((t,i)=>({...t,go:()=>{if(!p?.can_edit_organization)return deny();if(!controller.state.orgEdit)controller.orgStartEdit();controller.orgPatch('type',controller.orgTypeDefs()[i].id);}})),subtitle:p?.organization||''},stats:(v.stats||[]).map(s=>({...s,value:'—'})),profileSessionText:'Session S01 authentifiée. Les jetons restent côté serveur.',profileDataText:'Profil, annuaire et invitations issus de Supabase local. Les autres modules et informations d’abonnement restent à raccorder.',userName:p?.name||'',userInitials:initials(p?.name),userRole:p?.can_manage?'Gestion des droits':'Membre',profileRole:p?.can_manage?'Gestion des droits':'Membre',profileFields:[{label:'Courriel',value:p?.email||'—'},{label:'Organisation',value:p?.organization||'—'},{label:'Mandat',value:'Non renseigné'},{label:'Fonction',value:p?.role_label||'Non renseignée'},{label:'Commissions',value:'Non renseignées'}],profileSignatureName:p?.name||'',profileSignatureRole:p?.role_label||'Non renseigné',profileSignatureEmail:p?.email||'',toast_saved:()=>{controller.openSheet('editSignature');controller.setState({sheetText:[p?.name||'',p?.role_label||'',p?.email||''].join('\n')});},sheetDoneLines:controller.state.sheet==='editSignature'?[{text:'Signature enregistrée dans Supabase pour cette organisation.'}]:v.sheetDoneLines,toggleVisible:deny,members:memberRows(v.members||[]),memberSummary:p?.can_manage?current.directory.members.length+' membres · '+current.directory.invitations.length+' invitations':'Annuaire réservé aux personnes habilitées',orgStats:[{value:String(current?.directory.members.filter(m=>!m.revoked_at&&!m.suspended).length||0),label:'membres actifs'},{value:String(current?.directory.invitations.filter(i=>i.status==='pending').length||0),label:'invitations en attente'}]};};
 const go=controller.go.bind(controller);controller.go=async(route,...args)=>{if(['profil','membres','contacts'].includes(route)){try{await refresh();}catch(e){controller.flash('Accès refusé ou lecture indisponible.');}}return go(route,...args);};
 controller.refreshIdentity=refresh;controller.clearIdentity=()=>{generation++;current=null;empty();};empty();return {refresh};
}

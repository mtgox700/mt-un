// Existing row actions, with server authorization and the existing confirmation flow.
export function createS01MemberActions(controller,request,organizationId,read,refresh){
 let pending=false;
 async function run(path,data){
  if(pending)return;
  if(!read()?.profile.can_manage)return controller.flash('Gestion des membres réservée aux personnes habilitées.');
  pending=true;
  try{await request(path,{organization_id:organizationId,...data});await refresh();controller.flash('Modification enregistrée dans Supabase.');}
  catch(e){controller.flash('Action refusée ou service indisponible.');}
  finally{pending=false;}
 }
 return function rows(views){return views.map((view,index)=>{
  const row=controller.state.members[index];if(!row)return view;
  const invite=row.kind==='invitation',terminal=invite?['Acceptée','Révoquée'].includes(row.status):!!row.revoked_at;
  const unavailable=()=>controller.flash('Cet accès est clôturé. Aucune réactivation automatique.');
  const self=!invite&&row.id===read()?.profile.id;
  const blocked=()=>controller.flash('Vous ne pouvez pas suspendre ou retirer votre propre accès.');
  const go=terminal?unavailable:self?blocked:()=>run(invite?'/identity/invitations/resend':'/identity/memberships/status',invite?{invitation_id:row.id}:{user_id:row.id,action:row.suspended?'resume':'suspend'});
  const remove=()=>run(invite?'/identity/invitations/revoke':'/identity/memberships/revoke',invite?{invitation_id:row.id}:{user_id:row.id});
  return {...view,action:terminal?'Clôturée':invite?'Relancer':row.suspended?'Réactiver':'Suspendre',go,del:terminal?{...view.del,act:unavailable}:self?{...view.del,act:blocked}:controller.askDel('s01-member-'+row.id,'Retirer',remove)};
 });};
}

export const invitationDefinition = {
        title: 'Inviter des élus',
        sub: 'Chaque invité reçoit un lien nominatif valable 7 jours et devra activer une double authentification.',
        optLabel: 'Profil indicatif — droits à attribuer séparément',
        options: [
          { label: 'Élu titulaire', hint: 'Aucun accès au coffre accordé automatiquement' },
          { label: 'Élu suppléant', hint: 'Lecture et sondages à autoriser séparément' },
          { label: 'Expert externe', hint: 'Accès aux dossiers à autoriser explicitement' }
        ],
        field: 'Adresses email, séparées par une virgule',
        placeholder: 'prenom.nom@cse-valenciennes.fr',
        confirm: 'Envoyer les invitations',
        doneTitle: 'Invitations envoyées',
        doneLines: ['Aucun droit métier attribué par cette invitation.', 'Statut suivi dans la liste des membres.'],
        doneAction: 'Voir les membres', doneGo: 'membres'
      };
export function createInvitation(store,{go,flash,submitReal}){
 const empty=()=>({open:false,opt:0,text:'',error:'',done:false});
 const read=()=>store.read().invitationDraft||empty();
 const patch=p=>store.update({invitationDraft:{...read(),...p}});
 const close=()=>patch({open:false,error:''});
 let submitting=false;
 const submit=async()=>{if(!read().open||read().done||submitting)return;if(read().text.indexOf('@')===-1){patch({error:'Renseignez au moins une adresse email valide.'});return;}if(submitReal){submitting=true;try{await submitReal({text:read().text,requestedRole:read().opt});patch({done:true,error:''});flash('Invitation déposée dans la messagerie locale.');}catch(e){patch({error:e.message||'Invitation indisponible.'});}finally{submitting=false;}return;}patch({done:true,error:''});flash(invitationDefinition.doneTitle);};
 return Object.freeze({openInvitation(){store.update({invitationDraft:{...empty(),open:true}})},submitInvitation:submit,invitationVals(){const s=read(),d=invitationDefinition;return {
 sheetOpen:s.open,sheetTitle:d.title,sheetSub:d.sub,sheetOptLabel:d.optLabel,
 sheetOptions:d.options.map((o,i)=>({...o,selected:s.opt===i,idle:s.opt!==i,pick:()=>patch({opt:i})})),
 sheetHasChecks:false,sheetChecks:[],sheetHasField:true,sheetFieldLabel:d.field,sheetPlaceholder:d.placeholder,
 sheetText:s.text,onSheetText:e=>patch({text:e.target.value,error:''}),sheetErr:s.error,sheetHasErr:!!s.error,
 sheetConfirmLabel:d.confirm,sheetForm:s.open&&!s.done,sheetDone:s.done,sheetDoneTitle:d.doneTitle,
 sheetDoneLines:d.doneLines.map(text=>({text})),sheetIsFile:false,sheetDoneAction:d.doneAction,
 sheetConfirm:submit,sheetClose:close,sheetFollow:()=>{close();go(d.doneGo)}
 };}});
}

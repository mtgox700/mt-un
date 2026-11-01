// Uses the existing sheet; no draft is persisted in browser storage.
export function attachDocumentLogout(c,{pending,pause,resume,flush}){
 let quit=null,busy=false,epoch=0;
 c.requestDocumentLogout=async action=>{if(busy)return;if(!pending()){try{return await action();}catch{c.flash('Déconnexion non confirmée : réessayez.');return;}}pause();quit=action;c.openSheet('documentLogout');};
 const defs=c.sheetDefs?.bind(c);c.sheetDefs=()=>({...defs?.(),documentLogout:{title:'Brouillon non sauvegardé',sub:'Des modifications ne sont pas encore confirmées sur le serveur. Choisissez avant de vous déconnecter.',optLabel:'Déconnexion',options:[{label:'Enregistrer puis se déconnecter',hint:'La déconnexion attend la confirmation du serveur.'},{label:'Quitter sans réessayer',hint:'Les modifications non envoyées seront perdues. Une sauvegarde déjà transmise peut aboutir.'}],confirm:'Confirmer'}});
 const confirm=c.confirmSheet?.bind(c);c.confirmSheet=async()=>{if(c.state.sheet!=='documentLogout')return confirm?.();if(busy||!quit)return;busy=true;const stamp=epoch;try{if(c.state.sheetOpt===0)await flush();else if(c.state.sheetOpt!==1)return;if(stamp!==epoch)return;const action=quit;await action();if(stamp===epoch){quit=null;c.setState({sheet:'',sheetErr:''});}}catch{if(stamp===epoch)c.setState({sheetErr:'Sauvegarde non confirmée. Restez sur le document ou choisissez explicitement de quitter sans réessayer.'});}finally{if(stamp===epoch)busy=false;}};
 const render=c.renderVals.bind(c);c.renderVals=()=>{const v=render();return {...v,sheetClose:()=>{if(c.state.sheet==='documentLogout'){if(busy)return;quit=null;resume();}return v.sheetClose?.();}};};
 const clear=c.clearIdentity?.bind(c);c.clearIdentity=()=>{epoch++;quit=null;busy=false;clear?.();c.setState({sheet:'',sheetErr:''});};
}

// Shared private vault; case references always retain the message's source ACL.
export function attachMessageFiles(c,{api,read,epoch,own,organization}){
 let busy=false,preview=null,run=0;const retries=new Map();
 const current=(s,id)=>s===epoch()&&c.curConvo()?.id===id;
 const close=()=>{run++;preview=null;c.setState({previewOpen:false,piecePreviewUrl:'',piecePreviewText:''});};
 const choose=(cv,m,file='')=>{c.setState({waMenu:null});return c.openServerCasePicker?.({who:m.who,conv:cv.name,text:file?m.file.name:m.text,source:{conversation:cv.id,seq:m.seq,file}});};
 c.uploadMessageFile=async(file,id=c.curConvo()?.id)=>{
  if(busy||!id||!own(c.curConvo()))return;
  if(!file.size||file.size>5242880)return c.flash('Fichier vide ou supérieur à 5 Mo.');
  const stamp=epoch();busy=true;c.setState({});
  try{
   const bytes=new Uint8Array(await file.arrayBuffer());if(!current(stamp,id))return;
   const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');
   if(!current(stamp,id))return;
   const key=JSON.stringify([id,file.name,digest]);if(!retries.has(key)){const unfinished=c.curConvo().messages.find(m=>m.mine&&m.file?.name===file.name&&m.file.sha256===digest&&['pending','error'].includes(m.file.status));retries.set(key,unfinished?.clientId||crypto.randomUUID());}
   let binary='';for(const b of bytes)binary+=String.fromCharCode(b);
   await api('file_upload',{id,clientId:retries.get(key),filename:file.name,content:btoa(binary)});
   if(!current(stamp,id))return;retries.delete(key);await read(id);c.flash('Pièce contrôlée et enregistrée.');
  }catch(e){if(current(stamp,id)){await read(id);c.flash('Dépôt non confirmé ou pièce bloquée. Consultez son état ; reprendre le même fichier évite les doublons.');}}
  finally{if(stamp===epoch()){busy=false;c.setState({});}}
 };
 const attach=()=>{if(busy)return;const cv=c.curConvo();if(!own(cv))return;const stamp=epoch(),id=cv.id,input=document.createElement('input');input.type='file';input.accept='.pdf,.png,.jpg,.jpeg,.txt,.docx,.xlsx';input.style.display='none';document.body.appendChild(input);input.oncancel=()=>input.remove();input.onchange=()=>{const f=input.files?.[0];input.remove();if(f&&current(stamp,id))c.uploadMessageFile(f,id);};input.click();};
 async function access(cv,m,action,page=1){
  const stamp=epoch(),id=cv.id,ticket=++run;preview=null;c.setState({previewOpen:false,piecePreviewUrl:'',piecePreviewText:'',waMenu:null});
  try{
   const r=await api(action,{id,attachment:m.file.id,...(action==='file_preview'?{page}:{})});
   if(!current(stamp,id)||ticket!==run)return;
   if(action==='file_rescan'){await read(id);c.flash('Analyse terminée.');}
   else if(action==='file_download')window.uniionFiles.download(new Blob([Uint8Array.from(atob(r.content),x=>x.charCodeAt(0))],{type:r.mime}),r.filename);
   else {preview={cv,m,page:r.page,pages:r.pages};c.setState({previewOpen:true,piecePreviewUrl:r.image,piecePreviewText:'Page '+r.page+' sur '+r.pages});setTimeout(()=>{const frame=document.getElementById('local-piece-frame');if(frame&&current(stamp,id)&&ticket===run&&c.state.previewOpen)frame.srcdoc=/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(r.image)?'<html><body style="margin:0"><img alt="Page du document" style="display:block;width:100%;height:auto" src="'+r.image+'"></body></html>':'';},0);}
  }catch(e){if(current(stamp,id)&&ticket===run){close();await read(id);c.flash(e.status===403?'Accès à la pièce refusé.':'Pièce bloquée, analyse ou aperçu indisponible.');}}
 }
 c.messageFile=access;
 const menu=c.msgActs.bind(c);c.msgActs=(cv,m)=>{
  const base=menu(cv,m);if(!own(cv))return base;
  const rows=base.map(a=>a.label==='Envoyer dans un dossier — indisponible'?{label:'Envoyer dans un dossier',go:()=>choose(cv,m)}:a);
  if(m.file){
   if(m.file.status==='clean'&&m.file.preview)rows.push({label:'Aperçu de la pièce',go:()=>access(cv,m,'file_preview')});
   if(m.file.status==='clean')rows.push({label:'Télécharger la pièce',go:()=>access(cv,m,'file_download')},{label:'Classer la pièce dans un dossier',go:()=>choose(cv,m,m.file.id)});
   if(m.file.canWrite){if(['pending','error'].includes(m.file.status))rows.push(m.file.uploaded?{label:'Reprendre l’analyse',go:()=>access(cv,m,'file_rescan')}:{label:'Reprendre le dépôt du même fichier',go:attach});rows.push({label:'Corbeille de la pièce',go:()=>{location.href='/s02/rights?organization='+encodeURIComponent(organization)+'&case='+encodeURIComponent(m.file.resource)+'&piece='+encodeURIComponent(m.file.id)+'&revision=1#corbeille';}});}
  }
  const stamp=epoch();return rows.map(a=>({...a,go:()=>current(stamp,cv.id)&&a.go()}));
 };
 const convo=c.convoVals.bind(c);c.convoVals=()=>{const v=convo(),cv=c.curConvo();if(!own(cv))return v;return {...v,messages:v.messages.map((row,i)=>{const m=cv.messages[i],f=m.file;return f?{...row,hasAtt:true,att:f.name+' · '+({clean:'Contrôlée',pending:'En quarantaine',error:'Analyse à reprendre',infected:'Bloquée',invalid:'Format bloqué',trash:'En corbeille'}[f.status]||f.status),attachmentKey:e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();if(f.status==='clean'&&f.preview)access(cv,m,'file_preview');}},openAttachment:()=>f.status==='clean'&&f.preview?access(cv,m,'file_preview'):c.flash(f.status==='clean'?'Aperçu indisponible pour ce format. Utilisez Télécharger dans le menu.':'Pièce indisponible : '+f.status)}:row;})};};
 const render=c.renderVals.bind(c);c.renderVals=()=>{const v=render(),active=own(c.curConvo());return {...v,...(active?{attach,messagingStatus:busy?'Dépôt et analyse antivirus en cours…':v.messagingStatus}:{}),...(preview?{piece:{...v.piece,name:preview.m.file.name,meta:'Pièce du message · droits actuels vérifiés',previewNote:'Aperçu inerte'},piecePreviewBinary:true,closePreview:close,hasPreviousPage:preview.page>1,hasNextPage:preview.page<preview.pages,previousPage:()=>access(preview.cv,preview.m,'file_preview',preview.page-1),nextPage:()=>access(preview.cv,preview.m,'file_preview',preview.page+1)}:{})};};
 c.closeMessageFilePreview=close;
 const go=c.go.bind(c);c.go=(...args)=>{close();return go(...args);};
 const clear=c.clearIdentity?.bind(c);c.clearIdentity=()=>{close();busy=false;retries.clear();clear?.();};
}

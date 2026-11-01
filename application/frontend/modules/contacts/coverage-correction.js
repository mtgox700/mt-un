import {euros} from './dues-ledger.js';
export function createCoverageCorrection(c,rpc,allowed,onChange){
 let draft=null,epoch=0,busy=false;const redraw=()=>c.setState?.({});
 async function run(action,payload,done){if(busy||!allowed())return;busy=true;const stamp=epoch;redraw();try{const r=await rpc(action,payload);if(stamp!==epoch)return;done(r);}catch(e){if(stamp===epoch&&draft)draft.error='Correction non confirmée : vérifiez la période, les droits et la version. En cas de conflit, rechargez les périodes. Aucun montant modifié.';}finally{if(stamp===epoch){busy=false;redraw();}}}
 const edit=(key,value)=>{if(!busy&&draft){draft[key]=value;draft.request=crypto.randomUUID();draft.error='';redraw();}};
 const load=()=>draft&&run('coverage_list',{id:draft.id},r=>{draft={...draft,rows:r.coverages,selected:null,error:''};});
 return {clear(){epoch++;draft=null;busy=false;},open(id){if(!allowed()||busy)return;epoch++;draft={id,rows:[],selected:null,error:''};return load();},values(){return {open:!!draft,busy,error:draft?.error||'',empty:!!draft&&!busy&&!draft.rows.length,
 rows:(draft?.rows||[]).map(e=>({id:e.id,text:'Du '+e.period+' au '+e.lastDay+' · '+euros(e.cents),choose:()=>{if(!busy){draft={...draft,selected:e,lastDay:e.lastDay,reason:'',request:crypto.randomUUID(),error:''};redraw();}},history:e.history.map(h=>({text:h.date+' · '+h.before.lastDay+' → '+h.after.lastDay+' · '+h.reason+' · acteur '+h.actor}))})),
 editing:!!draft?.selected,before:draft?.selected?'Fin confirmée : '+draft.selected.lastDay+' · début conservé : '+draft.selected.period:'',lastDay:draft?.lastDay||'',reason:draft?.reason||'',changeDate:e=>edit('lastDay',e.target.value),changeReason:e=>edit('reason',e.target.value),
 canConfirm:!!draft?.selected&&!busy&&draft.lastDay!==draft.selected.lastDay&&/^\d{4}-\d{2}-\d{2}$/.test(draft.lastDay)&&draft.reason.trim().length>=5&&draft.reason.trim().length<=500,
 confirm:()=>{if(!draft?.selected||!draft.reason.trim()||draft.lastDay===draft.selected.lastDay)return;return run('coverage_correct',{id:draft.id,entry:draft.selected.id,revision:draft.selected.revision,lastDay:draft.lastDay,reason:draft.reason,request_id:draft.request},r=>{draft={...draft,rows:r.coverages,selected:null,error:''};onChange();c.flash('Couverture corrigée et journalisée. Montants conservés.');});},reload:load,cancel:()=>{if(!busy){epoch++;draft=null;redraw();}}};}};
}

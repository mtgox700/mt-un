import {effectiveDate} from './effective-date.js';
export const euros=cents=>(cents/100).toLocaleString('fr-FR',{minimumFractionDigits:2,maximumFractionDigits:2})+' €';
export function duesView(entries=[]){
 const normalized=entries.map(e=>({...e,remainingCents:e.cents-(e.paidCents??(e.paidAt?e.cents:0)),payments:e.payments??(e.paidAt?[{cents:e.cents,recordedAt:e.paidAt}]:[])}));
 const pending=normalized.filter(e=>e.remainingCents>0),payments=normalized.flatMap(e=>e.payments).filter(p=>p.cents>0).sort((a,b)=>(a.effectiveOn||'').localeCompare(b.effectiveOn||''));
 return {pending,du:pending.length?euros(pending.reduce((s,e)=>s+e.remainingCents,0)):'',dernier:payments.at(-1)?.effectiveOn||(payments.length?'Date effective non renseignée':'Aucun règlement enregistré'),echeance:pending[0]?.dueOn||'Aucune échéance enregistrée',histo:normalized.flatMap(e=>[{date:e.period,what:'Échéance '+euros(e.cents)+' — exigible le '+e.dueOn,ok:false},...e.payments.flatMap(p=>[{date:p.recordedAt.slice(0,10),what:'Règlement déclaré — '+euros(p.originalCents??p.cents)+' — versement : '+(p.originalEffectiveOn||'date non renseignée'),ok:true},...(p.corrections||[]).map(c=>({date:c.recordedAt.slice(0,10),what:'Correction n°'+c.revision+' — montant retenu '+euros(c.cents)+' — '+c.reason+(c.effectiveOn?' — versement : '+c.effectiveOn:'')+' — auteur '+c.actor,ok:true}))])])};
}
export function paymentPayload(d,entries){
 const entry=duesView(entries).pending.find(e=>e.id===d.entryId);
 if(!entry)throw Error('Sélectionnez une échéance avec un solde restant.');
 const text=String(d.amount||'').trim();if(!/^\d{1,9}([.,]\d{1,2})?$/.test(text))throw Error('Indiquez un montant en euros avec deux décimales maximum.');
 const [whole,fraction='']=text.replace(',','.').split('.');const cents=Number(whole)*100+Number(fraction.padEnd(2,'0'));
 if(cents<=0||cents>entry.remainingCents)throw Error('Le règlement doit être positif et ne pas dépasser le solde de '+euros(entry.remainingCents)+'.');
 return {id:entry.id,amount_cents:cents,request_id:d.requestId,...(d.effectiveOn!==undefined?{effective_on:effectiveDate(d.effectiveOn)}:{})};
}

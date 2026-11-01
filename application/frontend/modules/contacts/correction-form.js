import {effectiveDate} from './effective-date.js';
export function correctionPayload(d,entries=[]){
 const entry=entries.find(e=>(e.payments||[]).some(p=>p.id===d.paymentId)),payment=entry?.payments.find(p=>p.id===d.paymentId);
 if(!payment)throw Error('Sélectionnez un règlement à corriger.');
 const t=String(d.amount??'').trim();if(!/^\d{1,9}([.,]\d{1,2})?$/.test(t))throw Error('Indiquez le montant corrigé, positif ou nul, avec deux décimales maximum.');
 const [whole,fraction='']=t.replace(',','.').split('.');const cents=Number(whole)*100+Number(fraction.padEnd(2,'0'));
 if(cents>entry.cents-(entry.paidCents||0)+payment.cents)throw Error('Le montant corrigé ferait dépasser le montant de l’échéance.');
 const reason=String(d.reason||'').trim();if(reason.length<3||reason.length>500)throw Error('Précisez un motif de correction de 3 à 500 caractères.');
 return {id:payment.id,revision:payment.revision||0,amount_cents:cents,reason,request_id:d.requestId,...(d.effectiveOn?.trim()?{effective_on:effectiveDate(d.effectiveOn)}:{})};
}

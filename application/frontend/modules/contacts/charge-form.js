import {validJoinedDate} from './adherent-values.js';
export function chargePayload(d){
 const amount=String(d.amount||'').trim();
 if(!/^\d{1,9}([.,]\d{1,2})?$/.test(amount))throw Error('Indiquez un montant positif en euros, avec deux décimales maximum.');
 const [whole,fraction='']=amount.replace(',','.').split('.');const cents=Number(whole)*100+Number(fraction.padEnd(2,'0'));
 if(cents<=0)throw Error('Le montant doit être supérieur à zéro.');
 const date=(text,label)=>{const t=String(text||'').trim();if(!t||!validJoinedDate(t))throw Error(label+' : utilisez JJ/MM/AAAA ou AAAA-MM-JJ.');return t.includes('/')?t.split('/').reverse().join('-'):t;};
 return {adherent_id:d.adherentId,amount_cents:cents,period:date(d.period,'Date de période'),due_on:date(d.dueOn,'Date d’exigibilité'),request_id:d.requestId};
}

import {validJoinedDate} from './adherent-values.js';
export function effectiveDate(value){
 const text=String(value||'').trim();
 if(!text||!validJoinedDate(text))throw Error('Indiquez la date effective du versement : JJ/MM/AAAA ou AAAA-MM-JJ.');
 const iso=text.includes('/')?text.split('/').reverse().join('-'):text;
 const now=new Date(),today=[now.getFullYear(),String(now.getMonth()+1).padStart(2,'0'),String(now.getDate()).padStart(2,'0')].join('-');
 if(iso>today)throw Error('La date effective ne peut pas être future.');
 return iso;
}

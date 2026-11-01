// Input validation mirrors the SQL boundary; only SQL authorizes persistence.
export function validJoinedDate(text){
 const t=String(text||'').trim();if(!t)return true;
 let m=t.match(/^(\d{4})-(\d{2})-(\d{2})$/),y,month,day;
 if(m){[,y,month,day]=m;}else{m=t.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);if(!m)return false;[,day,month,y]=m;}
 y=Number(y);month=Number(month);day=Number(day);
 const leap=y%4===0&&(y%100!==0||y%400===0);
 return y>=1&&month>=1&&month<=12&&day>=1&&day<=[31,leap?29:28,31,30,31,30,31,31,30,31,30,31][month-1];
}
export function validDues(text){return !String(text||'').trim()||/^\d{1,9}([.,]\d{1,2})?\s*(€|eur)(\s*\/\s*(mois|trimestre|an))?$/i.test(String(text).trim());}
export function typedError(data,previous){
 if((!previous||String(data.since||'').trim()!==String(previous.since||'').trim())&&!validJoinedDate(data.since))return 'Date invalide : utilisez JJ/MM/AAAA ou AAAA-MM-JJ, ou laissez le champ vide.';
 if(Object.hasOwn(data,'montant')&&(!previous||String(data.montant||'').trim()!==String(previous.montant||'').trim())&&!validDues(data.montant))return 'Montant invalide : indiquez par exemple 12,50 €/mois, 150 €/an ou 15 €. Deux décimales maximum.';
 return '';
}

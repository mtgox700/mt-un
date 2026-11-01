import {euros} from './dues-ledger.js';
export function financialSummary(s,rows,c,canWrite){
 if(!s)return {recouvPct:'—',recouvW:'0%',cotisStats:[],modes:[],retards:[],noRetard:false,relanceAll:()=>c.flash('Synthèse financière indisponible.')};
 const pct=s.dueCents?Math.round(100*s.paidDueCents/s.dueCents):null;
 const up=s.assessedMembers?Math.round(100*s.upToDateMembers/s.assessedMembers)+' %':'—';
 return {up,late:String(s.arrears.length),recouvPct:pct===null?'—':pct+' %',recouvW:(pct??0)+'%',
 cotisStats:[{value:euros(s.quarterCents),label:'déclaré ce trimestre · dates effectives'},
 {value:euros(s.remainingCents),label:'reste exigible au '+s.asOf},
 {value:euros(s.overdueCents),label:'en retard · '+euros(s.undatedCents)+' versés sans date'}],
 modes:s.modes.map(m=>({...m,w:(rows.length?100*m.n/rows.length:0)+'%',n:m.n+' fiche'+(m.n>1?'s':'')})),
 retards:s.arrears.map(r=>{const a=rows.find(a=>a.id===r.id);return {name:a.prenom+' '+a.nom,where:[a.etab,a.sect].filter(Boolean).join(' · '),mode:a.mode||'Non renseigné',du:euros(r.cents),echeance:'Échéance depuis le '+r.dueOn,
 open:()=>c.go('adherent',{adherentId:a.id}),relance:()=>c.flash('La relance sera raccordée dans un prochain lot S04. Aucun envoi effectué.'),paid:async()=>{if(!canWrite)return c.flash('Droit de cotisation requis.');if(await c.go('adherent',{adherentId:a.id})!==false)c.adhMarkPaid(a.id);}};}),
 noRetard:s.arrears.length===0,emptyArrears:s.assessedMembers?'Aucune échéance passée en retard.':'Aucune échéance exigible enregistrée.',
 relanceAll:()=>c.flash('Les relances groupées seront raccordées dans un prochain lot S04. Aucun envoi effectué.')};
}

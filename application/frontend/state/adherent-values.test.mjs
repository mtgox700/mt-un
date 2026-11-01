import {test} from 'node:test';import assert from 'node:assert/strict';
import {validJoinedDate,validDues,typedError} from '../modules/contacts/adherent-values.js';
test('calendar validation rejects rollover and ambiguous dates',()=>{
 for(const d of ['','29/02/2024','2026-10-28','01/01/0001'])assert.equal(validJoinedDate(d),true,d);
 for(const d of ['29/02/2026','31/04/2026','2026-13-01','2026-00-01','0000-01-01','septembre 2026','1/2/2026'])assert.equal(validJoinedDate(d),false,d);
});
test('dues require currency and preserve explicit precision/cadence',()=>{
 for(const m of ['','12,50 €/mois','150 EUR/an','0 €','9.5 €/trimestre','15 €'])assert.equal(validDues(m),true,m);
 for(const m of ['12','12.345 €','-2 €','1e3 €','1 %','12 $','2 €/jour'])assert.equal(validDues(m),false,m);
});
test('unrelated edit preserves legacy ambiguity but new invalid values fail',()=>{
 const old={since:'septembre 2026',montant:'à définir'};
 assert.equal(typedError({...old,nom:'Autre'},old),'');
 assert.ok(typedError({...old,since:'octobre 2026'},old));
 assert.ok(typedError(old));
 assert.equal(typedError({since:'2026-10-01',montant:'12,50 €/mois'},old),'');
});

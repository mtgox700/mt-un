import {test} from 'node:test';import assert from 'node:assert/strict';import {chargePayload} from '../modules/contacts/charge-form.js';
const d={adherentId:'member',requestId:'stable',amount:'12,5',period:'01/11/2026',dueOn:'2026-11-05'};
test('explicit charge converts exact cents and canonical dates',()=>assert.deepEqual(chargePayload(d),{adherent_id:'member',amount_cents:1250,period:'2026-11-01',due_on:'2026-11-05',request_id:'stable'}));
test('invalid charge refuses missing date, rollover and nonpositive amount',()=>{for(const patch of [{amount:'0'},{amount:'-2'},{amount:'1.234'},{amount:'1e3'},{period:''},{dueOn:'31/02/2026'}])assert.throws(()=>chargePayload({...d,...patch}));});

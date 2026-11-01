import {test} from 'node:test';import assert from 'node:assert/strict';import {paymentPayload} from '../modules/contacts/dues-ledger.js';
const entries=[{id:'a',cents:2000,paidCents:750,payments:[],dueOn:'2026-12-01'}],d={entryId:'a',amount:'7,50',requestId:'stable'};
test('selected payment converts exact cents and retains retry identity',()=>assert.deepEqual(paymentPayload(d,entries),{id:'a',amount_cents:750,request_id:'stable'}));
test('selection, positive amount, precision and remaining balance required',()=>{for(const p of [{entryId:''},{entryId:'other'},{amount:'0'},{amount:'-1'},{amount:'12,51'},{amount:'1.234'}])assert.throws(()=>paymentPayload({...d,...p},entries));});

import test from 'node:test';
import assert from 'node:assert/strict';
import {attachMeetingMinutes} from '../modules/meetings/minutes.js';
function fixture(){
 const meeting={id:'meeting',title:'Réunion fictive'},pv={id:'pv',title:'PV',version:1,meetingPV:true,canWrite:true,transcript:'Source privée',markers:['Décision à vérifier'],minutes:'Projet à corriger'};
 let rows=[meeting,pv],calls=[],handler;
 const c={state:{sheetOpt:0},setState(p){Object.assign(this.state,p);},sheetDefs:()=>({}),confirmSheet:()=>{},openSheet(s){this.state.sheet=s;},curReunion:()=>meeting,businessRecords:()=>rows,refreshBusiness:async()=>{},renderVals:()=>({reu:{}}),flash:()=>{},go:()=>{},back:()=>{},clearIdentity:()=>{},flushBusiness:async()=>{},selectedMeetingAudio:()=> 'selected',openBusinessPublication:async()=>{}};
 const request=async(_,r)=>{calls.push(r);if(handler)return handler(r);if(r.action==='audio_list')return {files:[{id:'selected',current:true,status:'clean'},{id:'other',current:true,status:'clean'}]};if(r.action==='pv_prepare')return pv;if(r.action==='save')return {...pv,version:2,...r.payload.data};return {};};
 attachMeetingMinutes(c,request,'org');return {c,pv,meeting,calls,setRows:r=>rows=r,handler:h=>handler=h};
}
test('selected audio is used and source fields survive correction',async()=>{const f=fixture();await f.c.openMeetingPV();assert.equal(f.calls.find(r=>r.action==='pv_prepare').payload.audio,'selected');f.c.editMeetingPV();f.c.state.sheetText='PV corrigé';await f.c.confirmSheet();const save=f.calls.find(r=>r.action==='save');assert.equal(save.payload.version,1);assert.equal(save.payload.data.transcript,'Source privée');assert.equal(save.payload.data.minutes,'PV corrigé');});
test('published copy is readable but cannot open private source tools',()=>{const f=fixture();Object.assign(f.meeting,{publishedCopy:true,minutes:'Version approuvée',version:3});const v=f.c.renderVals();assert.equal(v.meetingPVText,'Version approuvée');assert.equal(v.meetingPVEditable,false);assert.equal(v.meetingPVPrivate,false);assert.equal(v.meetingPVManage,false);});
test('source revocation removes an already displayed draft on refresh',async()=>{const f=fixture();await f.c.openMeetingPV();assert.equal(f.c.renderVals().meetingPVVisible,true);f.setRows([f.meeting]);await f.c.refreshBusiness('reunions');assert.equal(f.c.renderVals().meetingPVVisible,false);});
test('late prepare after identity change cannot restore private text',async()=>{const f=fixture();let resolve;f.handler(r=>r.action==='audio_list'?{files:[{id:'selected',current:true,status:'clean'}]}:new Promise(r=>resolve=r));const work=f.c.openMeetingPV();await new Promise(r=>setImmediate(r));f.c.clearIdentity();resolve(f.pv);await work;assert.equal(f.c.renderVals().meetingPVVisible,false);});
test('conflicting edit keeps entered correction and shows error',async()=>{const f=fixture();await f.c.openMeetingPV();f.c.editMeetingPV();f.c.state.sheetText='Saisie non sauvegardée';f.handler(()=>{throw Error('stale');});await f.c.confirmSheet();assert.equal(f.c.state.sheetText,'Saisie non sauvegardée');assert.match(f.c.state.sheetErr,/non enregistrée/);});

test('background row refresh also clears the open editor after source revocation',async()=>{const f=fixture();await f.c.openMeetingPV();f.c.editMeetingPV();f.c.onBusinessRowsChanged('reunions',[f.meeting]);assert.equal(f.c.renderVals().meetingPVVisible,false);assert.equal(f.c.state.sheet,null);});

test('published text is not cached after its row is revoked',async()=>{const f=fixture();Object.assign(f.meeting,{publishedCopy:true,minutes:'Copie diffusée',version:2});await f.c.openMeetingPV();assert.equal(f.c.renderVals().meetingPVText,'Copie diffusée');delete f.meeting.publishedCopy;delete f.meeting.minutes;assert.equal(f.c.renderVals().meetingPVVisible,false);});

for(const action of ['sheetClose','sheetFollow'])test(action+' resets PV dialog without clearing its display',async()=>{const f=fixture();await f.c.openMeetingPV();f.c.editMeetingPV();assert.match(f.c.sheetDefs().diffuse.title,/Corriger/);f.c.renderVals()[action]();assert.equal(f.c.sheetDefs().diffuse,undefined);assert.equal(f.c.renderVals().meetingPVVisible,true);});
test('local consent withdrawal immediately clears private PV',async()=>{const f=fixture();await f.c.openMeetingPV();f.c.onMeetingConsentWithdrawn();assert.equal(f.c.renderVals().meetingPVVisible,false);});

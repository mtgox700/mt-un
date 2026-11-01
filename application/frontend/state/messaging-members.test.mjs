import test from 'node:test';import assert from 'node:assert/strict';import {webcrypto} from 'node:crypto';import {attachMessagingMembers} from '../modules/messaging/members.js';
if(!globalThis.crypto)globalThis.crypto=webcrypto;
const member=(id,me=false)=>({id,period:'period-'+id,name:id,role:'Membre',me,admin:me,historyCount:0});
function fixture(api=async()=>({id:'g'})){
 let generation=0;const cv={id:'g',kind:'group',name:'Groupe',desc:'',version:7,serverMessage:true,canManage:true,canHistory:true,memberRows:[member('a',true),member('b')],messages:[{seq:'3',text:'Autorisé'}]};
 const calls=[],flashes=[];const c={state:{convos:[cv],convoId:'g',grEdit:null,grQ:'',thSel:[0]},setState(p){Object.assign(this.state,typeof p==='function'?p(this.state):p)},curConvo:()=>cv,flash:t=>flashes.push(t),msgActs:()=>[],thVals:()=>({}),waVals:()=>({info:{del:{}}}),askDel:(_,label,act)=>({label,act}),openConvo:async()=>{},go:async()=>{},grmVals:()=>({open:false})};
 attachMessagingMembers(c,{api:async(a,p)=>{calls.push([a,p]);return api(a,p)},read:async()=>true,contacts:()=>[member('b')],epoch:()=>generation,own:x=>x.serverMessage,unavailable:()=>flashes.push('unavailable')});
 return {c,cv,calls,flashes,clear:()=>{generation++;c.state.grEdit=null;}};
}
test('group creation retains its client id through uncertain retry',async()=>{
 const {c,calls}=fixture(async()=>{throw Error('network')});await c.openGroupEdit(null);
 c.state.grEdit={...c.state.grEdit,name:'Nouveau',memberIds:['b']};await c.saveGroup();await c.saveGroup();
 assert.equal(calls[0][0],'group_create');assert.equal(calls[0][1].clientId,calls[1][1].clientId);assert.equal(c.state.grEdit.name,'Nouveau');
});
test('membership edit carries server version and no caller authority fields',async()=>{
 const {c,calls}=fixture();await c.openGroupEdit('g');await c.saveGroup();assert.deepEqual(calls[0],['group_save',{id:'g',version:7,name:'Groupe',desc:'',members:['b']}]);
});
test('history uses selected sequence and current recipient episode',async()=>{
 const {c,calls}=fixture();c.thVals().openHistory();c.grmVals().cands[0].toggle();await c.saveGroup();
 assert.deepEqual(calls[0],['history_grant',{id:'g',version:7,period:'period-b',messages:['3']}]);
});
test('no history option without separate authority',()=>{
 const {c,cv,flashes}=fixture();cv.canHistory=false;assert.equal(c.thVals().canOpenHistory,false);assert.deepEqual(c.msgActs(cv,cv.messages[0]),[]);c.thVals().openHistory();assert.equal(flashes[0],'unavailable');
});
test('late mutation cannot populate another identity or announce success',async()=>{
 let release;const {c,clear,flashes}=fixture(()=>new Promise(r=>release=r));await c.openGroupEdit('g');const pending=c.saveGroup();clear();release({id:'g'});await pending;assert.deepEqual(flashes,[]);assert.equal(c.state.grEdit,null);
});
test('remove prepares an explicit edit, no immediate request',async()=>{
 const {c,calls}=fixture();c.grRemove('g','b');await Promise.resolve();await Promise.resolve();assert.deepEqual(c.state.grEdit.memberIds,[]);assert.equal(calls.length,0);
});
test('self role change and non moderator edits do not reach server',async()=>{
 const {c,cv,calls}=fixture();c.grToggleAdmin('g','a');cv.canManage=false;await c.openGroupEdit('g');c.grToggleAdmin('g','b');assert.equal(calls.length,0);
});
test('failed version update keeps the edit for review',async()=>{
 const {c}=fixture(async()=>{throw Object.assign(Error(),{status:403})});await c.openGroupEdit('g');await c.saveGroup();assert.equal(c.state.grEdit.version,7);
});
test('failure remains visible inside the form',async()=>{
 const {c}=fixture(async()=>{throw Object.assign(Error(),{status:403})});await c.openGroupEdit('g');await c.saveGroup();assert.match(c.grmVals().error,/Accès refusé/);
});
test('confirmation does not discard edits made while saving',async()=>{
 let release;const {c}=fixture(()=>new Promise(r=>release=r));await c.openGroupEdit('g');const pending=c.saveGroup();c.state.grEdit={...c.state.grEdit,name:'Nouvelle saisie'};release({id:'g'});await pending;assert.equal(c.state.grEdit.name,'Nouvelle saisie');
});
test('old history callbacks cannot open a form in a new identity',()=>{
 const {c,cv,clear}=fixture();const callback=c.msgActs(cv,cv.messages[0])[0].go;clear();callback();assert.equal(c.state.grEdit,null);
});

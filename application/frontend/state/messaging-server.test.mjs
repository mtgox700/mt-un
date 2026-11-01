import test from 'node:test';import assert from 'node:assert/strict';import {webcrypto} from 'node:crypto';import {attachMessaging} from '../modules/messaging/service.js';
if(!globalThis.crypto)globalThis.crypto=webcrypto;
const row={id:'thread',name:'Destinataire',messages:[],next:null};
function setup(request){
 const c={state:{convos:[],convoId:null,msgDraft:'',route:'messagerie'},setState(p){Object.assign(this.state,typeof p==='function'?p(this.state):p);},flash(){},go(r,p){this.setState({route:r,...p});},curConvo(){return this.state.convos.find(x=>x.id===this.state.convoId)||{messages:[]};},sendMsgNow(){throw Error('simulation called')},waVals(){return {info:{},noRowsText:'Vide'}},msgActs(){return []},thVals(){return {presets:[]}},convoVals(){return {messages:[]}},renderVals(){return {}},clearIdentity(){}};
 return {c,h:attachMessaging(c,request,'org')};
}
const msg=(id,text)=>({id,seq:'1',text,who:'A',created:'2026-10-30T10:00:00Z'});
test('uncertain retry uses identical key; draft and double-click protected',async()=>{
 let calls=[],release,fail=true;
 const {c,h}=setup(async(_,{action,payload})=>{
  if(action==='get')return row;
  if(action==='send'){calls.push(payload);await new Promise(r=>release=r);if(fail)throw Error('network');return msg('m',payload.text);}
 });
 await h.read('thread');c.setState({convoId:'thread',msgDraft:'Bonjour'});
 const first=c.sendMsgNow();await c.sendMsgNow();assert.equal(calls.length,1);release();await first;assert.equal(c.state.msgDraft,'Bonjour');
 fail=false;const retry=c.sendMsgNow();release();await retry;assert.equal(calls[0].clientId,calls[1].clientId);assert.equal(c.curConvo().messages.length,1);assert.equal(c.state.msgDraft,'');
});
test('late reads and sends cannot repopulate a cleared identity',async()=>{
 let release;const {c,h}=setup(async()=>new Promise(r=>release=r));
 const read=h.read('thread');c.clearIdentity();release(row);await read;assert.deepEqual(c.state.convos,[]);
});
test('late send leaves another conversation draft untouched',async()=>{
 let release;const {c,h}=setup(async(_,{action})=>action==='get'?row:new Promise(r=>release=r));
 await h.read('thread');c.setState({convoId:'thread',msgDraft:'Bonjour'});
 const send=c.sendMsgNow();c.setState({convoId:'other',msgDraft:'Autre saisie'});release(msg('m','Bonjour'));await send;
 assert.equal(c.state.msgDraft,'Autre saisie');
});
test('pagination merges without duplicate and refuses stale thread responses',async()=>{
 const {c,h}=setup(async(_,{payload})=>({...row,next:payload.before?null:'2',messages:payload.before?[msg('old','ancien')]:[msg('new','récent')]}));
 await h.read('thread');await h.read('thread',true);assert.deepEqual(c.state.convos[0].messages.map(x=>x.id),['old','new']);
});
test('denied read erases private content with no demo fallback',async()=>{
 let denied=false;const {c,h}=setup(async()=>{if(denied)throw Object.assign(Error(),{status:403});return row;});
 await h.read('thread');denied=true;await h.read('thread');assert.deepEqual(c.state.convos,[]);
});
test('conversation load and participants exclude prototype contacts',async()=>{
 const {c,h}=setup(async(_,{action})=>action==='list'?{rows:[row],next:null}:[{id:'b',name:'B',role:'Membre'}]);
 await h.load();assert.equal(c.waVals().teamRows[0].name,'B');assert.equal(c.state.convos.length,1);
 c.clearIdentity();assert.equal(c.waVals().teamRows.length,0);
});
test('late confirmed send after logout cannot restore data or draft',async()=>{
 let release;const {c,h}=setup(async(_,{action})=>action==='get'?row:new Promise(r=>release=r));
 await h.read('thread');c.setState({convoId:'thread',msgDraft:'Bonjour'});const send=c.sendMsgNow();c.clearIdentity();release(msg('m','Bonjour'));await send;
 assert.deepEqual(c.state.convos,[]);assert.equal(c.state.msgDraft,'');
});
test('unavailable attachment does not call legacy mutation',()=>{
 const {c}=setup(async()=>{});assert.equal(typeof c.renderVals().attach,'function');c.renderVals().attach();assert.deepEqual(c.state.convos,[]);
});
test('drafts survive navigation between discussions in memory',async()=>{
 const {c}=setup(async(_,{action,payload})=>action==='get'?{...row,id:payload.id}:[]);
 await c.openConvo('one');c.setState({msgDraft:'À conserver'});await c.openConvo('two');assert.equal(c.state.msgDraft,'');await c.openConvo('one');assert.equal(c.state.msgDraft,'À conserver');
});
test('late list cannot navigate after identity change',async()=>{
 let resolveList,resolvePeople;
 const {c}=setup(async(_,{action})=>new Promise(r=>{if(action==='list')resolveList=r;else resolvePeople=r;}));
 const navigation=c.go('messagerie');c.clearIdentity();c.setState({route:'login'});
 resolveList({rows:[row],next:null});resolvePeople([]);await navigation;
 assert.equal(c.state.route,'login');assert.deepEqual(c.state.convos,[]);
});
test('reopening does not restore a quote absent from the authorized page',async()=>{
 const {c}=setup(async(_,{payload})=>({...row,id:payload.id,messages:[]}));
 await c.openConvo('one');c.setState({msgDraft:'Saisie',waReply:{seq:'1',text:'Ancien accès',who:'A'}});
 await c.openConvo('two');await c.openConvo('one');assert.equal(c.state.msgDraft,'Saisie');assert.equal(c.state.waReply,null);
});

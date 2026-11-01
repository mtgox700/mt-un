import assert from 'node:assert/strict';import {createModuleStores} from './module-stores.js';import {createMessagingPresenters} from '../modules/messaging/presenters.js';
let count=0;function test(n,f){f();count++;console.log('PASS '+n)}
const stores=createModuleStores({convos:[{id:'t',name:'Fictif',kind:'direct',messages:[{text:'Bonjour',time:'12:00'}],memberIds:[],admins:[]}],convoId:'t',waPane:'chats',waQ:'',waF:'all',thSel:[],fwdMsg:null,grEdit:null});const store=stores.module('messaging');let opened;const p=createMessagingPresenters(store,{convoSub:()=>'Test',cvFull:c=>c,curConvo:()=>store.read().convos[0],lastReal:c=>c.messages.at(-1),allContacts:()=>[],contactById:()=>null,hashIdx:()=>0,openConvo:id=>opened=id,swv:()=>({}),askDel:()=>({}),threadUniiContext:()=>({label:'Contexte',raw:'Fictif'}),flash:()=>{}},()=>({route:'messagerie',isDesktop:true,isWide:true,groupes:[],dosBusy:false}),()=>{});
test('list rendered from owned state',()=>assert.equal(p.waVals().rows[0].name,'Fictif'));
test('list action uses navigation port',()=>{p.waVals().rows[0].go();assert.equal(opened,'t')});
test('filter searches message content',()=>{store.update({waQ:'introuvable'});assert.equal(p.waVals().rows.length,0)});
test('message selection updates owned state',()=>{store.update({thSelMode:true});p.convoVals().messages[0].pick();assert.deepEqual(store.read().thSel,[0])});
test('selection cleared by assistant panel',()=>{p.thVals().clear();assert.deepEqual(store.read().thSel,[]);assert.equal(store.read().thUniiOpen,false)});
test('closed modals return empty view models',()=>{assert.equal(p.fwmVals().open,false);assert.equal(p.grmVals().open,false)});
console.log(count+' presenter checks passed');

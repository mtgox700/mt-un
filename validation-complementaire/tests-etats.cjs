const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),path=require('path');
const html=fs.readFileSync(path.resolve(__dirname,'../reference-prototype/2026-10-23-v1/application/public/uniion App v3.dc.html'),'utf8');
const source=html.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1];
const sandbox={React:{createRef:()=>({})},DCLogic:class{props={};setState(p){Object.assign(this.state,typeof p==='function'?p(this.state):p)}},setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},console,Date,Map,Set,Blob,URL,window:{scrollTo(){},localStorage:{getItem(){},setItem(){}}}};
vm.createContext(sandbox);vm.runInContext(source+'\nglobalThis.C=Component;',sandbox);
function app(){const a=new sandbox.C();a.flash=x=>a.lastFlash=x;a.go=(r,p)=>a.setState({route:r,...p});return a;}
(async()=>{
const a=app();await a.startRecording();assert.equal(a.state.rec.phase,'live');assert.equal(a.state.rec.sim,true);assert.match(a.state.rec.err,/simul/);console.log('PASS micro indisponible : simulation explicitement signalée (test de logique, sans périphérique)');
a.pauseRecording();assert.equal(a.state.rec.phase,'paused');a.resumeRecording();assert.equal(a.state.rec.phase,'live');a.stopRecording();assert.equal(a.state.rec.phase,'done');console.log('PASS simulation : pause, reprise et arrêt');
sandbox.navigator={mediaDevices:{getUserMedia:async()=>{throw Error('Denied')}}};const b=app();await b.startRecording();assert.equal(b.state.rec.sim,true);assert.match(b.state.rec.err,/refusé/);console.log('PASS permission refusée : repli simulé explicite (mock)');
let stopped=0; b.recStream={getTracks:()=>[{stop(){stopped++}}]};b.releaseMic();assert.equal(stopped,1);assert.equal(b.recStream,null);console.log('PASS libération de la piste (mock)');
const c=app();c.state.rec.sim=true;c.state.rec.t=30;c.state.rec.markers=[];c.saveRecording();assert.equal(c.state.route,'reunion');assert.equal(c.state.reunions[0].audio,'kept');assert.match(c.lastFlash,/chiffré/);console.log('CONSTAT : sauvegarde simulée annoncée audio conservé/chiffré ; aucune preuve de contenu audio stocké');
})().catch(e=>{console.error(e);process.exitCode=1});

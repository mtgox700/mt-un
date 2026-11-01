// Acceptance probe: exercise the actual S02 service and auth adapter, with a denied server response.
import fs from 'node:fs';
import {createNavigationService} from '../modules/navigation/service.js';
import {attachS01Auth} from '../services/auth-s01.js';
globalThis.location={search:'?organization=fixture',hash:'',pathname:'/s02'};
let state={route:'accueil',history:[]};const store={read:()=>state,update:p=>Object.assign(state,p)};
const service=createNavigationService(store,{leaveAudio(){},applyRouteExtras:p=>Object.assign(state,p),scrollTop(){}});
const c={get state(){return state},setState:p=>Object.assign(state,p),setAuth(){},renderVals:()=>({}),services:{navigation:service},go:service.go,back:service.back,flash(){}};
let calls=0;attachS01Auth(c,async path=>{if(path==='/auth/session')return {ok:true,json:async()=>({csrf:'fixture'})};calls++;return {ok:false,json:async()=>({error:'denied'})};});
await c.go('reunions');const guarded=state.route!=='reunions'&&calls===1;
await service.go('reunions');const transversal=state.route!=='reunions';
state={route:'accueil',history:['reunions']};await c.back();const back=state.route!=='reunions';
const subroutes=[];for(const route of ['sondage','newpoll','reunion','record','signature']){state={route:'accueil',history:[]};const before=calls;await service.go(route);subroutes.push({route,denied:state.route==='accueil'&&calls===before+1});}
const result={subroutes,guardedEntryDenied:guarded,transversalEntryDenied:transversal,historyEntryDenied:back,passed:guarded&&transversal&&back&&subroutes.every(x=>x.denied)};
fs.writeFileSync(new URL('../../preuves/S02-corrections-finales/navigation-acceptance.json',import.meta.url),JSON.stringify(result,null,2));console.log(JSON.stringify(result));

if(!result.passed)throw Error("Navigation acceptance failed");

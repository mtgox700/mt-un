export function createNavigationService(store,{leaveAudio,applyRouteExtras,scrollTop}){
 let guard=null,denied=()=>{},generation=0;
 function transition(route,commit){const ticket=++generation;if(!guard){commit();return true;}return Promise.resolve().then(()=>guard(route)).then(()=>{if(ticket!==generation)return false;commit();return true;},()=>{if(ticket===generation)denied();return false;});}
 return Object.freeze({setGuard(check,onDenied=()=>{}){guard=check;denied=onDenied;generation++;},go(route,extra){const nextRoute=extra?.route??route;return transition(nextRoute,()=>{const state=store.read();if(nextRoute!==state.route)leaveAudio();applyRouteExtras({...extra,route:nextRoute,history:state.history.concat([state.route])});scrollTop();});},back(){const history=store.read().history.slice();const route=history.pop()||'accueil';return transition(route,()=>{leaveAudio();store.update({route,history});scrollTop();});}});
}

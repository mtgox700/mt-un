export function defineModule({id,routes,View,version=1}) {
 if(!/^[a-z][a-z-]*$/.test(id)||!Array.isArray(routes)||routes.length===0||new Set(routes).size!==routes.length||typeof View!=='function'||version!==1)throw Error('Invalid UI module contract');
 return Object.freeze({id,version,routes:Object.freeze([...routes]),View});
}
export function moduleRegistry(modules){const entries=new Map();for(const module of modules){for(const route of module.routes){if(entries.has(route))throw Error('Duplicate UI route');entries.set(route,module);}}return Object.freeze({resolve:route=>entries.get(route)||null,routes:Object.freeze([...entries.keys()])});}

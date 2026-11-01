// Navigation is a convenience gate; PostgreSQL remains authoritative.
export function createPermissionsNavigation(request,organizationId,navigate,notify,options={}){
 let busy=false;
 return async()=>{if(busy)return;busy=true;try{await request(options.endpoint||'/identity/rights',{organization_id:organizationId});navigate('/s02/rights?organization='+encodeURIComponent(organizationId)+(options.hash||''));}catch(e){notify('Accès aux habilitations refusé ou indisponible.');}finally{busy=false;}};
}

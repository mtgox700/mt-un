// Same-origin S01 only. No bearer token or privileged key reaches this adapter.
export function createS01Invitations(fetcher,organizationId){
 if(!/^[0-9a-f-]{36}$/i.test(organizationId||''))throw Error('Organisation requise pour les invitations.');
 return async ({text})=>{
  const emails=[...new Set(text.split(/[,;\n]/).map(s=>s.trim().toLowerCase()).filter(Boolean))];
  if(!emails.length||emails.length>20||emails.some(e=>e.length>320||!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)))throw Error('Renseignez des adresses email valides (20 maximum).');
  const sessionResponse=await fetcher('/auth/session',{credentials:'same-origin',cache:'no-store'});
  if(!sessionResponse.ok)throw Error('Session indisponible.');
  const session=await sessionResponse.json();
  if(!session.authenticated||!session.business_allowed||session.aal!=='aal2')throw Error('Connexion S01 et vérification MFA requises.');
  let accepted=0;
  for(const email of emails){
   const response=await fetcher('/identity/invitations/send',{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/json','X-Uniion-CSRF':session.csrf},body:JSON.stringify({organization_id:organizationId,email})});
   if(!response.ok)throw Error((accepted?accepted+' invitation(s) déjà créée(s). ':'')+(response.status===403?'Accès refusé pour cette organisation.':'Création indisponible.'));
   // The ticket is intentionally not persisted in browser storage or exposed in logs.
   accepted++;
  }
  return {created:accepted,delivered:true};
 };
}

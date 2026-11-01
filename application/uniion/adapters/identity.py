"""Identity commands: exact arguments, user token, database authorization."""
from uniion.core.contracts import Denied
ROUTES={
 '/identity/agenda/audiences':('uniion_agenda_audience_context',{'organization_id':'p_org'}),
 '/identity/agenda/publication-notices':('uniion_agenda_publication_notices',{'organization_id':'p_org','read_id':'p_read'}),
 '/identity/agenda/notifications':('uniion_agenda_notifications',{'organization_id':'p_org'}),
 '/identity/agenda':('uniion_agenda_list',{'organization_id':'p_org'}),
 '/identity/agenda/save':('uniion_agenda_save',{'organization_id':'p_org','event':'p_event'}),
 '/identity/partners':('uniion_partners_registry',{}),
 '/identity/partners/save':('uniion_partners_save',{'source':'p_source','target':'p_target','enabled':'p_enabled'}),
'/identity/modules':('uniion_modules_context', {'organization_id': 'p_org'}),
'/identity/modules/config':('uniion_module_config', {'organization_id': 'p_org', 'module': 'p_module', 'action': 'p_action', 'enabled': 'p_enabled'}),
'/identity/modules/commercial':('uniion_module_commercial', {'organization_id': 'p_org', 'module': 'p_module', 'reason': 'p_reason', 'from': 'p_from', 'until': 'p_until'}),
'/identity/modules/revoke':('uniion_module_revoke', {'organization_id': 'p_org', 'module': 'p_module', 'entitlement': 'p_entitlement'}),
'/identity/modules/use':('uniion_module_use', {'organization_id': 'p_org', 'module': 'p_module'}),

 '/identity/platform-role':('uniion_platform_role',{}),
 '/identity/support-agents':('uniion_support_registry',{}),
 '/identity/support-agents/save':('uniion_support_registry_save',{'user_id':'p_user','name':'p_name','enabled':'p_enabled'}),
 '/identity/support/approve-files':('uniion_support_approve_files',{'organization_id':'p_org','ticket':'p_ticket','agents':'p_agents','resources':'p_resources','until':'p_until','download':'p_download','attachments':'p_attachments'}),
 '/identity/support/assign':('uniion_support_assign',{'organization_id':'p_org','ticket':'p_ticket','agents':'p_agents'}),
 '/identity/support/request':('uniion_support_request',{'organization_id':'p_org','ticket':'p_ticket','reason':'p_reason'}),
 '/identity/support/reject':('uniion_support_reject',{'organization_id':'p_org','ticket':'p_ticket','request':'p_request'}),
 '/identity/support/approve':('uniion_support_approve',{'organization_id':'p_org','ticket':'p_ticket','agents':'p_agents','resources':'p_resources','until':'p_until','download':'p_download'}),
 '/identity/support/revoke':('uniion_support_revoke',{'organization_id':'p_org','ticket':'p_ticket','grant':'p_grant'}),
 '/identity/support/read':('uniion_support_read',{'organization_id':'p_org','ticket':'p_ticket','grant':'p_grant','resource':'p_resource','download':'p_download'}),
 "/identity/support":("uniion_support_context",{"organization_id":"p_org"}),
 "/identity/support/create":("uniion_support_create",{"organization_id":"p_org","title":"p_title"}),
 "/identity/support/status":("uniion_support_status",{"organization_id":"p_org","ticket":"p_ticket","action":"p_action"}),
 '/identity/collections/create':('uniion_collection_create',{'organization_id':'p_org','target':'p_target','name':'p_name','color':'p_color','text':'p_text'}),
 '/identity/collections':('uniion_collections_context',{'organization_id':'p_org'}),
 '/identity/collections/change':('uniion_collection_change',{'organization_id':'p_org','collection':'p_collection','action':'p_action','data':'p_data'}),
 '/identity/organizations':('uniion_context',{}),
 '/identity/console':('uniion_admin_context',{'organization_id':'p_org'}),
 '/identity/shares/create':('uniion_share_create',{'organization_id':'p_org','target':'p_target','resources':'p_resources','people':'p_people','until':'p_until','download':'p_download','versions':'p_versions','attachments':'p_attachments'}),
 '/identity/shares/accept':('uniion_share_accept',{'organization_id':'p_org','share':'p_share','people':'p_people'}),
 '/identity/shares/revoke':('uniion_share_revoke',{'organization_id':'p_org','share':'p_share'}),
 '/identity/shares/read':('uniion_shared_read',{'organization_id':'p_org','share':'p_share','resource':'p_resource','download':'p_download'}),
 '/identity/consents':('uniion_directory_context',{'organization_id':'p_org'}),
 '/identity/consents/change':('uniion_directory_authorize',{'organization_id':'p_org','target':'p_target','grantee':'p_grantee','people':'p_people','until':'p_until','enabled':'p_enabled'}),
 '/identity/rights':('uniion_identity_rights',{'organization_id':'p_org'}),
 '/identity/rights/change':('uniion_rights_batch',{'organization_id':'p_org','user_id':'p_user','changes':'p_changes'}),
 '/identity/memberships/status':('uniion_membership_status',{'organization_id':'p_org','user_id':'p_user','action':'p_action'}),
 '/identity/invitations/resend':('uniion_invite_resend',{'organization_id':'p_org','invitation_id':'p_invitation'}),
 '/identity/profile/save':('uniion_identity_profile_save',{'organization_id':'p_org','name':'p_name','role':'p_role','email':'p_email'}),
 '/identity/organization/save':('uniion_identity_organization_save',{'organization_id':'p_org','details':'p_details'}),
 '/identity/profile':('uniion_identity_profile',{'organization_id':'p_org'}),
 '/identity/directory':('uniion_identity_directory',{'organization_id':'p_org'}),
 '/auth/mfa/lost/cancel':('uniion_lost_factor_cancel',{'request_id':'p_request'}),
 '/auth/mfa/lost/approve':('uniion_lost_factor_approve',{'request_id':'p_request','verification_reference':'p_verification_reference'}),
 '/auth/mfa/recovery/approve':('uniion_mfa_recovery_approve',{'request_id':'p_request','verification_reference':'p_verification_reference'}),
 '/identity/invitations/create':('uniion_invite_create',{'organization_id':'p_org','email':'p_email'}),
 '/identity/invitations/accept':('uniion_invite_accept',{'token':'p_token'}),
 '/identity/invitations/revoke':('uniion_invite_revoke',{'organization_id':'p_org','invitation_id':'p_invitation'}),
 '/identity/memberships/revoke':('uniion_membership_revoke',{'organization_id':'p_org','user_id':'p_user'})}
def dispatch(api,token,path,data):
 if path not in ROUTES:raise Denied()
 rpc,fields=ROUTES[path]
 if set(data)!=set(fields):raise Denied()
 for k,v in data.items():
  if k=='read_id' and path=='/identity/agenda/publication-notices':
   if v is not None and (not isinstance(v,str) or len(v)!=36):raise Denied()
  elif k=='event':
   if not isinstance(v,dict) or len(v)>12 or any(type(x) not in (str,int,bool) or (isinstance(x,str) and len(x)>4000) for x in v.values()):raise Denied()
  elif k=='data':
   if not isinstance(v,dict) or len(v)>3 or any(type(x) not in (str,int) or (isinstance(x,str) and len(x)>400) for x in v.values()):raise Denied()
  elif k in ('people','resources','attachments','agents'):
   if not isinstance(v,list) or len(v)>20 or (k!='attachments' and not (k=='agents' and path=='/identity/support/assign') and not v) or any(not isinstance(x,str) or len(x)!=36 for x in v):raise Denied()
  elif k in ('download','enabled'):
   if type(v) is not bool:raise Denied()
  elif k=='versions':
   if not isinstance(v,dict) or len(v)>20 or any(not isinstance(x,str) or len(x)!=36 or type(n) is not int or n<1 for x,n in v.items()):raise Denied()
  elif k=='changes':
   if not isinstance(v,list) or not 1<=len(v)<=100 or any(not isinstance(c,dict) or set(c)-{'type','module','permission','enabled','resource','until','history'} or type(c.get('enabled')) is not bool for c in v):raise Denied()
  elif k=='details':
   if not isinstance(v,dict) or len(v)>14 or any(not isinstance(x,str) or len(x)>500 for x in v.values()):raise Denied()
  elif not isinstance(v,str) or not v or len(v)>1024:raise Denied()
 return api.request('/rest/v1/rpc/'+rpc,token,{v:data[k] for k,v in fields.items()})

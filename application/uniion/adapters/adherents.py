"""Organization-scoped adherents; never creates Auth accounts or memberships."""
from uuid import UUID
from uniion.core.contracts import Denied

def dispatch(api,token,data):
 if set(data)!={'organization_id','action','payload'} or data['action'] not in ('list_create','list_update','campaign_targets','directory_export','schedule_activate_preview','schedule_activate','list','save','import','membership_return_preview','membership_return','membership_end_correct','membership_end','coverage_list','coverage_correct','schedule_resolve_preview','schedule_resolve','schedule_coverage','schedule_pause','schedule_preview','schedule_resume','charge','settle','payment','correct','evidence_list','evidence_upload','evidence_download','evidence_preview','evidence_resume','receipt','export_csv'):raise Denied()
 try:org=str(UUID(data['organization_id']))
 except (TypeError,ValueError,AttributeError):raise Denied() from None
 payload=data['payload']
 if data['action']=='import':
  if not isinstance(payload,list) or not 1<=len(payload)<=100:raise Denied()
 elif not isinstance(payload,dict):raise Denied()
 if data['action'] in ('receipt','export_csv'):
  from .dues_exports import dispatch as export
  return export(api,token,org,data['action'],payload)
 if data['action'].startswith('evidence_'):
  from .dues_evidence import dispatch as evidence
  return evidence(api,token,org,data['action'],payload)
 return api.request('/rest/v1/rpc/uniion_adherents',token,{'p_org':org,'p_action':data['action'],'p_payload':payload})

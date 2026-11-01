"""Dossier commands; all access decisions are repeated in PostgreSQL."""
from uuid import UUID
from uniion.core.contracts import Denied

def dispatch(api,token,data):
 if set(data)!={'organization_id','action','payload'} or data['action'] not in ('disposal','list','get','create','edit','status','note','assign','files','file_upload','file_download','file_preview','file_rescan','file_version','file_restore','file_trash','classify','message_classify','link_download','link_preview') or not isinstance(data['payload'],dict):raise Denied()
 try:org=str(UUID(data['organization_id']))
 except (TypeError,ValueError,AttributeError):raise Denied() from None
 if data['action']=='disposal':
  p=data['payload'];op=p.get('operation')
  fields={'list':{'operation','case'},'request':{'operation','case','link','expected','reason'},'restore':{'operation','case','request'},'admin_list':{'operation'},'approve':{'operation','request'},'reject':{'operation','request'}}
  if op not in fields or set(p)!=fields[op]:raise Denied()
  args={'p_org':org,'p_action':op}
  for key in ('case','link','request','expected','reason'):
   if key in p:args['p_'+key]=p[key]
  return api.request('/rest/v1/rpc/uniion_case_disposal',token,args)
 if data['action']=='message_classify':
  p=data['payload']
  if set(p)!={'case','expected','conversation','seq','file'} or type(p['expected']) is not int or not isinstance(p['seq'],str) or not p['seq'].isdigit() or not 1<=len(p['seq'])<=18:raise Denied()
  try:
   for key in ('case','conversation'):UUID(p[key])
   if p['file']:UUID(p['file'])
  except (ValueError,TypeError,AttributeError):raise Denied() from None
  return api.request('/rest/v1/rpc/uniion_message_classify',token,{'p_org':org,'p_case':p['case'],'p_expected':p['expected'],'p_conversation':p['conversation'],'p_seq':int(p['seq']),'p_file':p['file']})
 if data['action']=='classify':
  p=data['payload']
  if set(p)!={'case','expected','convocation','file'} or type(p['expected']) is not int:raise Denied()
  return api.request('/rest/v1/rpc/uniion_case_classify',token,{'p_org':org,'p_case':p['case'],'p_expected':p['expected'],'p_convocation':p['convocation'],'p_file':p['file']})
 if data['action'] in ('link_download','link_preview'):
  import base64
  from . import agenda,antivirus
  p=data['payload']
  if set(p) not in ({'case','link'},{'case','link','page'}) or ('page' in p and data['action']!='link_preview'):raise Denied()
  page=p.get('page',1)
  if type(page) is not int or not 1<=page<=200:raise Denied()
  params={'p_org':org,'p_case':p['case'],'p_link':p['link']}
  ref=api.request('/rest/v1/rpc/uniion_case_link',token,params)
  if 'conversation' in ref:
   from .message_files import dispatch as message_file
   result=message_file(api,token,org,'file_preview' if data['action']=='link_preview' else 'file_download',{'id':ref['conversation'],'attachment':ref['attachment'],**({'page':page} if data['action']=='link_preview' else {})})
   api.request('/rest/v1/rpc/uniion_case_link',token,params)
   if data['action']=='link_download' and not api.request('/rest/v1/rpc/uniion_case_files',token,{'p_org':org,'p_case':p['case']})['download']:raise Denied()
   return result
  result=agenda.history_files(api,token,{'organization_id':org,**ref})
  api.request('/rest/v1/rpc/uniion_case_link',token,params)
  if data['action']=='link_preview':
   rendered=antivirus.renderer(base64.b64decode(result['content']),result['mime'],page,True)
   api.request('/rest/v1/rpc/uniion_case_link',token,params)
   return {'image':'data:image/png;base64,'+rendered['png'],'page':page,'pages':rendered['pages']}
  return result
 if data['action'].startswith('file'):
  from .case_files import dispatch as files
  return files(api,token,org,data['action'],data['payload'])
 if data['action']=='assign':return api.request('/rest/v1/rpc/uniion_case_assign',token,{'p_org':org,'p_payload':data['payload']})
 return api.request('/rest/v1/rpc/uniion_cases',token,{'p_org':org,'p_action':data['action'],'p_payload':data['payload']})

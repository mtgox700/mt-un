"""Dossier attachment bridge: existing quarantine pipeline, live parent ACL."""
import base64
from uuid import UUID
from uniion.core.contracts import Denied
from . import attachments

def dispatch(api,token,org,action,payload):
 if action=='file_trash':
  allowed={'list':{'case','operation'},'request':{'case','operation','attachment','expected','reason'},'restore':{'case','operation','request'},'admin_list':{'operation'},'approve':{'operation','request'},'reject':{'operation','request'}}
  operation=payload.get('operation')
  if operation not in allowed or set(payload)!=allowed[operation]:raise Denied()
  params={'p_org':org,'p_case':payload.get('case'),'p_action':operation}
  for key,name in [('attachment','p_root'),('request','p_request'),('expected','p_expected'),('reason','p_reason')]:
   if key in payload:params[name]=payload[key]
  return api.request('/rest/v1/rpc/uniion_case_trash',token,params)
 fields={'files':{'case'},'file_upload':{'case','filename','content'},'file_download':{'case','attachment'},'file_preview':{'case','attachment','page'},'file_rescan':{'case','attachment'},'file_version':{'case','attachment','expected','filename','content'},'file_restore':{'case','attachment','expected','version'}}
 if action not in fields or set(payload)!=fields[action]:raise Denied()
 try:
  case=str(UUID(payload['case']));attachment=str(UUID(payload['attachment'])) if 'attachment' in payload else None
 except (ValueError,TypeError,AttributeError):raise Denied() from None
 def context():return api.request('/rest/v1/rpc/uniion_case_files',token,{'p_org':org,'p_case':case,'p_attachment':attachment})
 state=context()
 if action=='files':return state
 if action in ('file_version','file_restore'):
  if not state['write'] or type(payload['expected']) is not int or payload['expected']<1:raise Denied()
  params={'p_org':org,'p_case':case,'p_root':attachment,'p_expected':payload['expected']}
  if action=='file_restore':
   if type(payload['version']) is not int or payload['version']<1:raise Denied()
   params['p_restore']=payload['version']
  else:
   name,mime,raw,sha=attachments.validate_upload(payload)
   params.update(p_filename=name,p_mime=mime,p_size=len(raw),p_sha256=sha)
  item=api.request('/rest/v1/rpc/uniion_case_file_version',token,params)
  if action=='file_version':
   attachments.storage(api,token,item['path'],raw,mime)
   attachments.rescan(api,token,org,{'attachment':item['id']})
  return context()
 if action=='file_upload':
  if not state['write']:raise Denied()
  attachments.upload(api,token,org,{**payload,'resource':case})
  return context()
 if action=='file_rescan':
  if not state['write']:raise Denied()
  attachments.rescan(api,token,org,payload)
  return context()
 if action=='file_preview':
  if type(payload['page']) is not int or not 1<=payload['page']<=200:raise Denied()
  result=attachments.preview(api,token,org,payload)
  context()
  return result
 meta,raw=attachments.download(api,token,org,payload)
 context()
 return {'filename':meta['filename'],'mime':meta['mime'],'content':base64.b64encode(raw).decode()}

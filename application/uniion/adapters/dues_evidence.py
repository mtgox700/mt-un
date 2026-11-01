"""Financial evidence: private immutable bytes, scanner-only storage, live ACL checks."""
import base64,hashlib
from . import attachments,antivirus,office_files
from uniion.core.contracts import Denied
from .supabase_transport import AccessDenied

def scan_stored(api,worker,meta):
 raw=attachments.storage(api,worker,meta['path'])
 if len(raw)!=meta['size'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']:
  status='blocked'
 else:
  status=antivirus.scan(raw)[0]
  if status=='clean':
   try:
    if meta['mime'] in office_files.MIMES.values():office_files.validate(raw,next(k for k,v in office_files.MIMES.items() if v==meta['mime']))
    else:antivirus.renderer(raw,meta['mime'])
   except (antivirus.FileBlocked,ValueError):status='blocked'
 api.request('/rest/v1/rpc/uniion_dues_evidence_finish',worker,{'p_id':meta['id'],'p_sha':meta['sha256'],'p_status':'clean' if status=='clean' else 'blocked'})
 if status!='clean':raise Denied()

def dispatch(api,token,org,action,payload):
 def rpc(action,p):return api.request('/rest/v1/rpc/uniion_dues_evidence',token,{'p_org':org,'p_payment':payload['payment'],'p_action':action,'p_payload':p})
 if action=='evidence_list':
  if set(payload)!={'payment'}:raise Denied()
  return rpc('list',{})
 if action=='evidence_resume':
  if set(payload)!={'payment','id'}:raise Denied()
  meta=rpc('resume',{'id':payload['id']})
  if meta['status']=='pending':scan_stored(api,antivirus.worker_token(api),meta)
  return rpc('list',{})
 if action in ('evidence_download','evidence_preview'):
  preview=action=='evidence_preview'
  if set(payload)!=({'payment','id','page'} if preview else {'payment','id'}):raise Denied()
  if preview and (type(payload['page']) is not int or not 1<=payload['page']<=200):raise Denied()
  operation='preview' if preview else 'get'
  meta=rpc(operation,{'id':payload['id'],'audit':False})
  raw=attachments.storage(api,antivirus.worker_token(api),meta['path'])
  if len(raw)!=meta['size'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']:raise Denied()
  if antivirus.scan(raw)[0]!='clean':raise Denied()
  if preview:
   from .evidence_preview import render
   result=render(raw,meta['mime'],payload['page'])
  rpc(operation,{'id':payload['id'],'audit':True})
  if preview:return {**result,'id':meta['id'],'filename':meta['filename']}
  return {'filename':meta['filename'],'mime':meta['mime'],'content':base64.b64encode(raw).decode()}
 if action!='evidence_upload' or set(payload)!={'payment','filename','content','request_id'}:raise Denied()
 # Check financial access before processing bytes; prepare checks write again.
 rpc('list',{})
 name,mime,raw,sha=attachments.validate_upload(payload)
 meta=rpc('prepare',{'filename':name,'mime':mime,'size':len(raw),'sha256':sha,'request_id':payload['request_id']})
 if meta['status']=='blocked':raise Denied()
 worker=antivirus.worker_token(api)
 if meta['status']!='clean':
  try:attachments.storage(api,worker,meta['path'],raw,mime)
  except AccessDenied:
   existing=attachments.storage(api,worker,meta['path'])
   if existing!=raw:raise Denied()
  scan_stored(api,worker,meta)
 return rpc('list',{})

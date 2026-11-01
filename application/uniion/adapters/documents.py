"""Durable document drafts; PostgreSQL owns authorization and optimistic versions."""
from uuid import UUID
from uniion.core.contracts import Denied

def dispatch(api,token,data):
 if set(data)!={'organization_id','action','payload'} or data['action'] not in ('list','get','create','save','defaults_get','defaults_save','export','publication_status','publication_review','publication_publish','publication_correction','history','archive','notices','disposal','export_start','export_status') or not isinstance(data['payload'],dict):raise Denied()
 try:org=str(UUID(data['organization_id']))
 except (ValueError,TypeError,AttributeError):raise Denied() from None
 if data['action'] in ('export_start','export_status'):
  from .document_jobs import dispatch as jobs
  return jobs(api,token,org,data['action'],data['payload'])
 if data['action']=='disposal':
  p=data['payload'];op=p.get('operation')
  fields={'list':{'operation','case'},'request':{'operation','case','link','expected','reason'},'restore':{'operation','case','request'},'admin_list':{'operation'},'approve':{'operation','request'},'reject':{'operation','request'}}
  if op not in fields or set(p)!=fields[op]:raise Denied()
  args={'p_org':org,'p_action':op}
  for key in ('case','link','request','expected','reason'):
   if key in p:args['p_'+key]=p[key]
  return api.request('/rest/v1/rpc/uniion_document_disposal',token,args)
 if data['action'] in ('history','archive'):
  p=data['payload']
  if set(p)!=({'id','version'} if data['action']=='archive' else {'id'}):raise Denied()
  return api.request('/rest/v1/rpc/uniion_document_history',token,{'p_org':org,'p_id':p['id'],'p_version':p.get('version')})
 if data['action']=='notices':
  if set(data['payload'])-{'read'}:raise Denied()
  return api.request('/rest/v1/rpc/uniion_document_notices',token,{'p_org':org,'p_read':data['payload'].get('read')})
 if data['action']=='publication_publish':
  from .document_exports import publish
  return publish(api,token,org,data['payload'])
 if data['action'].startswith('publication_'):
  return api.request('/rest/v1/rpc/uniion_document_publication',token,{'p_org':org,'p_action':data['action'].removeprefix('publication_'),'p_payload':data['payload']})
 if data['action']=='export':
  from .document_exports import export
  return export(api,token,org,data['payload'])
 if data['action'].startswith('defaults_'):
  action=data['action'].removeprefix('defaults_')
  if action=='save':
   current=api.request('/rest/v1/rpc/uniion_document_defaults',token,{'p_org':org,'p_action':'get','p_payload':{}})
   if not current['canWrite'] or current['version']!=data['payload'].get('version'):raise Denied()
   from .document_images import certify
   certify(api,token,org,{'charte':{'logo':data['payload'].get('logo')}},{'charte':{'logo':current['logo']}},scope='document_defaults')
  return api.request('/rest/v1/rpc/uniion_document_defaults',token,{'p_org':org,'p_action':action,'p_payload':data['payload']})
 if data['action']=='save':
  current=api.request('/rest/v1/rpc/uniion_documents',token,{'p_org':org,'p_action':'get','p_payload':{'id':data['payload'].get('id')}})
  if not current['canWrite'] or current['version']!=data['payload'].get('version'):raise Denied()
  from .document_images import certify
  certify(api,token,current['id'],data['payload'].get('document'),current,scope='document')
 return api.request('/rest/v1/rpc/uniion_documents',token,{'p_org':org,'p_action':data['action'],'p_payload':data['payload']})

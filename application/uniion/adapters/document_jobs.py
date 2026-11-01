"""Bounded asynchronous rendering; durable jobs, no persisted authentication tokens."""
from concurrent.futures import ThreadPoolExecutor
from threading import BoundedSemaphore
from uniion.core.contracts import Denied,Unavailable,PDFOverflow,PDFContentMissing
from .document_exports import export
from .antivirus import worker_token
_pool=ThreadPoolExecutor(max_workers=2,thread_name_prefix='document-render')
_slots=BoundedSemaphore(8)
def dispatch(api,token,org,action,payload):
 if set(payload)!={'id','version'}:raise Denied()
 p={'p_org':org,'p_id':payload['id'],'p_version':payload['version']}
 result=api.request('/rest/v1/rpc/uniion_document_job',token,{**p,'p_action':'start' if action=='export_start' else 'status'})
 if action=='export_start' and result['state']!='done':
  if not _slots.acquire(blocking=False):raise Unavailable()
  try:
   claim=api.request('/rest/v1/rpc/uniion_document_job',token,{**p,'p_action':'claim'})
   if not claim.get('lease'):_slots.release();return result
   _pool.submit(_render,api,token,org,payload,claim)
  except Exception:_slots.release();raise
 return result

def _render(api,token,org,payload,claim):
 try:
  try:result=export(api,token,org,payload);error=None
  except PDFContentMissing:result=None;error='pdf_content_missing'
  except PDFOverflow:result=None;error='pdf_overflow'
  except Exception:result=None;error='unavailable'
  api.request('/rest/v1/rpc/uniion_document_job_finish',worker_token(api),{'p_job':claim['id'],'p_lease':claim['lease'],'p_result':result,'p_error':error})
 finally:_slots.release()

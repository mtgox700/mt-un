"""Immutable generated attachments, stored before delivery in private Storage."""
import base64
import hashlib
from uuid import uuid4
from . import antivirus, attachments
from .supabase_transport import SupabaseUnavailable


def read(api, meta):
 raw=attachments.storage(api,antivirus.worker_token(api),meta['path'])
 if len(raw)!=meta['size'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']:
  raise SupabaseUnavailable('Intégrité de l’archive non confirmée')
 return raw


def persist(api, org, convocation, generated):
 worker=antivirus.worker_token(api)
 files=[]
 for kind,item in zip(('pdf','ics'),generated,strict=True):
  raw=base64.b64decode(item['Content'],validate=True)
  if antivirus.scan(raw)[0]!='clean':raise antivirus.FileBlocked('Archive bloquée')
  oid=str(uuid4())
  files.append({'id':kind,'object':oid,'path':org+'/'+convocation+'/'+oid,'mime':item['ContentType'],'size':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
 def rpc(action):return api.request('/rest/v1/rpc/uniion_convocation_archive',worker,{'p_org':org,'p_convocation':convocation,'p_action':action,'p_files':files if action=='reserve' else None})
 rpc('reserve')
 for meta,item in zip(files,generated,strict=True):
  raw=base64.b64decode(item['Content'],validate=True)
  attachments.storage(api,worker,meta['path'],raw,meta['mime'])
  # Sending uses bytes read back from Storage, never a new rendering.
  item['Content']=base64.b64encode(read(api,meta)).decode()
 rpc('finish')

"""Bounded, user-token Storage transport; no signed links and no service key."""
import base64,hashlib,re,urllib.request,urllib.error
from .supabase_transport import AccessDenied,SupabaseUnavailable
from . import antivirus,office_files
LIMIT=5*1024*1024

def validate_upload(data):
 name=data['filename']
 if not isinstance(name,str) or not 1<=len(name)<=180 or re.search(r'[\x00-\x1f\x7f/\\]',name):raise ValueError('Nom de fichier invalide')
 raw=base64.b64decode(data['content'],validate=True)
 if not 0<len(raw)<=LIMIT:raise ValueError('Fichier vide ou supérieur à 5 Mo')
 ext=name.rsplit('.',1)[-1].lower()
 if ext in office_files.MIMES:mime=office_files.validate(raw,ext)
 elif ext=='txt':
  raw.decode('utf-8')
  if b'\x00' in raw:raise ValueError('Texte invalide')
  mime='text/plain'
 elif ext=='pdf' and raw.startswith(b'%PDF-') and b'%%EOF' in raw[-2048:]:mime='application/pdf'
 elif ext=='png' and raw.startswith(b'\x89PNG\r\n\x1a\n'):mime='image/png'
 elif ext in ('jpg','jpeg') and raw.startswith(b'\xff\xd8\xff') and raw.endswith(b'\xff\xd9'):mime='image/jpeg'
 else:raise ValueError('Formats acceptés : PDF, PNG, JPEG ou texte UTF-8')
 return name,mime,raw,hashlib.sha256(raw).hexdigest()

def storage(api,token,path,raw=None,mime=None):
 # Path comes exclusively from a checked SQL RPC, not the browser.
 if not re.fullmatch(r'[a-f0-9-]{36}/[a-f0-9-]{36}/[a-f0-9-]{36}',path):raise AccessDenied()
 headers={'Authorization':'Bearer '+token}
 if api.key:headers['apikey']=api.key
 if raw is not None:headers.update({'Content-Type':mime,'x-upsert':'false'})
 route='/storage/v1/object/'+('uniion-private/' if raw is not None else 'authenticated/uniion-private/')+path
 try:
  with api.open(urllib.request.Request(api.url+route,data=raw,headers=headers),timeout=30) as res:
   body=res.read(LIMIT+1)
   if len(body)>LIMIT:raise SupabaseUnavailable('Fichier trop volumineux')
   return body
 except urllib.error.HTTPError as exc:
  if exc.code in (400,401,403,404):raise AccessDenied('Pièce jointe inaccessible') from None
  raise SupabaseUnavailable('Stockage indisponible') from None
 except OSError:raise SupabaseUnavailable('Stockage indisponible') from None

def upload(api,token,org,data):
 name,mime,raw,sha=validate_upload(data)
 item=api.request('/rest/v1/rpc/uniion_attachment_prepare',token,{'p_org':org,'p_resource':data['resource'],'p_filename':name,'p_mime':mime,'p_size':len(raw),'p_sha256':sha})
 storage(api,token,item['path'],raw,mime)
 return rescan(api,token,org,{'attachment':item['id']})

def download(api,token,org,data):
 params={'p_org':org,'p_attachment':data['attachment'],'p_share':data.get('share'),'p_audit':False}
 meta=api.request('/rest/v1/rpc/uniion_attachment_get',token,params)
 # End-user direct Storage reads are closed. Only this checked gateway fetches bytes.
 raw=storage(api,antivirus.worker_token(api),meta['path'])
 if len(raw)!=meta['size'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']:raise SupabaseUnavailable('Intégrité du fichier non confirmée')
 # Recheck after fetching bytes, then audit only a successful integrity check.
 params['p_audit']=True
 api.request('/rest/v1/rpc/uniion_attachment_get',token,params)
 return meta,raw


def rescan(api,token,org,data):
 api.request('/rest/v1/rpc/uniion_scan_request',token,{'p_org':org,'p_attachment':data['attachment']})
 worker=antivirus.worker_token(api)
 meta=api.request('/rest/v1/rpc/uniion_scan_job',worker,{'p_attachment':data['attachment']})
 status='error';engine='';reason='Analyse indisponible'
 try:
  raw=storage(api,worker,meta['path'])
  if len(raw)!=meta['size'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']:raise antivirus.FileBlocked('Integrite non confirmee')
  status,engine,reason=antivirus.scan(raw)
  if status=='clean':
   if meta['mime'] in office_files.MIMES.values():office_files.validate(raw,next(k for k,v in office_files.MIMES.items() if v==meta['mime']))
   else:antivirus.renderer(raw,meta['mime'])
 except (antivirus.FileBlocked,ValueError):status='invalid';reason='Format actif, chiffre, invalide ou hors limites'
 except (antivirus.ScanUnavailable,AccessDenied,SupabaseUnavailable):status='error';reason='Analyse non terminee'
 result=api.request('/rest/v1/rpc/uniion_scan_result',worker,{'p_attachment':meta['id'],'p_sha256':meta['sha256'],'p_status':status,'p_engine':engine,'p_reason':reason,'p_generation':meta['generation']})
 if status=='error':raise antivirus.ScanUnavailable('Analyse indisponible. Fichier conserve en quarantaine.')
 if status!='clean':raise antivirus.FileBlocked('Fichier bloque. Il reste en quarantaine et ne peut pas etre partage.')
 return result

def preview(api,token,org,data):
 params={'p_org':org,'p_attachment':data['attachment'],'p_share':data.get('share'),'p_audit':False,'p_preview':True}
 meta=api.request('/rest/v1/rpc/uniion_attachment_get',token,params)
 raw=storage(api,antivirus.worker_token(api),meta['path'])
 if len(raw)!=meta['size'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']:raise SupabaseUnavailable('Integrite non confirmee')
 try:result=antivirus.renderer(raw,meta['mime'],data.get('page',1),True)
 except antivirus.FileBlocked:raise antivirus.PreviewUnavailable() from None
 params['p_audit']=True
 api.request('/rest/v1/rpc/uniion_attachment_get',token,params)
 return {'id':meta['id'],'filename':meta['filename'],'page':result['page'],'pages':result['pages'],'image':'data:image/png;base64,'+result['png']}

def support_file(api,token,org,data,preview_mode=False):
 params={'p_org':org,'p_ticket':data['ticket'],'p_grant':data['grant'],'p_attachment':data['attachment'],'p_preview':preview_mode,'p_audit':False}
 meta=api.request('/rest/v1/rpc/uniion_support_file_get',token,params)
 raw=storage(api,antivirus.worker_token(api),meta['path'])
 if len(raw)!=meta['size'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']:raise SupabaseUnavailable('Intégrité du fichier non confirmée')
 if preview_mode:
  try:result=antivirus.renderer(raw,meta['mime'],data['page'],True)
  except antivirus.FileBlocked:raise antivirus.PreviewUnavailable() from None
 params['p_audit']=True
 api.request('/rest/v1/rpc/uniion_support_file_get',token,params)
 if preview_mode:return {'id':meta['id'],'filename':meta['filename'],'page':result['page'],'pages':result['pages'],'image':'data:image/png;base64,'+result['png']}
 return {'filename':meta['filename'],'mime':meta['mime'],'content':base64.b64encode(raw).decode()}

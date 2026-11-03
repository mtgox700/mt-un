"""Server-side ICS, current authorization and current version on every export."""
from datetime import datetime,timezone
from zoneinfo import ZoneInfo
from uuid import UUID
from uniion.core.contracts import Denied

def calendar(event):
 def escape(value):return str(value).replace('\\','\\\\').replace('\r\n','\n').replace('\r','\n').replace('\n','\\n').replace(';','\\;').replace(',','\\,')
 def stamp(key):return datetime.fromisoformat(event['date']+'T'+event[key]).replace(tzinfo=ZoneInfo('Europe/Paris')).astimezone(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
 lines=['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//uniion//Agenda//FR','CALSCALE:GREGORIAN','BEGIN:VEVENT','UID:'+str(UUID(event['id']))+'@uniion.local','SEQUENCE:'+str(event['version']),'DTSTAMP:'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'),'DTSTART:'+stamp('start'),'DTEND:'+stamp('end'),'SUMMARY:'+escape(event['title']),'LOCATION:'+escape(event['lieu']),'DESCRIPTION:'+escape(event['notes']),'END:VEVENT','END:VCALENDAR']
 folded=[]
 for line in lines:
  part=''
  for char in line:
   if len((part+char).encode('utf8'))>75:folded.append(part);part=' '
   part+=char
  folded.append(part)
 return '\r\n'.join(folded)+'\r\n'

def export(api,token,data):
 if set(data)!={'organization_id','event_id'}:raise Denied()
 try:org=str(UUID(data['organization_id']));event=str(UUID(data['event_id']))
 except (ValueError,TypeError,AttributeError):raise Denied() from None
 row=api.request('/rest/v1/rpc/uniion_agenda_export',token,{'p_org':org,'p_id':event})
 return {'filename':'evenement.ics','mime':'text/calendar;charset=utf-8','content':calendar(row)}

SEND_WORKERS=4

def send_mail(message):
 """Local mail service (Inbucket) of the fictitious test environment; no redirect followed."""
 import json,urllib.request
 class NoRedirect(urllib.request.HTTPRedirectHandler):
  def redirect_request(self,req,fp,code,msg,headers,newurl):return None
 try:
  req=urllib.request.Request('http://127.0.0.1:54324/api/v1/send',data=json.dumps(message).encode(),headers={'Content-Type':'application/json'},method='POST')
  with urllib.request.build_opener(NoRedirect()).open(req,timeout=8) as response:ok=response.status==200;response.read()
  return ok
 except Exception:return False

def workflow(api,token,data,send=False):
 import json,urllib.request
 if set(data)!={'organization_id','event_id','action','payload'} or not isinstance(data['payload'],dict) or data['action'] not in ('files','select_files','upload_file','document','save_document','recipients','prepare','export','status','review','publish','published'):raise Denied()
 try:org=str(UUID(data['organization_id']));event=str(UUID(data['event_id']))
 except (ValueError,TypeError,AttributeError):raise Denied() from None
 def rpc(action,payload):return api.request('/rest/v1/rpc/uniion_agenda_work',token,{'p_org':org,'p_event':event,'p_action':action,'p_payload':payload})
 if not send and data['action'] in ('files','select_files','upload_file'):
  def file_rpc(action,payload):return api.request('/rest/v1/rpc/uniion_agenda_files',token,{'p_org':org,'p_event':event,'p_action':action,'p_payload':payload})
  if data['action']=='upload_file':
   from . import attachments
   payload=data['payload']
   if set(payload)!={'resource','filename','content'}:raise Denied()
   context=file_rpc('context',{})
   if not any(r['id']==payload['resource'] for r in context['resources']):raise Denied()
   attachments.upload(api,token,org,payload)
   return file_rpc('context',{})
  return file_rpc('select' if data['action']=='select_files' else 'context',data['payload'])
 if not send and data['action'] in ('export','status','review','publish','published'):
  result=api.request('/rest/v1/rpc/uniion_agenda_publication',token,{'p_org':org,'p_event':event,'p_action':data['action'],'p_payload':data['payload']})
  if data['action']=='export':
   from .agenda_pdf import render
   import base64
   return {'filename':'ordre-du-jour.pdf','mime':'application/pdf','base64':base64.b64encode(render(result['document'],result['version'])).decode()}
  return result
 if not send:
  if data['action']=='prepare':raise Denied()
  if data['action']=='save_document':
   current=rpc('document',{})
   if not current['canWrite'] or data['payload'].get('version')!=current['version']:raise Denied()
   from .document_images import certify
   certify(api,token,event,data['payload'].get('document',{}),current['document'])
  return rpc(data['action'],data['payload'])
 if data['action']!='prepare':raise Denied()
 attachments=[]
 if 'attachment_version' in data['payload']:
  from .agenda_pdf import render
  from . import antivirus
  import base64
  checked=rpc('attachments',{'version':data['payload']['attachment_version'],'people':data['payload'].get('people')})
  raw=render(checked['document'],checked['version'])
  status,_,_=antivirus.scan(raw)
  if status!='clean':raise antivirus.FileBlocked('Pièce jointe bloquée')
  attachments=[{'Filename':'ordre-du-jour.pdf','ContentType':'application/pdf','Content':base64.b64encode(raw).decode()}, {'Filename':'evenement.ics','ContentType':'text/calendar','Content':base64.b64encode(calendar(checked['event']).encode()).decode()}]
  from .attachments import download
  for item in checked['document'].get('convocation_files',[]):
   meta,content=download(api,token,org,{'attachment':item['id']})
   if meta['sha256']!=item['sha256']:raise Denied()
   status,_,_=antivirus.scan(content)
   if status!='clean':raise antivirus.FileBlocked('Pièce jointe bloquée')
   attachments.append({'Filename':meta['filename'],'ContentType':meta['mime'],'Content':base64.b64encode(content).decode()})
 batch=rpc('prepare',data['payload']);sent=uncertain=0
 if attachments and batch['deliveries']:
  from .convocation_archive import persist
  persist(api,org,data['payload']['id'],attachments[:2])
 def deliver(recipient):
  # Each recipient keeps its own check -> send -> finish sequence; recipients are independent.
  payload={'id':data['payload']['id'],'user':recipient['user']}
  rpc('check',payload)
  message={'From':{'Email':'agenda@uniion-local.example','Name':'uniion — Convocation locale'},'To':[{'Email':recipient['email']}],'Subject':batch['subject'],'Text':batch['body'],'Headers':{'Message-ID':'<'+payload['id']+'.'+payload['user']+'@agenda.uniion.local>'}}
  if attachments:message['Attachments']=attachments
  ok=send_mail(message)
  rpc('finish',{**payload,'ok':ok});return ok
 # Bounded parallel delivery (R24): at most SEND_WORKERS connections to the mail service.
 from concurrent.futures import ThreadPoolExecutor
 deliveries=batch['deliveries'] or []
 outcomes=[]
 if deliveries:
  with ThreadPoolExecutor(max_workers=min(SEND_WORKERS,len(deliveries)),thread_name_prefix='convocation-send') as pool:
   futures=[pool.submit(deliver,recipient) for recipient in deliveries]
  outcomes=[f.exception() or f.result() for f in futures]
  failure=next((o for o in outcomes if isinstance(o,BaseException)),None)
  if failure is not None:raise failure
 sent=sum(1 for o in outcomes if o is True);uncertain=len(outcomes)-sent
 return {'sent':sent,'uncertain':uncertain,'replayed':batch['replayed']}

def history_files(api,token,data):
 import base64
 from . import attachments,antivirus
 if set(data)!={'organization_id','convocation','file'}:raise Denied()
 try:org=str(UUID(data['organization_id']));cid=str(UUID(data['convocation']))
 except (ValueError,TypeError,AttributeError):raise Denied() from None
 file=data['file']
 if file is not None and (not isinstance(file,str) or len(file)>36):raise Denied()
 params={'p_org':org,'p_convocation':cid,'p_file':file}
 checked=api.request('/rest/v1/rpc/uniion_convocation_files',token,params)
 if file is None:return checked
 if file in ('pdf','ics'):
  from .convocation_archive import read
  raw=read(api,checked['archive']);name='ordre-du-jour.pdf' if file=='pdf' else 'evenement.ics';mime=checked['archive']['mime']
 else:
  meta,raw=attachments.download(api,token,org,{'attachment':file});name=meta['filename'];mime=meta['mime']
 if antivirus.scan(raw)[0]!='clean':raise antivirus.FileBlocked('Fichier bloqué')
 api.request('/rest/v1/rpc/uniion_convocation_files',token,params)
 return {'filename':name,'mime':mime,'content':base64.b64encode(raw).decode()}

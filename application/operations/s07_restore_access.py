"""S07 Auth, MFA, references, private bytes and revocation on restored services."""
import json,time,base64,struct,hmac,hashlib,subprocess,sys,io,urllib.error
from pathlib import Path
import backup_restore as b,restore_services as s
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root));proof=root/'preuves/S07-F'/('restore-final140' if '--final' in sys.argv else '.')
from uniion.adapters import message_files
from uniion.adapters.supabase_transport import AccessDenied
r=json.loads(max((p for p in proof.glob('restore-*.json') if p.name!='restore-access.json'),key=lambda p:p.stat().st_mtime).read_text());checks=[]
def check(label,ok):
 checks.append({'test':label,'ok':bool(ok)})
 (proof/'restore-access.json').write_text(json.dumps({'passed':False,'checks':checks},indent=2))
 if not ok:raise RuntimeError(label)
def otp(secret):
 d=hmac.new(base64.b32decode(secret+'='*((8-len(secret)%8)%8)),struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();i=d[-1]&15
 return str((struct.unpack('>I',d[i:i+4])[0]&0x7fffffff)%1000000).zfill(6)
try:
 client=s.start(r)
 for _ in range(120):
  try:
   if s.request(client,9999,'/health')['status']==200 and s.request(client,5000,'/status')['status']==200:break
  except RuntimeError:pass
  time.sleep(.5)
 accounts=json.loads((root/'.local-auth/sessions-fixtures.json').read_text());f=json.loads((root/'.local-auth/s02-browser-fixture.json').read_text());d=json.loads((root/'.local-auth/s07-d-fixture.json').read_text());e=json.loads((root/'.local-auth/s07-e-fixture.json').read_text());third=json.loads((root/'.local-auth/s07-fixture.json').read_text())
 check('sessions_not_restored',b.sql('select count(*) from auth.sessions',r['container'],'restored')=='0')
 def rpc(token,action,payload={},org=d['organization']):return s.request(client,3000,'/rpc/uniion_messaging',token,{'p_org':org,'p_action':action,'p_payload':payload})
 tokens=[]
 for i,(a,factor,secret) in enumerate([(accounts[0],f['factor'],f['secret']),(accounts[1],f['recipientFactor'],f['recipientSecret']),(third['third'],third['thirdFactor'],third['thirdSecret'])]):
  login=s.request(client,9999,'/token?grant_type=password',body={'email':a['email'],'password':a['password']});check('login_'+str(i),login['status']==200);token=login['data']['access_token']
  check('aal1_messaging_denied_'+str(i),rpc(token,'list')['status']==403)
  challenge=s.request(client,9999,'/factors/'+factor+'/challenge',token,{})
  verified=s.request(client,9999,'/factors/'+factor+'/verify',token,{'challenge_id':challenge['data']['id'],'code':otp(secret)})
  check('restored_mfa_'+str(i),verified['status']==200);tokens.append(verified['data']['access_token'])
 x,y,z=tokens
 check('source_locate',rpc(x,'locate',{'id':d['source'],'seq':'1'})['status']==200)
 check('history_grant_restored',rpc(y,'locate',{'id':d['source'],'seq':'1'})['status']==200)
 check('hidden_history_denied',rpc(z,'locate',{'id':d['source'],'seq':'1'})['status']==403)
 check('forward_reference_restored',rpc(y,'get',{'id':d['target']})['status']==200)
 check('forward_source_hidden', 'Aiguille' not in json.dumps(rpc(z,'get',{'id':d['target']})['data']))
 check('reinvitation_no_old_history',rpc(y,'get',{'id':e['conversation']},e['organization'])['data']['messages']==[])
 check('reinvitation_no_unread',rpc(y,'get',{'id':e['conversation']},e['organization'])['data']['unread']==0)
 class API:
  key='';url='http://isolated'
  def login(self,email,password):
   response=s.request(client,9999,'/token?grant_type=password',body={'email':email,'password':password})
   if response['status']!=200:raise AccessDenied()
   return response['data']
  def request(self,path,token,body=None,method=None):
   result=s.request(client,3000,path.removeprefix('/rest/v1'),token,body,method)
   if result['status']!=200:raise AccessDenied()
   return result['data']
  def open(self,request,timeout=30):
   arg={'path':request.full_url.removeprefix(self.url+'/storage/v1'),'headers':dict(request.header_items())}
   code="""(async()=>{let t='';for await(const c of process.stdin)t+=c;const a=JSON.parse(t);const r=await fetch('http://127.0.0.1:5000'+a.path,{headers:a.headers});console.log(JSON.stringify({status:r.status,body:Buffer.from(await r.arrayBuffer()).toString('base64')}))})()"""
   result=json.loads(b.run(['docker','exec','-i',client,'node','-e',code],json.dumps(arg).encode()))
   if result['status']>=400:raise urllib.error.HTTPError(request.full_url,result['status'],'Denied',{},None)
   return io.BytesIO(base64.b64decode(result['body']))
 api=API();payload={'id':d['source'],'attachment':d['attachment']}
 restored=message_files.dispatch(api,x,d['organization'],'file_download',payload)
 check('restored_private_bytes_exact',base64.b64decode(restored['content'])==(root/'preuves/S07-C/piece-recette.png').read_bytes())
 check('restored_preview',message_files.dispatch(api,y,d['organization'],'file_preview',{**payload,'page':1})['image'].startswith('data:image/png;base64,'))
 def denied(fn):
  try:fn();return False
  except AccessDenied:return True
 check('restored_download_separate',denied(lambda:message_files.dispatch(api,y,d['organization'],'file_download',payload)))
 check('restored_hidden_file_denied',denied(lambda:message_files.dispatch(api,z,d['organization'],'file_preview',{**payload,'page':1})))
 check('foreign_org_denied',rpc(x,'get',{'id':d['source']},e['organization'])['status']==403)
 check('private_reads_denied',s.request(client,3000,'/message_reads?select=*',x)['status'] in (403,404))
 b.sql("update public.uniion_memberships set revoked_at=now() where organization_id='"+d['organization']+"' and user_id='"+accounts[1]['id']+"'",r['container'],'restored')
 check('restored_revocation_live_denied',rpc(y,'live')['status']==403)
 check('restored_revocation_bytes_denied',denied(lambda:message_files.dispatch(api,y,d['organization'],'file_preview',{**payload,'page':1})))
 (proof/'restore-access.json').write_text(json.dumps({'passed':True,'count':len(checks),'container':r['container'],'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))
finally:
 subprocess.run(['docker','stop',*r.get('services',[]),r['container'],r['file_container']],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

"""Real GoTrue TOTP and SQL controls; dedicated fictional users only.
Secrets and TOTP codes remain in memory; proof contains labels and booleans only.
"""
import pathlib,sys,json,io,base64,hmac,hashlib,struct,time
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from uniion.app import create_app
from uniion.config import Config
from uniion.adapters.supabase_transport import SupabaseAccess,AccessDenied
accounts=json.loads((ROOT/'.local-auth/sessions-fixtures.json').read_text());api=SupabaseAccess('http://127.0.0.1:54321','',local=True)
app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url}),api)
checks=[];factors=[];cleanup_token=None
class Client:
 def __init__(self):self.cookie='';self.csrf='';self.call('/auth/session')
 def call(self,path,data=None,**extra):
  body=json.dumps(data).encode() if data is not None else b'';r=[]
  e={'REQUEST_METHOD':'GET' if data is None else 'POST','PATH_INFO':path,'HTTP_HOST':'127.0.0.1:5060','HTTP_ORIGIN':'http://127.0.0.1:5060','HTTP_COOKIE':self.cookie,'HTTP_X_UNIION_CSRF':self.csrf,'CONTENT_TYPE':'application/json','CONTENT_LENGTH':str(len(body)),'wsgi.input':io.BytesIO(body),'REMOTE_ADDR':'127.0.0.1',**extra}
  raw=b''.join(app(e,lambda status,headers:r.append((int(status[:3]),dict(headers)))))
  status,headers=r[0];d=json.loads(raw)
  if 'Set-Cookie' in headers:self.cookie=headers['Set-Cookie'].split(';')[0]
  if 'csrf' in d:self.csrf=d['csrf']
  return status,d,headers
 def login(self,a):return self.call('/auth/login',{'email':a['email'],'password':a['password']})
 def state(self):return app.sessions.sessions.get(self.cookie.split('=',1)[1])
def check(name,ok):
 checks.append({'test':name,'ok':bool(ok)})
 if not ok:raise AssertionError(name)
def resource(c,a):return c.call('/api/organizations/'+a['org']+'/resources/'+a['resource'])
def code(secret):
 key=base64.b32decode(secret+'='*((8-len(secret)%8)%8));digest=hmac.new(key,struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();off=digest[-1]&15
 return str((struct.unpack('>I',digest[off:off+4])[0]&0x7fffffff)%1000000).zfill(6)
def verify(c,f,secret):
 status,d,_=c.call('/auth/mfa/challenge',{'factor_id':f});check('challenge_created',status==200)
 return c.call('/auth/mfa/verify',{'factor_id':f,'challenge_id':d['id'],'code':code(secret)}),d['id']
import tempfile,subprocess,os
from uniion.adapters.durable_sessions import DurableSessionStore
CHILD=r"""
import sys,os
from uniion.adapters.durable_sessions import DurableSessionStore
from uniion.adapters.supabase_transport import SupabaseAccess
class CrashApi(SupabaseAccess):
 def request(self,path,*args,**kwargs):
  if path=='/auth/v1/user' and sys.argv[4]=='after-save':os._exit(76)
  value=super().request(path,*args,**kwargs)
  if 'grant_type=refresh_token' in path and sys.argv[4]=='before-save':os._exit(75)
  return value
api=CrashApi('http://127.0.0.1:54321','',local=True)
s=DurableSessionStore(api,sys.argv[1],sys.argv[2])
with s.lock:s.authenticate(s.sessions[sys.argv[3]])
"""
checks=[]
for mode in ('before-save','after-save'):
 with tempfile.TemporaryDirectory() as temp:
  folder=pathlib.Path(temp);clock=[time.time()]
  def reopen():
   global app
   store=DurableSessionStore(api,folder/'db/state.sqlite3',folder/'key/session.key',clock=lambda:clock[0])
   app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url}),api,store)
   return store
  store=reopen();c=Client();check(mode+'_login',c.login(accounts[1])[0]==200)
  sid=c.cookie.split('=',1)[1]
  with store.lock:
   store.sessions[sid]['expires_at']=0;old=store.sessions[sid]['access_token']
  env={**os.environ,'PYTHONPATH':str(ROOT)}
  child=subprocess.run([sys.executable,'-B','-c',CHILD,str(folder/'db/state.sqlite3'),str(folder/'key/session.key'),sid,mode],env=env,capture_output=True,timeout=20)
  check(mode+'_abrupt_process_exit',child.returncode==(75 if mode=='before-save' else 76))
  store=reopen()
  if mode=='before-save':
   check('uncertain_session_business_closed',resource(c,accounts[1])[0]==403)
   with store.lock:check('uncertain_rotation_queued_for_revocation',len(store.pending)==1 and sid not in store.sessions)
   # Do not rely solely on an immediate token reuse grace period.
   time.sleep(15);clock[0]=time.time()+31;store.maintain()
   check('old_token_direct_rest_denied_after_reconciliation',api.request('/rest/v1/uniion_resources?select=id&organization_id=eq.'+accounts[1]['org'],old)==[])
   with store.lock:check('uncertain_rotation_queue_resolved',not store.pending)
  else:
   check('saved_rotation_remains_authenticated',c.call('/auth/session')[1]['authenticated'])
   check('saved_rotation_own_access',resource(c,accounts[1])[0]==200)
   check('saved_rotation_cross_org_denied',resource(c,accounts[0])[0]==403)
   check('saved_rotation_logout',c.call('/auth/logout',{})[0]==200)
   check('saved_rotation_logout_closes_access',resource(c,accounts[1])[0]==403)
proof={'checks':checks,'passed':True,'count':len(checks),'real_supabase_refresh':True,'abrupt_child_exits':2,'supabase_services_stopped':False}
(ROOT/'preuves/S01-resilience/crashes.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({'passed':True,'count':len(checks)}))

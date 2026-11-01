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
import tempfile
from uniion.adapters.durable_sessions import DurableSessionStore
from uniion.adapters.supabase_transport import SupabaseUnavailable
class Flaky(SupabaseAccess):
 down=False
 def logout(self,token,scope='local'):
  if self.down:raise SupabaseUnavailable()
  return super().logout(token,scope)
api=Flaky('http://127.0.0.1:54321','',local=True);clock=[time.time()]
with tempfile.TemporaryDirectory() as temp:
 folder=pathlib.Path(temp)
 def reopen():
  global app
  store=DurableSessionStore(api,folder/'db/state.sqlite3',folder/'keys/session.key',clock=lambda:clock[0])
  app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url}),api,store)
  return store
 store=reopen();c=Client();check('real_login',c.login(accounts[1])[0]==200)
 check('own_business_initial',resource(c,accounts[1])[0]==200)
 with store.lock:
  sid=c.cookie.split('=',1)[1];original=store.sessions[sid]['access_token'];store.sessions[sid]['expires_at']=0
 store=reopen();check('real_refresh_after_reload',c.call('/auth/session')[0]==200)
 check('own_business_after_real_refresh',resource(c,accounts[1])[0]==200)
 check('cross_org_denied_after_reload',resource(c,accounts[0])[0]==403)
 with store.lock:token=store.sessions[sid]['access_token']
 check('real_tokens_not_plaintext_on_disk',token.encode() not in (folder/'db/state.sqlite3').read_bytes())
 api.down=True
 status,_,headers=c.call('/auth/logout',{})
 check('provider_failure_reported',status==503)
 check('cookie_closed_despite_provider_failure','Max-Age=0' in headers.get('Set-Cookie',''))
 store=reopen()
 with store.lock:check('revocation_queue_survives_reload',len(store.pending)==1 and sid not in store.sessions)
 check('local_access_closed_during_provider_failure',resource(c,accounts[1])[0]==403)
 api.down=False;clock[0]+=31;store.maintain()
 with store.lock:check('retry_queue_drained',not store.pending)
 check('old_jwt_refused_by_direct_rest_after_retry',api.request('/rest/v1/uniion_resources?select=id&organization_id=eq.'+accounts[1]['org'],token)==[])
 check('logout_survives_second_reload',not Client().call('/auth/session')[1]['authenticated'])
out=ROOT/'preuves/S01-sessions-durables';out.mkdir(exist_ok=True)
(out/'integration.json').write_text(json.dumps({'checks':checks,'passed':True,'count':len(checks),'fault_injection':'Only the test transport logout raises temporary failure; Supabase services remain running.'},indent=2))
print(json.dumps({'passed':True,'count':len(checks)}))

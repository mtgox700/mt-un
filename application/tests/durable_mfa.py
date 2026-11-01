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
from fixture_mfa_setup import prepare
prepare();factor=None;token=None
with tempfile.TemporaryDirectory() as temp:
 folder=pathlib.Path(temp);store=DurableSessionStore(api,folder/'db/state.sqlite3',folder/'key/session.key')
 app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url}),api,store)
 try:
  c=Client();check('login',c.login(accounts[0])[0]==200)
  status,e,_=c.call('/auth/mfa/enroll',{'name':'Durable MFA fictif'});check('enrollment',status==200);factor=e['id'];secret=e['totp']['secret']
  status,ch,_=c.call('/auth/mfa/challenge',{'factor_id':factor});check('challenge',status==200)
  wrong=str((int(code(secret))+1)%1000000).zfill(6)
  check('wrong_totp_denied',c.call('/auth/mfa/verify',{'factor_id':factor,'challenge_id':ch['id'],'code':wrong})[0]==403)
  old_cookie=c.cookie
  status,state,_=c.call('/auth/mfa/verify',{'factor_id':factor,'challenge_id':ch['id'],'code':code(secret)})
  check('retry_valid_totp',status==200 and state.get('aal')=='aal2');token=c.state()['access_token']
  check('old_cookie_rotated',old_cookie!=c.cookie)
  check('old_cookie_business_denied',c.call('/api/organizations/'+accounts[0]['org']+'/resources/'+accounts[0]['resource'],HTTP_COOKIE=old_cookie)[0]==403)
  check('own_business_allowed',resource(c,accounts[0])[0]==200)
  check('cross_org_denied',resource(c,accounts[1])[0]==403)
  # Reopen encrypted state in another instance without changing the client cookie.
  store=DurableSessionStore(api,folder/'db/state.sqlite3',folder/'key/session.key')
  app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url}),api,store)
  check('verified_mfa_survives_reload',c.call('/auth/session')[1]['aal']=='aal2')
  check('own_business_after_reload',resource(c,accounts[0])[0]==200)
 finally:
  if factor and token:api.request('/auth/v1/factors/'+factor,token,method='DELETE')
  if token:
   try:c.call('/auth/logout',{})
   except Exception:pass
proof={'checks':checks,'passed':True,'count':len(checks),'totp_secret_persisted':False}
(ROOT/'preuves/S01-resilience/mfa.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({'passed':True,'count':len(checks)}))

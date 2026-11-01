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
from fixture_mfa_setup import prepare
prepare()
try:
 c=Client();check('login',c.login(accounts[0])[0]==200)
 status,e,_=c.call('/auth/mfa/enroll',{'name':'Principal fictif'});check('primary_enroll',status==200);primary=e['id'];factors.append(primary)
 (status,_,_),_=verify(c,primary,e['totp']['secret']);check('primary_verified',status==200);cleanup_token=c.state()['access_token']
 status,e,_=c.call('/auth/mfa/enroll',{'name':'Secours fictif'});check('backup_enroll',status==200);backup=e['id'];factors.append(backup);secret=e['totp']['secret']
 (status,_,_),_=verify(c,backup,secret);check('backup_verified',status==200);cleanup_token=c.state()['access_token']
 check('two_verified_factors',len([f for f in c.call('/auth/session')[1]['factors'] if f['status']=='verified'])==2)
 fresh=Client();check('new_password_login',fresh.login(accounts[0])[0]==200)
 check('password_alone_denied',resource(fresh,accounts[0])[0]==403)
 time.sleep(30-time.time()%30+.2)
 (status,_,_),_=verify(fresh,backup,secret);check('backup_allows_aal2',status==200);cleanup_token=fresh.state()['access_token']
 check('backup_own_business',resource(fresh,accounts[0])[0]==200)
 check('backup_cross_org_denied',resource(fresh,accounts[1])[0]==403)
 check('primary_removal_with_backup',fresh.call('/auth/mfa/remove',{'factor_id':primary})[0]==200);factors.remove(primary)
 check('last_backup_removal_denied',fresh.call('/auth/mfa/remove',{'factor_id':backup})[0]==403)
 check('removed_primary_challenge_denied',fresh.call('/auth/mfa/challenge',{'factor_id':primary})[0]==403)
finally:
 for f in factors:
  if cleanup_token:
   try:api.request('/auth/v1/factors/'+f,cleanup_token,method='DELETE')
   except Exception:print('Facteur fictif à vérifier ; aucun secret affiché.')
 for session in list(app.sessions.sessions.values()):
  if session.get('access_token'):
   try:api.logout(session['access_token'])
   except Exception:pass
proof={'checks':checks,'count':len(checks),'passed':all(c['ok'] for c in checks),'secrets_persisted':False}
(ROOT/'preuves/S01-finalisation/backup-factor.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({'passed':proof['passed'],'count':len(checks)}))

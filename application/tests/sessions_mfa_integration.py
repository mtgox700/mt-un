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
 c=Client();anonymous=c.cookie
 check('anonymous_business_denied',resource(c,accounts[0])[0]==403)
 check('csrf_login_denied',c.call('/auth/login',{'email':accounts[0]['email'],'password':accounts[0]['password']},HTTP_X_UNIION_CSRF='')[0]==403)
 check('foreign_origin_denied',c.call('/auth/login',{'email':accounts[0]['email'],'password':accounts[0]['password']},HTTP_ORIGIN='https://invalid.example')[0]==403)
 check('wrong_password_denied',c.call('/auth/login',{'email':accounts[0]['email'],'password':'incorrect'})[0]==403)
 status,state,headers=c.login(accounts[0]);check('password_login',status==200)
 check('opaque_cookie_flags','HttpOnly' in headers['Set-Cookie'] and 'SameSite=Strict' in headers['Set-Cookie'])
 check('login_rotates_cookie',anonymous!=c.cookie)
 check('tokens_not_exposed',not any(k in state for k in ('access_token','refresh_token')))
 s=c.state();old_access=s['access_token'];old_refresh=s['refresh_token']
 check('bearer_bypass_denied',resource(c,accounts[1])[0]==403 and c.call('/health',HTTP_AUTHORIZATION='Bearer '+old_access)[0]==403)
 status,enrollment,_=c.call('/auth/mfa/enroll',{'name':'Recette S01 TOTP'});check('totp_enrollment',status==200)
 factor=enrollment['id'];secret=enrollment['totp']['secret'];factors.append(factor)
 check('totp_secret_not_in_session_store',secret not in json.dumps(app.sessions.sessions))
 status,challenge,_=c.call('/auth/mfa/challenge',{'factor_id':factor});check('initial_challenge',status==200)
 incorrect=str((int(code(secret))+1)%1000000).zfill(6)
 check('invalid_totp_denied',c.call('/auth/mfa/verify',{'factor_id':factor,'challenge_id':challenge['id'],'code':incorrect})[0]==403)
 old_cookie=c.cookie
 status,mfa,_=c.call('/auth/mfa/verify',{'factor_id':factor,'challenge_id':challenge['id'],'code':code(secret)})
 check('valid_totp_aal2',status==200 and mfa.get('aal')=='aal2' and mfa.get('business_allowed'))
 cleanup_token=c.state()['access_token'];check('mfa_rotates_cookie',old_cookie!=c.cookie)
 check('replayed_challenge_denied',c.call('/auth/mfa/verify',{'factor_id':factor,'challenge_id':challenge['id'],'code':code(secret)})[0]==403)
 check('own_resource_aal2',resource(c,accounts[0])[0]==200)
 check('other_organization_aal2_denied',resource(c,accounts[1])[0]==403)
 check('direct_rest_aal2',len(api.resources(cleanup_token,accounts[0]['org']))==1)
 # Fresh password-only session must not bypass MFA through direct REST or the BFF.
 low=Client();check('second_password_login',low.login(accounts[0])[0]==200)
 check('aal1_mfa_required',low.call('/auth/session')[1]['mfa_required'])
 check('aal1_business_denied',resource(low,accounts[0])[0]==403)
 low_token=low.state()['access_token']
 check('direct_rest_aal1_empty',api.resources(low_token,accounts[0]['org'])==[])
 context=api.request('/rest/v1/rpc/uniion_context',low_token,{})
 check('rpc_context_aal1_empty',context['organizations']==[])
 check('challenge_not_bound_to_other_session',low.call('/auth/mfa/verify',{'factor_id':factor,'challenge_id':challenge['id'],'code':code(secret)})[0]==403)
 check('aal1_cannot_add_factor',low.call('/auth/mfa/enroll',{'name':'Interdit'})[0]==403)
 # A fresh timestep proves a real second login, not just enrollment.
 time.sleep(30-time.time()%30+0.2)
 (status,second,_),_=verify(low,factor,secret)
 check('second_login_totp_aal2',status==200 and second.get('aal')=='aal2')
 check('second_login_business_authorized',resource(low,accounts[0])[0]==200)
 other=Client();check('other_user_login',other.login(accounts[1])[0]==200)
 check('other_users_factor_denied',other.call('/auth/mfa/challenge',{'factor_id':factor})[0]==403)
 check('last_verified_factor_cannot_be_removed',c.call('/auth/mfa/remove',{'factor_id':factor})[0]==403)
 # Exercise actual renewal without waiting for an hour.
 c.state()['expires_at']=0
 status,state,_=c.call('/auth/session');check('real_refresh_preserves_aal2',status==200 and state['aal']=='aal2');cleanup_token=c.state()['access_token']
 # Remove this test factor directly using its own verified Auth session only.
 # The sticky requirement remains: unenrolling cannot restore password-only business access.
 api.request('/auth/v1/factors/'+factor,cleanup_token,method='DELETE');factors.remove(factor)
 check('requirement_survives_factor_removal',api.request('/rest/v1/rpc/uniion_session_status',low_token,{})['required'])
 check('removed_factor_no_aal1_bypass',api.resources(low_token,accounts[0]['org'])==[])
 # Replay proof after logout, even with the old JWT which has not expired cryptographically.
 active=c.state()['access_token'];refresh=c.state()['refresh_token'];cookie=c.cookie
 c.state()['expires_at']=0
 status,_,headers=c.call('/auth/logout',{});check('logout_cookie_expired',status==200 and 'Max-Age=0' in headers['Set-Cookie'])
 check('logged_out_cookie_refused',c.call('/api/organizations/'+accounts[0]['org']+'/resources/'+accounts[0]['resource'],HTTP_COOKIE=cookie)[0]==403)
 try:api.request('/auth/v1/token?grant_type=refresh_token',body={'refresh_token':refresh});rejected=False
 except AccessDenied:rejected=True
 check('logout_refresh_revoked',rejected)
 check('logout_old_jwt_rest_denied',api.request('/rest/v1/uniion_resources?select=id&organization_id=eq.'+accounts[0]['org'],active)==[])
 check('other_user_session_preserved',resource(other,accounts[1])[0]==200)
 low.call('/auth/logout',{});other.call('/auth/logout',{})
finally:
 # No users, business records, backups or original data are deleted.
 # Revoke only test-created authentication factors with the test user's own session.
 for f in factors:
  token=cleanup_token or (c.state() or {}).get('access_token')
  if token:
   try:api.request('/auth/v1/factors/'+f,token,method='DELETE')
   except Exception:print('Nettoyage du facteur de recette à vérifier ; aucun secret affiché.')
 for session in list(app.sessions.sessions.values()):
  if session.get('access_token'):
   try:api.logout(session['access_token'])
   except Exception:pass
proof={'checks':checks,'count':len(checks),'passed':all(c['ok'] for c in checks),'totp_secret_persisted':False,'business_records_deleted':False}
(ROOT/'preuves/S01-sessions-mfa/integration.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({'passed':proof['passed'],'count':len(checks)}))

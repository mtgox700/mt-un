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
import subprocess,uuid
user,operator=accounts;created=[];operator_token=None;user_token=None
uid=str(uuid.UUID(operator['id']))
def operator_active(active):
 q=f"INSERT INTO uniion_private.platform_operators(user_id,active) VALUES('{uid}',{str(active).lower()}) ON CONFLICT(user_id) DO UPDATE SET active=excluded.active;"
 p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if p.returncode:raise RuntimeError('Fictional operator setup failed')
from fixture_mfa_setup import prepare
prepare()
try:
 initial=Client();check('initial_owner_login',initial.login(user)[0]==200)
 status,first,_=initial.call('/auth/mfa/enroll',{'name':'Appareil perdu fictif'});check('existing_lost_factor_enrolled',status==200);created.append(('user',first['id']))
 (status,_,_),_=verify(initial,first['id'],first['totp']['secret']);check('existing_lost_factor_verified',status==200);user_token=initial.state()['access_token']
 c=Client();review=Client();check('requester_login',c.login(user)[0]==200);check('reviewer_login',review.login(operator)[0]==200)
 status,e,_=review.call('/auth/mfa/enroll',{'name':'Opérateur fictif'});check('reviewer_factor_enrolled',status==200);of=e['id'];created.append(('operator',of))
 (status,_,_),_=verify(review,of,e['totp']['secret']);check('reviewer_mfa_verified',status==200);operator_token=review.state()['access_token']
 status,e,_=c.call('/auth/mfa/recovery/enroll',{})
 check('lost_registered_factor_fails_closed_pending_privileged_adapter',status==403)
 # Test-only owner still holds its original verified session; no support bypass.
 api.request('/auth/v1/factors/'+first['id'],user_token,method='DELETE');created.remove(('user',first['id']))
 status,e,_=c.call('/auth/mfa/recovery/enroll',{});check('request_requires_human_approval',status==200 and e['request']['approval_required']);rf=e['id'];created.append(('user',rf));secret=e['totp']['secret'];rid=e['request']['id']
 payload={'request_id':rid,'verification_reference':'RECETTE IDENTITE S01 - fictif'}
 check('self_approval_refused',c.call('/auth/mfa/recovery/approve',payload)[0]==403)
 check('ordinary_mfa_user_cannot_approve',review.call('/auth/mfa/recovery/approve',payload)[0]==403)
 check('pending_request_business_denied',resource(c,user)[0]==403)
 operator_active(True)
 low=Client();check('operator_aal1_login',low.login(operator)[0]==200)
 check('operator_aal1_approval_refused',low.call('/auth/mfa/recovery/approve',payload)[0]==403)
 check('missing_verification_reference_refused',review.call('/auth/mfa/recovery/approve',{'request_id':rid,'verification_reference':''})[0]==403)
 check('designated_operator_approval',review.call('/auth/mfa/recovery/approve',payload)[0]==200)
 check('approval_single_use',review.call('/auth/mfa/recovery/approve',payload)[0]==403)
 check('old_requester_session_closed',c.call('/auth/session')[0]==403)
 recovered=Client();check('fresh_login_required',recovered.login(user)[0]==200)
 check('approval_alone_not_business_access',resource(recovered,user)[0]==403)
 (status,_,_),_=verify(recovered,rf,secret);check('approved_new_factor_verified',status==200);user_token=recovered.state()['access_token']
 check('recovered_own_resource_authorized',resource(recovered,user)[0]==200)
 check('recovered_cross_org_denied',resource(recovered,operator)[0]==403)
 check('platform_operator_has_no_implicit_business_access',resource(review,user)[0]==403)
 operator_active(False)
 check('revoked_operator_refused',review.call('/auth/mfa/recovery/approve',payload)[0]==403)
finally:
 operator_active(False)
 for owner,f in created:
  token=operator_token if owner=='operator' else user_token or (c.state() or {}).get('access_token')
  if token:
   try:api.request('/auth/v1/factors/'+f,token,method='DELETE')
   except Exception:print('Facteur fictif à vérifier ; aucun secret affiché.')
 for session in list(app.sessions.sessions.values()):
  if session.get('access_token'):
   try:api.logout(session['access_token'])
   except Exception:pass
 # Return only the designated no-MFA fixture to its prior policy, never real users.
 q=f"UPDATE uniion_private.mfa_requirements SET required=false WHERE user_id='{uid}' AND NOT EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id='{uid}' AND status='verified');"
 subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True,check=True)
proof={'checks':checks,'count':len(checks),'passed':all(c['ok'] for c in checks),'fictional_operator_revoked':True,'limitation':'Lost device with factor still registered is refused; privileged Auth adapter remains required. Successful recovery here starts after owner-authorized test factor removal.'}
(ROOT/'preuves/S01-identite/assisted-mfa.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({'passed':proof['passed'],'count':len(checks)}))

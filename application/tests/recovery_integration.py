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
# Only dedicated fictional account mail is read; tokens never enter proof output.
import urllib.request,urllib.parse,secrets,os
from html.parser import HTMLParser
class Links(HTMLParser):
 def __init__(self):super().__init__();self.urls=[]
 def handle_starttag(self,tag,attrs):
  if tag=='a':self.urls.extend(v for k,v in attrs if k=='href')
def get(url):
 with urllib.request.urlopen(url,timeout=10) as response:return json.load(response)
def recovery_hash(a):
 messages=get('http://127.0.0.1:54324/api/v1/search?query='+urllib.parse.quote('to:'+a['email']))['messages']
 for message in messages:
  body=get('http://127.0.0.1:54324/api/v1/message/'+message['ID']);parser=Links();parser.feed(body.get('HTML',''))
  for link in parser.urls:
   u=urllib.parse.urlsplit(link);q=urllib.parse.parse_qs(u.query)
   if u.hostname in ('localhost','127.0.0.1') and u.port in (3000,54321) and q.get('type')==['recovery']:return (q.get('token_hash') or q.get('token'))[0]
 raise AssertionError('Recovery mail missing')
try:
 a=accounts[1];c=Client();old=Client();check('existing_login',old.login(a)[0]==200);old_token=old.state()['access_token'];old_password=a['password']
 check('ordinary_session_cannot_reset_password',old.call('/auth/password',{'password':'unacceptable-example'})[0]==403)
 check('request_recovery',c.call('/auth/recovery/request',{'email':a['email']})[0]==200)
 token=recovery_hash(a)
 check('invalid_recovery_denied',c.call('/auth/recovery/verify',{'token_hash':'invalid'*8})[0]==403)
 previous=c.cookie;status,d,_=c.call('/auth/recovery/verify',{'token_hash':token})
 check('email_recovery_verified',status==200 and d.get('authenticated'))
 check('recovery_cookie_rotated',c.cookie!=previous)
 replay=Client();check('recovery_token_single_use',replay.call('/auth/recovery/verify',{'token_hash':token})[0]==403)
 check('short_password_denied',c.call('/auth/password',{'password':'short'})[0]==403)
 new_password=secrets.token_urlsafe(32)
 status,_,headers=c.call('/auth/password',{'password':new_password})
 check('password_updated_and_cookie_closed',status==200 and 'Max-Age=0' in headers.get('Set-Cookie',''))
 # Persist only this fictional credential after successful update, never in logs.
 a['password']=new_password;target=ROOT/'.local-auth/sessions-fixtures.json';temp=target.with_suffix('.tmp')
 fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
 with os.fdopen(fd,'w') as output:json.dump(accounts,output)
 os.replace(temp,target)
 check('all_previous_sessions_revoked',api.request('/rest/v1/uniion_resources?select=id&organization_id=eq.'+a['org'],old_token)==[])
 fresh=Client();check('new_password_accepted',fresh.login(a)[0]==200)
 wrong=Client();check('old_password_refused',wrong.call('/auth/login',{'email':a['email'],'password':old_password})[0]==403)
 check('recovered_own_access',resource(fresh,a)[0]==200)
 check('recovered_cross_org_denied',resource(fresh,accounts[0])[0]==403)
 # Email possession must never remove an existing MFA requirement.
 strong=Client();check('mfa_account_recovery_requested',strong.call('/auth/recovery/request',{'email':accounts[0]['email']})[0]==200)
 status,d,_=strong.call('/auth/recovery/verify',{'token_hash':recovery_hash(accounts[0])})
 check('recovery_preserves_mfa_requirement',status==200 and d.get('mfa_required') and not d.get('business_allowed'))
 check('recovery_cannot_replace_missing_mfa',strong.call('/auth/mfa/enroll',{'name':'Interdit'})[0]==403)
 check('recovery_without_mfa_business_denied',resource(strong,accounts[0])[0]==403)
 check('recovery_without_mfa_password_denied',strong.call('/auth/password',{'password':secrets.token_urlsafe(32)})[0]==403)
 check('recovery_without_mfa_direct_rest_denied',api.resources(strong.state()['access_token'],accounts[0]['org'])==[])
finally:
 for session in list(app.sessions.sessions.values()):
  if session.get('access_token'):
   try:api.logout(session['access_token'])
   except Exception:pass
proof={'checks':checks,'count':len(checks),'passed':all(c['ok'] for c in checks),'local_fictional_mail_only':True}
(ROOT/'preuves/S01-finalisation/recovery.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({'passed':proof['passed'],'count':len(checks)}))

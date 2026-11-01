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
import uuid,subprocess
from fixture_mfa_setup import prepare
prepare();org=str(uuid.uuid4());a,b=accounts
# Isolated fictional organization: no pre-existing rights are changed.
q=f"""BEGIN;
INSERT INTO public.uniion_organizations VALUES('{org}','Recette invitations S01',true);
INSERT INTO public.uniion_memberships VALUES('{org}','{a['id']}',now()-interval '1 day',null);
INSERT INTO public.uniion_authorities VALUES('{org}','{a['id']}','rights',false);
COMMIT;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Fictional organization preparation failed')
def invite(c,email=b['email'],organization=org):return c.call('/identity/invitations/create',{'organization_id':organization,'email':email})
try:
 admin=Client();member=Client();check('admin_password_login',admin.login(a)[0]==200);check('member_login',member.login(b)[0]==200)
 check('admin_aal1_invitation_refused',invite(admin)[0]==403)
 status,e,_=admin.call('/auth/mfa/enroll',{'name':'Invitations fictives'});check('admin_enrollment',status==200);f=e['id'];factors.append(f)
 (status,_,_),_=verify(admin,f,e['totp']['secret']);check('admin_aal2',status==200);cleanup_token=admin.state()['access_token']
 check('unprivileged_invitation_refused',invite(member)[0]==403)
 check('other_org_admin_refused',invite(admin,organization=b['org'])[0]==403)
 check('self_escalation_fields_refused',admin.call('/identity/invitations/create',{'organization_id':org,'email':b['email'],'role':'superadmin'})[0]==403)
 status,ticket,_=invite(admin);check('authorized_invitation',status==200);token=ticket['token']
 check('wrong_email_holder_refused',admin.call('/identity/invitations/accept',{'token':token})[0]==403)
 check('invalid_token_refused',member.call('/identity/invitations/accept',{'token':'0'*64})[0]==403)
 check('revocation_wrong_org_refused',admin.call('/identity/invitations/revoke',{'organization_id':b['org'],'invitation_id':ticket['id']})[0]==403)
 check('pending_invitation_revoked',admin.call('/identity/invitations/revoke',{'organization_id':org,'invitation_id':ticket['id']})[0]==200)
 check('revoked_invitation_refused',member.call('/identity/invitations/accept',{'token':token})[0]==403)
 status,ticket,_=invite(admin);check('replacement_invitation',status==200)
 status,result,_=member.call('/identity/invitations/accept',{'token':ticket['token']});check('matching_verified_email_accepted',status==200 and result.get('business_rights_granted') is False)
 check('invitation_single_use',member.call('/identity/invitations/accept',{'token':ticket['token']})[0]==403)
 mt=member.state()['access_token'];context=api.request('/rest/v1/rpc/uniion_context',mt,{})
 check('multi_org_membership_visible',org in json.dumps(context) and b['org'] in json.dumps(context))
 check('no_automatic_business_access',api.resources(mt,org)==[])
 check('original_org_access_preserved',resource(member,b)[0]==200)
 check('other_org_resource_refused',resource(member,a)[0]==403)
 check('self_revocation_refused',admin.call('/identity/memberships/revoke',{'organization_id':org,'user_id':a['id']})[0]==403)
 check('unprivileged_revocation_refused',member.call('/identity/memberships/revoke',{'organization_id':org,'user_id':a['id']})[0]==403)
 check('membership_revoked',admin.call('/identity/memberships/revoke',{'organization_id':org,'user_id':b['id']})[0]==200)
 check('revoked_org_disappears_direct_rpc',org not in json.dumps(api.request('/rest/v1/rpc/uniion_context',mt,{})))
 check('other_membership_preserved_after_revocation',resource(member,b)[0]==200)
 check('revoked_membership_cannot_silently_rejoin',invite(admin)[0]==403)
 try:api.request('/rest/v1/rpc/uniion_invite_create',mt,{'p_org':org,'p_email':a['email']});denied=False
 except AccessDenied:denied=True
 check('direct_rpc_without_rights_refused',denied)
 # Direct Auth may verify an unapproved replacement; SQL must still deny business.
 api.request('/auth/v1/factors/'+f,cleanup_token,method='DELETE');factors.remove(f)
 low=Client();check('lost_factor_password_login',low.login(a)[0]==200)
 check('missing_factor_app_reenrollment_refused',low.call('/auth/mfa/enroll',{'name':'Interdit'})[0]==403)
 lt=low.state()['access_token'];new=api.request('/auth/v1/factors',lt,{'factor_type':'totp','friendly_name':'Contournement fictif'});f=new['id'];factors.append(f)
 ch=api.request('/auth/v1/factors/'+f+'/challenge',lt,{})
 high=api.request('/auth/v1/factors/'+f+'/verify',lt,{'challenge_id':ch['id'],'code':code(new['totp']['secret'])});cleanup_token=high['access_token']
 check('direct_unapproved_aal2_denied',not api.request('/rest/v1/rpc/uniion_session_status',cleanup_token,{})['allowed'])
 check('direct_unapproved_aal2_resources_empty',api.request('/rest/v1/uniion_resources?select=id&organization_id=eq.'+a['org'],cleanup_token)==[])
 try:api.request('/rest/v1/rpc/uniion_require_mfa',cleanup_token,{});denied=False
 except AccessDenied:denied=True
 check('unapproved_factor_cannot_self_approve',denied)
finally:
 for f in factors:
  if cleanup_token:
   try:api.request('/auth/v1/factors/'+f,cleanup_token,method='DELETE')
   except Exception:print('Facteur fictif à vérifier ; aucun secret affiché.')
 for session in list(app.sessions.sessions.values()):
  if session.get('access_token'):
   try:api.logout(session['access_token'])
   except Exception:pass
proof={'checks':checks,'count':len(checks),'passed':all(c['ok'] for c in checks),'fictional_org':org,'business_data_deleted':False}
out=ROOT/'preuves/S02-invitations-s01';out.mkdir(exist_ok=True)
(out/'integration.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({'passed':proof['passed'],'count':len(checks)}))

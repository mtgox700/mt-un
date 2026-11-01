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
import uuid,subprocess,datetime
from fixture_mfa_setup import prepare
prepare();a,b=accounts
reader=json.loads((ROOT.parent/'prototype-evolution/organisation-droits-partage/.local-auth/accounts.json').read_text())[2]
o1,o2,res=[str(uuid.uuid4()) for _ in range(3)]
def sql(q):
 p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if p.returncode:raise RuntimeError('Fictional SQL setup failed')
q=['begin;']
for org,owner in [(o1,a),(o2,b)]:
 q += [f"insert into public.uniion_organizations values('{org}','Recette administration MFA',true);",f"insert into public.uniion_memberships values('{org}','{owner['id']}',now()-interval '1 day',null);",f"insert into public.uniion_module_access values('{org}','socle',true,true,'included',now()+interval '1 day');",f"insert into public.uniion_permissions values('{org}','{owner['id']}','socle','read');"]
q += [f"insert into public.uniion_memberships values('{o2}','{reader['id']}',now()-interval '1 day',null);",f"insert into public.uniion_permissions values('{o2}','{reader['id']}','socle','read');",f"insert into public.uniion_memberships values('{o1}','{b['id']}',now()-interval '1 day',null);",f"insert into public.uniion_partners values('{o1}','{o2}'),('{o2}','{o1}');",f"insert into public.uniion_resources(id,organization_id,module,title,body,kind,client_id,external_share_allowed) values('{res}','{o1}','socle','Dossier fictif administration','{{}}','dossiers','s01-admin',true);",f"insert into public.uniion_resource_grants values('{o1}','{res}','{a['id']}',false,false,now()+interval '1 day',null);"]
for org,owner,perms in [(o1,a,['rights','share','download']),(o2,b,['rights','accept'])]:
 for perm in perms:q.append(f"insert into public.uniion_authorities values('{org}','{owner['id']}','{perm}',false);")
sql('\n'.join(q+['commit;']))
until=(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(hours=1)).isoformat()
rights={'p_org':o1,'p_user':b['id'],'p_type':'permission','p_module':'socle','p_permission':'read','p_enabled':True}
create={'p_org':o1,'p_target':o2,'p_resources':[res],'p_people':[reader['id']],'p_until':until,'p_download':False,'p_versions':{res:1},'p_attachments':[]}
consent={'p_org':o1,'p_target':o2,'p_grantee':reader['id'],'p_people':[a['id']],'p_until':until}
def rpc(c,name,data):return api.request('/rest/v1/rpc/uniion_'+name,c.state()['access_token'],data)
def denied(c,name,data):
 try:rpc(c,name,data);return False
 except AccessDenied:return True
created=[];tokens={}
try:
 ca,cb,cr=Client(),Client(),Client()
 check('admin_a_login',ca.login(a)[0]==200);check('admin_b_login',cb.login(b)[0]==200);check('reader_login',cr.login(reader)[0]==200)
 calls={'rights_change':rights,'rights_batch':{'p_org':o1,'p_user':b['id'],'p_changes':[]},'share_create':create,'share_accept':{'p_org':o2,'p_share':str(uuid.uuid4()),'p_people':[reader['id']]},'share_revoke':{'p_org':o1,'p_share':str(uuid.uuid4())},'directory_authorize':consent,'admin_context':{'p_org':o1}}
 for name,data in calls.items():check('aal1_denied_'+name,denied(cb if name=='share_accept' else ca,name,data))
 for c,who in [(ca,'a'),(cb,'b')]:
  status,e,_=c.call('/auth/mfa/enroll',{'name':'Administration fictive '+who});check('enroll_'+who,status==200);created.append((who,e['id']))
  (status,_,_),_=verify(c,e['id'],e['totp']['secret']);check('aal2_'+who,status==200);tokens[who]=c.state()['access_token']
 check('aal2_rights_change',rpc(ca,'rights_change',rights)['ok'])
 check('aal2_rights_batch',rpc(ca,'rights_batch',{'p_org':o1,'p_user':b['id'],'p_changes':[{'type':'permission','module':'socle','permission':'read','enabled':False}]})['ok'])
 check('aal2_admin_context',isinstance(rpc(ca,'admin_context',{'p_org':o1}),dict))
 check('aal2_wrong_org_context_denied',denied(ca,'admin_context',{'p_org':o2}))
 check('aal2_no_self_escalation',denied(ca,'rights_change',{**rights,'p_user':a['id']}))
 check('aal2_directory_consent',rpc(ca,'directory_authorize',consent)['ok'])
 sid=rpc(ca,'share_create',create);check('aal2_share_created',isinstance(sid,str))
 check('aal2_share_accepted',rpc(cb,'share_accept',{'p_org':o2,'p_share':sid,'p_people':[reader['id']]})['ok'])
 check('ordinary_reader_remains_aal1',cr.call('/auth/session')[1]['aal']=='aal1')
 check('ordinary_reader_shared_read_allowed',isinstance(rpc(cr,'shared_read',{'p_org':o2,'p_share':sid,'p_resource':res}),dict))
 check('ordinary_reader_admin_context_denied',denied(cr,'admin_context',{'p_org':o2}))
 check('aal2_share_revoked',rpc(ca,'share_revoke',{'p_org':o1,'p_share':sid})['ok'])
 check('reader_denied_after_share_revocation',denied(cr,'shared_read',{'p_org':o2,'p_share':sid,'p_resource':res}))
 check('ordinary_reader_no_cross_org_direct_read',api.resources(cr.state()['access_token'],o1)==[])
finally:
 for who,f in created:
  if who in tokens:
   try:api.request('/auth/v1/factors/'+f,tokens[who],method='DELETE')
   except Exception:print('Facteur fictif à vérifier ; aucun secret affiché.')
 for session in list(app.sessions.sessions.values()):
  if session.get('access_token'):
   try:api.logout(session['access_token'])
   except Exception:pass
 sql(f"update uniion_private.mfa_requirements set required=false where user_id='{b['id']}' and not exists(select 1 from auth.mfa_factors where user_id='{b['id']}' and status='verified');")
proof={'checks':checks,'passed':True,'count':len(checks),'fictional_organizations':[o1,o2],'business_data_deleted':False}
(ROOT/'preuves/S01-administration/integration.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({'passed':True,'count':len(checks)}))

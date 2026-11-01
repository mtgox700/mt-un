"""S08 A real local Auth/MFA/RPC/WSGI. Provider is fake except explicit --codex."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
import uuid,subprocess,threading,os
from uniion.adapters.ai_gateway import AIGateway
out=ROOT/'preuves/S08-A';out.mkdir(exist_ok=True)
def sql(q):
 p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if p.returncode:raise RuntimeError(p.stderr.decode())
 return p.stdout.decode().strip()
def new_account():
 account={'email':'s08-'+uuid.uuid4().hex+'@uniion-local.example','password':uuid.uuid4().hex+'aA1!'}
 u=api.request('/auth/v1/signup',body=account);account['id']=u.get('user',u)['id']
 sql(f"update auth.users set email_confirmed_at=coalesce(email_confirmed_at,now()) where id='{account['id']}'")
 return account
a,b,admin=new_account(),new_account(),new_account()
org,foreign=str(uuid.uuid4()),str(uuid.uuid4())
sql(f"""begin;
insert into public.uniion_organizations values('{org}','S08 — recette fictive IA',true),('{foreign}','S08 — autre organisation fictive',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null),('{foreign}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_authorities values('{org}','{a['id']}','organization_edit',false);
insert into public.uniion_module_access values('{org}','assistant',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','assistant','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions values('{org}','{a['id']}','assistant','read'),('{org}','{a['id']}','assistant','write'),('{org}','{b['id']}','assistant','read');
insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Membre'),('{org}','{b['id']}','Alex Recette','Membre');
insert into uniion_private.super_admins values('{admin['id']}',true);
commit;""")
x,y,z=Client(),Client(),Client()
check('author_login',x.login(a)[0]==200)
st,af,_=x.call('/auth/mfa/enroll',{'name':'Recette S08 auteur'});check('author_enroll',st==200);verify(x,af['id'],af['totp']['secret'])
check('reader_login',y.login(b)[0]==200)
st,bf,_=y.call('/auth/mfa/enroll',{'name':'Recette S08 lecteur'});check('reader_enroll',st==200);verify(y,bf['id'],bf['totp']['secret'])
f={'factor':af['id'],'secret':af['totp']['secret']}
check('platform_login',z.login(admin)[0]==200)
def call(c,path,data):
 app.sessions.clock=lambda:time.time()+len(checks)*61
 return c.call(path,data)
def policy(c,action,payload=None,o=org):return call(c,'/identity/ai',{'organization_id':o,'action':action,'payload':payload or {}})
def generate(c,**extra):return call(c,'/identity/ai/generate',{'organization_id':org,'request_id':str(uuid.uuid4()),'fixture':'connection',**extra})
check('aal1_denied',policy(z,'status')[0]==403)
st,fac,_=z.call('/auth/mfa/enroll',{'name':'Recette S08'});check('platform_enroll',st==200);verify(z,fac['id'],fac['totp']['secret'])
check('anonymous_denied',generate(Client())[0]==403)
check('foreign_organization_denied',generate(x,organization_id=foreign)[0]==403)
p=policy(z,'status')[1]
check('initial_revoke',policy(z,'approve',{'enabled':False,'version':p['providerVersion']})[0]==200)
check('before_approval_denied',generate(x)[0]==403)
p=policy(z,'status')[1]
check('org_admin_cannot_approve',policy(x,'approve',{'enabled':True,'version':p['providerVersion']})[0]==403)
check('platform_approval',policy(z,'approve',{'enabled':True,'version':p['providerVersion']})[0]==200)
p=policy(x,'status')[1]
check('before_activation_denied',generate(x)[0]==403)
check('platform_no_implicit_activation',policy(z,'activate',{'enabled':True,'version':0,'providerVersion':p['providerVersion']})[0]==403)
check('org_activation',policy(x,'activate',{'enabled':True,'version':0,'providerVersion':p['providerVersion']})[0]==200)
class Fake:
 calls=0
 effect=lambda self:None
 def complete(self,q,sources,cancelled):self.calls+=1;self.effect();return 'FICTIF_OK'
fake=Fake();app.ai_gateway.provider_factory=lambda:fake
check('write_permission_denied',generate(y)[0]==403)
check('platform_no_business_access',generate(z)[0]==403)
check('server_question_only',generate(x,question='Donnée interdite')[0]==403)
check('unknown_fixture_denied',generate(x,fixture='arbitrary')[0]==403)
check('no_provider_on_denials',fake.calls==0)
check('csrf_denied',x.call('/identity/ai/generate',{'organization_id':org,'request_id':str(uuid.uuid4()),'fixture':'connection'},HTTP_X_UNIION_CSRF='wrong')[0]==403)
check('origin_denied',x.call('/identity/ai/generate',{'organization_id':org,'request_id':str(uuid.uuid4()),'fixture':'connection'},HTTP_ORIGIN='https://example.invalid')[0]==403)
check('bearer_bypass_denied',x.call('/identity/ai/generate',{},HTTP_AUTHORIZATION='Bearer fake')[0]==403)
check('success',generate(x)[1].get('text')=='FICTIF_OK')
rid=str(uuid.uuid4());check('first_request',generate(x,request_id=rid)[0]==200);before=fake.calls
check('duplicate_request_refused',generate(x,request_id=rid)[0]==403 and fake.calls==before)
def denied(fn):
 try:fn();return False
 except AccessDenied:return True
check('direct_rpc_without_write_denied',denied(lambda:api.request('/rest/v1/rpc/uniion_ai_policy',y.state()['access_token'],{'p_org':org,'p_action':'authorize','p_payload':{}})))
check('private_provider_table_hidden',denied(lambda:api.request('/rest/v1/ai_providers?select=*',x.state()['access_token'])))
check('private_activation_table_hidden',denied(lambda:api.request('/rest/v1/ai_activations?select=*',x.state()['access_token'])))
for field,value,restore in [('enabled','false','true'),('authorized','false','true'),('valid_until',"now()-interval '1 second'","now()+interval '10 days'")]:
 sql(f"update public.uniion_module_access set {field}={value} where organization_id='{org}' and module='assistant'")
 check('module_'+field+'_denied',generate(x)[0]==403)
 sql(f"update public.uniion_module_access set {field}={restore} where organization_id='{org}' and module='assistant'")
sql(f"update uniion_private.module_entitlements set ends=now()-interval '1 second' where organization_id='{org}'")
check('commercial_expired_denied',generate(x)[0]==403)
sql(f"update uniion_private.module_entitlements set ends=now()+interval '10 days' where organization_id='{org}'")
sql(f"insert into uniion_private.membership_suspensions values('{org}','{a['id']}',true)")
check('suspended_denied',generate(x)[0]==403)
sql(f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}'")
p=policy(z,'status')[1];check('reapprove',policy(z,'approve',{'enabled':True,'version':p['providerVersion']})[0]==200)
check('new_approval_invalidates_activation',generate(x)[0]==403)
p=policy(x,'status')[1]
check('old_version_denied',policy(x,'activate',{'enabled':True,'version':0,'providerVersion':p['providerVersion']})[0]==403)
check('reactivate',policy(x,'activate',{'enabled':True,'version':p['activationVersion'],'providerVersion':p['providerVersion']})[0]==200)
# Concurrent HTTP cancellation must work while the provider is blocked.
started=threading.Event();finish=threading.Event();result=[]
def hold():started.set();finish.wait(10)
fake.effect=hold;rid=str(uuid.uuid4())
t=threading.Thread(target=lambda:result.append(generate(x,request_id=rid)));t.start();check('started',started.wait(5))
check('cancel_route',call(x,'/identity/ai/cancel',{'organization_id':org,'request_id':rid})[0]==200);finish.set();t.join(10)
check('cancel_discards_response',not t.is_alive() and result[0][0]==403 and 'FICTIF_OK' not in json.dumps(result[0]))
fake.effect=lambda:sql(f"update uniion_private.ai_activations set enabled=false,version=version+1 where organization_id='{org}'")
check('revoked_during_generation',generate(x)[0]==403)
p=policy(x,'status')[1];check('activation_restored',policy(x,'activate',{'enabled':True,'version':p['activationVersion'],'providerVersion':p['providerVersion']})[0]==200)
fake.effect=lambda:None
# Logout proceeds without the provider holding the session lock.
started.clear();finish.clear();result=[];fake.effect=hold
rid=str(uuid.uuid4());t=threading.Thread(target=lambda:result.append(generate(x,request_id=rid)));t.start();check('logout_started',started.wait(5))
check('logout_while_running',call(x,'/auth/logout',{})[0]==200);finish.set();t.join(10)
check('logout_discards_response',not t.is_alive() and result[0][0]==403)
x=Client();check('relogin',x.login(a)[0]==200);verify(x,f['factor'],f['secret'])
check('configuration_persistent',policy(x,'status')[1]['ready'] is True)
check('audit_rows',int(sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event like 'ai.%'"))>=5)
fixture={'organization':org,'foreign':foreign,'author':a,'reader':b,'authorFactor':af['id'],'authorSecret':af['totp']['secret'],'readerFactor':bf['id'],'readerSecret':bf['totp']['secret'],'admin':admin,'factor':fac['id'],'secret':fac['totp']['secret']}
pth=ROOT/'.local-auth/s08-fixture.json';pth.write_text(json.dumps(fixture));pth.chmod(0o600)
(out/'integration.json').write_text(json.dumps({'checks':checks,'count':len(checks),'passed':all(c['ok'] for c in checks)},indent=2))
print({'passed':len(checks),'organization':org},flush=True)
if '--codex' in sys.argv:
 from uniion.adapters.codex_local import CodexLocal
 os.environ['UNIION_AI_CODEX_FIXTURES']='1';app.ai_gateway.provider_factory=CodexLocal
 st,r,_=generate(x)
 ok=st==200 and r.get('text')=='UNIION_S08_OK'
 (out/'codex-live.json').write_text(json.dumps({'status':st,'exact_fixture_response':ok,'provider':'codex-local','scope':'fixture-only','no_business_content':True,'error_code':r.get('code')},indent=2))
 print({'codex_status':st,'exact_fixture_response':ok},flush=True)
 assert ok

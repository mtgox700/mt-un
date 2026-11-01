"""Additional adversarial D09 checks on the existing S08 fictional fixture."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
import uuid,subprocess
f=json.loads((ROOT/'.local-auth/s08-fixture.json').read_text());org=f['organization'];a=f['author']
assert a['email'].endswith('@uniion-local.example')
def sql(q):
 r=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr.decode())
 return r.stdout.decode().strip()
x=Client();check('login',x.login(a)[0]==200);verify(x,f['authorFactor'],f['authorSecret'])
def rpc(action='authorize',payload={},o=org):return api.request('/rest/v1/rpc/uniion_ai_policy',x.state()['access_token'],{'p_org':o,'p_action':action,'p_payload':payload})
def denied(fn):
 try:fn();return False
 except AccessDenied:return True
for action,payload in [(None,{}),('unknown',{}),('authorize',None),('authorize',[]),('authorize',{'provider':'evil'}),('authorize',{'url':'https://example.invalid'}),('authorize',{'role':'superadmin'}),('activate',{'enabled':True,'version':1,'providerVersion':None}),('activate',{'enabled':'true','version':1,'providerVersion':1}),('approve',{'enabled':True,'version':1})]:
 check('invalid_'+str(action)+'_'+str(len(checks)),denied(lambda:rpc(action,payload)))
p=rpc('status');
if not p['ready']:rpc('activate',{'enabled':True,'version':p['activationVersion'],'providerVersion':p['providerVersion']})
check('authorized',rpc()['ready'])
sql(f"delete from public.uniion_permissions where organization_id='{org}' and user_id='{a['id']}' and module='assistant' and permission='read'")
try:check('missing_read_denied',denied(rpc))
finally:sql(f"insert into public.uniion_permissions values('{org}','{a['id']}','assistant','read')")
sql(f"update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{a['id']}'")
try:check('revoked_membership_denied',denied(rpc))
finally:sql(f"update public.uniion_memberships set revoked_at=null where organization_id='{org}' and user_id='{a['id']}'")
sql(f"update public.uniion_organizations set active=false where id='{org}'")
try:check('inactive_org_denied',denied(rpc))
finally:sql(f"update public.uniion_organizations set active=true where id='{org}'")
class Broken:
 def complete(self,*a,**k):raise RuntimeError('PRIVATE_PROVIDER_ERROR')
app.ai_gateway.provider_factory=Broken
r=x.call('/identity/ai/generate',{'organization_id':org,'request_id':str(uuid.uuid4()),'fixture':'connection'})
check('provider_error_sanitized',r[0]==503 and 'PRIVATE_PROVIDER_ERROR' not in json.dumps(r))
check('policy_audit_without_content',sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event like 'ai.%' and (details ? 'text' or details ? 'question')")=='0')
(ROOT/'preuves/S08-A/policy-edges.json').write_text(json.dumps({'checks':checks,'passed':all(x['ok'] for x in checks),'count':len(checks)},indent=2))
print({'passed':len(checks)})

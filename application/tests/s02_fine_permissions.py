from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import uuid,subprocess
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts;org=str(uuid.uuid4());res=str(uuid.uuid4())
q=f"""begin;
insert into public.uniion_organizations values('{org}','Recette droits fins S02',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_module_access values('{org}','documents',true,true,'included',now()+interval '30 days');
insert into public.uniion_authorities values('{org}','{a['id']}','rights',false),('{org}','{a['id']}','download',true);
insert into public.uniion_permissions values('{org}','{a['id']}','documents','read');
insert into public.uniion_resources(id,organization_id,module,title,body) values('{res}','{org}','documents','Document fictif droits','{{}}');
insert into public.uniion_resource_grants values('{org}','{res}','{a['id']}',false,false,now()+interval '10 days',null);commit;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Fixture setup failed')
x=Client();y=Client();read={'type':'permission','module':'documents','permission':'read','enabled':True};dl={'type':'authority','permission':'download','enabled':True}
def change(c,changes,user=b['id'],organization=org):return c.call('/identity/rights/change',{'organization_id':organization,'user_id':user,'changes':changes})[0]
check('anonymous_refused',change(x,[read])==403);check('admin_login',x.login(a)[0]==200);check('aal1_refused',change(x,[read])==403)
(status,_,_),_=verify(x,f['factor'],f['secret']);check('admin_mfa',status==200)
check('member_login',y.login(b)[0]==200);(status,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('member_mfa',status==200)
check('member_rights_read_refused',y.call('/identity/rights',{'organization_id':org})[0]==403)
check('member_mutation_refused',change(y,[read],a['id'])==403)
check('self_escalation_refused',change(x,[read],a['id'])==403)
check('foreign_organization_refused',change(x,[read],organization=b['org'])==403)
check('unowned_write_refused',change(x,[{**read,'permission':'write'}])==403)
check('nondelegable_authority_refused',change(x,[{**dl,'permission':'rights'}])==403)
check('batch_rollback_refusal',change(x,[read,{**dl,'permission':'share'}])==403)
_,ctx,_=x.call('/identity/rights',{'organization_id':org});target=next(m for m in ctx['members'] if m['id']==b['id']);check('batch_atomic',target['permissions']==[])
check('permission_authorized',change(x,[read])==200)
check('permission_alone_no_resource',api.resources(y.state()['access_token'],org)==[])
from datetime import datetime,timedelta,timezone
until=(datetime.now(timezone.utc)+timedelta(days=1)).isoformat();grant={'type':'resource','resource':res,'permission':'read','enabled':True,'until':until,'history':False}
check('history_without_authority_refused',change(x,[{**grant,'history':True}])==403)
check('duration_escalation_refused',change(x,[{**grant,'until':(datetime.now(timezone.utc)+timedelta(days=20)).isoformat()}])==403)
check('resource_grant_authorized',change(x,[grant])==200)
check('real_resource_access',any(r['id']==res for r in api.resources(y.state()['access_token'],org)))
check('authority_delegation_authorized',change(x,[dl])==200)
check('authority_no_redelegation',change(y,[dl],a['id'])==403)
check('resource_revoke_authorized',change(x,[{**grant,'enabled':False}])==200)
check('existing_session_loses_access',api.resources(y.state()['access_token'],org)==[])
try:api.request('/rest/v1/rpc/uniion_rights_change',y.state()['access_token'],{'p_org':org,'p_user':a['id'],'p_type':'permission','p_module':'documents','p_permission':'read','p_enabled':True});denied=False
except AccessDenied:denied=True
check('direct_rpc_refused',denied)
check('forged_delegable_field_refused',change(x,[{**dl,'delegable':True}])==403)
out=ROOT/'preuves/S02-permissions';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'checks':checks,'count':len(checks),'passed':True},indent=2));(ROOT/'.local-auth/s02-rights-organization.json').write_text(json.dumps({'organization':org}));print(json.dumps({'passed':True,'count':len(checks)}))

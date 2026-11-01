from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import uuid,subprocess
from datetime import datetime,timedelta,timezone
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts;src=str(uuid.uuid4());dst=str(uuid.uuid4());res=str(uuid.uuid4())
q=f"""begin;
insert into public.uniion_organizations values('{src}','Recette source S02',true),('{dst}','Recette destinataire S02',true);
insert into public.uniion_memberships values('{src}','{a['id']}',now()-interval '1 day',null),('{dst}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_module_access values('{src}','documents',true,true,'included',now()+interval '30 days'),('{dst}','documents',true,true,'included',now()+interval '30 days');
insert into public.uniion_authorities values('{src}','{a['id']}','rights',false),('{src}','{a['id']}','share',false),('{src}','{a['id']}','download',false),('{dst}','{b['id']}','accept',false);
insert into public.uniion_permissions values('{src}','{a['id']}','documents','read'),('{dst}','{b['id']}','documents','read');
insert into public.uniion_partners values('{src}','{dst}');
insert into public.uniion_resources(id,organization_id,module,title,body,external_share_allowed) values('{res}','{src}','documents','Document de partage fictif','{{"title":"Document de partage fictif","text":"Contenu fictif version 1"}}',true);
insert into public.uniion_resource_grants values('{src}','{res}','{a['id']}',false,false,now()+interval '10 days',null);
commit;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Fixture setup failed')
x=Client();y=Client();payload={'organization_id':src,'target':dst,'resources':[res],'people':[b['id']],'until':(datetime.now(timezone.utc)+timedelta(days=1)).isoformat(),'download':False,'versions':{res:1},'attachments':[]}
check('anonymous_share_refused',x.call('/identity/shares/create',payload)[0]==403);check('source_login',x.login(a)[0]==200);check('aal1_share_refused',x.call('/identity/shares/create',payload)[0]==403)
(status,_,_),_=verify(x,f['factor'],f['secret']);check('source_mfa',status==200);check('target_login',y.login(b)[0]==200);(status,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('target_mfa',status==200)
_,ctx,_=x.call('/identity/organizations',{});check('only_membership_organizations',src in [o['id'] for o in ctx['organizations']] and dst not in [o['id'] for o in ctx['organizations']])
check('source_cannot_open_target',x.call('/identity/console',{'organization_id':dst})[0]==403);check('target_cannot_open_source',y.call('/identity/console',{'organization_id':src})[0]==403)
_,ctx,_=x.call('/identity/console',{'organization_id':src});check('partner_contacts_not_implicit',all(not p['members'] for p in ctx['partners']))
check('recipient_cannot_create_as_source',y.call('/identity/shares/create',payload)[0]==403)
check('non_member_beneficiary_refused',x.call('/identity/shares/create',{**payload,'people':[a['id']]})[0]==403)
status,sid,_=x.call('/identity/shares/create',payload);check('explicit_proposal_allowed',status==200)
read={'organization_id':dst,'share':sid,'resource':res,'download':False}
check('no_read_before_acceptance',y.call('/identity/shares/read',read)[0]==403)
check('source_cannot_accept_for_target',x.call('/identity/shares/accept',{'organization_id':dst,'share':sid,'people':[b['id']]})[0]==403)
check('beneficiary_expansion_refused',y.call('/identity/shares/accept',{'organization_id':dst,'share':sid,'people':[a['id'],b['id']]})[0]==403)
check('explicit_acceptance',y.call('/identity/shares/accept',{'organization_id':dst,'share':sid,'people':[b['id']]})[0]==200)
check('shared_read_authorized',y.call('/identity/shares/read',read)[0]==200)
check('download_refused',y.call('/identity/shares/read',{**read,'download':True})[0]==403)
check('no_direct_source_access',api.resources(y.state()['access_token'],src)==[])
check('target_cannot_revoke_source',y.call('/identity/shares/revoke',{'organization_id':src,'share':sid})[0]==403)
check('source_revoke_allowed',x.call('/identity/shares/revoke',{'organization_id':src,'share':sid})[0]==200)
check('existing_session_read_revoked',y.call('/identity/shares/read',read)[0]==403)
try:api.request('/rest/v1/rpc/uniion_shared_read',y.state()['access_token'],{'p_org':dst,'p_share':sid,'p_resource':res,'p_download':False});denied=False
except AccessDenied:denied=True
check('direct_rpc_revoked_refused',denied)
status,pending,_=x.call('/identity/shares/create',payload);check('pending_ui_fixture',status==200)
(ROOT/'.local-auth/s02-shares-organization.json').write_text(json.dumps({'source':src,'target':dst,'pending':pending}))
out=ROOT/'preuves/S02-organisations-partages';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

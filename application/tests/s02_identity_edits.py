from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import uuid,subprocess
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts
org=str(uuid.uuid4())
q=f"""begin;
insert into public.uniion_organizations values('{org}','Recette édition S02',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_authorities values('{org}','{a['id']}','organization_edit',false);
commit;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Fixture preparation failed')
admin=Client();member=Client();payload={'organization_id':org,'details':{'nom':'Organisation fictive modifiée','type':'section','sigle':'TEST','siret':'12345678901234'}}
profile={'organization_id':org,'name':'Profil fictif édité','role':'Fonction de recette','email':b['email']}
check('anonymous_write_refused',admin.call('/identity/organization/save',payload)[0]==403)
check('admin_login',admin.login(a)[0]==200)
check('aal1_write_refused',admin.call('/identity/organization/save',payload)[0]==403)
(status,_,_),_=verify(admin,f['factor'],f['secret']);check('admin_mfa',status==200)
check('organization_save_authorized',admin.call('/identity/organization/save',payload)[0]==200)
status,d,_=admin.call('/identity/profile',{'organization_id':org});check('organization_persisted',status==200 and d['organization']==payload['details']['nom'] and d['organization_details']['sigle']=='TEST')
check('organization_edit_does_not_grant_rights',not d['can_manage'])
check('foreign_organization_refused',admin.call('/identity/organization/save',{**payload,'organization_id':b['org']})[0]==403)
check('rights_alone_not_edit',admin.call('/identity/organization/save',{**payload,'organization_id':f['organization']})[0]==403)
check('privilege_field_refused',admin.call('/identity/organization/save',{**payload,'details':{**payload['details'],'active':'true'}})[0]==403)
check('invalid_siret_refused',admin.call('/identity/organization/save',{**payload,'details':{**payload['details'],'siret':'123'}})[0]==403)
check('member_login',member.login(b)[0]==200)
(status,_,_),_=verify(member,f['recipientFactor'],f['recipientSecret']);check('member_mfa',status==200)
check('member_organization_write_refused',member.call('/identity/organization/save',payload)[0]==403)
check('own_profile_saved',member.call('/identity/profile/save',profile)[0]==200)
status,d,_=member.call('/identity/profile',{'organization_id':org});check('profile_persisted',status==200 and d['name']==profile['name'] and d['role_label']==profile['role'])
status,d,_=member.call('/identity/profile',{'organization_id':f['organization']});check('profile_not_leaked_other_org',status==200 and d['name']!=profile['name'])
check('other_user_field_refused',member.call('/identity/profile/save',{**profile,'user_id':a['id']})[0]==403)
check('login_email_change_refused',member.call('/identity/profile/save',{**profile,'email':a['email']})[0]==403)
check('foreign_profile_write_refused',member.call('/identity/profile/save',{**profile,'organization_id':a['org']})[0]==403)
try:api.request('/rest/v1/rpc/uniion_identity_organization_save',member.state()['access_token'],{'p_org':org,'p_details':payload['details']});denied=False
except AccessDenied:denied=True
check('direct_rpc_organization_refused',denied)
check('no_business_rights_added',api.resources(member.state()['access_token'],org)==[])
check('csrf_write_refused',member.call('/identity/profile/save',profile,HTTP_X_UNIION_CSRF='wrong')[0]==403)
out=ROOT/'preuves/S02-edition-identite';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'checks':checks,'count':len(checks),'passed':all(c['ok'] for c in checks)},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))
# Browser fixture: credentials stay in the existing private file, only fictional organization identifier here.
(ROOT/'.local-auth/s02-edit-organization.json').write_text(json.dumps({'organization':org}))

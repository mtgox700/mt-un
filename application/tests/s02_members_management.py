from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import uuid,subprocess
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts;org=str(uuid.uuid4())
q=f"""begin;insert into public.uniion_organizations values('{org}','Recette membres S02',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_authorities values('{org}','{a['id']}','rights',false);commit;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Fixture setup failed')
admin=Client();member=Client();payload={'organization_id':org,'user_id':b['id'],'action':'suspend'}
check('anonymous_suspend_refused',admin.call('/identity/memberships/status',payload)[0]==403)
check('admin_login',admin.login(a)[0]==200);check('aal1_suspend_refused',admin.call('/identity/memberships/status',payload)[0]==403)
(status,_,_),_=verify(admin,f['factor'],f['secret']);check('admin_mfa',status==200)
check('member_login',member.login(b)[0]==200);(status,_,_),_=verify(member,f['recipientFactor'],f['recipientSecret']);check('member_mfa',status==200)
check('member_mutation_refused',member.call('/identity/memberships/status',{**payload,'user_id':a['id']})[0]==403)
check('self_suspend_refused',admin.call('/identity/memberships/status',{**payload,'user_id':a['id']})[0]==403)
check('foreign_org_refused',admin.call('/identity/memberships/status',{**payload,'organization_id':b['org']})[0]==403)
check('suspend_authorized',admin.call('/identity/memberships/status',payload)[0]==200)
check('existing_session_profile_blocked',member.call('/identity/profile',{'organization_id':org})[0]==403)
check('other_org_unaffected',member.call('/identity/profile',{'organization_id':b['org']})[0]==200)
try:api.request('/rest/v1/rpc/uniion_identity_profile',member.state()['access_token'],{'p_org':org});denied=False
except AccessDenied:denied=True
check('direct_rpc_suspended_refused',denied)
status,d,_=admin.call('/identity/directory',{'organization_id':org});check('suspended_status_visible',any(m['id']==b['id'] and m['suspended'] for m in d['members']))
check('resume_authorized',admin.call('/identity/memberships/status',{**payload,'action':'resume'})[0]==200)
check('membership_restored',member.call('/identity/profile',{'organization_id':org})[0]==200)
mail='recette-relance-'+uuid.uuid4().hex[:10]+'@uniion-local.example'
status,ticket,_=admin.call('/identity/invitations/create',{'organization_id':org,'email':mail});check('invitation_created',status==200)
ip={'organization_id':org,'invitation_id':ticket['id']}
check('member_resend_refused',member.call('/identity/invitations/resend',ip)[0]==403)
check('foreign_invite_revoke_refused',admin.call('/identity/invitations/revoke',{**ip,'organization_id':b['org']})[0]==403)
check('resend_local_mail_success',admin.call('/identity/invitations/resend',ip)[0]==200)
# Token equality is checked inside PostgreSQL; no token or archive is printed.
q=f"select token_hash <> encode(sha256(convert_to('{ticket['token']}','UTF8')),'hex') from uniion_private.invitations where id='{ticket['id']}';"
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-At'],input=q.encode(),capture_output=True);check('old_invitation_token_invalidated',p.returncode==0 and p.stdout.strip()==b't')
check('invite_revoke_authorized',admin.call('/identity/invitations/revoke',ip)[0]==200)
check('revoked_resend_refused',admin.call('/identity/invitations/resend',ip)[0]==403)
check('member_revoke_refused',member.call('/identity/memberships/revoke',{'organization_id':org,'user_id':a['id']})[0]==403)
check('self_revoke_refused',admin.call('/identity/memberships/revoke',{'organization_id':org,'user_id':a['id']})[0]==403)
check('member_revoke_authorized',admin.call('/identity/memberships/revoke',{'organization_id':org,'user_id':b['id']})[0]==200)
check('revoked_session_blocked',member.call('/identity/profile',{'organization_id':org})[0]==403)
check('revoked_cannot_resume',admin.call('/identity/memberships/status',{**payload,'action':'resume'})[0]==403)
check('removed_cannot_be_reinvited',admin.call('/identity/invitations/create',{'organization_id':org,'email':b['email']})[0]==403)
out=ROOT/'preuves/S02-gestion-membres';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'checks':checks,'count':len(checks),'passed':True},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

(ROOT/'.local-auth/s02-members-organization.json').write_text(json.dumps({'organization':org}))

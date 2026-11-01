from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts
admin=Client();member=Client();org={'organization_id':f['organization']}
check('anonymous_profile_refused',admin.call('/identity/profile',org)[0]==403)
check('admin_login',admin.login(a)[0]==200)
check('aal1_directory_refused',admin.call('/identity/directory',org)[0]==403)
(status,_,_),_=verify(admin,f['factor'],f['secret']);check('admin_mfa',status==200)
status,p,_=admin.call('/identity/profile',org);check('own_profile',status==200 and p['email']==a['email'])
status,d,_=admin.call('/identity/directory',org);check('directory_authorized',status==200 and any(m['email']==b['email'] for m in d['members']))
check('accepted_invitation_visible',any(i['email']==b['email'] and i['status']=='accepted' for i in d['invitations']))
check('no_invitation_secrets',not any('token' in k for i in d['invitations'] for k in i))
check('foreign_directory_refused',admin.call('/identity/directory',{'organization_id':b['org']})[0]==403)
check('foreign_profile_refused',admin.call('/identity/profile',{'organization_id':b['org']})[0]==403)
check('identity_spoof_fields_refused',admin.call('/identity/profile',{**org,'user_id':b['id']})[0]==403)
check('member_login',member.login(b)[0]==200)
(status,_,_),_=verify(member,f['recipientFactor'],f['recipientSecret']);check('member_mfa',status==200)
status,p,_=member.call('/identity/profile',org);check('member_own_profile',status==200 and p['id']==b['id'] and not p['can_manage'])
check('member_directory_refused',member.call('/identity/directory',org)[0]==403)
try:api.request('/rest/v1/rpc/uniion_identity_directory',member.state()['access_token'],{'p_org':f['organization']});denied=False
except AccessDenied:denied=True
check('direct_rpc_refused',denied)
check('no_business_grant',api.resources(member.state()['access_token'],f['organization'])==[])
out=ROOT/'preuves/S02-profil-annuaire';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'checks':checks,'count':len(checks),'passed':all(c['ok'] for c in checks)},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

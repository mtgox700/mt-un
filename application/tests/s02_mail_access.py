"""Non-destructive access checks using the current dedicated fictional factors."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts
admin=Client();member=Client();check('admin_login',admin.login(a)[0]==200)
check('send_without_mfa_refused',admin.call('/identity/invitations/send',{'organization_id':f['organization'],'email':f['recipient']})[0]==403)
(status,_,_),_=verify(admin,f['factor'],f['secret']);check('admin_mfa',status==200)
check('foreign_origin_refused',admin.call('/identity/invitations/send',{'organization_id':f['organization'],'email':f['recipient']},HTTP_ORIGIN='https://invalid.example')[0]==403)
check('missing_csrf_refused',admin.call('/identity/invitations/send',{'organization_id':f['organization'],'email':f['recipient']},HTTP_X_UNIION_CSRF='')[0]==403)
check('external_email_refused',admin.call('/identity/invitations/send',{'organization_id':f['organization'],'email':'test@external.invalid'})[0]==403)
check('recipient_login',member.login(b)[0]==200)
(status,_,_),_=verify(member,f['recipientFactor'],f['recipientSecret']);check('recipient_mfa',status==200)
check('recipient_has_no_invite_authority',member.call('/identity/invitations/send',{'organization_id':f['organization'],'email':f['recipient']})[0]==403)
link=json.loads((ROOT/'.local-auth/s02-received-invitation.json').read_text())['link'];token=link.split('#invitation=')[1]
check('accepted_token_cannot_be_reused',member.call('/identity/invitations/accept',{'token':token})[0]==403)
mt=member.state()['access_token'];context=api.request('/rest/v1/rpc/uniion_context',mt,{})
check('accepted_organization_membership_exists',f['organization'] in json.dumps(context))
check('no_business_resources_granted',api.resources(mt,f['organization'])==[])
check('other_organization_resource_denied',resource(member,a)[0]==403)
out=ROOT/'preuves/S02-connexion-mail';out.mkdir(exist_ok=True);(out/'access.json').write_text(json.dumps({'checks':checks,'passed':all(c['ok'] for c in checks),'count':len(checks)},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

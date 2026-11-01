from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());org=json.loads((ROOT/'.local-auth/s02-edit-organization.json').read_text())['organization'];c=Client();check('new_session_login',c.login(accounts[0])[0]==200);(status,_,_),_=verify(c,f['factor'],f['secret']);check('new_session_mfa',status==200)
status,p,_=c.call('/identity/profile',{'organization_id':org});check('browser_profile_persisted_new_session',status==200 and p['name']=='Profil recette interface' and p['role_label']=='Fonction fictive');check('browser_organization_persisted_new_session',p['organization_details']['sigle']=='RECETTE UI')
(ROOT/'preuves/S02-edition-identite/ui-persistence.json').write_text(json.dumps({'checks':checks,'passed':True,'count':len(checks)},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

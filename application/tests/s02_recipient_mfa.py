"""Prepare only the explicitly authorized fictional recipient's test factor."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import os,subprocess,uuid
p=ROOT/'.local-auth/s02-browser-fixture.json';f=json.loads(p.read_text());account=next(a for a in accounts if a['email']==f['recipient'])
if account['email']!='recette-s01-mfa-1-db101542@uniion-local.example':raise RuntimeError('Wrong fixture')
uid=str(uuid.UUID(account['id']))
q="DO $$ BEGIN IF EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id='"+uid+"' AND status='verified') THEN RAISE EXCEPTION 'Existing factor'; END IF; UPDATE uniion_private.mfa_requirements SET required=false WHERE user_id='"+uid+"'; END $$;"
r=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if r.returncode:raise RuntimeError('Fixture preparation refused')
c=Client();check('recipient_login',c.login(account)[0]==200);status,e,_=c.call('/auth/mfa/enroll',{'name':'Recette invitation reçue S02'});check('enroll',status==200);(status,_,_),_=verify(c,e['id'],e['totp']['secret']);check('verified',status==200)
f['recipientSecret']=e['totp']['secret'];f['recipientFactor']=e['id'];p.write_text(json.dumps(f));os.chmod(p,0o600);print('Recipient test MFA enrolled and verified; no secret displayed')

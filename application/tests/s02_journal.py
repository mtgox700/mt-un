"""Scoped journal: fictional local organizations only."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0];exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import uuid,subprocess
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts
org,foreign,empty=[str(uuid.uuid4()) for _ in range(3)]
q=f"""begin;
insert into public.uniion_organizations values('{org}','Recette journal S02',true),('{foreign}','Journal extérieur fictif',true),('{empty}','Journal vide fictif',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now(),null),('{org}','{b['id']}',now(),null),('{empty}','{a['id']}',now(),null);
insert into public.uniion_authorities values('{org}','{a['id']}','rights',false),('{empty}','{a['id']}','rights',false);
insert into public.uniion_security_events(organization_id,actor,event,details) values
('{org}','{a['id']}','recette.journal.local','{{"test":"Événement fictif local"}}'),
('{foreign}','{b['id']}','recette.journal.exterieur','{{"test":"Ne doit pas apparaître"}}'),
('{org}','{a['id']}','<img src=x onerror=alert(1)>','{{"test":"<script>alert(1)</script>"}}');commit;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Fixture preparation failed')
x=Client();y=Client()
def journal(c,o=org):return c.call('/identity/console',{'organization_id':o})
check('anonymous_denied',journal(x)[0]==403);check('admin_login',x.login(a)[0]==200);check('aal1_denied',journal(x)[0]==403)
(st,_,_),_=verify(x,f['factor'],f['secret']);check('admin_mfa',st==200)
st,d,_=journal(x);check('local_events_visible',st==200 and len(d['events'])==2);check('foreign_events_absent','recette.journal.exterieur' not in json.dumps(d));check('latest_first',d['events'][0]['event'].startswith('<img'));check('foreign_org_denied',journal(x,foreign)[0]==403);check('empty_journal',journal(x,empty)[1]['events']==[])
check('member_login',y.login(b)[0]==200);(st,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('member_mfa',st==200)
st,d,_=journal(y);check('nonmanager_no_events',st==200 and d['events']==[]);check('forged_fields_denied',x.call('/identity/console',{'organization_id':org,'all':True})[0]==403)
try:api.request('/rest/v1/uniion_security_events?select=*',x.state()['access_token']);denied=False
except AccessDenied:denied=True
check('direct_table_denied',denied)
(ROOT/'.local-auth/s02-journal.json').write_text(json.dumps({'organization':org,'foreign':foreign,'empty':empty}))
out=ROOT/'preuves/S02-journal';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

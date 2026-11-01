from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:");exec(compile(source,__file__,'exec'))
import uuid,subprocess
from datetime import date
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts
org,foreign=str(uuid.uuid4()),str(uuid.uuid4())
def sql(q):
 p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if p.returncode:raise RuntimeError('Agenda fixture SQL failed')
sql(f"""begin;
insert into public.uniion_organizations values('{org}','Agenda pilote fictif S03',true),('{foreign}','Agenda organisation B fictive',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null),('{foreign}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_module_access values('{org}','agenda',true,true,'included',now()+interval '10 days'),('{foreign}','agenda',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','agenda','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE'),('{foreign}','agenda','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions values('{org}','{a['id']}','agenda','read'),('{org}','{a['id']}','agenda','write'),('{org}','{a['id']}','agenda','create'),('{org}','{b['id']}','agenda','read'),('{foreign}','{b['id']}','agenda','read');
insert into uniion_private.agenda_audiences values('{org}','{a['id']}','elus'),('{org}','{b['id']}','adherents'),('{foreign}','{b['id']}','elus');commit;""")
x,y=Client(),Client()
def listing(c,o=org):return c.call('/identity/agenda',{'organization_id':o})
event={'title':'Réunion pilote S03','type':'cse','date':date.today().isoformat(),'start':'09:00','end':'11:00','lieu':'Salle de recette','visib':'elus','notes':'Données fictives uniquement','rappel':False}
def save(c,e=event,o=org):return c.call('/identity/agenda/save',{'organization_id':o,'event':e})
check('anonymous_denied',listing(x)[0]==403);x.login(a);check('aal1_denied',listing(x)[0]==403);(st,_,_),_=verify(x,f['factor'],f['secret']);check('mfa_a',st==200)
y.login(b);(st,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('mfa_b',st==200)
check('empty_real_agenda',listing(x)[1]==[])
st,created,_=save(x);check('create_allowed',st==200)
check('persisted_read',listing(x)[1][0]['id']==created['id'])
check('restricted_audience_hidden',listing(y)[1]==[])
check('create_without_permission_denied',save(y,{**event,'visib':'adherents'})[0]==403)
check('superadmin_foreign_org_denied',listing(x,foreign)[0]==403)
check('cross_org_id_denied',save(y,{**event,'id':created['id'],'version':1},foreign)[0]==403)
check('invalid_time_denied',save(x,{**event,'end':'08:00'})[0]==403)
check('extra_owner_field_denied',save(x,{**event,'creator':b['id']})[0]==403)
st,updated,_=save(x,{**event,'id':created['id'],'version':1,'title':'Réunion pilote modifiée'});check('update_allowed',st==200 and updated['version']==2)
check('stale_version_denied',save(x,{**event,'id':created['id'],'version':1})[0]==403)
st,shared,_=save(x,{**event,'title':'Assemblée ouverte fictive','visib':'adherents'});check('audience_event_created',st==200)
check('audience_filtered',len(listing(y)[1])==1 and listing(y)[1][0]['id']==shared['id'])
check('read_only_update_denied',save(y,{**event,'visib':'adherents','id':shared['id'],'version':1})[0]==403)
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='agenda';")
check('disabled_read_denied',listing(x)[0]==403);check('disabled_write_denied',save(x)[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='agenda';update uniion_private.module_entitlements set revoked_at=now() where organization_id='{org}' and module='agenda';")
check('unpaid_denied',listing(x)[0]==403)
sql(f"update uniion_private.module_entitlements set revoked_at=null where organization_id='{org}' and module='agenda';update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{b['id']}';")
check('revoked_membership_denied',listing(y)[0]==403)
sql(f"update public.uniion_memberships set revoked_at=null where organization_id='{org}' and user_id='{b['id']}';")
try:api.request('/rest/v1/agenda_events',x.state()['access_token']);denied=False
except AccessDenied:denied=True
check('direct_table_inaccessible',denied)
(ROOT/'.local-auth/s03-agenda.json').write_text(json.dumps({'organization':org,'foreign':foreign,'event':created['id']}))
out=ROOT/'preuves/S03-agenda';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

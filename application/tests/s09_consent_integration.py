"""Fictive S09 organization only; no audio, provider, deletion or old proof writes."""
from pathlib import Path
bootstrap=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(bootstrap,__file__,'exec'))
import uuid,subprocess
out=ROOT/'preuves/S09-A-consentement';out.mkdir(exist_ok=True)
f=json.loads((ROOT/'.local-auth/s08-fixture.json').read_text());a,b=f['author'],f['reader']
assert all(u['email'].endswith('@uniion-local.example') for u in (a,b))
def sql(q):
 r=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if r.returncode:raise RuntimeError('S09 SQL failed; inspect locally without publishing fixture data')
 return r.stdout.decode().strip()
org,foreign=str(uuid.uuid4()),str(uuid.uuid4())
sql(f"""begin;
insert into public.uniion_organizations values('{org}','S09 consentement fictif',true),('{foreign}','S09 autre organisation fictive',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null),('{foreign}','{a['id']}',now()-interval '1 day',null);
insert into public.uniion_module_access values('{org}','reunions',true,true,'included',now()+interval '10 days'),('{foreign}','reunions',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','reunions','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-S09-FICTIVE'),('{foreign}','reunions','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-S09-FICTIVE');
insert into public.uniion_permissions select '{org}','{a['id']}','reunions',p from unnest(array['read','write','create'])p;
insert into public.uniion_permissions values('{org}','{b['id']}','reunions','read'),('{foreign}','{a['id']}','reunions','read');commit;""")
x,y=Client(),Client();check('author_login',x.login(a)[0]==200);check('author_mfa',verify(x,f['authorFactor'],f['authorSecret'])[0][0]==200)
check('reader_login',y.login(b)[0]==200);check('reader_mfa',verify(y,f['readerFactor'],f['readerSecret'])[0][0]==200)
def business(c,action,payload,organization=org):
 app.sessions.clock=lambda:time.time()+len(checks)*11
 return c.call('/identity/business',{'organization_id':organization,'module':'reunions','action':action,'payload':payload})
st,r,_=business(x,'create',{'data':{'title':'Réunion S09 entièrement fictive'}});check('meeting_created',st==200);rid=r['id']
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '1 day',null)")
def read(c=None,organization=org):return business(c or x,'consent_get',{'id':rid},organization)
def write(c=None,**kw):return business(c or x,'consent_set',{'id':rid,'version':0,'meetingVersion':1,'accepted':True,**kw})
check('initial_not_attested',read()[1]['current'] is False)
check('reader_cannot_attest',write(y)[0]==403)
check('other_org_refused',read(organization=foreign)[0]==403)
for label,changes in [('extra_actor',{'actor':a['id']}),('null',{'accepted':None}),('string_bool',{'accepted':'true'}),('bool_version',{'version':False}),('negative_version',{'version':-1}),('fraction',{'version':0.5}),('stale_meeting',{'meetingVersion':2})]:
 check(label+'_refused',write(**changes)[0]==403)
check('attestation_saved',write()[1]['current'] is True)
check('independent_read_persisted',read(y)[1]['version']==1)
check('replayed_version_refused',write()[0]==403)
# New application/session store, same database: no in-memory success illusion.
app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url}),api)
x=Client();check('restart_login',x.login(a)[0]==200);check('restart_mfa',verify(x,f['authorFactor'],f['authorSecret'])[0][0]==200)
check('restart_persistence',read()[1]['current'] is True)
check('meeting_updated',business(x,'save',{'id':rid,'version':1,'data':{'title':'Réunion fictive modifiée'}})[0]==200)
check('meeting_change_invalidates',read()[1]['current'] is False)
check('renewed_for_version',write(version=1,meetingVersion=2)[1]['current'] is True)
check('withdrawn',write(version=2,meetingVersion=2,accepted=False)[1]['current'] is False)
check('withdrawal_persisted',read()[1]['accepted'] is False and read()[1]['version']==3)
check('audit_three_transitions',sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event='meeting.consent'")=='3')
check('direct_table_privilege_denied',sql("select has_table_privilege('authenticated','uniion_private.meeting_consents','select')")=='f')
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}'")
check('disabled_module_refused',read()[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}';update public.uniion_resource_grants set revoked_at=now() where organization_id='{org}' and resource_id='{rid}' and user_id='{a['id']}'")
check('revoked_acl_refused',read()[0]==403)
check('revoked_write_refused',write(version=3,meetingVersion=2)[0]==403)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

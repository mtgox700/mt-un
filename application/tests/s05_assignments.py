from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:");exec(compile(source,__file__,'exec'))
import uuid,subprocess
org,foreign=str(uuid.uuid4()),str(uuid.uuid4());a,b=accounts
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text())
def sql(q):
 p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if p.returncode:raise RuntimeError(p.stderr.decode())
 return p.stdout.decode().strip()
sql(f"""begin;
insert into public.uniion_organizations values('{org}','S05 — section fictive',true),('{foreign}','S05 — fédération fictive',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null),('{foreign}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_module_access values('{org}','dossiers',true,true,'included',now()+interval '10 days'),('{foreign}','dossiers',true,true,'included',now()+interval '10 days');
insert into public.uniion_module_access values('{org}','cotisations',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','dossiers','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE'),('{foreign}','dossiers','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions values('{org}','{a['id']}','dossiers','read'),('{org}','{a['id']}','dossiers','write'),('{org}','{a['id']}','dossiers','create'),('{org}','{a['id']}','cotisations','read'),('{org}','{a['id']}','cotisations','write'),('{org}','{b['id']}','dossiers','read'),('{foreign}','{b['id']}','dossiers','read');commit;""")
x,y=Client(),Client()
def call(c,action='list',payload={},o=org):return c.call('/identity/cases',{'organization_id':o,'action':action,'payload':payload})
x.login(a);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret'])
record={'title':'Affectation fictive S05','long':'Recette locale uniquement.','tag':'Juridique','due':'30 j'}
st,row,_=call(x,'create',record);check('create',st==200);rid=row['id']
def assign(c,target=b['id'],version=1,o=org):return call(c,'assign',{'id':rid,'version':version,'user':target},o)
check('no_assignment_authority_denied',assign(x)[0]==403)
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','dossiers_assign',false)")
check('ungranted_recipient_denied',assign(x)[0]==403)
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null)")
check('read_only_recipient_denied',assign(x)[0]==403)
sql(f"update public.uniion_resource_grants set can_write=true where resource_id='{rid}' and user_id='{b['id']}';insert into public.uniion_permissions values('{org}','{b['id']}','dossiers','write')")
check('self_assignment_denied',assign(x,a['id'])[0]==403)
check('writer_without_assignment_authority_denied',assign(y,a['id'])[0]==403)
check('foreign_org_denied',assign(y,a['id'],o=foreign)[0]==403)
check('stale_version_denied',assign(x,version=99)[0]==403)
sql(f"insert into uniion_private.membership_suspensions values('{org}','{b['id']}',true)")
check('suspended_target_denied',assign(x)[0]==403)
sql(f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}';update public.uniion_resource_grants set valid_until=now()-interval '1 minute' where resource_id='{rid}' and user_id='{b['id']}'")
check('expired_target_denied',assign(x)[0]==403)
sql(f"update public.uniion_resource_grants set valid_until=now()+interval '3 days' where resource_id='{rid}' and user_id='{b['id']}'")
ctx=call(x,'get',{'id':rid})[1];check('eligible_target_listed',ctx['canAssign'] and b['id'] in [u['id'] for u in ctx['assignees']])
st,res,_=assign(x);check('assignment_saved',st==200 and res=={'ok':True,'accessRetained':False})
check('old_owner_read_denied',call(x,'get',{'id':rid})[0]==403)
check('old_owner_write_denied',call(x,'note',{'id':rid,'version':2,'text':'Refus'})[0]==403)
check('old_owner_rls_denied',api.request('/rest/v1/uniion_resources?id=eq.'+rid,x.state()['access_token'])==[])
res=call(y,'get',{'id':rid})[1];check('new_owner_and_history',res['ownerId']==b['id'] and res['version']==2 and res['timeline'][-1]['title']=='Référent modifié')
check('new_owner_write_allowed',call(y,'note',{'id':rid,'version':2,'text':'Note du nouveau référent'})[0]==200)
check('replay_denied',assign(x)[0]==403)
app.sessions.clock=lambda:time.time()+61
sql(f"insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Gestionnaire'),('{org}','{b['id']}','Alex Recette','Référent');insert into uniion_private.organization_details values('{org}', '{{\"type\":\"section\"}}')")
rows=[]
for fmt in ('mobile','tablette','desktop'):
 st,r,_=call(x,'create',{**record,'title':'Affectation '+fmt});check('fixture_'+fmt,st==200);rows.append(r['id'])
 sql(f"insert into public.uniion_resource_grants values('{org}','{r['id']}','{b['id']}',true,false,now()+interval '3 days',null)")
# Reader can consult a candidate but cannot assign without the separate authority.
out=ROOT/'preuves/S05-affectations';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'checks':checks,'count':len(checks)},indent=2))
(ROOT/'.local-auth/s05-affectations.json').write_text(json.dumps({'organization':org,'foreign':foreign,'rows':rows}))
print(json.dumps({'passed':True,'count':len(checks)}))

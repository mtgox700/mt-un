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
insert into public.uniion_organizations values('{org}','S04 — section fictive',true),('{foreign}','S04 — fédération fictive',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null),('{foreign}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_module_access values('{org}','adherents',true,true,'included',now()+interval '10 days'),('{foreign}','adherents',true,true,'included',now()+interval '10 days');
insert into public.uniion_module_access values('{org}','cotisations',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','adherents','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE'),('{foreign}','adherents','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions values('{org}','{a['id']}','adherents','read'),('{org}','{a['id']}','adherents','write'),('{org}','{a['id']}','adherents','create'),('{org}','{a['id']}','cotisations','read'),('{org}','{a['id']}','cotisations','write'),('{org}','{b['id']}','adherents','read'),('{foreign}','{b['id']}','adherents','read');commit;""")
x,y=Client(),Client()
def call(c,action='list',payload={},o=org):return c.call('/identity/adherents',{'organization_id':o,'action':action,'payload':payload})
check('anonymous_denied',call(x)[0]==403);x.login(a);check('aal1_denied',call(x)[0]==403);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret'])
check('empty_register',call(x)[1]['rows']==[])
record={'prenom':'Camille','nom':'Recette','email':'camille@uniion-local.example','ent':'Entreprise fictive','etab':'Site A','since':'01/10/2026','mode':'Virement','montant':'12,50 €/mois'}
check('read_only_import_denied',call(y,'import',[record])[0]==403)
users_before=sql('select count(*) from auth.users');members_before=sql(f"select count(*) from public.uniion_memberships where organization_id='{org}'")
st,result,_=call(x,'import',[record]);check('import_saved',st==200 and len(result['rows'])==1);row=result['rows'][0]
check('no_user_created',sql('select count(*) from auth.users')==users_before);check('no_membership_created',sql(f"select count(*) from public.uniion_memberships where organization_id='{org}'")==members_before)
check('reloaded_from_database',call(x)[1]['rows'][0]['id']==row['id'])
check('financial_fields_hidden',not {'mode','montant'}&set(call(y)[1]['rows'][0]))
check('financial_fields_authorized',call(x)[1]['rows'][0]['montant']==record['montant'])
check('foreign_read_empty',call(y,o=foreign)[1]['rows']==[])
check('nonmember_admin_denied',call(x,o=foreign)[0]==403)
check('duplicate_case_denied',call(x,'import',[{**record,'email':record['email'].upper()}])[0]==403)
check('atomic_import_denied',call(x,'import',[{**record,'email':'new@uniion-local.example'},record])[0]==403)
check('atomic_no_partial_rows',len(call(x)[1]['rows'])==1)
for key,value in [('prenom',''),('email','bad'),('ent',None),('owner','bad')]:check('invalid_'+key,call(x,'import',[{**record,key:value}])[0]==403)
app.sessions.clock=lambda:time.time()+61
payload={'id':row['id'],'version':1,'data':{**record,'poste':'Technicienne'}}
check('read_only_edit_denied',call(y,'save',payload)[0]==403)
check('cross_org_edit_denied',call(y,'save',payload,o=foreign)[0]==403)
st,result,_=call(x,'save',payload);check('edit_saved',st==200 and result['rows'][0]['version']==2)
check('stale_edit_denied',call(x,'save',payload)[0]==403)
check('new_value_read_by_second_actor',call(y)[1]['rows'][0]['poste']=='Technicienne')
sql(f"insert into public.uniion_permissions values('{org}','{b['id']}','adherents','write');")
check('profile_write_does_not_grant_finance',call(y,'save',{**payload,'version':2})[0]==403)
st,result,_=call(y,'save',{'id':row['id'],'version':2,'data':{k:v for k,v in payload['data'].items() if k not in ('mode','montant')}});check('nonfinancial_editor_allowed',st==200)
check('finance_preserved',call(x)[1]['rows'][0]['montant']==record['montant'])
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='adherents';")
check('module_disabled_denied',call(x)[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='adherents';update uniion_private.module_entitlements set revoked_at=now() where organization_id='{org}' and module='adherents';")
check('commercial_access_revoked_denied',call(x)[0]==403)
sql(f"update uniion_private.module_entitlements set revoked_at=null where organization_id='{org}' and module='adherents';update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{b['id']}';")
check('departed_member_denied',call(y)[0]==403)
sql(f"update public.uniion_memberships set revoked_at=null where organization_id='{org}' and user_id='{b['id']}';")
try:api.request('/rest/v1/adherents',x.state()['access_token']);blocked=False
except AccessDenied:blocked=True
check('private_table_denied',blocked)
out=ROOT/'preuves/S04-adherents';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'checks':checks,'count':len(checks)},indent=2))
(ROOT/'.local-auth/s04-adherents.json').write_text(json.dumps({'organization':org,'foreign':foreign,'adherent':row['id']}))
print(json.dumps({'passed':True,'count':len(checks)}))

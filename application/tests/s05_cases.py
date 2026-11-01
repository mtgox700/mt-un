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
check('anonymous_denied',call(x)[0]==403);x.login(a);check('aal1_denied',call(x)[0]==403);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret'])
record={'title':'Dossier de recette S05','long':'Contexte fictif confidentiel du dossier.','tag':'Juridique','due':'15 j'}
check('read_only_create_denied',call(y,'create',record)[0]==403)
st,row,_=call(x,'create',record);check('create_saved',st==200 and row['version']==1);rid=row['id']
res=call(x);check('list_persistent',res[0]==200 and res[1]['rows'][0]['id']==rid)
check('same_org_without_grant_empty',call(y)[1]['rows']==[])
check('guessed_id_denied',call(y,'get',{'id':rid})[0]==403)
check('cross_org_id_denied',call(y,'get',{'id':rid},foreign)[0]==403)
check('nonmember_denied',call(x,o=foreign)[0]==403)
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null)")
check('explicit_reader_allowed',call(y,'get',{'id':rid})[1]['title']==record['title'])
check('reader_note_denied',call(y,'note',{'id':rid,'version':1,'text':'Refus'})[0]==403)
check('reader_status_denied',call(y,'status',{'id':rid,'version':1,'status':'doing'})[0]==403)
st,row,_=call(x,'note',{'id':rid,'version':1,'text':'Note fictive persistante'});check('note_saved',st==200 and row['timeline'][-1]['body']=='Note fictive persistante')
check('stale_status_denied',call(x,'status',{'id':rid,'version':1,'status':'doing'})[0]==403)
st,row,_=call(x,'status',{'id':rid,'version':2,'status':'doing'});check('status_saved',st==200 and row['status']=='doing')
check('second_actor_reads_history',len(call(y,'get',{'id':rid})[1]['timeline'])==3)
app.sessions.clock=lambda:time.time()+61
check('edit_saved',call(x,'edit',{'id':rid,'version':3,'title':record['title'],'long':'Description modifiée, persistante.','due':'30 j'})[0]==200)
check('spoof_owner_denied',call(x,'create',{**record,'owner':b['id']})[0]==403)
check('invalid_title_denied',call(x,'create',{**record,'title':''})[0]==403)
check('invalid_status_denied',call(x,'status',{'id':rid,'version':4,'status':'anything'})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=now() where organization_id='{org}' and user_id='{b['id']}'")
check('revoked_grant_denied',call(y,'get',{'id':rid})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null,valid_until=now()-interval '1 minute' where organization_id='{org}' and user_id='{b['id']}'")
check('expired_grant_denied',call(y,'get',{'id':rid})[0]==403)
sql(f"update public.uniion_resource_grants set valid_until=now()+interval '3 days' where organization_id='{org}' and user_id='{b['id']}';update public.uniion_module_access set enabled=false where organization_id='{org}' and module='dossiers'")
check('disabled_module_denied',call(x)[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}';update uniion_private.module_entitlements set revoked_at=now() where organization_id='{org}'")
check('commercial_revoked_denied',call(x)[0]==403)
sql(f"update uniion_private.module_entitlements set revoked_at=null where organization_id='{org}';update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{b['id']}'")
check('departed_reader_denied',call(y)[0]==403)
sql(f"update public.uniion_memberships set revoked_at=null where organization_id='{org}' and user_id='{b['id']}'")
for table in ('cases','case_history'):
 try:api.request('/rest/v1/'+table,x.state()['access_token']);blocked=False
 except AccessDenied:blocked=True
 check('private_'+table+'_denied',blocked)
check('resource_table_ungranted_hidden',api.request('/rest/v1/uniion_resources?id=eq.'+rid,y.state()['access_token'])!=[])
# A second dossier remains private even to the granted reader of the first.
st,private,_=call(x,'create',{**record,'title':'Dossier réservé au rédacteur'});check('private_case_created',st==200)
check('reader_other_case_denied',call(y,'get',{'id':private['id']})[0]==403)
check('direct_rls_hides_other_case',api.request('/rest/v1/uniion_resources?id=eq.'+private['id'],y.state()['access_token'])==[])
sql(f"insert into uniion_private.organization_details values('{org}', '{{\"type\":\"section\"}}')")
out=ROOT/'preuves/S05-dossiers';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'checks':checks,'count':len(checks)},indent=2))
(ROOT/'.local-auth/s05-dossiers.json').write_text(json.dumps({'organization':org,'foreign':foreign,'resource':rid,'private':private['id']}))
print(json.dumps({'passed':True,'count':len(checks)}))

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
def call(c,action='files',payload=None,o=org):return c.call('/identity/cases',{'organization_id':o,'action':action,'payload':payload or {'case':rid}})
x.login(a);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret'])
st,row,_=call(x,'create',{'title':'Coffre de recette S05','long':'Pièces fictives uniquement.','tag':'Juridique','due':'30 j'});check('case_created',st==200);rid=row['id']
check('ungranted_file_list_denied',call(y)[0]==403)
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null);insert into public.uniion_authorities values('{org}','{a['id']}','download',false),('{org}','{a['id']}','dossiers_assign',false)")
import base64,io,hashlib
from PIL import Image
out=ROOT/'preuves/S05-coffre';out.mkdir(parents=True,exist_ok=True)
buf=io.BytesIO();Image.new('RGB',(320,180),(240,120,70)).save(buf,format='PNG');raw=buf.getvalue();(out/'piece-recette.png').write_bytes(raw)
def upload(c,name='piece-recette.png',content=raw):return call(c,'file_upload',{'case':rid,'filename':name,'content':base64.b64encode(content).decode()})
check('anonymous_denied',call(Client())[0]==403);check('reader_upload_denied',upload(y)[0]==403)
st,result,_=upload(x);check('real_upload_clean',st==200 and result['files'][0]['status']=='clean');aid=result['files'][0]['id']
check('metadata_persistent',call(y)[1]['files'][0]['id']==aid)
def get(c,preview=False,o=org,case=None,attachment=aid):return call(c,'file_preview' if preview else 'file_download',{'case':case or rid,'attachment':attachment,**({'page':1} if preview else {})},o)
check('download_without_authority_denied',get(y)[0]==403)
st,result,_=get(x);check('exact_download_bytes',st==200 and base64.b64decode(result['content'])==raw)
st,result,_=get(y,True);check('reader_preview_allowed',st==200 and result['image'].startswith('data:image/png;base64,'))
check('foreign_org_denied',get(y,o=foreign)[0]==403)
check('wrong_parent_denied',get(x,case=str(uuid.uuid4()))[0]==403)
check('wrong_attachment_denied',get(x,attachment=str(uuid.uuid4()))[0]==403)
app.sessions.clock=lambda:time.time()+61
check('invalid_extension_denied',upload(x,'false.pdf',b'not a pdf')[0]!=200)
eicar=b'X5O!P%@AP[4'+b'\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
check('infected_blocked',upload(x,'eicar-recette.txt',eicar)[0]!=200)
blocked=next(f for f in call(x)[1]['files'] if f['filename']=='eicar-recette.txt');check('quarantine_recorded',blocked['status']=='infected')
check('quarantine_download_denied',get(x,attachment=blocked['id'])[0]==403)
check('quarantine_preview_denied',get(x,True,attachment=blocked['id'])[0]==403)
path=sql(f"select object_name from public.uniion_attachments where id='{aid}'")
from uniion.adapters import attachments
try:attachments.storage(api,x.state()['access_token'],path);direct=True
except AccessDenied:direct=False
check('direct_storage_denied',not direct)
# Reassignment must revoke the old owner's files, too.
sql(f"insert into public.uniion_permissions values('{org}','{b['id']}','dossiers','write');update public.uniion_resource_grants set can_write=true where resource_id='{rid}' and user_id='{b['id']}'")
check('reassignment',call(x,'assign',{'id':rid,'version':1,'user':b['id']})[0]==200)
check('old_owner_list_denied',call(x)[0]==403);check('old_owner_preview_denied',get(x,True)[0]==403);check('old_owner_download_denied',get(x)[0]==403)
check('new_owner_preview',get(y,True)[0]==200);check('new_owner_no_implicit_download',get(y)[0]==403)
# Separate browser dossier: writer and reader, no writes granted to the reader.
st,row,_=call(x,'create',{'title':'Coffre interface S05','long':'Fichiers fictifs mobile tablette desktop.','tag':'Juridique','due':'30 j'});check('ui_case_created',st==200);ui=row['id']
sql(f"delete from public.uniion_permissions where organization_id='{org}' and user_id='{b['id']}' and module='dossiers' and permission='write';insert into public.uniion_resource_grants values('{org}','{ui}','{b['id']}',false,false,now()+interval '3 days',null);insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Gestionnaire'),('{org}','{b['id']}','Alex Recette','Lecteur');insert into uniion_private.organization_details values('{org}', '{{\"type\":\"section\"}}')")
(ROOT/'.local-auth/s05-coffre.json').write_text(json.dumps({'organization':org,'resource':ui}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

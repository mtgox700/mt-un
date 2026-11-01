from pathlib import Path
source=Path(__file__).with_name('s03_convocation_attachments.py').read_text().split("check('anonymous_denied'")[0];exec(compile(source,__file__,'exec'))
out=ROOT/'preuves/S05-classement';out.mkdir(exist_ok=True)
check('review',work(y,'review',{'version':1})[0]==200);check('publish',work(x,'publish',{'version':1})[0]==200)
p['subject']='Classement S05 — convocation fictive';p['body']='Texte de recette à accès restreint.'
check('local_delivery',send(x,p)[0]==200)
sql(f"""insert into public.uniion_module_access values('{org}','dossiers',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','dossiers','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions values('{org}','{a['id']}','dossiers','read'),('{org}','{a['id']}','dossiers','write'),('{org}','{a['id']}','dossiers','create'),('{org}','{b['id']}','dossiers','read');""")
def call(c,action,payload,o=org):return c.call('/identity/cases',{'organization_id':o,'action':action,'payload':payload})
st,row,_=call(x,'create',{'title':'Classement interface S05','long':'Sources contrôlées séparément.','tag':'Juridique','due':'30 j'});check('case_created',st==200);rid=row['id']
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null)")
def classify(c,file='',version=1,o=org,cid=p['id']):return call(c,'classify',{'case':rid,'expected':version,'convocation':cid,'file':file},o)
check('anonymous_denied',classify(Client())[0]==403)
check('reader_classification_denied',classify(y)[0]==403)
check('foreign_denied',classify(x,o=foreign)[0]==403)
check('unknown_source_denied',classify(x,cid=str(uuid.uuid4()))[0]==403)
st,r,_=classify(x);check('message_classified',st==200)
check('idempotent_link',classify(x)[1]['already'])
check('message_visible_with_source',any(t['body']==p['body'] for t in call(y,'get',{'id':rid})[1]['timeline']))
app.sessions.clock=lambda:time.time()+61
check('stale_target_denied',classify(x,'pdf',version=1)[0]!=200)
st,r,_=classify(x,'pdf',version=2);check('pdf_classified',st==200);link=r['id']
check('ics_classified',classify(x,'ics',version=3)[0]==200)
files=call(y,'files',{'case':rid})[1]['files'];check('two_file_references',len(files)==2 and all(f['classified'] for f in files))
st,r,_=call(x,'link_download',{'case':rid,'link':link});check('pdf_download',st==200 and r['filename']=='ordre-du-jour.pdf');saved=r['content']
check('preview',call(y,'link_preview',{'case':rid,'link':link})[0]==200)
sql(f"update uniion_private.agenda_audiences set audience='none' where organization_id='{org}' and user_id='{b['id']}'")
check('source_revocation_hides_text',not any(t['body']==p['body'] for t in call(y,'get',{'id':rid})[1]['timeline']))
check('source_revocation_hides_files',call(y,'files',{'case':rid})[1]['files']==[])
check('source_revocation_denies_download',call(y,'link_download',{'case':rid,'link':link})[0]==403)
check('source_revocation_denies_preview',call(y,'link_preview',{'case':rid,'link':link})[0]==403)
sql(f"update uniion_private.agenda_audiences set audience='adherents' where organization_id='{org}' and user_id='{b['id']}';update public.uniion_resource_grants set revoked_at=now() where resource_id='{rid}' and user_id='{b['id']}'")
check('case_revocation_denies_download',call(y,'link_download',{'case':rid,'link':link})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{rid}' and user_id='{b['id']}'")
# UI uses a clean second target; first target retains integration evidence.
app.sessions.clock=lambda:time.time()+122
st,row,_=call(x,'create',{'title':'Dossier cible interface','long':'Classement fictif depuis Messages.','tag':'Juridique','due':'30 j'});ui=row['id']
sql(f"insert into public.uniion_resource_grants values('{org}','{ui}','{b['id']}',false,false,now()+interval '3 days',null)")
(ROOT/'.local-auth/s05-classement.json').write_text(json.dumps({'organization':org,'resource':ui,'convocation':p['id']}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

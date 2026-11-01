from pathlib import Path
source=Path(__file__).with_name('s03_free_files.py').read_text().split("check('anonymous_upload_denied'")[0]
exec(compile(source,__file__,'exec'))
out=ROOT/'preuves/S05-finalisation';out.mkdir(exist_ok=True)
image=io.BytesIO();Image.new('RGB',(240,120),'orange').save(image,format='PNG');raw=image.getvalue()
st,ctx,_=upload(x,'preuve-classee.png',raw);check('upload_clean',st==200);aid=ctx['available'][0]['id']
check('select',work(x,'select_files',{'version':1,'files':[aid]})[0]==200)
check('review',work(y,'review',{'version':2})[0]==200);check('publish',work(x,'publish',{'version':2})[0]==200)
p.update(attachment_version=2,subject='Classement final S05',body='Contenu fictif contrôlé.')
check('delivery',send(x,p)[0]==200)
sql(f"""insert into public.uniion_module_access values('{org}','dossiers',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','dossiers','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions values('{org}','{a['id']}','dossiers','read'),('{org}','{a['id']}','dossiers','write'),('{org}','{a['id']}','dossiers','create'),('{org}','{b['id']}','dossiers','read');""")
def call(c,action,payload,o=org):return c.call('/identity/cases',{'organization_id':o,'action':action,'payload':payload})
st,row,_=call(x,'create',{'title':'Classement final S05','long':'Dossier fictif de recette.','tag':'Juridique','due':'30 j'});check('create',st==200);case=row['id']
sql(f"insert into public.uniion_resource_grants values('{org}','{case}','{b['id']}',false,false,now()+interval '3 days',null)")
def classify(c,file,expected=1):return call(c,'classify',{'case':case,'expected':expected,'convocation':p['id'],'file':file})
check('reader_denied',classify(y,aid)[0]==403)
st,r,_=classify(x,aid);check('free_file_classified',st==200);link=r['id']
app.sessions.clock=lambda:time.time()+61
st,r,_=call(y,'link_download',{'case':case,'link':link});check('bytes_exact',st==200 and base64.b64decode(r['content'])==raw)
check('preview_allowed',call(y,'link_preview',{'case':case,'link':link})[0]==200)
sql(f"update public.uniion_resource_grants set revoked_at=now() where resource_id='{rid}' and user_id='{b['id']}'")
check('source_revoked_hidden',call(y,'files',{'case':case})[1]['files']==[])
check('source_revoked_download',call(y,'link_download',{'case':case,'link':link})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{rid}' and user_id='{b['id']}'")
# Quarantine must invalidate a reference even after classification.
sql(f"update public.uniion_attachments set ready=false,scan_status='infected' where id='{aid}'")
check('quarantined_hidden',call(y,'files',{'case':case})[1]['files']==[])
check('quarantined_preview_denied',call(y,'link_preview',{'case':case,'link':link})[0]==403)
sql(f"update public.uniion_attachments set ready=true,scan_status='clean' where id='{aid}'")
check('foreign_denied',call(y,'link_download',{'case':case,'link':link},foreign)[0]==403)
# Reproduce the rapid UI sequence without weakening the real limiter.
app.sessions.clock=lambda:time.time()+122
statuses=[call(y,'files',{'case':case})[0] for _ in range(21)]
check('rapid_navigation_rate_limit_reproduced',statuses[:20]==[200]*20 and statuses[20]==429)
app.sessions.clock=lambda:time.time()+183
check('rate_limit_recovers',call(y,'files',{'case':case})[0]==200)
(ROOT/'.local-auth/s05-finalisation.json').write_text(json.dumps({'organization':org,'resource':case,'convocation':p['id'],'file':aid,'link':link}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

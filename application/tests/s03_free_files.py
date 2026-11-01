"""Local fictional file upload, quarantine, version approval and actual MIME delivery."""
from pathlib import Path
source=Path(__file__).with_name('s03_convocation_attachments.py').read_text().split("check('anonymous_denied'")[0];exec(compile(source,__file__,'exec'))
import io,base64,hashlib,email,email.policy
from PIL import Image
out=ROOT/'preuves/S03-fichiers-libres';out.mkdir(parents=True,exist_ok=True)
rid=str(uuid.uuid4());private=str(uuid.uuid4())
sql(f"""insert into public.uniion_resources(id,organization_id,module,title,body) values('{rid}','{org}','documents','Pièces de recette S03','{{}}'),('{private}','{org}','documents','Dossier privé fictif','{{}}');
insert into public.uniion_resource_grants values('{org}','{rid}','{a['id']}',true,true,now()+interval '10 days',null),('{org}','{rid}','{b['id']}',false,true,now()+interval '10 days',null),('{org}','{private}','{a['id']}',true,true,now()+interval '10 days',null);""")
def upload(c,name,raw,resource=rid):return work(c,'upload_file',{'resource':resource,'filename':name,'content':base64.b64encode(raw).decode()})
check('anonymous_upload_denied',upload(Client(),'test.txt',b'test')[0]==403)
check('reader_upload_denied',upload(y,'test.txt',b'test')[0]==403)
check('wrong_resource_denied',upload(x,'test.txt',b'test',str(uuid.uuid4()))[0]==403)
image=io.BytesIO();Image.new('RGB',(48,48),(200,70,20)).save(image,format='PNG');raws={'note-fictive.txt':b'Note de convocation fictive.','image-fictive.png':image.getvalue()}
from uniion.adapters.agenda_pdf import render
raws['document-fictif.pdf']=render(d['document'],1)
for name,raw in raws.items():
 st,ctx,_=upload(x,name,raw);check('clean_'+name,st==200)
 (out/name).write_bytes(raw)
ids=[f['id'] for f in ctx['available']];check('three_clean_files',len(ids)==3)
check('reader_sees_allowed',len(work(y,'files')[1]['available'])==3)
check('not_writer_select_denied',work(y,'select_files',{'version':1,'files':ids})[0]==403)
st,sel,_=work(x,'select_files',{'version':1,'files':ids});check('selection_persisted',st==200 and sel['version']==2 and len(work(x,'files')[1]['selected'])==3)
p={**p,'attachment_version':2,'id':str(uuid.uuid4()),'subject':'Fichiers libres '+org}
check('unreviewed_files_denied',send(x,p)[0]==403)
check('self_review_denied',work(x,'review',{'version':2})[0]==403)
check('second_actor_review',work(y,'review',{'version':2})[0]==200)
check('publication',work(x,'publish',{'version':2})[0]==200)
app.sessions.clock=lambda:time.time()+61
st,result,_=send(x,p);check('three_files_sent',st==200 and result['sent']==1)
q=urllib.parse.quote('subject:"'+p['subject']+'"')
with urllib.request.urlopen('http://127.0.0.1:54324/api/v1/search?query='+q) as response:messages=json.load(response)['messages']
check('single_delivery',len(messages)==1)
with urllib.request.urlopen('http://127.0.0.1:54324/api/v1/message/'+messages[0]['ID']+'/raw') as response:mail=email.message_from_bytes(response.read(),policy=email.policy.default)
parts={a.get_filename():a.get_payload(decode=True) for a in mail.iter_attachments()};check('five_mime_parts',len(parts)==5)
for name,raw in raws.items():check('exact_bytes_'+name,parts[name]==raw)
# Revoke source access without changing event audience: delivery must still fail.
sql(f"update public.uniion_resource_grants set revoked_at=now() where resource_id='{rid}' and user_id='{b['id']}';")
check('source_revocation_denies_send',send(x,{**p,'id':str(uuid.uuid4())})[0]==403)
check('source_revocation_hides_files',work(y,'files')[1]['available']==[])
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{rid}' and user_id='{b['id']}';")
check('foreign_org_denied',work(x,'files',o=foreign)[0]==403)
# Invalid types and infection never become selectable. No deletion of quarantine.
eicar=b'X5O!P%@AP[4'+b'\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
check('infected_blocked',upload(x,'antivirus-test.txt',eicar)[0]!=200)
check('false_pdf_blocked',upload(x,'false.pdf',b'not a pdf')[0]!=200)
check('oversize_blocked',upload(x,'large.txt',b'a'*(5*1024*1024+1))[0]!=200)
check('office_not_silently_allowed',upload(x,'unsupported.docx',b'PKfake')[0]!=200)
check('blocked_files_not_selectable',len(work(x,'files')[1]['available'])==3)
# Deselect means a new version, not a physical deletion.
st,sel,_=work(x,'select_files',{'version':2,'files':ids[:2]});check('changed_selection_new_version',st==200 and sel['version']==3)
check('old_approval_invalid',send(x,{**p,'id':str(uuid.uuid4()),'attachment_version':3})[0]==403)
check('old_version_refused',send(x,{**p,'id':str(uuid.uuid4())})[0]==403)
app.sessions.clock=lambda:time.time()+122
# Restore a validated selection for browser tests.
st,sel,_=work(x,'select_files',{'version':3,'files':ids});check('browser_selection',st==200)
check('browser_review',work(y,'review',{'version':4})[0]==200);check('browser_publish',work(x,'publish',{'version':4})[0]==200)
(ROOT/'.local-auth/s03-free-files.json').write_text(json.dumps({'organization':org,'event':eid,'resource':rid,'files':ids,'version':4}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'checks':len(checks)}))

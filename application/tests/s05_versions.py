from pathlib import Path
source=Path(__file__).with_name('s05_files.py').read_text().split('x,y=Client(),Client()')[0];exec(compile(source,__file__,'exec'))
import base64,io
from PIL import Image
out=ROOT/'preuves/S05-versions';out.mkdir(exist_ok=True)
x,y=Client(),Client();x.login(a);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret'])
def call(c,action,payload,o=org):return c.call('/identity/cases',{'organization_id':o,'action':action,'payload':payload})
st,row,_=call(x,'create',{'title':'Versions interface S05','long':'Documents fictifs de recette.','tag':'Juridique','due':'30 j'});check('create',st==200);rid=row['id']
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null);insert into public.uniion_authorities values('{org}','{a['id']}','download',false);insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Gestionnaire'),('{org}','{b['id']}','Alex Recette','Lecteur');insert into uniion_private.organization_details values('{org}', '{{\"type\":\"section\"}}')")
def png(color):
 b=io.BytesIO();Image.new('RGB',(320,180),color).save(b,format='PNG');return b.getvalue()
raw=png('orange');new=png('steelblue');(out/'version-orange.png').write_bytes(raw);(out/'version-bleue.png').write_bytes(new)
def upload(c,expected=None,content=new,name='version.png',o=org,root=None):return call(c,'file_upload' if expected is None else 'file_version',{'case':rid,'filename':name,'content':base64.b64encode(content).decode(),**({'attachment':root or aid,'expected':expected} if expected is not None else {})},o)
st,r,_=upload(x,content=raw);check('initial_clean',st==200);aid=r['files'][0]['id']
check('reader_version_denied',upload(y,1)[0]==403)
check('foreign_denied',upload(y,1,o=foreign)[0]==403)
check('unknown_root_denied',upload(x,1,root=str(uuid.uuid4()))[0]==403)
st,r,_=upload(x,1);check('version_2',st==200 and len(r['files'])==1 and r['files'][0]['version']==2);newid=r['files'][0]['attachment']
check('stale_version_denied',upload(x,1)[0]!=200)
def download(attachment):return call(x,'file_download',{'case':rid,'attachment':attachment})
check('old_bytes_preserved',base64.b64decode(download(aid)[1]['content'])==raw)
check('new_bytes_exact',base64.b64decode(download(newid)[1]['content'])==new)
def restore(c,expected,version):return call(c,'file_restore',{'case':rid,'attachment':aid,'expected':expected,'version':version})
check('reader_restore_denied',restore(y,2,1)[0]==403)
st,r,_=restore(x,2,1);check('restore_appends',st==200 and r['files'][0]['version']==3 and len(r['files'][0]['versions'])==3 and r['files'][0]['attachment']==aid)
app.sessions.clock=lambda:time.time()+61
check('stale_restore_denied',restore(x,2,2)[0]!=200)
eicar=b'X5O!P%@AP[4'+b'\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
check('infected_new_version_blocked',upload(x,3,eicar,'eicar.txt')[0]!=200)
st,r,_=call(x,'files',{'case':rid});piece=r['files'][0];check('clean_current_preserved',piece['version']==3 and piece['maxVersion']==4 and len(r['files'])==1)
check('infected_restore_denied',restore(x,4,4)[0]==403)
check('count_groups_not_versions',call(x,'get',{'id':rid})[1]['fileCount']==1)
check('history_persistent',len(call(x,'get',{'id':rid})[1]['timeline'])==4)
check('reader_no_download',call(y,'file_download',{'case':rid,'attachment':newid})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=now() where resource_id='{rid}' and user_id='{b['id']}'")
check('revoked_versions_denied',call(y,'files',{'case':rid})[0]==403)
# Restore only the fictional reader fixture for browser refusal checks.
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{rid}' and user_id='{b['id']}'")
(ROOT/'.local-auth/s05-versions.json').write_text(json.dumps({'organization':org,'resource':rid}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

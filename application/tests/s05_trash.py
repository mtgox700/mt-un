from pathlib import Path
source=Path(__file__).with_name('s05_files.py').read_text().split('x,y=Client(),Client()')[0];exec(compile(source,__file__,'exec'))
import base64,io
from PIL import Image
out=ROOT/'preuves/S05-corbeille';out.mkdir(exist_ok=True)
x,y=Client(),Client();x.login(a);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret'])
def call(c,action,payload,o=org):return c.call('/identity/cases',{'organization_id':o,'action':action,'payload':payload})
# Use the existing super admin A without changing its role. B is the fictional business writer.
sql(f"insert into public.uniion_permissions values('{org}','{b['id']}','dossiers','write'),('{org}','{b['id']}','dossiers','create');insert into public.uniion_authorities values('{org}','{b['id']}','download',false);insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Super admin de recette'),('{org}','{b['id']}','Alex Recette','Gestionnaire');insert into uniion_private.organization_details values('{org}', '{{\"type\":\"section\"}}')")
st,row,_=call(y,'create',{'title':'Corbeille interface S05','long':'Pièces fictives uniquement.','tag':'Juridique','due':'30 j'});check('create',st==200);rid=row['id']
buf=io.BytesIO();Image.new('RGB',(320,180),'orange').save(buf,format='PNG');raw=buf.getvalue();(out/'piece.png').write_bytes(raw)
st,r,_=call(y,'file_upload',{'case':rid,'filename':'piece.png','content':base64.b64encode(raw).decode()});check('upload',st==200);aid=r['files'][0]['id']
def trash(c,operation,extra={},o=org):return call(c,'file_trash',{'operation':operation,**({'case':rid} if operation not in ('admin_list','approve','reject') else {}),**extra},o)
revision=1
def req(c):return trash(c,'request',{'attachment':aid,'expected':revision,'reason':'obsolete'})
check('ungranted_request_denied',req(x)[0]==403)
check('ordinary_admin_list_denied',trash(y,'admin_list')[0]==403)
st,r,_=req(y);check('request_created',st==200);qid=r['id']
check('no_implicit_trash',len(call(y,'files',{'case':rid})[1]['files'])==1)
check('ordinary_approval_denied',trash(y,'approve',{'request':qid})[0]==403)
st,r,_=trash(x,'admin_list');check('admin_metadata_only',st==200 and any(t['id']==qid for t in r['requests']) and 'filename' not in str(r) and 'piece.png' not in str(r))
check('admin_no_business_access',call(x,'files',{'case':rid})[0]==403)
st,versioned,_=call(y,'file_version',{'case':rid,'attachment':aid,'expected':1,'filename':'version2.png','content':base64.b64encode(raw).decode()});check('version_added_after_request',st==200);newaid=versioned['files'][0]['attachment'];revision=2
check('stale_approval_denied',trash(x,'approve',{'request':qid})[0]!=200)
check('stale_request_rejected',trash(x,'reject',{'request':qid})[0]==200)
app.sessions.clock=lambda:time.time()+61
st,r,_=req(y);check('fresh_request',st==200);qid=r['id']
check('admin_approve',trash(x,'approve',{'request':qid})[0]==200)
check('hidden_from_vault',call(y,'files',{'case':rid})[1]['files']==[])
check('download_denied',call(y,'file_download',{'case':rid,'attachment':aid})[0]==403)
check('new_version_download_denied',call(y,'file_download',{'case':rid,'attachment':newaid})[0]==403)
check('preview_denied',call(y,'file_preview',{'case':rid,'attachment':aid,'page':1})[0]==403)
check('version_denied',call(y,'file_restore',{'case':rid,'attachment':aid,'expected':2,'version':1})[0]==403)
app.sessions.clock=lambda:time.time()+122
check('trash_list',trash(y,'list')[1]['rows'][0]['state']=='approved')
check('foreign_trash_denied',trash(y,'list',o=foreign)[0]==403)
check('ungranted_restore_denied',trash(x,'restore',{'request':qid})[0]==403)
app.sessions.clock=lambda:time.time()+183
check('writer_restore',trash(y,'restore',{'request':qid})[0]==200)
st,r,_=call(y,'file_download',{'case':rid,'attachment':aid});check('restored_exact_bytes',st==200 and base64.b64decode(r['content'])==raw)
check('history_preserved',len(call(y,'get',{'id':rid})[1]['timeline'])==5)
st,r,_=req(y);qid2=r['id'];check('repeat_cycle',st==200)
check('admin_reject',trash(x,'reject',{'request':qid2})[0]==200)
check('rejection_keeps_file',len(call(y,'files',{'case':rid})[1]['files'])==1)
(ROOT/'.local-auth/s05-corbeille.json').write_text(json.dumps({'organization':org,'resource':rid,'attachment':aid}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

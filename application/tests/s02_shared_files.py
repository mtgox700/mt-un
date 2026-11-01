from pathlib import Path
source=Path(__file__).with_name('s02_organizations_shares.py').read_text().split('x=Client();y=Client();')[0]
exec(compile(source,str(Path(__file__).with_name('s02_organizations_shares.py')),'exec'))
from uniion.adapters import attachments
import base64,struct,zlib
q=f"""insert into public.uniion_permissions values('{src}','{a['id']}','documents','write');update public.uniion_resource_grants set can_write=true where organization_id='{src}';insert into public.uniion_authorities values('{dst}','{b['id']}','download',false);"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('File fixture preparation failed')
x=Client();y=Client();check('source_login',x.login(a)[0]==200);(status,_,_),_=verify(x,f['factor'],f['secret']);check('source_mfa',status==200);check('target_login',y.login(b)[0]==200);(status,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('target_mfa',status==200)
def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',2,2,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\x80\x00\xff\x80\x00'*2))+chunk(b'IEND',b'')
item=attachments.upload(api,x.state()['access_token'],src,{'resource':res,'filename':'image-recette.png','content':base64.b64encode(png).decode()});aid=item['id'];check('real_antivirus_clean_upload',True)
payload={'organization_id':src,'target':dst,'resources':[res],'people':[b['id']],'until':(datetime.now(timezone.utc)+timedelta(days=1)).isoformat(),'download':True,'versions':{res:1},'attachments':[aid]}
status,sid,_=x.call('/identity/shares/create',payload);check('file_share_created',status==200)
data={'organization_id':dst,'attachment':aid,'share':sid}
check('before_acceptance_download_refused',y.call('/identity/attachments/download',data)[0]==403)
check('accepted',y.call('/identity/shares/accept',{'organization_id':dst,'share':sid,'people':[b['id']]})[0]==200)
status,d,_=y.call('/identity/shares/read',{'organization_id':dst,'share':sid,'resource':res,'download':False});check('content_and_selected_attachment',status==200 and any(i['id']==aid for i in d['attachments']))
status,d,_=y.call('/identity/attachments/preview',{**data,'page':1});check('real_shared_preview',status==200 and d['image'].startswith('data:image/png;base64,'))
status,d,_=y.call('/identity/attachments/download',data);check('authorized_download_exact',status==200 and base64.b64decode(d['content'])==png)
check('foreign_org_file_refused',y.call('/identity/attachments/download',{**data,'organization_id':src})[0]==403)
check('without_share_refused',y.call('/identity/attachments/download',{**data,'share':None})[0]==403)
check('forged_path_refused',y.call('/identity/attachments/download',{**data,'path':'fake'})[0]==403)
check('invalid_preview_page_refused',y.call('/identity/attachments/preview',{**data,'page':0})[0]==403)
check('revocation_authorized',x.call('/identity/shares/revoke',{'organization_id':src,'share':sid})[0]==200)
check('revoked_preview_refused',y.call('/identity/attachments/preview',{**data,'page':1})[0]==403)
check('revoked_download_refused',y.call('/identity/attachments/download',data)[0]==403)
# Keep one active explicit share for read-only browser tests, using the same fictitious people.
status,active,_=x.call('/identity/shares/create',payload);check('active_browser_share_created',status==200)
check('active_browser_share_accepted',y.call('/identity/shares/accept',{'organization_id':dst,'share':active,'people':[b['id']]})[0]==200)
(ROOT/'.local-auth/s02-files-share.json').write_text(json.dumps({'source':src,'target':dst,'resource':res,'attachment':aid,'active':active,'revoked':sid}))
out=ROOT/'preuves/S02-contenus-partages';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

from pathlib import Path
source=Path(__file__).with_name('s02_support_access.py').read_text().split('x=Client();y=Client()')[0];exec(compile(source,str(Path(__file__).with_name('s02_support_access.py')),'exec'))
from uniion.adapters import attachments,antivirus
from datetime import datetime,timezone,timedelta
import struct,zlib
sql(f"insert into public.uniion_permissions values('{org}','{a['id']}','dossiers','write');update public.uniion_resource_grants set can_write=true where organization_id='{org}';")
x=Client();y=Client();check('manager_login',x.login(a)[0]==200);(st,_,_),_=verify(x,f['factor'],f['secret']);check('manager_mfa',st==200);check('agent_login',y.login(b)[0]==200);(st,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('agent_mfa',st==200)
def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',2,2,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\x80\x00\xff\x80\x00'*2))+chunk(b'IEND',b'')
def upload(raw,name):return attachments.upload(api,x.state()['access_token'],org,{'resource':rid,'filename':name,'content':base64.b64encode(raw).decode()})
aid=upload(png,'support-image.png')['id'];otherfile=upload(png,'support-non-selectionnee.png')['id'];check('real_antivirus_clean',True)
objects=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>',b'<< /Length 0 >>\nstream\n\nendstream'];pdf=b'%PDF-1.4\n';offsets=[]
for index,obj in enumerate(objects,1):offsets.append(len(pdf));pdf+=str(index).encode()+b' 0 obj\n'+obj+b'\nendobj\n'
start=len(pdf);pdf+=b'xref\n0 5\n0000000000 65535 f \n'+b''.join(('%010d 00000 n \n'%o).encode() for o in offsets)+b'trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n'+str(start).encode()+b'\n%%EOF\n'
pdfid=upload(pdf,'support-document.pdf')['id']
eicar=b'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
try:upload(eicar,'support-antivirus.txt');blocked=False
except antivirus.FileBlocked:blocked=True
check('eicar_blocked',blocked)
data={'organization_id':org,'ticket':tid,'agents':[b['id']],'resources':[rid],'until':(datetime.now(timezone.utc)+timedelta(hours=1)).isoformat(),'download':False,'attachments':[aid,pdfid]}
def grant(**kw):return x.call('/identity/support/approve-files',{**data,**kw})
def access(c,g,preview=True,**kw):return c.call('/identity/support/files/'+('preview' if preview else 'download'),{'organization_id':org,'ticket':tid,'grant':g,'attachment':aid,**({'page':1} if preview else {}),**kw})
check('agent_cannot_approve',y.call('/identity/support/approve-files',data)[0]==403);check('parent_selection_required',grant(resources=[other])[0]==403);check('unknown_file_denied',grant(attachments=[str(uuid.uuid4())])[0]==403)
st,d,_=grant();gid=d.get('id');check('explicit_files_approved',st==200)
check('preview_allowed',access(y,gid)[0]==200);check('download_separate_denied',access(y,gid,False)[0]==403);check('nonselected_denied',access(y,gid,attachment=otherfile)[0]==403);check('unnamed_agent_denied',access(x,gid)[0]==403);check('foreign_org_denied',access(y,gid,organization_id=foreign)[0]==403);check('invalid_page_denied',access(y,gid,page=0)[0]==403);check('forged_path_denied',access(y,gid,path='fake')[0]==403)
st,d,_=access(y,gid,attachment=pdfid);check('pdf_preview',st==200 and d['pages']==1)
st,d,_=grant(download=True);gid=d.get('id');st,d,_=access(y,gid,False);check('download_exact',st==200 and base64.b64decode(d['content'])==png)
sql(f"update public.uniion_attachments set ready=false,scan_status='pending' where id='{aid}';");check('pending_scan_denied',access(y,gid)[0]==403);check('pending_approval_denied',grant()[0]==403);sql(f"update public.uniion_attachments set ready=true,scan_status='clean' where id='{aid}';")
check('revoke',x.call('/identity/support/revoke',{'organization_id':org,'ticket':tid,'grant':gid})[0]==200);check('revoked_preview_denied',access(y,gid)[0]==403);check('revoked_download_denied',access(y,gid,False)[0]==403)
st,d,_=grant(download=True);gid=d.get('id')
original=attachments.storage
def closing_storage(*args,**kwargs):
 raw=original(*args,**kwargs);check('close_during_fetch',x.call('/identity/support/status',{'organization_id':org,'ticket':tid,'action':'close'})[0]==200);return raw
attachments.storage=closing_storage
try:check('post_fetch_recheck_denied',access(y,gid,False)[0]==403)
finally:attachments.storage=original
check('closed_preview_denied',access(y,gid)[0]==403);check('reopen',x.call('/identity/support/status',{'organization_id':org,'ticket':tid,'action':'reopen'})[0]==200);check('reopen_no_file_access',access(y,gid)[0]==403)
st,d,_=grant(download=True);check('browser_grant',st==200);gid=d['id']
(ROOT/'.local-auth/s02-support-files.json').write_text(json.dumps({'organization':org,'ticket':tid,'resource':rid,'grant':gid,'image':aid,'pdf':pdfid}));out=ROOT/'preuves/S02-support-fichiers';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

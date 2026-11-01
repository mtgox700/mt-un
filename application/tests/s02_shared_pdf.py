from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0];exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
from uniion.adapters import attachments,antivirus
from datetime import datetime,timedelta,timezone
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());v=json.loads((ROOT/'.local-auth/s02-files-share.json').read_text());a,b=accounts;x=Client();y=Client();check('source_login',x.login(a)[0]==200);(st,_,_),_=verify(x,f['factor'],f['secret']);check('source_mfa',st==200);check('target_login',y.login(b)[0]==200);(st,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('target_mfa',st==200)
objects=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>',b'<< /Length 0 >>\nstream\n\nendstream'];pdf=b'%PDF-1.4\n';offsets=[]
for index,obj in enumerate(objects,1):offsets.append(len(pdf));pdf+=str(index).encode()+b' 0 obj\n'+obj+b'\nendobj\n'
start=len(pdf);pdf+=b'xref\n0 5\n0000000000 65535 f \n'+b''.join(('%010d 00000 n \n'%o).encode() for o in offsets)+b'trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n'+str(start).encode()+b'\n%%EOF\n'
def upload(raw,name):return attachments.upload(api,x.state()['access_token'],v['source'],{'resource':v['resource'],'filename':name,'content':base64.b64encode(raw).decode()})
item=upload(pdf,'recette-partage.pdf');check('pdf_clean',item['scan_status']=='clean')
payload={'organization_id':v['source'],'target':v['target'],'resources':[v['resource']],'people':[b['id']],'until':(datetime.now(timezone.utc)+timedelta(days=1)).isoformat(),'download':True,'versions':{v['resource']:1},'attachments':[item['id']]}
st,sid,_=x.call('/identity/shares/create',payload);check('pdf_share_created',st==200);check('pdf_share_accepted',y.call('/identity/shares/accept',{'organization_id':v['target'],'share':sid,'people':[b['id']]})[0]==200)
data={'organization_id':v['target'],'attachment':item['id'],'share':sid};st,d,_=y.call('/identity/attachments/preview',{**data,'page':1});check('real_pdf_preview',st==200 and d['pages']==1 and d['image'].startswith('data:image/png;base64,'));st,d,_=y.call('/identity/attachments/download',data);check('pdf_exact',st==200 and base64.b64decode(d['content'])==pdf)
eicar=b'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
try:upload(eicar,'recette-antivirus.txt');blocked=False
except antivirus.FileBlocked:blocked=True
check('antivirus_standard_test_blocked',blocked)
check('pdf_share_revoked',x.call('/identity/shares/revoke',{'organization_id':v['source'],'share':sid})[0]==200);check('pdf_preview_after_revoke_refused',y.call('/identity/attachments/preview',{**data,'page':1})[0]==403)
(ROOT/'preuves/S02-contenus-partages/pdf-antivirus.json').write_text(json.dumps({'count':len(checks),'checks':checks,'passed':True},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

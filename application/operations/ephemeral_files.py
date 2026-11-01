"""Real file gateway qualification against fresh Storage; reference modules read only."""
import sys,pathlib,json,base64,io,urllib.error,secrets,hashlib,datetime,zlib,struct
import backup_restore as b,restore_services as services
ROOT=pathlib.Path(__file__).resolve().parents[1]
def run(container,client,accounts,credential,check):
 (ROOT/'preuves/S01-fichiers-neufs').mkdir(exist_ok=True)
 sys.path.insert(0,str(ROOT.parent/'prototype-evolution/organisation-droits-partage/backend'))
 import attachments,antivirus
 from supabase_access import AccessDenied
 class API:
  key='';url='http://isolated'
  def request(self,path,token,body=None,method=None):
   result=services.request(client,3000,path.removeprefix('/rest/v1'),token,body,method)
   if result['status']!=200:raise AccessDenied('Isolated RPC refused')
   return result['data']
  def open(self,request,timeout=30):
   path=request.full_url.removeprefix(self.url+'/storage/v1')
   arg={'path':path,'headers':dict(request.header_items()),'method':request.get_method(),'data':base64.b64encode(request.data).decode() if request.data is not None else None}
   code="""(async()=>{let t='';for await(const c of process.stdin)t+=c;const a=JSON.parse(t);const r=await fetch('http://127.0.0.1:5000'+a.path,{method:a.method,headers:a.headers,body:a.data===null?undefined:Buffer.from(a.data,'base64')});console.log(JSON.stringify({status:r.status,body:Buffer.from(await r.arrayBuffer()).toString('base64')}))})().catch(()=>process.exit(1))"""
   result=json.loads(b.run(['docker','exec','-i',client,'node','-e',code],json.dumps(arg).encode()))
   if result['status']>=400:
    raise urllib.error.HTTPError(request.full_url,result['status'],'Storage refused',{},None)
   return io.BytesIO(base64.b64decode(result['body']))
 api=API();a,c=accounts
 password=secrets.token_urlsafe(32)
 made=services.request(client,9999,'/admin/users',credential,{'email':'scanner-ci@uniion-local.example','password':password,'email_confirm':True});check('scanner_created',made['status'] in (200,201))
 b.sql("insert into uniion_private.scan_workers values('"+made['data']['id']+"')",container,'restored')
 login=services.request(client,9999,'/token?grant_type=password',body={'email':'scanner-ci@uniion-local.example','password':password});check('scanner_login',login['status']==200)
 scanner=login['data']['access_token'];original=antivirus.worker_token;antivirus.worker_token=lambda api:scanner
 def denied(label,fn):
  try:fn();blocked=False
  except (AccessDenied,antivirus.FileBlocked):blocked=True
  check(label,blocked)
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',2,2,8,2,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+b'\x20\x80\xc0'*2)*2))+chunk(b'IEND',b'')
 def upload(raw,filename):return attachments.upload(api,a['token'],a['org'],{'resource':a['resource'],'filename':filename,'content':base64.b64encode(raw).decode()})
 try:
  clean=upload(png,'fixture.png');check('real_png_upload_scanned_clean',clean['scan_status']=='clean');aid=clean['id']
  meta,raw=attachments.download(api,a['token'],a['org'],{'attachment':aid});check('owner_download_bytes_exact',raw==png)
  preview=attachments.preview(api,a['token'],a['org'],{'attachment':aid});check('owner_preview_real_png',base64.b64decode(preview['image'].split(',')[1]).startswith(b'\x89PNG\r\n\x1a\n'))
  (ROOT/'preuves/S01-fichiers-neufs/preview-image.png').write_bytes(base64.b64decode(preview['image'].split(',')[1]))
  denied('foreign_download_denied',lambda:attachments.download(api,c['token'],c['org'],{'attachment':aid}))
  denied('foreign_preview_denied',lambda:attachments.preview(api,c['token'],c['org'],{'attachment':aid}))
  denied('foreign_storage_upload_denied',lambda:attachments.storage(api,c['token'],meta['path'],png,'image/png'))
  denied('existing_file_overwrite_denied',lambda:attachments.storage(api,a['token'],meta['path'],png,'image/png'))
  denied('direct_storage_owner_denied',lambda:attachments.storage(api,a['token'],meta['path']))
  until=(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(hours=1)).isoformat()
  share=api.request('/rest/v1/rpc/uniion_share_create',a['token'],{'p_org':a['org'],'p_target':c['org'],'p_resources':[a['resource']],'p_people':[c['id']],'p_until':until,'p_download':True,'p_versions':{a['resource']:1},'p_attachments':[aid]})
  api.request('/rest/v1/rpc/uniion_share_accept',c['token'],{'p_org':c['org'],'p_share':share,'p_people':[c['id']]})
  data={'attachment':aid,'share':share}
  denied('recipient_without_download_permission_denied',lambda:attachments.download(api,c['token'],c['org'],data))
  b.sql("insert into public.uniion_authorities values('"+c['org']+"','"+c['id']+"','download',false)",container,'restored')
  check('explicit_shared_download_exact',attachments.download(api,c['token'],c['org'],data)[1]==png)
  check('explicit_shared_preview',attachments.preview(api,c['token'],c['org'],data)['image'].startswith('data:image/png;base64,'))
  api.request('/rest/v1/rpc/uniion_share_revoke',a['token'],{'p_org':a['org'],'p_share':share})
  denied('revoked_file_download_denied',lambda:attachments.download(api,c['token'],c['org'],data))
  denied('revoked_file_preview_denied',lambda:attachments.preview(api,c['token'],c['org'],data))
  objects=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>',b'<< /Length 0 >>\nstream\n\nendstream']
  pdf=b'%PDF-1.4\n';offsets=[]
  for index,obj in enumerate(objects,1):
   offsets.append(len(pdf));pdf+=str(index).encode()+b' 0 obj\n'+obj+b'\nendobj\n'
  start=len(pdf);pdf+=b'xref\n0 5\n0000000000 65535 f \n'+b''.join(('%010d 00000 n \n'%offset).encode() for offset in offsets)+b'trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n'+str(start).encode()+b'\n%%EOF\n'
  document=upload(pdf,'fixture.pdf');check('real_pdf_upload_scanned_clean',document['scan_status']=='clean')
  rendered=attachments.preview(api,a['token'],a['org'],{'attachment':document['id']});check('real_pdf_preview_page',rendered['pages']==1 and rendered['image'].startswith('data:image/png;base64,'))
  (ROOT/'preuves/S01-fichiers-neufs/preview-pdf.png').write_bytes(base64.b64decode(rendered['image'].split(',')[1]))
  check('pdf_download_bytes_exact',attachments.download(api,a['token'],a['org'],{'attachment':document['id']})[1]==pdf)
  eicar=b'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
  denied('real_antivirus_eicar_blocked',lambda:upload(eicar,'antivirus-test.txt'))
  rows=json.loads(b.sql("select json_agg(json_build_object('id',id,'status',scan_status,'ready',ready)) from public.uniion_attachments where filename='antivirus-test.txt'",container,'restored'))
  check('infected_remains_quarantined',len(rows)==1 and rows[0]['status']=='infected' and not rows[0]['ready'])
  denied('infected_download_denied',lambda:attachments.download(api,a['token'],a['org'],{'attachment':rows[0]['id']}))
 finally:antivirus.worker_token=original

from pathlib import Path
exec(compile(Path(__file__).with_name('s04_corrections.py').read_text().rsplit('out=ROOT/',1)[0],__file__,'exec'))
import base64
out=ROOT/'preuves/S04-dates-justificatifs';out.mkdir(parents=True,exist_ok=True)
app.sessions.clock=lambda:time.time()+366
entry=call(x)[1]['rows'][0]['duesLedger'][-1]
pay={'id':entry['id'],'amount_cents':100,'effective_on':'2026-10-20','request_id':str(uuid.uuid4())}
for value in ['2026-02-30','2999-01-01','',None]:check('invalid_effective_'+str(value),call(x,'payment',{**pay,'effective_on':value})[0]==403)
st,r,_=call(x,'payment',pay);payment=r['rows'][0]['duesLedger'][-1]['payments'][0];pid=payment['id'];check('effective_date_persisted',st==200 and payment['effectiveOn']=='2026-10-20' and payment['recordedAt'][:10]!='2026-10-20')
check('same_date_retry',call(x,'payment',pay)[0]==200)
check('changed_date_retry_refused',call(x,'payment',{**pay,'effective_on':'2026-10-21'})[0]==403)
check('audited_date_correction',call(x,'correct',{'id':pid,'revision':0,'amount_cents':100,'effective_on':'2026-10-21','reason':'Date corrigée fictive','request_id':str(uuid.uuid4())})[0]==200)
v=call(x)[1]['rows'][0]['duesLedger'][-1]['payments'][0];check('both_dates_preserved',v['effectiveOn']=='2026-10-21' and v['originalEffectiveOn']=='2026-10-20')
def evidence(c,action,p={},o=org):return call(c,'evidence_'+action,{'payment':pid,**p},o=o)
raw=b'Justificatif fictif de reglement - aucune donnee reelle.'
upload={'filename':'justificatif-fictif.txt','content':base64.b64encode(raw).decode(),'request_id':str(uuid.uuid4())}
check('anonymous_evidence_denied',evidence(Client(),'list')[0]==403)
check('nonfinancial_evidence_denied',evidence(y,'list')[0]==403)
check('nonfinancial_upload_denied',evidence(y,'upload',upload)[0]==403)
check('foreign_evidence_denied',evidence(y,'list',o=foreign)[0]==403)
st,ctx,_=evidence(x,'upload',upload);check('clean_evidence_uploaded',st==200 and ctx['files'][0]['status']=='clean');aid=ctx['files'][0]['id']
check('identical_upload_retry',len(evidence(x,'upload',upload)[1]['files'])==1)
check('altered_upload_retry_refused',evidence(x,'upload',{**upload,'filename':'other.txt'})[0]==403)
app.sessions.clock=lambda:time.time()+427
check('download_permission_required',evidence(x,'download',{'id':aid})[0]==403)
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','download',false)")
st,result,_=evidence(x,'download',{'id':aid});check('exact_authorized_download',st==200 and base64.b64decode(result['content'])==raw)
check('nonfinancial_download_denied',evidence(y,'download',{'id':aid})[0]==403)
check('foreign_download_denied',evidence(y,'download',{'id':aid},o=foreign)[0]==403)
eicar=b'X5O!P%@AP[4'+b'\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
check('antivirus_blocks',evidence(x,'upload',{'filename':'eicar-test.txt','content':base64.b64encode(eicar).decode(),'request_id':str(uuid.uuid4())})[0]==403)
items=evidence(x,'list')[1]['files'];blocked=next(f['id'] for f in items if f['status']=='blocked')
check('quarantine_not_downloadable',evidence(x,'download',{'id':blocked})[0]==403)
check('invalid_pdf_denied',evidence(x,'upload',{'filename':'bad.pdf','content':base64.b64encode(b'fake').decode(),'request_id':str(uuid.uuid4())})[0]!=200)
try:api.request('/rest/v1/rpc/uniion_dues_evidence_finish',x.state()['access_token'],{'p_id':blocked,'p_sha':'0'*64,'p_status':'clean'});ok=False
except AccessDenied:ok=True
check('client_cannot_mark_clean',ok)
path=sql(f"select path from uniion_private.dues_evidence where id='{aid}'")
from uniion.adapters.attachments import storage
try:storage(api,x.state()['access_token'],path);ok=False
except AccessDenied:ok=True
check('direct_storage_denied',ok)
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('module_revoked_download_denied',evidence(x,'download',{'id':aid})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
(out/'justificatif-fictif.txt').write_bytes(raw)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2))
(ROOT/'.local-auth/s04-evidence.json').write_text(json.dumps({'organization':org,'payment':pid,'adherent':row['id'],'file':aid}))
print(json.dumps({'passed':True,'count':len(checks)}))

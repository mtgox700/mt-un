"""Terminate a claimed worker process, then resume in a fresh process after lease expiry."""
from pathlib import Path
source=Path(__file__).with_name('s06_documents.py').read_text().split("check('anonymous_denied'")[0]
exec(compile(source,__file__,'exec'))
from uniion.adapters.antivirus import worker_token
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','download',false)")
st,row,_=call(x,'create',{'model':'courrier','document':doc});check('created',st==200);rid=row['id'];token=x.state()['access_token'];params={'p_org':org,'p_id':rid,'p_version':1}
api.request('/rest/v1/rpc/uniion_document_job',token,{**params,'p_action':'start'})
child="""import sys,json,os
from uniion.adapters.supabase_transport import SupabaseAccess
a=json.load(sys.stdin);api=SupabaseAccess('http://127.0.0.1:54321','',local=True)
c=api.request('/rest/v1/rpc/uniion_document_job',a['token'],{**a['params'],'p_action':'claim'})
print(json.dumps(c),flush=True);os._exit(0)
"""
p=subprocess.run([sys.executable,'-B','-c',child],input=json.dumps({'token':token,'params':params}).encode(),capture_output=True,cwd=ROOT,timeout=20);check('claimed_process_exited',p.returncode==0);old=json.loads(p.stdout)
check('running_survives_process_exit',api.request('/rest/v1/rpc/uniion_document_job',token,{**params,'p_action':'status'})['state']=='running')
check('unexpired_lease_not_stolen','lease' not in api.request('/rest/v1/rpc/uniion_document_job',token,{**params,'p_action':'claim'}))
# Advance only this fictional job's timestamp; production lease duration stays unchanged.
sql(f"update uniion_private.document_export_jobs set updated_at=now()-interval '6 minutes' where id='{old['id']}'")
child="""import sys,json
from uniion.adapters.supabase_transport import SupabaseAccess
from uniion.adapters.document_jobs import dispatch,_pool
a=json.load(sys.stdin);api=SupabaseAccess('http://127.0.0.1:54321','',local=True)
dispatch(api,a['token'],a['params']['p_org'],'export_start',{'id':a['params']['p_id'],'version':1});_pool.shutdown(wait=True)
"""
p=subprocess.run([sys.executable,'-B','-c',child],input=json.dumps({'token':token,'params':params}).encode(),capture_output=True,cwd=ROOT,timeout=60);check('fresh_worker_exited',p.returncode==0)
job=api.request('/rest/v1/rpc/uniion_document_job',token,{**params,'p_action':'status'});check('fresh_worker_completed_pdf',job['state']=='done' and base64.b64decode(job['result']['base64']).startswith(b'%PDF-'))
r=api.request('/rest/v1/rpc/uniion_document_job_finish',worker_token(api),{'p_job':old['id'],'p_lease':old['lease'],'p_result':None,'p_error':'unavailable'});check('obsolete_lease_cannot_overwrite',r['ok'] is False)
check('pdf_still_done',api.request('/rest/v1/rpc/uniion_document_job',token,{**params,'p_action':'status'})['state']=='done')
(ROOT/'preuves/S06-finalisation/worker-recovery.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks,'lease_expiry':'Timestamp advanced on this fictional job only'},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

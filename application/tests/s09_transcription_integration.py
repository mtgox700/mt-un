"""Real local transcription with independent worker and fictive Auth/MFA actors."""
from pathlib import Path
source=Path(__file__).with_name('s09_audio_integration.py').read_text().split("check('invalid_container_refused'")[0].replace('preuves/S09-A2-audio','preuves/S09-C')
exec(compile(source,__file__,'exec'))
import secrets,sys
sys.path.insert(0,str(ROOT/'operations'))
from transcription_worker import process_one
config=ROOT/'.local-auth/transcription-worker.json'
if not config.exists():
 account={'email':'transcription-'+uuid.uuid4().hex+'@uniion-local.example','password':secrets.token_urlsafe(32)}
 u=api.request('/auth/v1/signup',body=account);account['id']=u.get('user',u)['id']
 config.touch(mode=0o600);config.write_text(json.dumps(account))
else:account=json.loads(config.read_text())
sql(f"insert into uniion_private.transcription_workers values('{account['id']}') on conflict do nothing")
sql(f"update auth.users set email_confirmed_at=now() where id='{account['id']}' and email like 'transcription-%@uniion-local.example'")
wt=api.login(account['email'],account['password'])['access_token']
raw=(ROOT/'preuves/S09-C/parole-fictive.wav').read_bytes()
# Normalize platform WAV to strict PCM, preserving its actual samples.
buf=io.BytesIO()
with wave.open(io.BytesIO(raw)) as r, wave.open(buf,'wb') as w:
 w.setparams(r.getparams());w.writeframes(r.readframes(r.getnframes()))
raw=buf.getvalue();payload.update(content=base64.b64encode(raw).decode(),filename='parole-fictive.wav')
st,result,_=upload();check('speech_uploaded',st==200);aid=result['id']
def tx(action,c=x,organization=org):return business(c,'transcription_'+action,{'id':rid,'audio':aid},organization)
def worker(action,**kw):return api.request('/rest/v1/rpc/uniion_transcription_worker',wt,{'p_action':action,**kw})
def refused(fn):
 try:fn();return False
 except AccessDenied:return True
check('absent',tx('status')[1]['state']=='absent')
check('unauthorized_reader',tx('status',y)[0]==403)
check('foreign_org',tx('start',organization=foreign)[0]==403)
j=tx('start')[1];check('pending',j['state']=='pending');check('idempotent',tx('start')[1]['id']==j['id'])
check('ordinary_worker_refused',refused(lambda:api.request('/rest/v1/rpc/uniion_transcription_worker',x.state()['access_token'],{'p_action':'claim'})))
check('actual_worker',process_one(api,wt))
r=tx('status')[1];check('done',r['state']=='done' and r['completed']==1)
check('real_french_speech',any('vendredi' in s['text'].lower() for p in r['parts'] for s in p['result']['segments']))
(out/'result-real.json').write_text(json.dumps(r,ensure_ascii=False,indent=2))
check('completed_idempotent',tx('start')[1]['state']=='done')
check('private_jobs',sql("select not has_table_privilege('authenticated','uniion_private.transcription_jobs','select')")=='t')
meta=api.request('/rest/v1/rpc/uniion_meeting_audio',x.state()['access_token'],{'p_org':org,'p_meeting':rid,'p_action':'listen','p_payload':{'audio':aid,'audit':False}})
check('worker_cannot_read_completed_source',refused(lambda:attachments.storage(api,wt,meta['path'])))
check('no_download_inheritance',listen(download=True)[0]==403)
# New two-part recording with an absolute timeline.
recording=str(uuid.uuid4());ids=[]
for position in range(2):
 st,r,_=upload(c=x,p={**payload,'request_id':recording if position==0 else str(uuid.uuid4())});check('segment_uploaded_'+str(position),st==200);ids.append(r['id'])
 check('sequence_'+str(position),call(x,'audio_sequence',{'id':rid,'audio':r['id'],'recording':recording,'position':position})[0]==200)
aid=ids[0];job=tx('start')[1];check('two_sources',job['total']==2)
claim=worker('claim');args={'p_job':claim['id'],'p_lease':claim['lease']}
part=worker('next',**args)
check('leased_source_readable',len(attachments.storage(api,wt,part['path']))==len(raw))
check('unleased_source_refused',refused(lambda:attachments.storage(api,wt,meta['path'])))
check('cancel_running',tx('cancel')[1]['state']=='cancelled')
check('cancel_removes_storage',refused(lambda:attachments.storage(api,wt,part['path'])))
check('late_finish_refused',refused(lambda:worker('finish',**args,p_audio=part['audio'],p_result={})))
check('explicit_retry',tx('retry')[1]['state']=='pending')
claim=worker('claim');args={'p_job':claim['id'],'p_lease':claim['lease']}
first=worker('next',**args)
known=json.loads((out/'result-real.json').read_text())['parts'][0]['result']
check('invalid_result_refused',refused(lambda:worker('finish',**args,p_audio=first['audio'],p_result={**known,'segments':[{'startMs':None,'endMs':10,'text':'fictif'}]})))
nextpart=worker('finish',**args,p_audio=first['audio'],p_result=known)
check('checkpoint',tx('status')[1]['completed']==1)
# Simulate a process loss by expiring only this test job's lease, then launch a fresh worker.
sql(f"update uniion_private.transcription_jobs set updated_at=now()-interval '7 minutes' where id='{claim['id']}'")
check('expired_lease_refused',refused(lambda:worker('next',**args)))
check('restart_resumes',process_one(api,wt))
r=tx('status')[1];check('two_parts_done',r['state']=='done' and r['completed']==2)
check('absolute_timeline',r['parts'][1]['offsetMs']==r['parts'][0]['result']['segments'][-1]['endMs'] or r['parts'][1]['offsetMs']>7000)
check('no_duplicate_checkpoint',sql(f"select count(*) from uniion_private.transcription_parts where job_id='{claim['id']}'")=='2')
(out/'result-sequence.json').write_text(json.dumps(r,ensure_ascii=False,indent=2))
check('grant_revoked',grant(a['id'],version=1,read=False,write=False)[0]==200)
check('grant_hides_transcript',tx('status')[0]==403)
check('grant_restored',grant(a['id'],version=2)[0]==200)
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='reunions'")
check('module_hides_transcript',tx('status')[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='reunions'")
st,r,_=upload(c=x,p={**payload,'request_id':str(uuid.uuid4())});check('withdraw_case_audio',st==200);aid=r['id']
check('withdraw_case_start',tx('start')[1]['state']=='pending');claim=worker('claim');args={'p_job':claim['id'],'p_lease':claim['lease']};part=worker('next',**args)
worker('error',**args);check('error_persisted',tx('status')[1]['state']=='error');check('error_retry',tx('retry')[1]['state']=='pending')
claim=worker('claim');args={'p_job':claim['id'],'p_lease':claim['lease']};part=worker('next',**args)
check('withdraw',write(version=1,accepted=False)[0]==200)
check('withdraw_stops_storage',refused(lambda:attachments.storage(api,wt,part['path'])))
check('withdraw_stops_finish',refused(lambda:worker('finish',**args,p_audio=part['audio'],p_result=known)))
check('withdraw_hides_text',tx('status')[0]==403)
(out/'integration.json').write_text(json.dumps(checks,indent=2));print({'checks':len(checks),'passed':all(c['ok'] for c in checks)})

"""A2: actual synthetic PCM bytes, local Auth/PostgreSQL/Storage/ClamAV only."""
from pathlib import Path
source=Path(__file__).with_name('s09_consent_integration.py').read_text().split("check('initial_not_attested'")[0].replace("preuves/S09-A-consentement","preuves/S09-A2-audio")
exec(compile(source,__file__,'exec'))
import wave,io,base64,hashlib
from unittest.mock import patch
from uniion.adapters import antivirus,attachments
from uniion.adapters.supabase_transport import AccessDenied
from uniion.adapters.meeting_audio import dispatch as audio_dispatch
check('consent_saved',write()[1]['current'] is True)
buf=io.BytesIO()
with wave.open(buf,'wb') as wav:
 wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(16000);wav.writeframes(b'\0\0'*1600)
raw=buf.getvalue();encoded=base64.b64encode(raw).decode();request=str(uuid.uuid4())
payload={'id':rid,'request_id':request,'consentVersion':1,'filename':'silence-fictif.wav','content':encoded}
def call(c,action,p):return business(c,action,p)
def upload(c=x,p=None):return call(c,'audio_upload',p or payload)
def listen(c=x,download=False):return call(c,'audio_download' if download else 'audio_listen',{'id':rid,'audio':aid})
check('meeting_author_has_no_implicit_audio',upload()[0]==403)
# Dedicated fictive rights manager, no existing organization's rights changed.
sql(f"insert into public.uniion_authorities values('{org}','{b['id']}','rights',false);insert into public.uniion_permissions values('{org}','{b['id']}','reunions','write');update public.uniion_resource_grants set can_write=true where organization_id='{org}' and user_id='{b['id']}' and resource_id='{rid}'")
def grant(user,version=0,**values):return call(y,'audio_grant',{'id':rid,'user':user,'version':version,'read':True,'write':True,'download':False,**values})
check('manager_self_grant_refused',grant(b['id'])[0]==403)
check('audio_rights_granted',grant(a['id'])[0]==200)
check('stale_grant_refused',grant(a['id'])[0]==403)
check('manager_has_no_implicit_audio',call(y,'audio_list',{'id':rid})[0]==403)
check('invalid_container_refused',upload(p={**payload,'content':base64.b64encode(b'not audio').decode()})[0]==403)
check('stale_consent_refused',upload(p={**payload,'consentVersion':2})[0]==403)
st,result,_=upload();print({'upload_status':st,'error':result.get('error')});check('real_storage_and_scan',st==200 and result.get('status')=='clean');aid=result['id']
check('listen_exact_bytes',base64.b64decode(listen()[1]['content'])==raw)
check('download_separate_refused',listen(download=True)[0]==403)
check('idempotent_upload',upload()[1]['id']==aid)
check('request_collision_refused',upload(p={**payload,'filename':'autre.wav'})[0]==403)
check('download_granted',grant(a['id'],version=1,download=True)[0]==200)
check('download_exact_hash',hashlib.sha256(base64.b64decode(listen(download=True)[1]['content'])).hexdigest()==hashlib.sha256(raw).hexdigest())
meta=api.request('/rest/v1/rpc/uniion_meeting_audio',x.state()['access_token'],{'p_org':org,'p_meeting':rid,'p_action':'listen','p_payload':{'audio':aid,'audit':False}})
def refused(fn):
 try:fn();return False
 except AccessDenied:return True
check('direct_storage_read_denied',refused(lambda:attachments.storage(api,x.state()['access_token'],meta['path'])))
check('direct_storage_write_denied',refused(lambda:attachments.storage(api,x.state()['access_token'],meta['path'],raw,'audio/wav')))
check('forged_scan_denied',refused(lambda:api.request('/rest/v1/rpc/uniion_meeting_audio_finish',x.state()['access_token'],{'p_id':aid,'p_sha':meta['sha256'],'p_status':'clean'})))
check('foreign_org_denied',business(x,'audio_listen',{'id':rid,'audio':aid},foreign)[0]==403)
check('private_tables',sql("select not has_table_privilege('authenticated','uniion_private.meeting_audio','select') and not has_table_privilege('authenticated','uniion_private.meeting_audio_grants','update')")=='t')
check('consent_snapshot',sql(f"select consent_version=1 and meeting_version=1 and consent_actor='{a['id']}' and participants='[]'::jsonb from uniion_private.meeting_audio where id='{aid}'")=='t')
# Scanner outage leaves actual uploaded bytes pending; ordinary read cannot release them.
pending={**payload,'request_id':str(uuid.uuid4()),'filename':'attente.wav'}
with patch.object(antivirus,'scan',side_effect=antivirus.ScanUnavailable('recette')):
 try:audio_dispatch(api,x.state()['access_token'],org,'audio_upload',pending);ok=False
 except antivirus.ScanUnavailable:ok=True
check('scanner_outage_fails_closed',ok)
rows=call(x,'audio_list',{'id':rid})[1]['files'];pid=next(v['id'] for v in rows if v['filename']=='attente.wav')
check('pending_unreadable',call(x,'audio_listen',{'id':rid,'audio':pid})[0]==403)
check('retry_real_scan_reuses_pending',upload(p=pending)[1]['id']==pid)
# Real antivirus detection in a syntactically valid PCM payload.
eicar=b'X5O!P%@AP[4'+bytes([92])+b'PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
ebuf=io.BytesIO()
with wave.open(ebuf,'wb') as w:
 w.setnchannels(1);w.setsampwidth(2);w.setframerate(16000);w.writeframes(eicar)
infected={**payload,'request_id':str(uuid.uuid4()),'filename':'test-antivirus.wav','content':base64.b64encode(ebuf.getvalue()).decode()}
eicar_verdict=antivirus.scan(eicar)
check('real_eicar_scanner_detection',eicar_verdict[0]=='infected')
with patch.object(antivirus,'scan',return_value=eicar_verdict):
 check('infected_verdict_blocks_audio',upload(p=infected)[0]==403)
blocked=next(v for v in call(x,'audio_list',{'id':rid})[1]['files'] if v['filename']=='test-antivirus.wav')
check('blocked_persisted',blocked['status']=='blocked')
check('blocked_unreadable',call(x,'audio_listen',{'id':rid,'audio':blocked['id']})[0]==403)
check('blocked_retry_refused',upload(p=infected)[0]==403)
check('audio_grant_revoked',grant(a['id'],version=2,read=False,write=False,download=False)[0]==200)
check('audio_revocation_denies_read',listen()[0]==403)
check('audio_revocation_denies_upload',upload()[0]==403)
check('audio_grant_restored',grant(a['id'],version=3,download=True)[0]==200)
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}'")
check('disabled_module_denied',listen()[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}';insert into uniion_private.membership_suspensions values('{org}','{a['id']}',true)")
check('suspended_member_denied',listen()[0]==403)
sql(f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}';update public.uniion_resource_grants set revoked_at=now() where organization_id='{org}' and user_id='{a['id']}' and resource_id='{rid}'")
check('meeting_acl_revoked_denied',listen()[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null where organization_id='{org}' and user_id='{a['id']}' and resource_id='{rid}'")
check('acl_restored_read',listen()[0]==200)

# Fresh application/session proves durable bytes and metadata.
app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url}),api)
x=Client();check('restart_login',x.login(a)[0]==200);check('restart_mfa',verify(x,f['authorFactor'],f['authorSecret'])[0][0]==200)
check('restart_read',base64.b64decode(listen(x)[1]['content'])==raw)
check('withdraw_consent',write(x,version=1,accepted=False)[0]==200)
check('withdrawal_blocks_audio',listen(x)[0]==403)
check('renew_consent',write(x,version=2)[0]==200)
check('renewal_does_not_reactivate_old_take',listen(x)[0]==403)
new={**payload,'request_id':str(uuid.uuid4()),'consentVersion':3};st,result,_=upload(x,new);check('new_take_after_renewal',st==200);aid=result['id']
# Withdrawal while scan is in progress: bytes remain, response cannot claim usable success.
original_scan=antivirus.scan
def withdrawing_scan(data):
 result=original_scan(data);check('withdraw_during_scan',write(x,version=3,accepted=False)[0]==200);return result
with patch.object(antivirus,'scan',side_effect=withdrawing_scan):
 check('late_upload_withheld',upload(x,{**new,'request_id':str(uuid.uuid4())})[0]==403)
check('no_original_deleted',sql(f"select count(*)>=4 from uniion_private.meeting_audio where organization_id='{org}'")=='t')
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks,'audio':'synthetic PCM WAV; real ClamAV success and raw EICAR detection; explicit injected outage/infected verdict/race'},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

"""E: fictive-only exact inventory, approval, real bytes deletion and restore."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
(root/'preuves/S09-E').mkdir(exist_ok=True)
source=Path(__file__).with_name('s09_minutes_integration.py').read_text().split("check('publish_idempotent'")[0].replace('preuves/S09-D','preuves/S09-E')
exec(compile(source,__file__,'exec'))
import secrets
# Populate actual original-upload parts through their normal authenticated RPCs.
check('original_begin',call(x,'audio_source_begin',{'id':rid,'audio':aid,'filename':'original-fictif.wav','size':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})[0]==200)
for n,start in enumerate(range(0,len(raw),262144)):
 check('original_part_'+str(n),call(x,'audio_source_part',{'id':rid,'audio':aid,'part':n,'content':base64.b64encode(raw[start:start+262144]).decode()})[0]==200)
check('original_confirmed',call(x,'audio_source_complete',{'id':rid,'audio':aid})[0]==200)
# Saved transfer blocks are retained in normal browser uploads. This direct-upload
# fixture supplies equivalent fictive blocks so erasure checks are non-vacuous.
for n,start in enumerate(range(0,len(raw),262144)):
 sql(f"insert into uniion_private.meeting_audio_chunks values('{aid}',{n},decode('{base64.b64encode(raw[start:start+262144]).decode()}','base64'))")
check('bytes_present_before_deletion',int(sql(f"select count(*) from uniion_private.meeting_audio_chunks where audio_id='{aid}'"))>0 and int(sql(f"select count(*) from uniion_private.meeting_audio_original_parts where audio_id='{aid}'"))>0)
from audio_retention import execute
# Dedicated test operator, not an existing actor promoted globally.
admin={'email':'s09-retention-'+uuid.uuid4().hex+'@uniion-local.example','password':secrets.token_urlsafe(32)}
u=api.request('/auth/v1/signup',body=admin);admin['id']=u.get('user',u)['id']
sql(f"update auth.users set email_confirmed_at=now() where id='{admin['id']}';insert into uniion_private.super_admins values('{admin['id']}',true)")
z=Client();check('operator_login',z.login(admin)[0]==200)
check('aal1_operator_refused',business(z,'retention_list',{})[0]==403)
st,factor,_=z.call('/auth/mfa/enroll',{'name':'Recette E'});check('operator_enroll',st==200)
check('operator_mfa',verify(z,factor['id'],factor['totp']['secret'])[0][0]==200)
def retention(action,p=None,c=z,organization=org):return business(c,'retention_'+action,p or {},organization)
check('no_business_access_for_superadmin',business(z,'get',{'id':rid})[0]==403)
check('validation_from_second_review',sql(f"select count(*) from uniion_private.audio_retention_validations where audio_id='{aid}'")=='1')
check('member_status',retention('status',{'meeting':rid},x)[0]==200)
check('nonadmin_cannot_collect',retention('collect',c=x)[0]==403)
check('before_due_no_request',retention('collect')[1]['rows']==[])
# Only this fictive audio's validation date is advanced; production clock unchanged.
sql(f"update uniion_private.audio_retention_validations set validated_at=now()-interval '31 days' where audio_id='{aid}'")
st,inv,_=retention('collect');check('due_creates_request',st==200 and len(inv['rows'])==1);batch=inv['rows'][0];bid=batch['id']
check('collect_idempotent',retention('collect')[1]['rows'][0]['id']==bid)
check('deadline_does_not_delete',listen()[0]==200)
check('inventory_no_content',all(k not in json.dumps(batch['inventory']) for k in ['vendredi','participants','filename','Source privée']))
check('derived_retention_explicit',batch['inventory']['retained']['privatePV']==1 and batch['inventory']['scope']=='audio-bytes-only')
worker_token=antivirus.worker_token(api)
def run(action):return api.request('/rest/v1/rpc/uniion_audio_retention_execute',worker_token,{'p_batch':bid,'p_action':action})
check('unapproved_execution_denied',refused(lambda:run('begin')))
p={'id':bid,'inventory':batch['inventory'],'reason':'Recette fictive E, suppression audio uniquement'}
check('ordinary_approval_denied',retention('approve',p,x)[0]==403)
check('foreign_batch_denied',retention('approve',p,organization=foreign)[0]==403)
check('altered_inventory_denied',retention('approve',{**p,'inventory':{}})[0]==403)
check('hold',retention('hold',{**p,'until':'2099-01-01T00:00:00Z'})[0]==200)
check('hold_prevents_approval',retention('approve',p)[0]==403)
sql(f"update uniion_private.audio_retention_batches set hold_until=now()-interval '1 second' where id='{bid}'")
check('explicit_approval',retention('approve',p)[0]==200)
check('approval_does_not_delete',listen()[0]==200)
# Stale backup is deliberately taken BEFORE the deletion and latest revocation.
import backup_restore as backup
backup.REPORT=root/'preuves/S09-E/restore';backup.REPORT.mkdir(exist_ok=True)
receipt=backup.backup();(out/'backup.json').write_text(json.dumps(receipt,indent=2));stamp=receipt['backup']
check('backup_contains_audio',receipt['objects']>0)
manifest=json.loads(backup.decrypt(stamp,'database')['manifest.json']);physical=next(o['path'] for o in manifest['objects'] if '/'+aid+'/' in o['path'])
check('own_saved_receipt',any(r['audio']==aid for r in business(x,'retention_receipts',{})[1]['receipts']))
check('other_actor_no_receipt',not any(r['audio']==aid for r in business(y,'retention_receipts',{})[1]['receipts']))

started=run('begin');check('begin_tombstones_and_blocks',not started['done'] and listen()[0]==403)
check('finish_before_storage_denied',refused(lambda:run('finish')))
check('old_upload_cannot_resurrect',upload()[0]==403)
check('new_request_same_bytes_denied',upload(p={**payload,'request_id':str(uuid.uuid4())})[0]==403)
check('scanner_finish_cannot_resurrect',refused(lambda:api.request('/rest/v1/rpc/uniion_meeting_audio_finish',worker_token,{'p_id':aid,'p_sha':hashlib.sha256(raw).hexdigest(),'p_status':'clean'})))
sql(f"update uniion_private.super_admins set active=false where user_id='{admin['id']}'")
check('removed_approver_blocks_execution',refused(lambda:run('begin')))
sql(f"update uniion_private.super_admins set active=true where user_id='{admin['id']}'")
check('resume_execution',execute(api,worker_token,bid)['done'])
check('idempotent_execution',execute(api,worker_token,bid)['done'])
check('actual_file_gone',subprocess.run(['/Users/mt/.docker/bin/docker','exec','supabase_storage_unii','test','!','-e','/mnt/'+physical],capture_output=True).returncode==0)
check('tombstone_receipt_for_local_cleanup',any(r['audio']==aid for r in business(x,'retention_receipts',{})[1]['receipts']))
check('storage_gone',sql(f"select count(*) from storage.objects where name in(select path from uniion_private.meeting_audio where id='{aid}')")=='0')
check('db_chunks_gone',sql(f"select count(*) from uniion_private.meeting_audio_chunks where audio_id='{aid}'")=='0')
check('original_parts_gone',sql(f"select count(*) from uniion_private.meeting_audio_original_parts where audio_id='{aid}'")=='0')
check('published_copy_survives_audio_deletion',len(business(x,'publication_feed',{})[1]['rows'])==1)
check('ordinary_pv_blocked_after_deletion',get()[0]==403)
check('consent_withdrawal_after_snapshot',write(version=1,accepted=False)[0]==200)
check('copy_revocation_after_snapshot',pub('revoke',y)[0]==200)
check('audit',int(sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event like 'meeting.retention.%'"))>=5)
(out/'retention-integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2))
# IDs only; credentials never enter proof files.
(out/'restore-fixture.json').write_text(json.dumps({'organization':org,'meeting':rid,'audio':aid,'pv':pid,'batch':bid,'backup':stamp,'author':a['id'],'admin':admin['id']},indent=2))
print({'passed':True,'count':len(checks),'backup':stamp})

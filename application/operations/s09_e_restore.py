"""S09 E stale snapshot -> restrictive journal -> actual isolated Auth/RPC tests."""
import json,time,subprocess,base64,hmac,hashlib,struct,datetime
from pathlib import Path
import backup_restore as b,restore_services as s
from audio_retention_restore import journal,reconcile
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
proof=b.ROOT/'preuves/S09-E/restore';proof.mkdir(exist_ok=True);b.REPORT=proof
f=json.loads((b.ROOT/'preuves/S09-E/restore-fixture.json').read_text());checks=[];r=None;started=time.monotonic()
def check(name,ok):
 checks.append({'test':name,'ok':bool(ok)})
 (proof/'acceptance.json').write_text(json.dumps({'passed':False,'checks':checks},indent=2))
 if not ok:raise RuntimeError(name)
def otp(secret):
 d=hmac.new(base64.b32decode(secret+'='*((8-len(secret)%8)%8)),struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();i=d[-1]&15
 return str((struct.unpack('>I',d[i:i+4])[0]&0x7fffffff)%1000000).zfill(6)
try:
 captured=datetime.datetime.now(datetime.timezone.utc);manifest=json.loads(b.decrypt(f['backup'],'database')['manifest.json']);snapshot_age=(captured-datetime.datetime.fromisoformat(manifest['captured_at'])).total_seconds();data=journal();raw=b.canonical(data);key=AESGCM.generate_key(bit_length=256);nonce=__import__('secrets').token_bytes(12)
 suffix=__import__('secrets').token_hex(4)
 b.private(b.KEYS/('s09-reconcile-'+suffix+'.key'),key)
 dest=b.BACKUPS/f['backup']/('reconciliation-'+suffix+'.aesgcm');b.private(dest,nonce+AESGCM(key).encrypt(nonce,raw,f['backup'].encode()))
 encrypted=dest.read_bytes();data=json.loads(AESGCM(key).decrypt(encrypted[:12],encrypted[12:],f['backup'].encode()))
 check('independent_encrypted_journal_verified',b.digest(b.canonical(data))==b.digest(raw))
 r=b.restore(f['backup']);c=r['container']
 def sql(q):return b.sql(q,c,'restored')
 check('stale_audio_present_before_reconciliation',sql("select count(*) from storage.objects where name in(select path from uniion_private.meeting_audio where id="+b.literal(f['audio'])+")")=='1')
 check('stale_copy_not_revoked',sql("select bool_and(revoked_at is null) from uniion_private.business_publications where resource_id="+b.literal(f['pv']))=='t')
 rec=reconcile(r,data);check('journal_deletions_replayed',rec['deleted_restored_objects']>=1)
 check('no_storage_resurrection',sql("select count(*) from storage.objects where name in(select path from uniion_private.meeting_audio where id="+b.literal(f['audio'])+")")=='0')
 check('no_chunk_resurrection',sql("select count(*) from uniion_private.meeting_audio_chunks where audio_id="+b.literal(f['audio']))=='0')
 check('no_original_resurrection',sql("select count(*) from uniion_private.meeting_audio_original_parts where audio_id="+b.literal(f['audio']))=='0')
 check('consent_withdrawal_replayed',sql("select not accepted from uniion_private.meeting_consents where meeting_id="+b.literal(f['meeting']))=='t')
 check('publication_revoke_replayed',sql("select bool_and(revoked_at is not null) from uniion_private.business_publications where resource_id="+b.literal(f['pv']))=='t')
 check('reconciliation_idempotent',reconcile(r,data)['deleted_restored_objects']==0)
 client=s.start(r)
 for _ in range(100):
  if s.request(client,9999,'/health')['status']==200 and s.request(client,5000,'/status')['status']==200:break
  time.sleep(.4)
 fixture=json.loads((b.ROOT/'.local-auth/s08-fixture.json').read_text());actor=fixture['author']
 login=s.request(client,9999,'/token?grant_type=password',body={'email':actor['email'],'password':actor['password']});check('restored_login',login['status']==200);token=login['data']['access_token']
 ch=s.request(client,9999,'/factors/'+fixture['authorFactor']+'/challenge',token,{})
 v=s.request(client,9999,'/factors/'+fixture['authorFactor']+'/verify',token,{'challenge_id':ch['data']['id'],'code':otp(fixture['authorSecret'])});check('restored_mfa',v['status']==200);token=v['data']['access_token']
 def rpc(name,body):return s.request(client,3000,'/rpc/'+name,token,body)
 check('meeting_still_accessible',rpc('uniion_business_records',{'p_org':f['organization'],'p_module':'reunions','p_action':'get','p_payload':{'id':f['meeting']}})['status']==200)
 check('deleted_audio_denied',rpc('uniion_meeting_audio',{'p_org':f['organization'],'p_meeting':f['meeting'],'p_action':'listen','p_payload':{'audio':f['audio'],'audit':False}})['status']==403)
 check('private_pv_denied',rpc('uniion_business_records',{'p_org':f['organization'],'p_module':'reunions','p_action':'get','p_payload':{'id':f['pv']}})['status']==403)
 check('revoked_copy_not_republished',rpc('uniion_business_publication',{'p_org':f['organization'],'p_module':'reunions','p_action':'feed','p_payload':{}})['data']['rows']==[])
 elapsed=round(time.monotonic()-started,3)
 (proof/'acceptance.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks,'snapshot_checks':len(r['checks']),'restore_seconds':r['restore_seconds'],'total_seconds':elapsed,'reconciliation':rec,'source_unchanged':True,'snapshot_age_at_journal_seconds':round(snapshot_age,3),'rto_to_verified_access_seconds':elapsed,'rpo':'Âge du snapshot mesuré ; modifications de recette après sauvegarde réconciliées. Aucun RPO de production garanti','production_admission':False},indent=2))
 print({'passed':True,'checks':len(checks),'snapshot_checks':len(r['checks']),'seconds':elapsed})
finally:
 if r:subprocess.run(['docker','stop',*r.get('services',[]),r['container'],r['file_container']],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

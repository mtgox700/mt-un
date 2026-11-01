"""S08 isolated SQL/files + encrypted local AI snapshot restoration drill.

Never restores into the working service; no purge. Signing/session credentials
are not restored. This is a local drill, not a production backup schedule.
"""
import sys,json,time,sqlite3,secrets,subprocess,base64,hmac,hashlib,struct
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import backup_restore as b,restore_services as s
ROOT=b.ROOT;sys.path.insert(0,str(ROOT));proof=ROOT/'preuves/S08-F/restore';proof.mkdir(parents=True,exist_ok=True);b.REPORT=proof
from uniion.adapters.ai_runs import RunLedger
from uniion.adapters.ai_gateway import AIGateway
from uniion.adapters.ai_assistant import Assistant
from uniion.adapters.ai_context_service import ContextService
from uniion.adapters.supabase_transport import AccessDenied
from uniion.core.contracts import Denied
checks=[];r=None;ledger=None;started=time.monotonic()
def check(label,ok):
 checks.append({'test':label,'ok':bool(ok)})
 (proof/'acceptance.json').write_text(json.dumps({'passed':False,'checks':checks},indent=2))
 if not ok:raise RuntimeError(label)
def denied(fn):
 try:fn();return False
 except (Denied,AccessDenied):return True
def otp(secret):
 d=hmac.new(base64.b32decode(secret+'='*((8-len(secret)%8)%8)),struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();i=d[-1]&15
 return str((struct.unpack('>I',d[i:i+4])[0]&0x7fffffff)%1000000).zfill(6)
try:
 backup=b.backup();stamp=backup['backup'];(proof/'backup.json').write_text(json.dumps(backup,indent=2))
 # SQL backup and SQLite backup are separate snapshots. Every restored proposal
 # is revalidated against restored source versions before it can be admitted.
 src=ROOT/'.local-ai/runs.sqlite3'
 with sqlite3.connect(src.as_uri()+'?mode=ro',uri=True) as db:
  target=sqlite3.connect(':memory:');db.backup(target);raw=target.serialize();target.close()
 key=secrets.token_bytes(32);nonce=secrets.token_bytes(12)
 payload=b.pack({'runs.sqlite3':raw,'runs.history.key':src.with_suffix('.history.key').read_bytes()})
 b.private(b.KEYS/stamp/'ai.key',key)
 b.private(b.BACKUPS/stamp/'ai.enc',nonce+AESGCM(key).encrypt(nonce,payload,stamp.encode()))
 enc=(b.BACKUPS/stamp/'ai.enc').read_bytes()
 decoded=b.unpack(AESGCM((b.KEYS/stamp/'ai.key').read_bytes()).decrypt(enc[:12],enc[12:],stamp.encode()))
 check('ai_snapshot_roundtrip',decoded['runs.sqlite3']==raw)
 dest=ROOT/'.local-auth/s08-f'/('restore-'+secrets.token_hex(4));dest.mkdir(parents=True,mode=0o700)
 for name,content in decoded.items():b.private(dest/name,content)
 ledger=RunLedger(dest/'runs.sqlite3');check('ai_sqlite_integrity',ledger.db.execute('pragma integrity_check').fetchone()[0]=='ok')
 check('ai_schema_v2',ledger.db.execute('pragma user_version').fetchone()[0]==2)
 r=b.restore(stamp);client=s.start(r)
 for _ in range(120):
  try:
   if s.request(client,9999,'/health')['status']==200 and s.request(client,5000,'/status')['status']==200:break
  except RuntimeError:pass
  time.sleep(.5)
 f=json.loads((ROOT/'.local-auth/s08-fixture.json').read_text());fixture=json.loads((ROOT/'.local-auth/s08-b-fixture.json').read_text());org=fixture['organization'];actor=f['reader']['id']
 login=s.request(client,9999,'/token?grant_type=password',body={'email':f['reader']['email'],'password':f['reader']['password']});check('restored_login',login['status']==200);token=login['data']['access_token']
 def rpc(endpoint,data):
  result=s.request(client,3000,endpoint.removeprefix('/rest/v1'),token,data)
  if result['status']!=200:raise AccessDenied()
  return result['data']
 def policy(o):return rpc('/rest/v1/rpc/uniion_ai_policy',{'p_org':o,'p_action':'authorize','p_payload':{}})
 check('restored_aal1_denied',denied(lambda:policy(org)))
 factor=f['readerFactor'];challenge=s.request(client,9999,'/factors/'+factor+'/challenge',token,{})
 verified=s.request(client,9999,'/factors/'+factor+'/verify',token,{'challenge_id':challenge['data']['id'],'code':otp(f['readerSecret'])});check('restored_mfa',verified['status']==200);token=verified['data']['access_token']
 check('restored_policy_ready',policy(org)['ready'] is True)
 context=ContextService(rpc);service=Assistant(AIGateway(ledger=ledger),context,policy,actor)
 rows=ledger.history.rows(org,actor);check('persisted_history_present',len(rows)>0)
 valid=[]
 for row in rows:
  try:valid.append(service.read(org,row['id']))
  except (Denied,AccessDenied):pass
 check('restored_history_source_revalidated',len(valid)>0)
 item=valid[0];rid=item['id'];ref=item['response']['snapshot'][0]
 check('restored_no_implicit_replay',denied(lambda:ledger.reserve(org,actor,rid,'replay')))
 check('restored_actor_isolation',denied(lambda:ledger.history.read(org,f['author']['id'],rid)))
 check('restored_org_isolation',denied(lambda:ledger.history.read(fixture['foreign'],actor,rid)))
 original=sqlite3.connect(src.as_uri()+'?mode=ro',uri=True)
 check('memory_preference_exact',[tuple(x) for x in ledger.db.execute('select * from memory_preferences order by org,actor')]==original.execute('select * from memory_preferences order by org,actor').fetchall())
 original.close()
 b.sql(f"update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{actor}'",r['container'],'restored')
 check('restored_revocation_blocks_history',denied(lambda:service.read(org,rid)))
 # Key loss is tested only on the newly restored copy.
 ledger.close();ledger=None;key_path=dest/'runs.history.key';key_path.rename(dest/'saved-history.key')
 try:RunLedger(dest/'runs.sqlite3');missing=False
 except RuntimeError:missing=True
 check('missing_key_fails_closed',missing and not key_path.exists())
 (dest/'saved-history.key').rename(key_path)
 (proof/'acceptance.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks,'sql_checks':len(r['checks']),'elapsed_seconds':round(time.monotonic()-started,3),'restore_seconds':r['restore_seconds'],'ai_snapshot_sha256':hashlib.sha256(raw).hexdigest(),'automatic_deletion':False,'production_admission':False,'limitation':'Separate SQL and SQLite snapshots; source revalidation mandatory; no production RPO/RTO claim'},indent=2))
 print(json.dumps({'passed':True,'checks':len(checks),'sql_checks':len(r['checks'])}))
finally:
 if ledger:ledger.close()
 if r:subprocess.run(['docker','stop',*r.get('services',[]),r['container'],r['file_container']],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

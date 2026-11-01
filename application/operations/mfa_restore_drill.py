"""Real restoration of a TOTP factor, never copying source service credentials."""
import pathlib,sys,json,time,base64,hmac,hashlib,struct,fcntl,subprocess
import backup_restore as b,restore_services as services,security_cut
sys.path.insert(0,str(b.ROOT))
from uniion.adapters.supabase_transport import SupabaseAccess
accounts=json.loads((b.ROOT/'.local-auth/sessions-fixtures.json').read_text());a=accounts[0]
api=SupabaseAccess('http://127.0.0.1:54321','',local=True);factor=None;token=None;result=None;checks=[]
def check(name,ok):
 checks.append({'test':name,'ok':bool(ok)})
 if not ok:raise AssertionError(name)
def code(secret):
 raw=hmac.new(base64.b32decode(secret+'='*((8-len(secret)%8)%8)),struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();off=raw[-1]&15
 return str((struct.unpack('>I',raw[off:off+4])[0]&0x7fffffff)%1000000).zfill(6)
source=b.ROOT;cfg=json.loads((source/'operations/backup-schedule.json').read_text());lockpath=pathlib.Path(cfg['state_dir'])
if not lockpath.is_absolute():lockpath=source/lockpath
lock=open(lockpath/'runner.lock','a');fcntl.flock(lock,fcntl.LOCK_EX)
sys.path.insert(0,str(b.ROOT/'tests'))
from fixture_mfa_setup import prepare
prepare()
try:
 token=api.login(a['email'],a['password'])['access_token']
 enrollment=api.request('/auth/v1/factors',token,{'factor_type':'totp','friendly_name':'Restauration S01'});factor=enrollment['id'];secret=enrollment['totp']['secret']
 api.request('/rest/v1/rpc/uniion_mfa_authorize_factor',token,{'p_factor':factor})
 challenge=api.request('/auth/v1/factors/'+factor+'/challenge',token,{})
 verified=api.request('/auth/v1/factors/'+factor+'/verify',token,{'challenge_id':challenge['id'],'code':code(secret)});token=verified['access_token']
 api.request('/rest/v1/rpc/uniion_require_mfa',token,{})
 receipt=b.backup();check('verified_totp_in_encrypted_backup',receipt['verified_totp_factors']>=1)
 # Source factor revoked after the snapshot: checkpoint must prevent resurrection.
 api.request('/auth/v1/factors/'+factor,token,method='DELETE');revoked_factor=factor;factor=None
 security_cut.capture(receipt['backup'])
 result=b.restore(receipt['backup']);checks.extend(result['checks']);client=services.start(result)
 def request(port,path,token=None,body=None):return services.request(client,port,path,token,body)
 for _ in range(40):
  if request(9999,'/health')['status']==200:break
  time.sleep(.25)
 login=request(9999,'/token?grant_type=password',body={'email':a['email'],'password':a['password']});check('restored_password_login',login['status']==200);low=login['data']['access_token']
 path='/uniion_resources?select=id&organization_id=eq.'+a['org']
 check('restored_aal1_cannot_read',request(3000,path,low)['data']==[])
 check('old_source_token_rejected',request(3000,path,token)['status']==401)
 ch=request(9999,'/factors/'+revoked_factor+'/challenge',low,{});check('restored_totp_challenge',ch['status']==200)
 v=request(9999,'/factors/'+revoked_factor+'/verify',low,{'challenge_id':ch['data']['id'],'code':code(secret)})
 check('same_authenticator_valid_after_restore',v['status']==200);high=v['data']['access_token']
 own=request(3000,path,high);check('restored_aal2_own_resource',own['status']==200 and any(r['id']==a['resource'] for r in own['data']))
 check('restored_aal2_cross_org_denied',request(3000,'/uniion_resources?select=id&organization_id=eq.'+accounts[1]['org'],high)['data']==[])
 cut=security_cut.reconcile(result);check('post_backup_factor_revocation_reconciled',cut['restrictive_updates']>=1)
 blocked=request(9999,'/token?grant_type=password',body={'email':a['email'],'password':a['password']})
 check('revoked_factor_user_not_readmitted',blocked['status'] in (400,401,403))
 # Entry must remain shut even for an AAL2 token issued during isolated verification.
 check('drill_aal2_session_closed_after_reconciliation',request(3000,path,high)['data']==[])
 check('reconciliation_remains_isolated',result['admission'].startswith('ISOLATED'))
 result.update({'checks':checks,'passed':True,'count':len(checks),'receipt':receipt,'security_reconciliation':cut,'source_service_keys_copied':False,'source_factor_revoked':True})
 (b.REPORT/'mfa-restoration.json').write_text(json.dumps(result,indent=2))
 print(json.dumps({'passed':True,'checks':len(checks),'restore_seconds':result['restore_seconds'],'objects':receipt['objects']}))
finally:
 if factor and token:
  try:api.request('/auth/v1/factors/'+factor,token,method='DELETE')
  except Exception:print('Facteur fictif à vérifier ; aucune donnée sensible affichée.')
 if token:
  try:api.logout(token)
  except Exception:pass
 if result:
  names=result.get('services',[])+[result['file_container'],result['container']]
  subprocess.run(['docker','stop',*names],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 lock.close()

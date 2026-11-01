"""Complete lost-device recovery against isolated Auth with a fresh test service key.
No source Auth admin credential is read and no source factor is removed.
"""
import pathlib,sys,json,time,base64,hmac,hashlib,struct,subprocess,secrets
import backup_restore as b,restore_services as services
from auth_recovery_worker import run_job
from isolated_worker import execute as execute_worker
accounts=json.loads((b.ROOT/'.local-auth/sessions-fixtures.json').read_text());a,operator=accounts
result=None;checks=[];credentials={}
def check(name,ok):
 checks.append({'test':name,'ok':bool(ok)})
 if not ok:raise AssertionError(name)
def code(secret):
 raw=hmac.new(base64.b32decode(secret+'='*((8-len(secret)%8)%8)),struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();offset=raw[-1]&15
 return str((struct.unpack('>I',raw[offset:offset+4])[0]&0x7fffffff)%1000000).zfill(6)
try:
 receipt=b.backup();result=b.restore(receipt['backup']);client=services.start(result,credentials)
 # Only these two fictional users in the isolated target are prepared for first MFA.
 b.sql("update uniion_private.mfa_requirements set required=false where user_id in ("+b.literal(a['id'])+','+b.literal(operator['id'])+");insert into uniion_private.platform_operators(user_id,active) values("+b.literal(operator['id'])+",true) on conflict(user_id) do update set active=true;",result['container'],'restored')
 def req(port,path,token=None,body=None,method=None):return services.request(client,port,path,token,body,method)
 for _ in range(60):
  if req(9999,'/health')['status']==200:break
  time.sleep(.2)
 def rpc(token,name,body=None):return req(3000,'/rpc/'+name,token,body or {})
 def login(account):
  value=req(9999,'/token?grant_type=password',body={'email':account['email'],'password':account['password']});check('password_login_'+account['id'][:6],value['status']==200);return value['data']['access_token']
 def enroll(token,label):
  e=req(9999,'/factors',token,{'factor_type':'totp','friendly_name':label});check('enroll_'+label,e['status']==200);f=e['data']['id'];secret=e['data']['totp']['secret']
  check('authorize_'+label,rpc(token,'uniion_mfa_authorize_factor',{'p_factor':f})['status']==200)
  ch=req(9999,'/factors/'+f+'/challenge',token,{})
  v=req(9999,'/factors/'+f+'/verify',token,{'challenge_id':ch['data']['id'],'code':code(secret)});check('verify_'+label,v['status']==200)
  high=v['data']['access_token'];check('require_'+label,rpc(high,'uniion_require_mfa')['status']==200);return f,high
 outside={'email':'isolated-outside-uniion@uniion-local.example','password':secrets.token_urlsafe(32)}
 made=req(9999,'/admin/users',credentials['service_token'],{**outside,'email_confirm':True});check('outside_identity_created_only_on_isolated_target',made['status'] in (200,201));outside['id']=made['data']['id']
 outside_token=login(outside)
 raw=req(9999,'/factors',outside_token,{'factor_type':'totp','friendly_name':'Outside fixture'});check('outside_auth_enrollment_exists',raw['status']==200)
 outsider_factor=raw['data']['id'];outsider_secret=raw['data']['totp']['secret']
 check('outside_cannot_register_uniion_trust',rpc(outside_token,'uniion_mfa_authorize_factor',{'p_factor':outsider_factor})['status']==403)
 ch=req(9999,'/factors/'+outsider_factor+'/challenge',outside_token,{})
 v=req(9999,'/factors/'+outsider_factor+'/verify',outside_token,{'challenge_id':ch['data']['id'],'code':code(outsider_secret)});check('outside_auth_totp_verified',v['status']==200)
 check('outside_identity_recovery_denied',rpc(v['data']['access_token'],'uniion_lost_factor_request')['status']==403)
 old_factor,owner= enroll(login(a),'lost-device')
 _,reviewer=enroll(login(operator),'reviewer')
 low=login(a)
 def worker_rpc(name,body):
  value=rpc(credentials['service_token'],name,body)
  if value['status']!=200:raise PermissionError('Worker RPC refused')
  return value['data']
 deleted=[]
 def delete_factor(user,factor):
  check('worker_target_bound_to_request',user==a['id'] and factor==old_factor)
  value=req(9999,'/admin/users/'+user+'/factors/'+factor,credentials['service_token'],method='DELETE')
  if value['status'] not in (200,204,404):raise RuntimeError('Auth factor deletion refused')
  deleted.append(factor)
 cancelled=rpc(low,'uniion_lost_factor_request');check('cancellable_request_created',cancelled['status']==200)
 cancelled_id=cancelled['data']['id']
 check('requester_can_cancel',rpc(low,'uniion_lost_factor_cancel',{'p_request':cancelled_id})['status']==200)
 check('cancelled_request_cannot_be_approved',rpc(reviewer,'uniion_lost_factor_approve',{'p_request':cancelled_id,'p_verification_reference':'RECETTE identite verifiee'})['status']==403)
 try:run_job(cancelled_id,worker_rpc,delete_factor);refused=False
 except PermissionError:refused=True
 check('cancelled_request_cannot_delete_factor',refused and not deleted)
 request=rpc(low,'uniion_lost_factor_request');check('request_without_old_device',request['status']==200);rid=request['data']['id']
 check('self_approval_refused',rpc(low,'uniion_lost_factor_approve',{'p_request':rid,'p_verification_reference':'RECETTE identite verifiee'})['status']==403)
 check('ordinary_user_cannot_claim_worker_job',rpc(low,'uniion_lost_factor_claim',{'p_request':rid})['status'] in (401,403))
 try:run_job(rid,worker_rpc,delete_factor);refused=False
 except PermissionError:refused=True
 check('worker_cannot_run_before_approval',refused and not deleted)
 check('approved_by_distinct_verified_operator',rpc(reviewer,'uniion_lost_factor_approve',{'p_request':rid,'p_verification_reference':'RECETTE identite verifiee'})['status']==200)
 check('approval_not_replayable',rpc(reviewer,'uniion_lost_factor_approve',{'p_request':rid,'p_verification_reference':'RECETTE identite verifiee'})['status']==403)
 check('old_owner_business_session_closed',not rpc(owner,'uniion_session_status')['data']['allowed'])
 outcome=execute_worker(result['container'],rid,credentials['service_token']);check('real_worker_http_transport_completed',outcome['ok'] and outcome['factors_processed']==1)
 deleted.append(old_factor)
 try:run_job(rid,worker_rpc,delete_factor);refused=False
 except PermissionError:refused=True
 check('worker_job_not_replayable',refused and len(deleted)==1)
 fresh=login(a);status=rpc(fresh,'uniion_session_status')['data']
 check('mfa_still_required_after_worker',status['required'] and not status['allowed'])
 check('temporary_reenrollment_permit',status['enrollment_allowed'])
 new_factor,recovered=enroll(fresh,'replacement')
 check('replacement_distinct',new_factor!=old_factor)
 state=rpc(recovered,'uniion_session_status')['data'];check('recovered_aal2_allowed',state['allowed'] and state['aal']=='aal2')
 check('permit_consumed',not state['enrollment_allowed'])
 own=req(3000,'/uniion_resources?select=id&organization_id=eq.'+a['org'],recovered)
 check('own_data_recovered',own['status']==200 and any(x['id']==a['resource'] for x in own['data']))
 check('cross_org_still_denied',req(3000,'/uniion_resources?select=id&organization_id=eq.'+operator['org'],recovered)['data']==[])
 check('operator_no_implicit_business_access',req(3000,'/uniion_resources?select=id&organization_id=eq.'+a['org'],reviewer)['data']==[])
 check('old_factor_absent',req(9999,'/factors/'+old_factor+'/challenge',recovered,{})['status'] in (400,403,404,422))
 proof={'checks':checks,'passed':True,'count':len(checks),'isolated_target':result['container'],'source_admin_key_read':False,'source_factors_changed':False,'temporary_service_key_generated':True,'production_admission':False}
 (b.ROOT/'preuves/S01-administration/lost-factor.json').write_text(json.dumps(proof,indent=2))
 print(json.dumps({'passed':True,'count':len(checks),'source_factors_changed':False}))
finally:
 credentials.clear()
 if result:
  subprocess.run(['docker','stop',*(result.get('services',[])+[result['file_container'],result['container']])],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

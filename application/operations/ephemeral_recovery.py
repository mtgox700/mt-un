"""Complete lost-device recovery on newly generated CI identities, real HTTP worker."""
import base64,hmac,hashlib,struct,time
import backup_restore as b,restore_services as s
from isolated_worker import execute

def run(container,client,accounts,key,check):
 a,operator=accounts;old=a['factor'];old_token=a['token'];reviewer=operator['token']
 def rpc(token,name,body=None):return s.request(client,3000,'/rpc/uniion_'+name,token,body or {})
 def login():
  result=s.request(client,9999,'/token?grant_type=password',body={'email':a['email'],'password':a['password']})
  check('recovery_password_login',result['status']==200);return result['data']['access_token']
 def refused_worker(rid,label):
  # A denied SQL claim is checked separately from transport errors.
  result=rpc(key,'lost_factor_claim',{'p_request':rid});check(label,result['status']==403)
 low=login();check('lost_device_aal1_cannot_read',s.request(client,3000,'/uniion_resources?select=id',low)['data']==[])
 request=rpc(low,'lost_factor_request');check('lost_device_request_created',request['status']==200);rid=request['data']['id']
 body={'p_request':rid,'p_verification_reference':'CI fictive verification identite'}
 check('recovery_self_approval_denied',rpc(low,'lost_factor_approve',body)['status']==403)
 check('non_operator_aal2_approval_denied',rpc(reviewer,'lost_factor_approve',body)['status']==403)
 check('ordinary_claim_denied',rpc(low,'lost_factor_claim',{'p_request':rid})['status'] in (401,403))
 refused_worker(rid,'worker_before_approval_denied')
 check('request_cancelled',rpc(low,'lost_factor_cancel',{'p_request':rid})['status']==200)
 b.sql("insert into uniion_private.platform_operators(user_id,active) values('"+operator['id']+"',true)",container,'restored')
 check('cancelled_approval_denied',rpc(reviewer,'lost_factor_approve',body)['status']==403);refused_worker(rid,'cancelled_claim_denied')
 request=rpc(low,'lost_factor_request');check('replacement_request_created',request['status']==200);rid=request['data']['id'];body['p_request']=rid
 check('distinct_operator_approves',rpc(reviewer,'lost_factor_approve',body)['status']==200)
 check('approval_replay_denied',rpc(reviewer,'lost_factor_approve',body)['status']==403)
 check('old_session_closed_on_approval',not rpc(old_token,'session_status')['data']['allowed'])
 outcome=execute(container,rid,key);check('real_worker_recovery_completed',outcome['ok'] and outcome['factors_processed']==1)
 refused_worker(rid,'completed_worker_replay_denied')
 fresh=login();state=rpc(fresh,'session_status')['data']
 check('mfa_remains_mandatory',state['required'] and not state['allowed']);check('temporary_enrollment_allowed',state['enrollment_allowed'])
 check('password_only_after_recovery_denied',s.request(client,3000,'/uniion_resources?select=id',fresh)['data']==[])
 enrolled=s.request(client,9999,'/factors',fresh,{'factor_type':'totp','friendly_name':'Replacement CI'})
 check('replacement_factor_enrolled',enrolled['status']==200);factor=enrolled['data']['id'];secret=enrolled['data']['totp']['secret']
 check('replacement_trust_authorized',rpc(fresh,'mfa_authorize_factor',{'p_factor':factor})['status']==200)
 challenge=s.request(client,9999,'/factors/'+factor+'/challenge',fresh,{})
 raw=hmac.new(base64.b32decode(secret+'='*((8-len(secret)%8)%8)),struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();offset=raw[-1]&15;code=str((struct.unpack('>I',raw[offset:offset+4])[0]&0x7fffffff)%1000000).zfill(6)
 verified=s.request(client,9999,'/factors/'+factor+'/verify',fresh,{'challenge_id':challenge['data']['id'],'code':code});check('replacement_totp_verified',verified['status']==200);recovered=verified['data']['access_token']
 check('mfa_requirement_confirmed',rpc(recovered,'require_mfa')['status']==200)
 state=rpc(recovered,'session_status')['data'];check('recovered_aal2_allowed',state['allowed'] and state['aal']=='aal2');check('enrollment_permit_consumed',not state['enrollment_allowed'])
 own=s.request(client,3000,'/uniion_resources?select=id&organization_id=eq.'+a['org'],recovered)
 check('recovered_own_data_allowed',own['status']==200 and any(x['id']==a['resource'] for x in own['data']))
 check('recovered_cross_org_denied',s.request(client,3000,'/uniion_resources?select=id&organization_id=eq.'+operator['org'],recovered)['data']==[])
 check('operator_no_business_bypass',s.request(client,3000,'/uniion_resources?select=id&organization_id=eq.'+a['org'],reviewer)['data']==[])
 check('old_factor_unusable',s.request(client,9999,'/factors/'+old+'/challenge',recovered,{})['status'] in (400,403,404,422))
 check('old_token_stays_denied',s.request(client,3000,'/uniion_resources?select=id',old_token)['data']==[])
 a['token']=recovered;a['factor']=factor

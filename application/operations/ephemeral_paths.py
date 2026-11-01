"""Advanced RPC tests with fictional accounts belonging only to a fresh CI stack."""
import base64,hmac,hashlib,struct,time,datetime
import backup_restore as b,restore_services as s

def run(container,client,accounts,check):
 def rpc(a,name,body):return s.request(client,3000,'/rpc/uniion_'+name,a['token'],body)
 def code(secret):
  raw=hmac.new(base64.b32decode(secret+'='*((8-len(secret)%8)%8)),struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();off=raw[-1]&15
  return str((struct.unpack('>I',raw[off:off+4])[0]&0x7fffffff)%1000000).zfill(6)
 a,c=accounts
 b.sql(f"""insert into public.uniion_partners values('{a['org']}','{c['org']}'),('{c['org']}','{a['org']}');
update public.uniion_resources set external_share_allowed=true where id='{a['resource']}';
insert into public.uniion_permissions values('{a['org']}','{a['id']}','socle','write');
update public.uniion_resource_grants set can_write=true where user_id='{a['id']}';
insert into public.uniion_authorities values('{a['org']}','{a['id']}','share',false),('{a['org']}','{a['id']}','download',false),('{c['org']}','{c['id']}','accept',false);""",container,'restored')
 until=(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(hours=1)).isoformat()
 share={'p_org':a['org'],'p_target':c['org'],'p_resources':[a['resource']],'p_people':[c['id']],'p_until':until,'p_download':False,'p_versions':{a['resource']:1},'p_attachments':[]}
 check('share_aal1_denied',rpc(a,'share_create',share)['status']==403)
 for i,user in enumerate(accounts):
  enrolled=s.request(client,9999,'/factors',user['token'],{'factor_type':'totp','friendly_name':'Fresh CI'})
  check('mfa_enroll_'+str(i),enrolled['status']==200)
  factor=enrolled['data']['id'];user['factor']=factor;secret=enrolled['data']['totp']['secret']
  check('mfa_authorize_'+str(i),rpc(user,'mfa_authorize_factor',{'p_factor':factor})['status']==200)
  challenge=s.request(client,9999,'/factors/'+factor+'/challenge',user['token'],{})
  verified=s.request(client,9999,'/factors/'+factor+'/verify',user['token'],{'challenge_id':challenge['data']['id'],'code':code(secret)})
  check('mfa_verified_'+str(i),verified['status']==200);user['token']=verified['data']['access_token']
  check('mfa_required_'+str(i),rpc(user,'require_mfa',{})['status']==200)
  check('mfa_other_org_still_denied_'+str(i),s.request(client,3000,'/uniion_resources?select=id&organization_id=eq.'+accounts[1-i]['org'],user['token'])['data']==[])
 created=rpc(a,'share_create',share);check('explicit_share_created',created['status']==200);sid=created['data']
 read={'p_org':c['org'],'p_share':sid,'p_resource':a['resource']}
 check('share_unaccepted_denied',rpc(c,'shared_read',read)['status']==403)
 check('share_accepted',rpc(c,'share_accept',{'p_org':c['org'],'p_share':sid,'p_people':[c['id']]})['status']==200)
 check('share_explicit_read_allowed',rpc(c,'shared_read',read)['status']==200)
 check('share_does_not_open_direct_table',s.request(client,3000,'/uniion_resources?select=id&organization_id=eq.'+a['org'],c['token'])['data']==[])
 prepare={'p_org':a['org'],'p_resource':a['resource'],'p_filename':'fixture.txt','p_mime':'text/plain','p_size':4,'p_sha256':hashlib.sha256(b'test').hexdigest()}
 check('foreign_attachment_prepare_denied',rpc(c,'attachment_prepare',prepare)['status']==403)
 attachment=rpc(a,'attachment_prepare',prepare);check('own_attachment_prepare_allowed',attachment['status']==200)
 aid=attachment['data']['id']
 check('file_without_upload_finish_denied',rpc(a,'attachment_finish',{'p_org':a['org'],'p_attachment':aid})['status']==403)
 check('unscanned_file_get_denied',rpc(a,'attachment_get',{'p_org':a['org'],'p_attachment':aid})['status']==403)
 check('file_not_explicitly_shared_denied',rpc(c,'attachment_get',{'p_org':c['org'],'p_attachment':aid,'p_share':sid})['status']==403)
 check('member_cannot_read_scanner_job',rpc(a,'scan_job',{'p_attachment':aid})['status']==403)
 check('member_cannot_forge_clean_result',rpc(a,'scan_result',{'p_attachment':aid,'p_sha256':prepare['p_sha256'],'p_status':'clean','p_engine':'fictional','p_reason':'forged'})['status']==403)
 check('recipient_cannot_request_foreign_scan',rpc(c,'scan_request',{'p_org':a['org'],'p_attachment':aid})['status']==403)
 check('share_download_not_granted',rpc(c,'shared_read',{**read,'p_download':True})['status']==403)
 check('share_revoked',rpc(a,'share_revoke',{'p_org':a['org'],'p_share':sid})['status']==200)
 check('share_read_after_revocation_denied',rpc(c,'shared_read',read)['status']==403)

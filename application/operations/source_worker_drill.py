"""Opt-in source-local worker recipe: new fictional identities only, explicit private config."""
import pathlib,sys,json,uuid,secrets,urllib.request,urllib.error,base64,hmac,hashlib,struct,time,subprocess,os
import backup_restore as b,ephemeral_recovery as recovery
from auth_recovery_worker import ServerTransport,NoRedirect
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 transport=ServerTransport(ROOT/'.local-auth/auth-admin.json')
 if transport.url!='http://127.0.0.1:54321':raise RuntimeError('Local only')
 checks=[];accounts=[];run=uuid.uuid4().hex[:10]
 def check(label,ok):
  checks.append({'test':label,'ok':bool(ok)})
  if not ok:raise RuntimeError('Fictional test failed: '+label)
 def request(client,port,path,token=None,body=None,method=None):
  url=transport.url+('/auth/v1' if port==9999 else '/rest/v1')+path
  req=urllib.request.Request(url,data=json.dumps(body).encode() if body is not None else None,method=method or ('GET' if body is None else 'POST'),headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
  try:
   with urllib.request.build_opener(NoRedirect()).open(req,timeout=20) as response:return {'status':response.status,'data':json.loads(response.read() or b'{}')}
  except urllib.error.HTTPError as e:
   return {'status':e.code,'data':None}
 original_sql=b.sql
 def sql(query,container=None,db=None):return original_sql(query)
 def rpc(a,name,body=None):return request(None,3000,'/rpc/uniion_'+name,a['token'],body or {})
 def execute(container,rid,key):
  result=subprocess.run([sys.executable,'-B',str(ROOT/'operations/auth_recovery_worker.py'),rid,'--config',str(ROOT/'.local-auth/auth-admin.json')],capture_output=True,timeout=60)
  if result.returncode:raise RuntimeError('Worker CLI refused; no secrets displayed')
  return json.loads(result.stdout)
 try:
  for i in range(2):
   email=f'worker-source-{run}-{i}@uniion-local.example';password=secrets.token_urlsafe(32)
   made=transport.request('/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True})
   user=made['id'];org=str(uuid.uuid4());res=str(uuid.uuid4());a={'id':user,'org':org,'resource':res,'email':email,'password':password};accounts.append(a)
   sql(f"""begin;
insert into public.uniion_organizations(id,name) values('{org}','Recette worker MFA {run}');
insert into public.uniion_memberships(organization_id,user_id) values('{org}','{user}');
insert into public.uniion_module_access values('{org}','socle',true,true,'included',now()+interval '1 day');
insert into public.uniion_permissions values('{org}','{user}','socle','read');
insert into public.uniion_resources(id,organization_id,module,title) values('{res}','{org}','socle','Fictif worker MFA');
insert into public.uniion_resource_grants values('{org}','{res}','{user}',false,true,now()+interval '1 day',null);commit;""")
   login=request(None,9999,'/token?grant_type=password',body={'email':email,'password':password});check('fixture_login_'+str(i),login['status']==200);a['token']=login['data']['access_token']
   e=request(None,9999,'/factors',a['token'],{'factor_type':'totp','friendly_name':'Recette worker source'});check('fixture_enroll_'+str(i),e['status']==200);a['factor']=e['data']['id'];secret=e['data']['totp']['secret']
   check('fixture_trust_'+str(i),rpc(a,'mfa_authorize_factor',{'p_factor':a['factor']})['status']==200)
   ch=request(None,9999,'/factors/'+a['factor']+'/challenge',a['token'],{})
   raw=hmac.new(base64.b32decode(secret+'='*((8-len(secret)%8)%8)),struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();off=raw[-1]&15;code=str((struct.unpack('>I',raw[off:off+4])[0]&0x7fffffff)%1000000).zfill(6)
   v=request(None,9999,'/factors/'+a['factor']+'/verify',a['token'],{'challenge_id':ch['data']['id'],'code':code});check('fixture_totp_'+str(i),v['status']==200);a['token']=v['data']['access_token'];check('fixture_mfa_required_'+str(i),rpc(a,'require_mfa')['status']==200)
  recovery.s.request=request;recovery.b.sql=sql;recovery.execute=execute
  recovery.run('source-local',None,accounts,transport.key,check)
 finally:
  # Preserve all fictional data. Retire only this run's access and close its sessions.
  for a in accounts:
   original_sql("begin;update uniion_private.platform_operators set active=false where user_id='"+a['id']+"';update public.uniion_memberships set revoked_at=now() where user_id='"+a['id']+"';update auth.sessions set not_after=now() where user_id='"+a['id']+"';commit;")
  b.sql=original_sql
 proof={'passed':True,'count':len(checks),'checks':checks,'fictional_accounts_retired':True,'data_deleted':False,'source_worker_configured':True,'configuration_mode':oct((ROOT/'.local-auth/auth-admin.json').stat().st_mode&0o777)}
 dest=ROOT/'preuves/S01-worker-source';dest.mkdir(exist_ok=True);(dest/'integration.json').write_text(json.dumps(proof,indent=2));print(json.dumps({'passed':True,'count':len(checks),'fixtures_retired':True}))
if __name__=='__main__':main()

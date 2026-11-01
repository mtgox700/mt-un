"""Check S04 authorizations using real Auth sessions against the isolated restore."""
import json,time,base64,struct,hmac,hashlib
from pathlib import Path
import backup_restore as b,restore_services as s
root=Path(__file__).resolve().parents[1];proof=root/'preuves/S05-cloture'
r=json.loads(max((p for p in proof.glob('restore-*.json') if p.name!='restore-access.json'),key=lambda p:p.stat().st_mtime).read_text());client=s.start(r);checks=[]
def check(n,ok):
 checks.append({'test':n,'ok':bool(ok)})
 if not ok:raise RuntimeError(n)
for _ in range(60):
 try:
  if s.request(client,9999,'/health')['status']==200:break
 except Exception:pass
 time.sleep(.5)
accounts=json.loads((root/'.local-auth/sessions-fixtures.json').read_text());f=json.loads((root/'.local-auth/s02-browser-fixture.json').read_text());cf=json.loads((root/'.local-auth/s05-cloture-restauration.json').read_text())
def otp(secret):
 key=base64.b32decode(secret+'='*((8-len(secret)%8)%8));d=hmac.new(key,struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();i=d[-1]&15;return str((struct.unpack('>I',d[i:i+4])[0]&0x7fffffff)%1000000).zfill(6)
def rpc(token,action,payload={},org=cf['organization']):return s.request(client,3000,'/rpc/uniion_cases',token,{'p_org':org,'p_action':action,'p_payload':payload})
tokens=[]
for i,a in enumerate(accounts):
 login=s.request(client,9999,'/token?grant_type=password',body={'email':a['email'],'password':a['password']});check('restored_login_'+str(i),login['status']==200);token=login['data']['access_token']
 check('aal1_refused_'+str(i),rpc(token,'list')['status']==403)
 fid=f['factor' if i==0 else 'recipientFactor'];secret=f['secret' if i==0 else 'recipientSecret']
 challenge=s.request(client,9999,'/factors/'+fid+'/challenge',token,{})
 verified=s.request(client,9999,'/factors/'+fid+'/verify',token,{'challenge_id':challenge['data']['id'],'code':otp(secret)})
 check('restored_mfa_'+str(i),verified['status']==200);tokens.append(verified['data']['access_token'])
x,y=tokens

check('restored_case_authorized',rpc(x,'get',{'id':cf['resource']})['status']==200)
check('restored_case_reader',rpc(y,'get',{'id':cf['resource']})['status']==200)
check('restored_write_denied',rpc(y,'note',{'id':cf['resource'],'version':2,'text':'Refus fictif'})['status']==403)
params={'p_org':cf['organization'],'p_case':cf['resource'],'p_link':cf['link']}
check('restored_reference_authorized',s.request(client,3000,'/rpc/uniion_case_link',y,params)['status']==200)
b.sql("update public.uniion_resource_grants set revoked_at=now() where resource_id='"+cf['resource']+"' and user_id='"+accounts[1]['id']+"'",r['container'],'restored')
check('restored_revocation_denies_reference',s.request(client,3000,'/rpc/uniion_case_link',y,params)['status']==403)
check('private_table_denied',s.request(client,3000,'/case_links?select=id',x)['status'] in (403,404))
(proof/'restore-access.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

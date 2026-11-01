"""Check S04 authorizations using real Auth sessions against the isolated restore."""
import json,time,base64,struct,hmac,hashlib
from pathlib import Path
import backup_restore as b,restore_services as s
root=Path(__file__).resolve().parents[1];proof=root/'preuves/S04-cloture'
r=json.loads(max((p for p in proof.glob('restore-*.json') if p.name!='restore-access.json'),key=lambda p:p.stat().st_mtime).read_text());client=s.start(r);checks=[]
def check(n,ok):
 checks.append({'test':n,'ok':bool(ok)})
 if not ok:raise RuntimeError(n)
for _ in range(60):
 try:
  if s.request(client,9999,'/health')['status']==200:break
 except Exception:pass
 time.sleep(.5)
accounts=json.loads((root/'.local-auth/sessions-fixtures.json').read_text());f=json.loads((root/'.local-auth/s02-browser-fixture.json').read_text());cf=json.loads((root/'.local-auth/s04-completion.json').read_text())
def otp(secret):
 key=base64.b32decode(secret+'='*((8-len(secret)%8)%8));d=hmac.new(key,struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();i=d[-1]&15;return str((struct.unpack('>I',d[i:i+4])[0]&0x7fffffff)%1000000).zfill(6)
def rpc(token,action,payload={},org=cf['organization']):return s.request(client,3000,'/rpc/uniion_adherents',token,{'p_org':org,'p_action':action,'p_payload':payload})
tokens=[]
for i,a in enumerate(accounts):
 login=s.request(client,9999,'/token?grant_type=password',body={'email':a['email'],'password':a['password']});check('restored_login_'+str(i),login['status']==200);token=login['data']['access_token']
 check('aal1_refused_'+str(i),rpc(token,'list')['status']==403)
 fid=f['factor' if i==0 else 'recipientFactor'];secret=f['secret' if i==0 else 'recipientSecret']
 challenge=s.request(client,9999,'/factors/'+fid+'/challenge',token,{})
 verified=s.request(client,9999,'/factors/'+fid+'/verify',token,{'challenge_id':challenge['data']['id'],'code':otp(secret)})
 check('restored_mfa_'+str(i),verified['status']==200);tokens.append(verified['data']['access_token'])
x,y=tokens
rows=rpc(x,'list');check('authorized_register',rows['status']==200 and len(rows['data']['rows'])==5)
check('lists_restored',len(rows['data']['groups'])>=1)
check('reader_finance_hidden',all('duesLedger' not in a for a in rpc(y,'list')['data']['rows']))
check('foreign_isolated',rpc(y,'list',org=cf['foreign'])['data']['rows']==[])
check('nonmember_denied',rpc(x,'list',org=cf['foreign'])['status']==403)
g=rows['data']['groups'][0];p={'id':g['id'],'version':g['version'],'name':'Refus fictif','description':''}
check('reader_list_write_denied',rpc(y,'list_update',p)['status']==403)
check('foreign_list_write_denied',rpc(y,'list_update',p,org=cf['foreign'])['status']==403)
check('reader_export_denied',rpc(y,'directory_export')['status']==403)
check('writer_export_allowed',rpc(x,'directory_export')['status']==200)
check('private_table_denied',s.request(client,3000,'/member_lists?select=id',x)['status'] in (403,404))
(proof/'restore-access.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

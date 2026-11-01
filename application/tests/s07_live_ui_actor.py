"""Second fictional actor through real HTTP; no browser state access."""
from pathlib import Path
import json,urllib.request,urllib.error,http.cookiejar,time,base64,hmac,hashlib,struct,uuid,sys
ROOT=Path(__file__).resolve().parents[1];accounts=json.loads((ROOT/'.local-auth/sessions-fixtures.json').read_text());f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());fixture=json.loads((ROOT/'.local-auth/s07-e-fixture.json').read_text())
jar=http.cookiejar.CookieJar();opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar));csrf=''
def call(path,data=None):
 global csrf
 req=urllib.request.Request('http://127.0.0.1:5068'+path,data=json.dumps(data).encode() if data is not None else None,headers={'Content-Type':'application/json','Origin':'http://127.0.0.1:5068','X-Uniion-CSRF':csrf})
 with opener.open(req,timeout=20) as r:result=json.load(r)
 if 'csrf' in result:csrf=result['csrf']
 return result
call('/auth/session');call('/auth/login',{'email':accounts[0]['email'],'password':accounts[0]['password']});challenge=call('/auth/mfa/challenge',{'factor_id':f['factor']})
key=base64.b32decode(f['secret']+'='*((8-len(f['secret'])%8)%8));d=hmac.new(key,struct.pack('>Q',int(time.time())//30),hashlib.sha1).digest();off=d[-1]&15;code=str((struct.unpack('>I',d[off:off+4])[0]&0x7fffffff)%1000000).zfill(6)
call('/auth/mfa/verify',{'factor_id':f['factor'],'challenge_id':challenge['id'],'code':code})
def rpc(action,payload):return call('/identity/messaging',{'organization_id':fixture['organization'],'action':action,'payload':payload})
if sys.argv[1]=='send':
 m=rpc('send',{'id':fixture['conversation'],'clientId':str(uuid.uuid4()),'text':sys.argv[2]});print(json.dumps({'sent':True,'seq':m['seq']}))
elif sys.argv[1] in ('remove','restore'):
 g=rpc('get',{'id':fixture['conversation']});rpc('group_save',{'id':g['id'],'version':g['version'],'name':g['name'],'desc':g['desc'],'members':[] if sys.argv[1]=='remove' else [accounts[1]['id']]});print(json.dumps({'membership':sys.argv[1]}))

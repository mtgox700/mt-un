"""Read only the explicitly authorized fictional recipient's local invitation."""
import pathlib,json,urllib.request,urllib.parse,re,os
root=pathlib.Path(__file__).resolve().parents[1]
f=json.loads((root/'.local-auth/s02-browser-fixture.json').read_text())
q='to:'+f['recipient']+' subject:"Invitation uniion"'
with urllib.request.urlopen('http://127.0.0.1:54324/api/v1/search?query='+urllib.parse.quote(q)) as r:d=json.load(r)
found=None
for m in d.get('messages',d.get('Messages',[])):
 mid=m.get('ID')
 with urllib.request.urlopen('http://127.0.0.1:54324/api/v1/message/'+mid) as r:msg=json.load(r)
 text=msg.get('Text','')
 if f['organization'] in text:
  match=re.search(r'http://127\.0\.0\.1:5068/s02\?organization=[^\s]+',text)
  if match:found={'link':match.group(),'messageId':mid};break
if not found:raise RuntimeError('Fictional invitation message not found')
fd=os.open(root/'.local-auth/s02-received-invitation.json',os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
with os.fdopen(fd,'w') as o:json.dump(found,o)
print('Invitation delivered to local mailbox; link retained privately for acceptance test')

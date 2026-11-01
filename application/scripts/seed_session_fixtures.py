"""Normal Auth signup for dedicated local fictional identities; no admin key."""
import pathlib,json,secrets,urllib.request,uuid,os
ROOT=pathlib.Path(__file__).resolve().parents[1];DEST=ROOT/'.local-auth/sessions-fixtures.json'
if DEST.exists():print('Fixtures déjà présentes ; aucune réinitialisation.');raise SystemExit(0)
accounts=[]
for i in range(2):
 email='recette-s01-mfa-'+str(i)+'-'+secrets.token_hex(4)+'@uniion-local.example';password=secrets.token_urlsafe(32)
 req=urllib.request.Request('http://127.0.0.1:54321/auth/v1/signup',data=json.dumps({'email':email,'password':password}).encode(),headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req) as r:result=json.load(r)
 user=result.get('user',result);accounts.append({'id':user['id'],'email':email,'password':password,'org':str(uuid.uuid4()),'resource':str(uuid.uuid4())})
DEST.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
fd=os.open(DEST,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
with os.fdopen(fd,'w') as f:json.dump(accounts,f)
print('Deux inscriptions fictives envoyées au service mail local. Aucun secret admin utilisé.')

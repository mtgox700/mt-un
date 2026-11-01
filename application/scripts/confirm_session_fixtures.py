"""Confirm ONLY the two local fictional signup emails, then seed their own test data."""
import pathlib,json,urllib.request,urllib.parse,html,subprocess,uuid
ROOT=pathlib.Path(__file__).resolve().parents[1];accounts=json.loads((ROOT/'.local-auth/sessions-fixtures.json').read_text())
from html.parser import HTMLParser
class Links(HTMLParser):
 def __init__(self):super().__init__();self.urls=[]
 def handle_starttag(self,tag,attrs):
  if tag=='a':self.urls.extend(v for k,v in attrs if k=='href')
def get(url):
 with urllib.request.urlopen(url,timeout=10) as r:return json.load(r)
for a in accounts:
 search=get('http://127.0.0.1:54324/api/v1/search?query='+urllib.parse.quote('to:'+a['email']))
 messages=search.get('messages',[])
 if not messages:raise RuntimeError('Message de confirmation local absent')
 msg=get('http://127.0.0.1:54324/api/v1/message/'+messages[0]['ID']);parser=Links();parser.feed(msg.get('HTML',''))
 link=next((u for u in parser.urls if '/auth/v1/verify?' in u),None)
 if not link:raise RuntimeError('Lien de confirmation non trouvé')
 url=urllib.parse.urlsplit(link)
 if url.hostname not in ('127.0.0.1','localhost') or url.port!=54321:raise RuntimeError('Confirmation limitée à Supabase local')
 q=urllib.parse.parse_qs(url.query)
 req=urllib.request.Request('http://127.0.0.1:54321/auth/v1/verify',data=json.dumps({'token_hash':q['token'][0],'type':'signup'}).encode(),headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req) as response:result=json.load(response)
 except urllib.error.HTTPError:raise RuntimeError('Confirmation refusée ; aucun secret affiché') from None
 if result.get('access_token'):
  req=urllib.request.Request('http://127.0.0.1:54321/auth/v1/logout?scope=local',data=b'{}',headers={'Authorization':'Bearer '+result['access_token'],'Content-Type':'application/json'})
  urllib.request.urlopen(req).close()
statements=['begin;']
for i,a in enumerate(accounts):
 org=str(uuid.UUID(a['org']));uid=str(uuid.UUID(a['id']));rid=str(uuid.UUID(a['resource']))
 statements += [f"insert into public.uniion_organizations values('{org}','Recette S01 MFA {i}',true) on conflict do nothing;",f"insert into public.uniion_memberships values('{org}','{uid}',now()-interval '1 day',null) on conflict do nothing;",f"insert into public.uniion_module_access values('{org}','socle',true,true,'included',now()+interval '365 days') on conflict do nothing;",f"insert into public.uniion_permissions values('{org}','{uid}','socle','read') on conflict do nothing;",f"insert into public.uniion_resources(id,organization_id,module,title,body,kind,client_id) values('{rid}','{org}','socle','Dossier fictif MFA','{{}}','dossiers','s01-mfa') on conflict do nothing;",f"insert into public.uniion_resource_grants values('{org}','{rid}','{uid}',false,true,now()+interval '365 days',null) on conflict do nothing;"]
statements+=['commit;']
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input='\n'.join(statements).encode(),capture_output=True)
if p.returncode:raise RuntimeError('Provisionnement métier non confirmé')
print('Comptes fictifs confirmés via leurs emails locaux ; données de test isolées créées.')

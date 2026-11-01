"""Opt-in READ ONLY integration against existing fictional local accounts.
No user creation, no rights changes, no production database use.
"""
import json,pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from uniion.app import create_resource_app as create_app
from uniion.config import Config
from uniion.adapters.supabase_transport import SupabaseAccess,AccessDenied
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT.parent/'prototype-evolution/organisation-droits-partage'
accounts=json.loads((source/'.local-auth/accounts.json').read_text())
api=SupabaseAccess('http://127.0.0.1:54321','',local=True)
config=Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url});app=create_app(config,api)
checks=[]
def check(name,ok):
 checks.append({'test':name,'ok':bool(ok)})
 if not ok:raise AssertionError(name)
def call(token,org,resource):
 status=[];body=b''.join(app({'REQUEST_METHOD':'GET','PATH_INFO':f'/api/organizations/{org}/resources/{resource}','HTTP_AUTHORIZATION':'Bearer '+token},lambda s,h:status.append(int(s[:3]))));return status[0],json.loads(body)
tokens=[]
try:
 for a in accounts:tokens.append(api.login(a['email'],a['password'])['access_token'])
 ids=[api.resources(tokens[i],accounts[i]['org'])[0]['id'] for i in (0,1)]
 for i in (0,1):
  status,row=call(tokens[i],accounts[i]['org'],ids[i]);check('own_org_'+str(i),status==200 and row['organization_id']==accounts[i]['org'])
  check('forged_org_'+str(i),call(tokens[i],accounts[1-i]['org'],ids[1-i])[0]==403)
  check('foreign_resource_same_org_parameter_'+str(i),call(tokens[i],accounts[i]['org'],ids[1-i])[0]==403)
  check('direct_rest_rls_'+str(i),api.resources(tokens[i],accounts[1-i]['org'])==[])
 check('member_without_business_rights',call(tokens[2],accounts[0]['org'],ids[0])[0]==403)
 check('anonymous_denied',call('',accounts[0]['org'],ids[0])[0]==403)
 check('invalid_token_denied',call('invalid',accounts[0]['org'],ids[0])[0]==403)
 check('unnamed_partner_denied',call(tokens[3],accounts[0]['org'],ids[0])[0]==403)
finally:
 for token in tokens:api.logout(token)
(ROOT/'preuves/S01/integration.json').write_text(json.dumps({'checks':checks,'passed':all(c['ok'] for c in checks),'count':len(checks),'database_mutations':'Auth sessions only; business data and rights untouched'},indent=2))
print(str(len(checks))+' contrôles Supabase réels réussis.')

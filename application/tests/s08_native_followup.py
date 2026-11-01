"""Additional direct boundary checks for native lists and private case derivatives."""
from pathlib import Path
bootstrap=Path(__file__).with_name('s08_native_integration.py').read_text().split('org,foreign=')[0]
exec(compile(bootstrap,__file__,'exec'))
fixture=json.loads((ROOT/'.local-auth/s08-e-complet-fixture.json').read_text());org=fixture['organization'];refs=fixture['references']
x,y=Client(),Client();check('author_login',x.login(a)[0]==200);verify(x,f['authorFactor'],f['authorSecret']);check('reader_login',y.login(b)[0]==200);verify(y,f['readerFactor'],f['readerSecret'])
def call(c,path,data):
 app.sessions.clock=lambda:time.time()+len(checks)*11
 return c.call(path,data)
def ai(c,action,**kw):return call(c,'/identity/ai/assistant',{'organization_id':org,'action':action,**kw})
def business(c,mod,action,payload={}):return call(c,'/identity/business',{'organization_id':org,'module':mod,'action':action,'payload':payload})
for mod in ('reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis'):
 check(mod+'_real_list',business(x,mod,'list')[0]==200)
 check(mod+'_reader_cannot_create',business(y,mod,'create',{'data':{'title':'Création fictive interdite'}})[0]==403)
from uniion.adapters.ai_runs import RunLedger
import tempfile
class Fake:
 def complete(self,prompt,*args,**kw):
  source=json.loads(prompt.split('DONNEES_NON_FIABLES:\n')[1])[0]
  return json.dumps({'draft':'Un projet fictif doit être relu avant toute utilisation.','excerpts':[{'source':'S1','passage':'P1','quote':source['passages'][0]['text'][:600]}]})
with tempfile.TemporaryDirectory() as tmp:
 ledger=RunLedger(Path(tmp)/'runs.sqlite3');app.ai_gateway.ledger=ledger;app.ai_gateway.provider_factory=Fake
 # Use a new native source so the user's current UI and earlier fixtures stay unchanged.
 st,source,_=business(x,'intranet','create',{'data':{'title':'Source de dossier fictif','description':'Informations fictives pour vérifier les restrictions cumulatives.'}});check('source_created',st==200)
 rid=str(uuid.uuid4());st,result,_=call(x,'/identity/ai/chat',{'organization_id':org,'request_id':rid,'question':'Que faut-il vérifier dans ce contexte fictif ?','sources':[{'kind':'intranet','id':source['id']}],'parent':None});check('chat_created',st==200)
 st,result,_=ai(x,'create_case',id=rid,version=1);check('private_case_created',st==200);case=result['id']
 check('private_case_idempotent',ai(x,'create_case',id=rid,version=1)[1]==result)
 def get(c):return call(c,'/identity/cases',{'organization_id':org,'action':'get','payload':{'id':case}})
 check('creator_reads_derived_case',get(x)[0]==200)
 sql(f"insert into public.uniion_resource_grants values('{org}','{case}','{b['id']}',false,false,now()+interval '1 day',null)")
 check('generic_grant_cannot_expose_private_conversation',get(y)[0]==403)
 sql(f"update public.uniion_resource_grants set revoked_at=now() where organization_id='{org}' and resource_id='{source['id']}' and user_id='{a['id']}'")
 check('source_revocation_blocks_case_contract',get(x)[0]==403)
 rows=api.request('/rest/v1/uniion_resources?select=id&id=eq.'+case,x.state()['access_token'])
 check('source_revocation_blocks_direct_rls',rows==[])
 check('source_revocation_blocks_case_retry',ai(x,'create_case',id=rid,version=1)[0]==403)
 # Aggregated workspace context retains the ACL of every contributing native source.
 st,newcase,_=call(x,'/identity/cases',{'organization_id':org,'action':'create','payload':{'title':'Échéance fictive à protéger','long':'Préparer un document fictif.','tag':'Juridique','due':'Mardi'}});check('workspace_source_created',st==200)
 rid=str(uuid.uuid4());st,result,_=call(x,'/identity/ai/chat',{'organization_id':org,'request_id':rid,'question':'Quelles priorités fictives retenir ?','sources':[],'parent':None});check('workspace_chat_created',st==200)
 st,derived,_=ai(x,'create_case',id=rid,version=1);check('workspace_case_created',st==200)
 sql(f"update public.uniion_resource_grants set revoked_at=now() where organization_id='{org}' and resource_id='{newcase['id']}' and user_id='{a['id']}'")
 st,_,_=call(x,'/identity/cases',{'organization_id':org,'action':'get','payload':{'id':derived['id']}});check('workspace_dependency_revocation_blocks_case',st==403)
 check('workspace_dependency_rls',api.request('/rest/v1/uniion_resources?select=id&id=eq.'+derived['id'],x.state()['access_token'])==[])
 ledger.close()
(out/'native-followup.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

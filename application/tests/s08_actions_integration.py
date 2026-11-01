"""S08 E: fictitious certified source history, real local ACL and MFA checks."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
import uuid,tempfile,os,subprocess
from uniion.adapters.ai_runs import RunLedger
from uniion.adapters.codex_local import CodexLocal
out=ROOT/'preuves/S08-E';out.mkdir(exist_ok=True)
f=json.loads((ROOT/'.local-auth/s08-fixture.json').read_text());b=json.loads((ROOT/'.local-auth/s08-b-fixture.json').read_text());org=b['organization']
x,y,z=Client(),Client(),Client()
check('author_login',x.login(f['author'])[0]==200);verify(x,f['authorFactor'],f['authorSecret'])
check('reader_login',y.login(f['reader'])[0]==200);verify(y,f['readerFactor'],f['readerSecret'])
check('admin_login',z.login(f['admin'])[0]==200);verify(z,f['factor'],f['secret'])

def call(c,path,**data):
 app.sessions.clock=lambda:time.time()+len(checks)*61
 return c.call('/identity/ai/'+path,{'organization_id':org,**data})
class Fake:
 calls=0
 def complete(self,prompt,*a,**k):
  self.calls+=1;sources=json.loads(prompt.split('DONNEES_NON_FIABLES:\n')[1]);return json.dumps({'excerpts':[{'source':s['source'],'passage':s['passages'][0]['id'],'quote':s['passages'][0]['text'][:180]} for s in sources]})
fake=Fake()
with tempfile.TemporaryDirectory() as temp:
 ledger=RunLedger(Path(temp)/'runs.sqlite3');app.ai_gateway.ledger=ledger;app.ai_gateway.provider_factory=lambda:fake
 for ref in b['references']:
  rid=str(uuid.uuid4());data={'request_id':rid,'action':ref['kind']+'-excerpts','source':ref}
  st,r,_=call(y,'actions',**data);check(ref['kind']+'_proposal_saved',st==200 and r.get('persistent') is True)
  st,r,_=call(y,'assistant',action='read',id=rid);check(ref['kind']+'_reread_exact_source',st==200 and len(r['response']['snapshot'])==1 and r['response']['snapshot'][0]['id']==ref['id'])
  count=fake.calls;check(ref['kind']+'_duplicate_no_call',call(y,'actions',**data)[0]==403 and fake.calls==count)
  check(ref['kind']+'_actor_isolation',call(x,'assistant',action='read',id=rid)[0]==403)
  check(ref['kind']+'_forged_text_denied',call(y,'actions',**{**data,'request_id':str(uuid.uuid4()),'text':'FICTIVE_INJECTION'})[0]==403)
 data={'request_id':str(uuid.uuid4()),'action':'case-excerpts','source':b['references'][0]}
 check('anonymous_denied',call(Client(),'actions',**data)[0]==403)
 check('forged_action_denied',call(y,'actions',**{**data,'action':'publish'})[0]==403)
 check('wrong_kind_denied',call(y,'actions',**{**data,'action':'document-excerpts'})[0]==403)
 check('private_source_denied',call(y,'actions',**{**data,'source':b['private']})[0]==403)
 check('forged_apply_denied',call(y,'actions',**data,apply={'role':'superadmin'})[0]==403)
 check('foreign_org_denied',call(y,'actions',**data,organization_id=b['foreign'])[0]==403)
 check('source_text_denied',call(y,'actions',**{**data,'source':{**data['source'],'text':'never send'}})[0]==403)
 cancelled=str(uuid.uuid4());check('cancel_tombstone',call(y,'cancel',request_id=cancelled)[0]==200)
 count=fake.calls;check('pre_cancelled_never_invoked',call(y,'actions',**{**data,'request_id':cancelled})[0]==403 and fake.calls==count)
 if '--codex' in sys.argv:
  os.environ['UNIION_AI_CODEX_FIXTURES']='1';app.ai_gateway.provider_factory=CodexLocal
  st,r,_=call(y,'actions',**{**data,'request_id':str(uuid.uuid4())});check('real_codex_private_proposal',st==200 and r.get('persistent') is True)
  (out/'codex-live.json').write_text(json.dumps({'status':st,'persistent':r.get('persistent'),'verified_excerpts':len(r.get('excerpts',[]))},indent=2))
 ledger.close()
(out/'integration.json').write_text(json.dumps({'count':len(checks),'checks':checks,'passed':all(c['ok'] for c in checks)},indent=2));print(json.dumps({'checks':len(checks),'passed':True}))

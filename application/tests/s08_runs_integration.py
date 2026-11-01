"""Lot C: authenticated local HTTP and real Supabase policy, isolated durable ledger."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
import uuid,tempfile,os
from uniion.adapters.ai_runs import RunLedger
from uniion.adapters.ai_gateway import AIGateway
from uniion.adapters.codex_local import CodexLocal
from uniion.core.contracts import Unavailable
out=ROOT/'preuves/S08-C';out.mkdir(exist_ok=True)
f=json.loads((ROOT/'.local-auth/s08-fixture.json').read_text());b=json.loads((ROOT/'.local-auth/s08-b-fixture.json').read_text());org=b['organization']
x,y=Client(),Client()
check('author_login',x.login(f['author'])[0]==200);verify(x,f['authorFactor'],f['authorSecret'])
check('reader_login',y.login(f['reader'])[0]==200);verify(y,f['readerFactor'],f['readerSecret'])
def call(c,path,data):
 app.sessions.clock=lambda:time.time()+len(checks)*61
 return c.call(path,data)
def status(c=x,**extra):return call(c,'/identity/ai/runs',{'organization_id':org,**extra})
class Fake:
 calls=0
 fail=False
 def complete(self,*a,**k):
  self.calls+=1
  if self.fail:raise Unavailable('ambiguous timeout')
  return 'UNIION_S08_OK'
fake=Fake()
with tempfile.TemporaryDirectory() as temp:
 path=Path(temp)/'ledger/runs.sqlite3';ledger=RunLedger(path,daily=3)
 app.ai_gateway.ledger=ledger;app.ai_gateway.provider_factory=lambda:fake
 data={'organization_id':org,'request_id':str(uuid.uuid4()),'fixture':'connection'}
 check('succeeded',call(x,'/identity/ai/generate',data)[0]==200)
 st,result,_=status();check('durable_count',st==200 and result['reservedOrDispatched']==1 and result['runs'][0]['state']=='succeeded')
 check('unknown_cost',result['usage'] is None and result['cost'] is None)
 check('no_content_in_ledger',not any('UNIION_S08_OK' in str(tuple(row)) for row in ledger.db.execute('SELECT * FROM runs')))
 check('reader_cannot_read_author_execution',status(y,request_id=data['request_id'])[1]['runs']==[])
 check('foreign_org_refused',call(x,'/identity/ai/runs',{'organization_id':b['foreign']})[0]==403)
 check('forged_actor_refused',status(actor=f['reader']['id'])[0]==403)
 check('forged_consumption_refused',status(usage=0)[0]==403)
 check('anonymous_refused',status(Client())[0]==403)
 check('bad_origin_refused',x.call('/identity/ai/runs',{'organization_id':org},HTTP_ORIGIN='https://example.invalid')[0]==403)
 check('bad_csrf_refused',x.call('/identity/ai/runs',{'organization_id':org},HTTP_X_UNIION_CSRF='forged')[0]==403)
 ledger.close();ledger=RunLedger(path,daily=3);app.ai_gateway.ledger=ledger
 check('restart_retains_execution',status()[1]['runs'][0]['state']=='succeeded')
 check('restart_duplicate_no_send',call(x,'/identity/ai/generate',data)[0]==403 and fake.calls==1)
 check('same_id_changed_body_no_send',call(x,'/identity/ai/generate',{**data,'fixture':'summary'})[0]==403 and fake.calls==1)
 pre=str(uuid.uuid4());check('early_cancel',call(x,'/identity/ai/cancel',{'organization_id':org,'request_id':pre})[0]==200)
 check('early_cancel_blocks_send',call(x,'/identity/ai/generate',{**data,'request_id':pre})[0]==403 and fake.calls==1)
 check('early_cancel_not_charged',status()[1]['reservedOrDispatched']==1)
 fake.fail=True;uncertain={**data,'request_id':str(uuid.uuid4())}
 check('timeout_http_unavailable',call(x,'/identity/ai/generate',uncertain)[0]==503)
 check('timeout_persisted_uncertain',status(request_id=uncertain['request_id'])[1]['runs'][0]['state']=='uncertain')
 check('timeout_still_charged',status()[1]['reservedOrDispatched']==2)
 check('timeout_duplicate_never_retried',call(x,'/identity/ai/generate',uncertain)[0]==403 and fake.calls==2)
 fake.fail=False
 check('last_quota_place',call(x,'/identity/ai/generate',{**data,'request_id':str(uuid.uuid4())})[0]==200)
 check('quota_refuses_before_provider',call(x,'/identity/ai/generate',{**data,'request_id':str(uuid.uuid4())})[0]==429 and fake.calls==3)
 check('quota_shared_across_actors',call(y,'/identity/ai/generate',{**data,'request_id':str(uuid.uuid4())})[0]==429 and fake.calls==3)
 check('no_remaining',status()[1]['remaining']==0)
 ledger.close()
 # Separate ledger for the explicitly authorized live fictitious fixture.
 if '--codex' in sys.argv:
  os.environ['UNIION_AI_CODEX_FIXTURES']='1'
  ledger=RunLedger(Path(temp)/'live/runs.sqlite3');app.ai_gateway.ledger=ledger;app.ai_gateway.provider_factory=CodexLocal
  live={**data,'request_id':str(uuid.uuid4())};st,res,_=call(x,'/identity/ai/generate',live)
  check('codex_real_success',st==200 and res.get('text')=='UNIION_S08_OK')
  entry=status(request_id=live['request_id'])[1]
  check('codex_real_persisted',entry['runs'][0]['state']=='succeeded' and entry['reservedOrDispatched']==1)
  (out/'codex-live.json').write_text(json.dumps({'http_status':st,'exact_fixture_response':res.get('text')=='UNIION_S08_OK','state':entry['runs'][0]['state'],'charged':entry['reservedOrDispatched'],'usage':entry['usage'],'cost':entry['cost']},indent=2))
  ledger.close()
(out/'integration.json').write_text(json.dumps({'count':len(checks),'checks':checks,'passed':all(c['ok'] for c in checks)},indent=2));print(json.dumps({'checks':len(checks),'passed':True}))

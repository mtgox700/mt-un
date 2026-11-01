"""Real Codex local quality samples on the explicitly enrolled fictitious tenant."""
from pathlib import Path
bootstrap=Path(__file__).with_name('s08_native_integration.py').read_text().split('org,foreign=')[0]
exec(compile(bootstrap,__file__,'exec'))
from uniion.adapters.codex_local import CodexLocal
from uniion.adapters.ai_runs import RunLedger
from uniion.adapters.ai_proposals import ACTIONS
fixture=json.loads((ROOT/'.local-auth/s08-e-complet-fixture.json').read_text());org=fixture['organization'];refs=fixture['references']
x=Client();check('login',x.login(a)[0]==200);verify(x,f['authorFactor'],f['authorSecret'])
os.environ['UNIION_AI_CODEX_FIXTURES']='1';app.ai_gateway.provider_factory=CodexLocal
private=ROOT/'.local-auth/s08-e-complet-quality';private.mkdir(exist_ok=True,mode=0o700)
app.ai_gateway.ledger=RunLedger(private/'runs.sqlite3')
results=[]
import sys
only=sys.argv[1:]
class Trace(CodexLocal):
 def complete(self,*args,**kwargs):
  value=super().complete(*args,**kwargs)
  (out/('sortie-'+action+'.json')).write_text(value)
  return value
if only:app.ai_gateway.provider_factory=Trace
for action,spec in ACTIONS.items():
 if only and action not in only:continue
 app.sessions.clock=lambda:time.time()+len(results)*80
 rid=str(uuid.uuid4());st,r,_=x.call('/identity/ai/actions',{'organization_id':org,'action':action,'source':refs[spec['mod']],'request_id':rid})
 result={'action':action,'status':st,'persistent':r.get('persistent',False),'text':r.get('text',''),'excerpts':r.get('excerpts',[]),'artifact':r.get('artifact')}
 results.append(result)
 (out/('qualite-codex-'+os.environ.get('UNIION_QUALITY_RUN','reprise')+'.json' if only else 'qualite-codex.json')).write_text(json.dumps(results,ensure_ascii=False,indent=2))
 print(action,st,flush=True)
app.ai_gateway.ledger.close()
assert all(r['status']==200 and r['persistent'] for r in results)

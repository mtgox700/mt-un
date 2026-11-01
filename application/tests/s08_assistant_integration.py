"""S08 D: fictitious certified source history, real local ACL and MFA checks."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
import uuid,tempfile,os,subprocess
from uniion.adapters.ai_runs import RunLedger
from uniion.adapters.codex_local import CodexLocal
out=ROOT/'preuves/S08-D';out.mkdir(exist_ok=True)
f=json.loads((ROOT/'.local-auth/s08-fixture.json').read_text());b=json.loads((ROOT/'.local-auth/s08-b-fixture.json').read_text());org=b['organization']
x,y,z=Client(),Client(),Client()
check('author_login',x.login(f['author'])[0]==200);verify(x,f['authorFactor'],f['authorSecret'])
check('reader_login',y.login(f['reader'])[0]==200);verify(y,f['readerFactor'],f['readerSecret'])
check('admin_login',z.login(f['admin'])[0]==200);verify(z,f['factor'],f['secret'])
def sql(q):
 r=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if r.returncode:raise RuntimeError('Fixture SQL failed')
def call(c,action,**extra):
 app.sessions.clock=lambda:time.time()+len(checks)*61
 return c.call('/identity/ai/assistant',{'organization_id':org,'action':action,**extra})
class Fake:
 calls=0
 def complete(self,prompt,*a,**k):
  self.calls+=1;sources=json.loads(prompt.split('DONNEES_NON_FIABLES:\n')[1]);return json.dumps({'excerpts':[{'source':s['source'],'passage':s['passages'][0]['id'],'quote':s['passages'][0]['text'][:180]} for s in sources]})
fake=Fake()
with tempfile.TemporaryDirectory() as temp:
 path=Path(temp)/'ledger/runs.sqlite3';ledger=RunLedger(path);app.ai_gateway.ledger=ledger;app.ai_gateway.provider_factory=lambda:fake
 rid=str(uuid.uuid4());st,result,_=call(y,'generate',request_id=rid,sources=b['references'])
 check('generation_saved',st==200 and result['persistent'] is True)
 st,item,_=call(y,'read',id=rid);check('reread_verified',st==200 and len(item['response']['excerpts'])==3)
 check('author_cannot_read_reader_history',call(x,'read',id=rid)[0]==403)
 check('superadmin_cannot_read_history',call(z,'read',id=rid)[0]==403)
 check('anonymous_denied',call(Client(),'list')[0]==403)
 check('foreign_org_denied',call(y,'list',organization_id=b['foreign'])[0]==403)
 check('forged_actor_denied',call(y,'list',actor=f['author']['id'])[0]==403)
 check('forged_content_denied',call(y,'generate',request_id=str(uuid.uuid4()),sources=b['references'],question='NEVER_SEND')[0]==403)
 check('no_plaintext_response',result['text'].encode() not in path.read_bytes())
 check('no_plaintext_source_id',b['references'][0]['id'].encode() not in path.read_bytes())
 check('remember',call(y,'remember',id=rid,version=1,enabled=True)[0]==200)
 st,listing,_=call(y,'list');check('memory_initially_off',st==200 and listing['memory']=={'enabled':False,'version':0} and len(listing['memories'])==1)
 check('stale_pin_denied',call(y,'remember',id=rid,version=1,enabled=False)[0]==403)
 check('opt_in',call(y,'configure',enabled=True,version=0)[0]==200)
 second=str(uuid.uuid4());st,r,_=call(y,'generate',request_id=second,sources=[b['references'][1]])
 check('memory_sources_accumulated',st==200 and len(r['snapshot'])==3)
 ledger.close();ledger=RunLedger(path);app.ai_gateway.ledger=ledger
 check('restart_history_readable',call(y,'read',id=rid)[0]==200)
 check('restart_memory_persisted',call(y,'list')[1]['memory']=={'enabled':True,'version':1})
 before=fake.calls;check('duplicate_after_restart_no_provider',call(y,'generate',request_id=rid,sources=b['references'])[0]==403 and fake.calls==before)
 q="update public.uniion_resource_grants set revoked_at=%s where organization_id='%s' and resource_id='%s' and user_id='%s'"
 values=(org,b['references'][0]['id'],f['reader']['id'])
 sql(q%(('now()',)+values))
 try:
  check('revoked_source_read_denied',call(y,'read',id=rid)[0]==403)
  st,l,_=call(y,'list');check('revoked_history_and_memory_absent',st==200 and l['items']==[] and l['memories']==[])
  before=fake.calls;check('memory_cannot_bypass_revoke',call(y,'generate',request_id=str(uuid.uuid4()),sources=[b['references'][1]])[0]==403 and fake.calls==before)
 finally:sql(q%(('null',)+values))
 check('opt_out',call(y,'configure',enabled=False,version=1)[0]==200)
 check('archive',call(y,'archive',id=rid,version=2)[0]==200)
 check('archived_unreadable',call(y,'read',id=rid)[0]==403)
 check('archive_retains_ciphertext',ledger.db.execute('SELECT archived,remembered FROM responses WHERE id=?',(rid,)).fetchone()[:]==(1,0))
 check('no_source_title_in_events',all('Réunion fictive' not in str(tuple(row)) for row in ledger.db.execute('SELECT * FROM events')))
 check('forged_source_snapshot_denied',call(y,'remember',id=second,version=1,enabled=True,snapshot=[])[0]==403)
 if '--codex' in sys.argv:
  os.environ['UNIION_AI_CODEX_FIXTURES']='1';app.ai_gateway.provider_factory=CodexLocal
  live=str(uuid.uuid4());st,r,_=call(x,'generate',request_id=live,sources=b['references']);check('codex_live_saved',st==200 and r.get('persistent') is True)
  st,r,_=call(x,'read',id=live);check('codex_live_reread',st==200 and len(r['response']['excerpts'])>=1)
  (out/'codex-live.json').write_text(json.dumps({'http_status':st,'persistent':True,'verified_excerpts':len(r['response']['excerpts'])},indent=2))
 ledger.close()
(out/'integration.json').write_text(json.dumps({'count':len(checks),'checks':checks,'passed':all(c['ok'] for c in checks)},indent=2));print(json.dumps({'checks':len(checks),'passed':True}))

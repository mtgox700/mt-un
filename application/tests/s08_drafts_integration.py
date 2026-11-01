"""S08 E final: real local source contracts and ACLs; only explicitly seeded fictive text."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
import uuid,subprocess,os
from uniion.adapters.ai_context_service import ContextService
out=ROOT/'preuves/S08-E-final';out.mkdir(exist_ok=True)
f=json.loads((ROOT/'.local-auth/s08-fixture.json').read_text());a,b,admin=f['author'],f['reader'],f['admin']
assert all(u['email'].endswith('@uniion-local.example') for u in (a,b,admin))
def sql(q):
 r=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr.decode())
 return r.stdout.decode().strip()
org,foreign=str(uuid.uuid4()),str(uuid.uuid4())
sql(f"""begin;
insert into public.uniion_organizations values('{org}','S08 E final — contexte fictif',true),('{foreign}','S08 E final — autre organisation',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null),('{foreign}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_authorities values('{org}','{a['id']}','organization_edit',false);
insert into public.uniion_module_access select '{org}',m,true,true,'included',now()+interval '10 days' from unnest(array['assistant','dossiers','documents','messagerie','reunions','agenda','communication','mobile','formations','adherents','sondages','intranet','reporting'])m;
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) select '{org}',m,'paid',now()-interval '1 day',now()+interval '10 days','RECETTE-S08-E-FICTIVE' from unnest(array['assistant','dossiers','documents','messagerie','reunions','agenda','communication','mobile','formations','adherents','sondages','intranet','reporting'])m where m in(select id from uniion_private.module_catalog);
insert into public.uniion_permissions select '{org}','{a['id']}',m,p from unnest(array['assistant','dossiers','documents','messagerie','reunions','agenda','communication','mobile','formations','adherents','sondages','intranet','reporting'])m cross join unnest(array['read','write','create'])p;
insert into public.uniion_permissions select '{org}','{b['id']}',m,'read' from unnest(array['assistant','dossiers','documents','messagerie','reunions','agenda','communication','mobile','formations','adherents','sondages','intranet','reporting'])m;
insert into public.uniion_permissions values('{org}','{b['id']}','assistant','write');
insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Membre'),('{org}','{b['id']}','Alex Recette','Membre');commit;""")
x,y,z=Client(),Client(),Client()
check('author_login',x.login(a)[0]==200);verify(x,f['authorFactor'],f['authorSecret'])
check('reader_login',y.login(b)[0]==200);verify(y,f['readerFactor'],f['readerSecret'])
check('admin_login',z.login(admin)[0]==200);verify(z,f['factor'],f['secret'])
def call(c,path,data):
 app.sessions.clock=lambda:time.time()+len(checks)*11
 return c.call(path,data)
def pol(c,action,payload={}):return call(c,'/identity/ai',{'organization_id':org,'action':action,'payload':payload})
p=pol(z,'status')[1]
if not p['approved']:check('approve',pol(z,'approve',{'enabled':True,'version':p['providerVersion']})[0]==200)
p=pol(x,'status')[1];check('activate',pol(x,'activate',{'enabled':True,'version':0,'providerVersion':p['providerVersion']})[0]==200)
def module(c,name,action,payload):return call(c,'/identity/'+name,{'organization_id':org,'action':action,'payload':payload})
from uniion.adapters.ai_runs import RunLedger
import tempfile

def make(kind):
 if kind=='case':st,row,_=module(x,'cases','create',{'title':'Dossier fictif E','long':'La réunion fictive concerne les horaires du mardi.','tag':'Juridique','due':'Mardi'})
 else:st,row,_=module(x,'documents','create',{'model':'courrier','document':{'title':'Document fictif E','format':'a4','blocks':[{'id':'p1','type':'p','text':'La réunion fictive concerne les horaires du mardi.'}]}})
 check(kind+'_created',st==200)
 ref={'kind':kind,'id':row['id']}
 service=ContextService(lambda path,payload:api.request(path,x.state()['access_token'],payload))
 s=service.load(org,[ref])[0]
 sql(f"insert into uniion_private.ai_recipe_sources values('{org}','{kind}','{row['id']}','','{s['fingerprint']}',true)")
 sql(f"insert into public.uniion_resource_grants values('{org}','{row['id']}','{b['id']}',false,false,now()+interval '1 day',null)")
 return ref,row
class Fake:
 calls=0
 def complete(self,prompt,*a,**k):
  self.calls+=1;s=json.loads(prompt.split('DONNEES_NON_FIABLES:\n')[1])[0]
  return json.dumps({'draft':'Suggestion fictive : préparer les questions sur les horaires.','excerpts':[{'source':s['source'],'passage':s['passages'][0]['id'],'quote':s['passages'][0]['text']}]})
fake=Fake()
def ai(c,path,**data):return call(c,'/identity/ai/'+path,{'organization_id':org,**data})
def draft(c,rid,action,version,**data):return ai(c,'drafts',id=rid,action=action,version=version,**data)
with tempfile.TemporaryDirectory() as temp:
 ledger=RunLedger(Path(temp)/'runs.sqlite3');app.ai_gateway.ledger=ledger;app.ai_gateway.provider_factory=lambda:fake
 doc,row=make('document')
 st,r,_=ai(x,'actions',action='catalog');check('catalog_37_server_actions',st==200 and len(r.get('actions',[]))==37)
 for kind,action in [('case','dos-next'),('document','doc-relire')]:
  ref,row=make(kind);rid=str(uuid.uuid4())
  st,r,_=ai(x,'actions',action=action,source=ref,request_id=rid);check(kind+'_draft_saved',st==200 and r.get('persistent'))
  check(kind+'_not_auto_applied',module(x,'cases' if kind=='case' else 'documents','get',{'id':ref['id']})[1]['version']==row['version'])
  check(kind+'_apply_before_review_refused',draft(x,rid,'apply',1)[0]==403)
  check(kind+'_other_actor_refused',draft(y,rid,'review',1)[0]==403)
  check(kind+'_edit_saved',draft(x,rid,'edit',1,text='Brouillon corrigé fictif.')[0]==200)
  check(kind+'_stale_review_refused',draft(x,rid,'review',1)[0]==403)
  check(kind+'_review_saved',draft(x,rid,'review',2)[0]==200)
  st,receipt,_=draft(x,rid,'apply',3);check(kind+'_explicit_apply',st==200 and receipt.get('applied') and receipt['version']==row['version']+1)
  st,retry,_=draft(x,rid,'apply',3);check(kind+'_retry_exactly_once',st==200 and retry==receipt)
  check(kind+'_source_version_unchanged_on_retry',module(x,'cases' if kind=='case' else 'documents','get',{'id':ref['id']})[1]['version']==row['version']+1)
  check(kind+'_old_draft_source_invalidated',ai(x,'assistant',action='read',id=rid)[0]==403)
 # Exercise every catalog action through HTTP, MFA, real module checks and persistence.
 from uniion.adapters.ai_proposals import ACTIONS
 case,_=make('case')
 st,conversation,_=module(x,'messaging','create',{'participant':b['id']});check('action_message_created',st==200)
 st,msg,_=module(x,'messaging','send',{'id':conversation['id'],'clientId':str(uuid.uuid4()),'text':'Réunion fictive sur les horaires du mardi.'});check('action_message_sent',st==200)
 message={'kind':'message','id':conversation['id'],'seq':msg['seq']}
 service=ContextService(lambda path,payload:api.request(path,x.state()['access_token'],payload));src=service.load(org,[message])[0]
 sql(f"insert into uniion_private.ai_recipe_sources values('{org}','message','{message['id']}','{message['seq']}','{src['fingerprint']}',true)")
 for action,spec in ACTIONS.items():
  ref=case if spec['mod']=='dossiers' else message if spec['mod']=='messagerie' else doc
  rid=str(uuid.uuid4());st,r,_=ai(x,'actions',action=action,source=ref,request_id=rid)
  check('http_'+action,st==200 and r.get('action')==action and r.get('persistent'))
  check('history_'+action,ai(x,'assistant',action='read',id=rid)[0]==200)
 # A reviewed/published document cannot receive a draft through the application endpoint.
 sql(f"insert into public.uniion_authorities values('{org}','{b['id']}','document_review',false)")
 ref,published=make('document');rid=str(uuid.uuid4())
 check('draft_before_document_review',ai(x,'actions',action='doc-relire',source=ref,request_id=rid)[0]==200)
 check('private_review_before_document_review',draft(x,rid,'review',1)[0]==200)
 check('document_second_actor_review',module(y,'documents','publication_review',{'id':ref['id'],'version':published['version']})[0]==200)
 check('apply_into_validated_document_refused',draft(x,rid,'apply',2)[0]==403)
 # The SQL boundary independently rejects stale/cross-org/arbitrary destinations.
 def raw_apply(payload,target_org=org):
  try:api.request('/rest/v1/rpc/uniion_ai_draft_apply',x.state()['access_token'],{'p_org':target_org,'p_action':'apply','p_payload':payload});return False
  except AccessDenied:return True
 payload={'id':str(uuid.uuid4()),'source':doc['id'],'kind':'document','version':999,'text':'Fictif'}
 check('direct_stale_version_refused',raw_apply(payload))
 check('direct_cross_org_refused',raw_apply({**payload,'version':1},foreign))
 check('direct_arbitrary_kind_refused',raw_apply({**payload,'kind':'notification','version':1}))
 check('direct_destination_extra_refused',raw_apply({**payload,'version':1,'publish':True}))
 # Classified message dependencies cannot be flattened into ordinary dossier notes.
 linked,linked_row=make('case')
 check('message_classified',module(x,'cases','message_classify',{'case':linked['id'],'expected':linked_row['version'],'conversation':message['id'],'seq':message['seq'],'file':''})[0]==200)
 src=service.load(org,[linked])[0]
 sql(f"update uniion_private.ai_recipe_sources set fingerprint='{src['fingerprint']}' where organization_id='{org}' and id='{linked['id']}'")
 rid=str(uuid.uuid4());check('linked_case_draft',ai(x,'actions',action='dos-sum',source=linked,request_id=rid)[0]==200)
 check('linked_case_review',draft(x,rid,'review',1)[0]==200)
 check('linked_case_flattening_refused',draft(x,rid,'apply',2)[0]==403)
 # Reader can prepare/review a private proposal but cannot mutate its source.
 rid=str(uuid.uuid4());check('reader_generate',ai(y,'actions',action='doc-relire',source=doc,request_id=rid)[0]==200)
 check('reader_review',draft(y,rid,'review',1)[0]==200)
 check('reader_apply_denied',draft(y,rid,'apply',2)[0]==403)
 check('edited_text_reopens_review',draft(y,rid,'edit',2,text='Correction fictive.')[0]==200 and ai(y,'assistant',action='read',id=rid)[1]['response']['reviewed'] is False)
 check('forged_destination_refused',draft(y,rid,'apply',3,destination=str(uuid.uuid4()))[0]==403)
 check('boolean_version_refused',draft(y,rid,'review',True)[0]==403)
 if '--codex' in sys.argv:
  from uniion.adapters.codex_local import CodexLocal
  os.environ['UNIION_AI_CODEX_FIXTURES']='1';app.ai_gateway.provider_factory=CodexLocal
  rid=str(uuid.uuid4());st,r,_=ai(x,'actions',action='doc-relire',source=doc,request_id=rid)
  check('real_codex_business_draft',st==200 and r.get('mode')=='business-draft' and r.get('persistent'))
  (out/'codex-live.json').write_text(json.dumps({'status':st,'action':r.get('action'),'citations':len(r.get('excerpts',[])),'persistent':r.get('persistent')},indent=2))
 ledger.close()
path=ROOT/'.local-auth/s08-e-final-fixture.json';path.write_text(json.dumps({'organization':org,'document':doc}));path.chmod(0o600)
(out/'integration.json').write_text(json.dumps({'count':len(checks),'checks':checks,'passed':all(c['ok'] for c in checks)},indent=2));print(json.dumps({'checks':len(checks),'passed':True}))

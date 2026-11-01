"""S08 E complet: real local source contracts and ACLs; only explicitly seeded fictive text."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
import uuid,subprocess,os
from uniion.adapters.ai_context_service import ContextService
out=ROOT/'preuves/S08-E-complet';out.mkdir(exist_ok=True)
f=json.loads((ROOT/'.local-auth/s08-fixture.json').read_text());a,b,admin=f['author'],f['reader'],f['admin']
assert all(u['email'].endswith('@uniion-local.example') for u in (a,b,admin))
def sql(q):
 r=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr.decode())
 return r.stdout.decode().strip()
org,foreign=str(uuid.uuid4()),str(uuid.uuid4())
sql(f"""begin;
insert into public.uniion_organizations values('{org}','S08 E complet — contexte fictif',true),('{foreign}','S08 E complet — autre organisation',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null),('{foreign}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_authorities values('{org}','{a['id']}','organization_edit',false);
insert into public.uniion_module_access select '{org}',m,true,true,'included',now()+interval '10 days' from unnest(array['assistant','dossiers','documents','messagerie','reunions','agenda','communication','mobile','formations','adherents','sondages','intranet','reporting','raccourcis'])m;
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) select '{org}',m,'paid',now()-interval '1 day',now()+interval '10 days','RECETTE-S08-E-FICTIVE' from unnest(array['assistant','dossiers','documents','messagerie','reunions','agenda','communication','mobile','formations','adherents','sondages','intranet','reporting','raccourcis'])m where m in(select id from uniion_private.module_catalog);
insert into public.uniion_permissions select '{org}','{a['id']}',m,p from unnest(array['assistant','dossiers','documents','messagerie','reunions','agenda','communication','mobile','formations','adherents','sondages','intranet','reporting','raccourcis'])m cross join unnest(array['read','write','create'])p;
insert into public.uniion_permissions select '{org}','{b['id']}',m,'read' from unnest(array['assistant','dossiers','documents','messagerie','reunions','agenda','communication','mobile','formations','adherents','sondages','intranet','reporting','raccourcis'])m;
insert into public.uniion_permissions values('{org}','{b['id']}','assistant','write');
insert into uniion_private.ai_business_roles select '{org}',u,r from unnest(array['{a['id']}'::uuid,'{b['id']}'::uuid])u cross join unnest(array['secretaire','tresorier','titulaire','suppleant','ds','ssct'])r;
insert into uniion_private.agenda_audiences values('{org}','{a['id']}','elus'),('{org}','{b['id']}','elus');
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
from uniion.adapters.ai_proposals import ACTIONS
import tempfile
refs={}
def rpc(c,name,**data):return api.request('/rest/v1/rpc/'+name,c.state()['access_token'],data)
def certify(ref):
 service=ContextService(lambda path,payload:api.request(path,x.state()['access_token'],payload));s=service.load(org,[ref])[0]
 sql(f"insert into uniion_private.ai_recipe_sources values('{org}','{ref['kind']}','{ref['id']}','{ref.get('seq','')}','{s['fingerprint']}',true) on conflict(organization_id,kind,id,seq) do update set fingerprint=excluded.fingerprint")
 return ref
for mod in ('reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis'):
 data={'title':'Réunion fictive sur les horaires du mardi'}
 data.update({'reunions':{'ordre':['Examiner les horaires fictifs'],'date':'2026-11-03'},'communication':{'sujet':'Informer sur les horaires fictifs','date':'2026-11-03','fmt':'Post réseau social','canal':'Application','obj':'Informer'},'mobile':{'type':'Actualité','aud':'Tous les salariés','blocks':[['p','Horaires fictifs du mardi à examiner.']],'pushOn':False,'push':''},'formations':{'theme':'Préparer une réunion fictive','dur':30,'level':'Débutant','role':'Élu','goal':'Formuler un ordre du jour'},'sondages':{'question':'Quel horaire fictif préférez-vous ?','options':['Matin','Après-midi'],'mode':'sans-identite'},'intranet':{'blocks':[['p','Présentation de la réunion fictive.']]},'reporting':{'description':'Une réunion fictive préparée','period':'Octobre 2026'},'raccourcis':{'description':'Accès au calendrier des réunions fictives','items':[]}}[mod])
 r=rpc(x,'uniion_business_records',p_org=org,p_module=mod,p_action='create',p_payload={'data':data});refs[mod]=certify({'kind':mod,'id':r['id']});check(mod+'_native_persisted',rpc(x,'uniion_business_records',p_org=org,p_module=mod,p_action='get',p_payload={'id':r['id']})['version']==1)
 sql(f"insert into public.uniion_resource_grants values('{org}','{r['id']}','{b['id']}',false,false,now()+interval '1 day',null)")
r=module(x,'cases','create',{'title':'Dossier fictif','long':'Préparation des horaires fictifs du mardi.','tag':'Juridique','due':'Mardi'})[1];refs['dossiers']=certify({'kind':'case','id':r['id']})
r=module(x,'documents','create',{'model':'courrier','document':{'title':'Document fictif','format':'a4','blocks':[{'id':'p1','type':'p','text':'Les horaires fictifs seront examinés mardi.'}]}})[1];refs['documents']=certify({'kind':'document','id':r['id']})
r=rpc(x,'uniion_agenda_save',p_org=org,p_event={'title':'Réunion fictive','type':'cse','date':'2026-11-03','start':'10:00','end':'11:00','lieu':'Salle fictive','visib':'elus','notes':'Examiner les horaires fictifs','rappel':False});refs['agenda']=certify({'kind':'agenda','id':r['id']})
r=rpc(x,'uniion_adherents',p_org=org,p_action='import',p_payload=[{'prenom':'Alex','nom':'Fictif','email':'alex@example.invalid','ent':'Entreprise fictive','etab':'Site fictif','poste':'Élu','mandat':'Titulaire'}]);refs['adherents']=certify({'kind':'adherents','id':r['rows'][0]['id']})
r=module(x,'messaging','create',{'participant':b['id']})[1];m=module(x,'messaging','send',{'id':r['id'],'clientId':str(uuid.uuid4()),'text':'Réunion fictive mardi sur les horaires.'})[1];refs['messagerie']=certify({'kind':'message','id':r['id'],'seq':m['seq']})
refs['accueil']=refs['params']=certify({'kind':'workspace','id':org})
class Fake:
 calls=0
 def complete(self,prompt,*a,**kw):
  self.calls+=1;s=json.loads(prompt.split('DONNEES_NON_FIABLES:\n')[1])[0]
  result={'draft':'Consultez votre espace pour découvrir les informations disponibles.','excerpts':[{'source':s['source'],'passage':s['passages'][0]['id'],'quote':s['passages'][0]['text'][:600]}]}
  from uniion.adapters.ai_artifacts import SPECS
  for action,spec in SPECS.items():
   if spec['ask'] in prompt:
    artifact={'title':'Projet fictif','paragraphs':['Les horaires fictifs seront examinés mardi.']}
    if action=='formation-course':artifact={'title':'Cours fictif','intro':'Préparer la réunion fictive.','retenir':['Vérifier les faits.'],'sources':'Référence à vérifier','modules':[{'title':'Préparer','minutes':30,'objectif':'Distinguer fait et avis','points':[{'h':'Faits','text':'Vérifier les faits.'}],'exemple':'Horaires fictifs','exercice':'Rédigez une question.','quiz':{'q':'Que vérifier ?','choices':['Les faits','Rien'],'answer':0,'explain':'Les faits sont à vérifier.'}}]}
    elif action=='formation-feedback':artifact={'text':'Précisez la date de la réunion fictive.'}
    elif action=='communication-compose':artifact={'titre':'Réunion fictive','accroche':'Préparons la réunion','corps':'Les horaires fictifs seront examinés mardi.','appel':'Consultez votre espace','visuel':'Illustration à préparer'}
    elif action=='poll-options':artifact={'options':['Matin','Après-midi']}
    result['artifact']=artifact
  return json.dumps(result)
fake=Fake()
def ai(c,path,**data):return call(c,'/identity/ai/'+path,{'organization_id':org,**data})
with tempfile.TemporaryDirectory() as tmp:
 ledger=RunLedger(Path(tmp)/'runs.sqlite3');app.ai_gateway.ledger=ledger;app.ai_gateway.provider_factory=lambda:fake
 for action,spec in ACTIONS.items():
  if spec.get('special'):continue
  rid=str(uuid.uuid4());st,r,_=ai(x,'actions',action=action,source=refs[spec['mod']],request_id=rid)
  check(action+'_native_generation',st==200 and r.get('persistent'))
  check(action+'_history',ai(x,'assistant',action='read',id=rid)[0]==200)
  if spec.get('apply') in ('mobpage','mobreplace','mobpush','complan'):
   check(action+'_review',ai(x,'drafts',action='review',id=rid,version=1)[0]==200)
   st,receipt,_=ai(x,'drafts',action='apply',id=rid,version=2);check(action+'_apply',st==200 and receipt.get('applied'))
   check(action+'_idempotent',ai(x,'drafts',action='apply',id=rid,version=2)[1]==receipt)
   certify(refs[spec['mod']])
 check('native_context_not_document_fallback',ai(x,'actions',action='mob-page',source=refs['documents'],request_id=str(uuid.uuid4()))[0]==403)
 sql(f"delete from uniion_private.ai_business_roles where organization_id='{org}' and user_id='{a['id']}'")
 count=fake.calls;check('role_required_before_provider',ai(x,'actions',action='dos-mail',source=refs['dossiers'],request_id=str(uuid.uuid4()))[0]==403 and fake.calls==count)
 sql(f"insert into uniion_private.ai_business_roles select '{org}','{a['id']}',r from unnest(array['secretaire','tresorier','titulaire','suppleant','ds','ssct'])r")
 # Native specialist contracts, strict outputs and persisted history.
 for action,spec in ACTIONS.items():
  if not spec.get('special'):continue
  rid=str(uuid.uuid4());st,r,_=ai(x,'actions',action=action,source=refs[spec['mod']],request_id=rid)
  check(action+'_structured_generation',st==200 and r.get('artifact') is not None)
  check(action+'_structured_history',ai(x,'assistant',action='read',id=rid)[1].get('response',{}).get('artifact')==r['artifact'])
 count=fake.calls
 check('chat_unenrolled_refused',ai(x,'chat',request_id=str(uuid.uuid4()),question='Question fictive',sources=[],parent=None)[0]==403 and fake.calls==count)
 sql(f"insert into uniion_private.ai_interactive_recipes values('{org}',true,1)")
 rid=str(uuid.uuid4());st,r,_=ai(x,'chat',request_id=rid,question='Comment préparer la réunion fictive ?',sources=[refs['reunions']],parent=None)
 check('chat_persisted',st==200 and r.get('mode')=='conversation' and r.get('persistent'))
 rid2=str(uuid.uuid4());st,r,_=ai(x,'chat',request_id=rid2,question='Précise les points à vérifier.',sources=[],parent=rid)
 check('chat_continues_with_cumulative_sources',st==200 and len(r['snapshot'])==2 and r['parents'][0]['id']==rid)
 check('chat_other_actor_refused',ai(y,'assistant',action='read',id=rid2)[0]==403)
 sql(f"delete from public.uniion_resource_grants where organization_id='{org}' and resource_id='{refs['reunions']['id']}' and user_id='{a['id']}'")
 check('chat_source_revoked_removes_descendant',ai(x,'assistant',action='read',id=rid2)[0]==403)
 sql(f"insert into public.uniion_resource_grants values('{org}','{refs['reunions']['id']}','{a['id']}',true,false,now()+interval '1 day',null)")
 # Versioned settings and explicit role decisions, no implicit self-escalation.
 st,cfg,_=ai(x,'actions',action='settings',payload={});check('settings_read',st==200 and cfg['manage'])
 setting=next(v for v in cfg['settings'] if v['id']=='mob-page')
 value={k:setting[k] for k in ('id','version','enabled','roles')};value['enabled']=False
 check('action_disable',ai(x,'actions',action='configure',payload=value)[0]==200)
 count=fake.calls;check('disabled_action_before_provider',ai(x,'actions',action='mob-page',source=refs['mobile'],request_id=str(uuid.uuid4()))[0]==403 and fake.calls==count)
 check('settings_stale_version',ai(x,'actions',action='configure',payload=value)[0]==403)
 check('reader_cannot_configure',ai(y,'actions',action='configure',payload={**value,'version':value['version']+1})[0]==403)
 check('cannot_self_assign_role',ai(x,'actions',action='assign_role',payload={'user':a['id'],'role':'ds','enabled':True})[0]==403)
 check('action_reenable',ai(x,'actions',action='configure',payload={**value,'version':value['version']+1,'enabled':True})[0]==200)
 # Publication is an explicit second actor decision over an immutable audience/version.
 def business(c,mod,action,payload={}):return call(c,'/identity/business',{'organization_id':org,'module':mod,'action':action,'payload':payload})
 st,m,_=business(x,'mobile','get',{'id':refs['mobile']['id']});check('business_http_get',st==200)
 payload={'id':m['id'],'version':m['version']}
 sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','content_review',false),('{org}','{a['id']}','content_publish',false),('{org}','{b['id']}','content_review',false),('{org}','{b['id']}','content_publish',false)")
 check('publication_self_review_denied',business(x,'mobile','publication_review',{**payload,'recipients':[b['email']]})[0]==403)
 check('publication_before_review_denied',business(x,'mobile','publication_publish',payload)[0]==403)
 check('publication_second_actor_review',business(y,'mobile','publication_review',{**payload,'recipients':[b['email']]})[0]==200)
 check('publication_publish',business(x,'mobile','publication_publish',payload)[0]==200)
 check('publication_idempotent',business(x,'mobile','publication_publish',payload)[0]==200)
 check('publication_no_audience_no_feed',business(x,'mobile','publication_feed')[1]['rows']==[])
 sql(f"delete from public.uniion_resource_grants where organization_id='{org}' and resource_id='{m['id']}' and user_id='{b['id']}'")
 check('published_version_separate_from_source',business(y,'mobile','get',{'id':m['id']})[0]==403 and len(business(y,'mobile','publication_feed')[1]['rows'])==1)
 from uniion.adapters.ai_native import FIELDS
 data={'title':m['title'],'type':'Actualité','blocks':[['p','Version modifiée après publication.']]}
 st,new,_=business(x,'mobile','save',{**payload,'data':data});check('published_source_can_become_new_draft',st==200 and new['version']>m['version'])
 check('old_published_version_revocable',business(x,'mobile','publication_revoke',payload)[0]==200)
 check('revocation_removes_feed',business(y,'mobile','publication_feed')[1]['rows']==[])
 ledger.close()
p=ROOT/'.local-auth/s08-e-complet-fixture.json';p.write_text(json.dumps({'organization':org,'references':refs}));p.chmod(0o600)
(out/'native-integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0];exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import uuid,subprocess
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts;src=str(uuid.uuid4());dst=str(uuid.uuid4());cid=str(uuid.uuid4())
q=f"""begin;insert into public.uniion_organizations values('{src}','Collection source fictive',true),('{dst}','Collection destinataire fictive',true);
insert into public.uniion_memberships values('{src}','{a['id']}',now()-interval '1 day',null),('{src}','{b['id']}',now()-interval '1 day',null),('{dst}','{a['id']}',now()-interval '1 day',null),('{dst}','{b['id']}',now()-interval '1 day',null);
insert into public.uniion_authorities values('{src}','{a['id']}','collection_publish',false),('{src}','{b['id']}','collection_publish',false),('{dst}','{b['id']}','organization_edit',false),('{dst}','{b['id']}','collection_accept',false);
insert into uniion_private.collections values('{cid}','{src}','{dst}','Charte et texte fictifs');insert into uniion_private.collection_versions values('{cid}',1,'#CC6600','Texte institutionnel v1','{a['id']}',true,'{b['id']}');commit;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Collection fixture setup failed')
x=Client();y=Client()
def change(c,org,action,data):return c.call('/identity/collections/change',{'organization_id':org,'collection':cid,'action':action,'data':data})[0]
def context(c,org):return c.call('/identity/collections',{'organization_id':org})[1]['collections'][0]
check('anonymous_refused',change(x,src,'collectionDraft',{'color':'#AABBCC','text':'v2'})==403);check('source_login',x.login(a)[0]==200);check('aal1_refused',change(x,src,'collectionDraft',{'color':'#AABBCC','text':'v2'})==403)
(st,_,_),_=verify(x,f['factor'],f['secret']);check('source_mfa',st==200);check('reviewer_login',y.login(b)[0]==200);(st,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('reviewer_mfa',st==200)
check('not_adopted_by_default',context(y,dst)['subscription'] is None)
check('adopt_without_permission_refused',change(x,dst,'collectionAdopt',{'version':1})==403)
check('wrong_organization_refused',change(x,a['org'],'collectionAdopt',{'version':1})==403)
check('adopt_explicit',change(y,dst,'collectionAdopt',{'version':1})==200)
check('override_saved',change(y,dst,'collectionOverride',{'text':'Adaptation locale fictive'})==200)
check('draft_created',change(x,src,'collectionDraft',{'color':'#AABBCC','text':'Texte institutionnel v2'})==200)
check('target_cannot_see_draft',len(context(y,dst)['versions'])==1)
check('self_publication_refused',change(x,src,'collectionPublish',{'version':2})==403)
check('draft_cannot_be_adopted',change(y,dst,'collectionAccept',{'version':2,'expected':1})==403)
check('second_actor_publication',change(y,src,'collectionPublish',{'version':2})==200)
check('no_automatic_update',context(y,dst)['subscription']['accepted']==1)
check('source_cannot_see_override',context(x,src)['subscription'] is None)
check('decline_keeps_current',change(y,dst,'collectionDecline',{'version':2,'expected':1})==200 and context(y,dst)['subscription']['accepted']==1)
check('stale_approval_refused',change(y,dst,'collectionAccept',{'version':2,'expected':0})==403)
check('approval_allowed',change(y,dst,'collectionAccept',{'version':2,'expected':1})==200)
sub=context(y,dst)['subscription'];check('local_override_preserved',sub['overrides']['text']=='Adaptation locale fictive' and sub['accepted']==2 and len(sub['history'])==2)
check('business_fields_refused',change(x,src,'collectionDraft',{'color':'#AABBCC','text':'v3','resource':a['resource']})==403)
check('stop_keeps_data',change(y,dst,'collectionStop',{})==200)
sub=context(y,dst)['subscription'];check('stop_preserves_accepted_and_override',not sub['active'] and sub['accepted']==2 and bool(sub['overrides']['text']))
check('stopped_updates_refused',change(y,dst,'collectionOverride',{'text':'interdit'})==403)
try:api.request('/rest/v1/rpc/uniion_collection_change',x.state()['access_token'],{'p_org':dst,'p_collection':cid,'p_action':'collectionAdopt','p_data':{'version':1}});denied=False
except AccessDenied:denied=True
check('direct_rpc_unprivileged_refused',denied)
# Separate collection awaiting approval for read-only responsive browser checks.
ui=str(uuid.uuid4());q=f"""begin;insert into uniion_private.collections values('{ui}','{src}','{dst}','Collection de recette interface');insert into uniion_private.collection_versions values('{ui}',1,'#CC6600','Texte approuvé v1','{a['id']}',true,'{b['id']}'),('{ui}',2,'#AA5500','Texte proposé v2','{a['id']}',true,'{b['id']}');insert into uniion_private.collection_subscriptions(collection,accepted,override_text) values('{ui}',1,'Texte local conservé');commit;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('UI fixture setup failed')
(ROOT/'.local-auth/s02-collections.json').write_text(json.dumps({'source':src,'target':dst,'collection':ui}))
out=ROOT/'preuves/S02-collections';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'checks':checks,'count':len(checks)},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

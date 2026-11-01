from pathlib import Path
source=Path(__file__).with_name('s02_collections.py').read_text().split('x=Client();y=Client()')[0];exec(compile(source,str(Path(__file__).with_name('s02_collections.py')),'exec'))
other=str(uuid.uuid4());q=f"insert into public.uniion_organizations values('{other}','Autre destinataire fictif',true);insert into public.uniion_partners values('{src}','{dst}'),('{src}','{other}');"
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Partner fixture failed')
x=Client();y=Client();data={'organization_id':src,'target':dst,'name':'Nouvelle collection fictive','color':'#AABBCC','text':'Texte institutionnel de recette'}
check('anonymous_creation_refused',x.call('/identity/collections/create',data)[0]==403);check('author_login',x.login(a)[0]==200);check('aal1_creation_refused',x.call('/identity/collections/create',data)[0]==403)
(st,_,_),_=verify(x,f['factor'],f['secret']);check('author_mfa',st==200);check('reviewer_login',y.login(b)[0]==200);(st,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('reviewer_mfa',st==200)
st,ctx,_=x.call('/identity/collections',{'organization_id':src});check('eligible_targets_only',st==200 and {o['id'] for o in ctx['targets']}=={dst,other})
check('nonpublisher_creation_refused',y.call('/identity/collections/create',{**data,'organization_id':dst,'target':src})[0]==403)
check('self_target_refused',x.call('/identity/collections/create',{**data,'target':src})[0]==403)
check('unrelated_target_refused',x.call('/identity/collections/create',{**data,'target':a['org']})[0]==403)
check('forged_source_refused',x.call('/identity/collections/create',{**data,'organization_id':b['org']})[0]==403)
check('business_field_refused',x.call('/identity/collections/create',{**data,'resource':a['resource']})[0]==403)
check('invalid_color_refused',x.call('/identity/collections/create',{**data,'color':'javascript:invalid'})[0]==403)
st,d,_=x.call('/identity/collections/create',data);created=d.get('id');check('draft_created',st==200 and created and d['published'] is False)
_,ctx,_=x.call('/identity/collections',{'organization_id':src});new=next(c for c in ctx['collections'] if c['id']==created);check('selected_target_exact',new['target']==dst);check('first_draft_visible_to_source',len(new['versions'])==1 and not new['versions'][0]['published'])
_,ctx,_=y.call('/identity/collections',{'organization_id':dst});check('unpublished_collection_hidden',all(c['id']!=created for c in ctx['collections']))
def change(c,org,action):return c.call('/identity/collections/change',{'organization_id':org,'collection':created,'action':action,'data':{'version':1}})[0]
check('author_cannot_publish',change(x,src,'collectionPublish')==403)
check('cannot_adopt_draft',change(y,dst,'collectionAdopt')==403)
check('second_actor_publishes',change(y,src,'collectionPublish')==200)
_,ctx,_=y.call('/identity/collections',{'organization_id':dst});new=next(c for c in ctx['collections'] if c['id']==created);check('published_not_auto_adopted',new['subscription'] is None)
check('explicit_first_adoption',change(y,dst,'collectionAdopt')==200)
check('no_business_access_created',api.resources(y.state()['access_token'],src)==[])
try:api.request('/rest/v1/rpc/uniion_collection_create',y.state()['access_token'],{'p_org':dst,'p_target':src,'p_name':'Interdit','p_color':'#AABBCC','p_text':'Test'});denied=False
except AccessDenied:denied=True
check('direct_rpc_unprivileged_refused',denied)
(ROOT/'.local-auth/s02-create-collections.json').write_text(json.dumps({'source':src,'target':dst,'other':other}))
out=ROOT/'preuves/S02-creation-collections';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

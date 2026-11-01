"""Ticket lifecycle without any business access: fictional local fixtures."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0];exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import uuid,subprocess
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts;org,foreign=[str(uuid.uuid4()) for _ in range(2)]
q=f"""begin;insert into public.uniion_organizations values('{org}','Recette support S02',true),('{foreign}','Support extérieur fictif',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now(),null),('{org}','{b['id']}',now(),null);
insert into public.uniion_authorities values('{org}','{a['id']}','share',false);commit;"""
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Fixture creation failed')
x=Client();y=Client()
def ctx(c,o=org):return c.call('/identity/support',{'organization_id':o})
def create(c,title='Ticket fictif'):return c.call('/identity/support/create',{'organization_id':org,'title':title})
def status(c,tid,action='close',o=org):return c.call('/identity/support/status',{'organization_id':o,'ticket':tid,'action':action})
check('anonymous_denied',ctx(x)[0]==403);check('admin_login',x.login(a)[0]==200);check('aal1_create_denied',create(x)[0]==403)
(st,_,_),_=verify(x,f['factor'],f['secret']);check('admin_mfa',st==200);check('empty_context',ctx(x)[1]['tickets']==[])
check('empty_title_denied',create(x,'   ')[0]==403);check('long_title_denied',create(x,'x'*121)[0]==403)
st,t,_=create(x,'Ticket du gestionnaire');tid=t.get('id');check('create_authorized',st==200 and tid)
check('foreign_context_denied',ctx(x,foreign)[0]==403);check('forged_org_denied',status(x,tid,o=foreign)[0]==403)
check('member_login',y.login(b)[0]==200);(st,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('member_mfa',st==200)
check('other_member_ticket_hidden',ctx(y)[1]['tickets']==[]);st,t,_=create(y,'Ticket personnel fictif');member_tid=t.get('id');check('member_create',st==200);check('own_ticket_visible',len(ctx(y)[1]['tickets'])==1);check('manager_sees_two',len(ctx(x)[1]['tickets'])==2)
check('member_close_denied',status(y,member_tid)[0]==403);check('invalid_action_denied',status(x,tid,'approve')[0]==403)
check('close_authorized',status(x,tid)[0]==200);check('double_close_denied',status(x,tid)[0]==403);st,d,_=status(x,tid,'reopen');check('reopen_without_access',st==200 and d['business_access'] is False)
check('forged_grant_fields_denied',x.call('/identity/support/create',{'organization_id':org,'title':'x','agents':[b['id']]})[0]==403)
check('no_implicit_resources',api.resources(y.state()['access_token'],org)==[])
(ROOT/'.local-auth/s02-support.json').write_text(json.dumps({'organization':org,'foreign':foreign}));out=ROOT/'preuves/S02-support-tickets';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

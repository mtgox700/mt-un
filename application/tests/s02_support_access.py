from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0];source=source.replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:");exec(compile(source,str(Path(__file__).with_name('s02_identity_integration.py')),'exec'))
import uuid,subprocess
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());a,b=accounts
org,foreign,rid,other,tid=[str(uuid.uuid4()) for _ in range(5)]
def sql(q):
 p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if p.returncode:raise RuntimeError('Local fixture SQL failed')
sql(f"""begin;insert into public.uniion_organizations values('{org}','Recette accès support S02',true),('{foreign}','Support externe fictif',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null);
insert into public.uniion_module_access values('{org}','dossiers',true,true,'included',now()+interval '10 days');
insert into public.uniion_permissions values('{org}','{a['id']}','dossiers','read');
insert into public.uniion_authorities values('{org}','{a['id']}','share',false),('{org}','{a['id']}','download',false);
insert into public.uniion_resources(id,organization_id,module,title,body,external_share_allowed) values('{rid}','{org}','dossiers','Document fictif support','{{"text":"Contenu fictif version 1"}}',true),('{other}','{org}','dossiers','Non sélectionné','{{}}',true);
insert into public.uniion_resource_grants values('{org}','{rid}','{a['id']}',false,true,now()+interval '10 days',null);
insert into uniion_private.support_agents values('{b['id']}','Agent de recette',true),('{a['id']}','Autre agent fictif',true) on conflict do nothing;
insert into uniion_private.support_tickets(id,organization_id,title,created_by) values('{tid}','{org}','Ticket accès temporaire fictif','{a['id']}');
insert into uniion_private.support_assignments(ticket,user_id) values('{tid}','{b['id']}'),('{tid}','{a['id']}');commit;""")
x=Client();y=Client()
data={'organization_id':org,'ticket':tid,'agents':[b['id']],'resources':[rid],'until':'2099-01-01T00:00:00Z','download':False}
from datetime import datetime,timezone,timedelta
data['until']=(datetime.now(timezone.utc)+timedelta(hours=1)).isoformat()
def grant(**kw):return x.call('/identity/support/approve',{**data,**kw})
def read(c,g,**kw):return c.call('/identity/support/read',{'organization_id':org,'ticket':tid,'grant':g,'resource':rid,'download':False,**kw})
check('anonymous_denied',grant()[0]==403);check('login_manager',x.login(a)[0]==200);check('aal1_denied',grant()[0]==403)
(st,_,_),_=verify(x,f['factor'],f['secret']);check('manager_mfa',st==200)
check('login_agent',y.login(b)[0]==200);(st,_,_),_=verify(y,f['recipientFactor'],f['recipientSecret']);check('agent_mfa',st==200)
check('assignment_no_access',api.resources(y.state()['access_token'],org)==[])
check('agent_no_approval',y.call('/identity/support/approve',data)[0]==403)
check('unknown_agent_denied',grant(agents=[str(uuid.uuid4())])[0]==403)
check('empty_agents_denied',grant(agents=[])[0]==403)
check('unowned_resource_denied',grant(resources=[other])[0]==403)
check('too_long_expiry_denied',grant(until='2099-01-01T00:00:00Z')[0]==403)
check('wrong_org_denied',grant(organization_id=foreign)[0]==403)
st,d,_=grant();gid=d.get('id');check('explicit_approval',st==200 and gid)
check('named_agent_read',read(y,gid)[0]==200);check('unnamed_agent_denied',read(x,gid)[0]==403);check('download_denied',read(y,gid,download=True)[0]==403);check('other_resource_denied',read(y,gid,resource=other)[0]==403);check('other_org_read_denied',read(y,gid,organization_id=foreign)[0]==403)
sql(f"update public.uniion_resources set version=2,body='{{\"text\":\"Version 2 non partagée\"}}' where id='{rid}';")
check('immutable_selected_version',read(y,gid)[1]['body']['text']=='Contenu fictif version 1')
check('revoke',x.call('/identity/support/revoke',{'organization_id':org,'ticket':tid,'grant':gid})[0]==200);check('revoked_read_denied',read(y,gid)[0]==403)
st,d,_=grant(download=True);gid=d.get('id');check('download_approval',st==200);check('controlled_download',read(y,gid,download=True)[0]==200)
sql(f"update uniion_private.support_grants set expires=now()-interval '1 second' where id='{gid}';")
check('expiry_denied',read(y,gid)[0]==403)
st,d,_=grant(download=True);gid=d.get('id')
check('close',x.call('/identity/support/status',{'organization_id':org,'ticket':tid,'action':'close'})[0]==200);check('closed_read_denied',read(y,gid)[0]==403);check('closed_download_denied',read(y,gid,download=True)[0]==403)
check('reopen',x.call('/identity/support/status',{'organization_id':org,'ticket':tid,'action':'reopen'})[0]==200);check('reopen_no_reactivation',read(y,gid)[0]==403)
st,d,_=grant();gid=d.get('id');sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}';");check('module_disabled_denied',read(y,gid)[0]==403);sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}';")
check('agent_still_no_membership_resources',api.resources(y.state()['access_token'],org)==[])
(ROOT/'.local-auth/s02-support-access.json').write_text(json.dumps({'organization':org,'ticket':tid,'resource':rid,'grant':gid}));out=ROOT/'preuves/S02-support-acces';out.mkdir(exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

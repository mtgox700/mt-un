from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0]
exec(compile(src,__file__,'exec'))
out=ROOT/'preuves/S07-B';f=json.loads((ROOT/'.local-auth/s07-fixture.json').read_text());org=f['organization'];a,b=accounts;t=f['third'];mf=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text())
x,y=Client(),Client()
check('login_author',x.login(a)[0]==200);verify(x,mf['factor'],mf['secret']);check('login_other',y.login(b)[0]==200);verify(y,mf['recipientFactor'],mf['recipientSecret'])
def rpc(c,action,payload,o=org):return api.request('/rest/v1/rpc/uniion_messaging',c.state()['access_token'],{'p_org':o,'p_action':action,'p_payload':payload})
def denied(c,action,payload,o=org):
 try:rpc(c,action,payload,o);return False
 except AccessDenied:return True
p={'clientId':str(uuid.uuid4()),'name':'Refus ciblés B','desc':'Fictif','members':[t['id']]}
g=rpc(x,'group_create',p);cid=g['id']
check('org_admin_outsider_no_read',denied(y,'get',{'id':cid}))
check('org_admin_outsider_no_manage',denied(y,'group_save',{'id':cid,'version':g['version'],'name':'Intrusion','desc':'','members':[a['id']]}))
for bad in [{**p,'members':[b['id'],b['id']]},{**p,'members':[None]},{**p,'name':None},{**p,'admin':True},{**p,'members':[str(uuid.uuid4())]}]:
 check('direct_bad_create_'+str(len(checks)),denied(x,'group_create',bad))
def current():return rpc(x,'get',{'id':cid})
period=next(m['period'] for m in g['memberRows'] if m['id']==t['id'])
for action,extra in [('member_role',{'participant':t['id'],'admin':'true'}),('history_grant',{'period':period,'messages':[None]}),('history_grant',{'period':period,'messages':['1','1']}),('history_grant',{'period':str(uuid.uuid4()),'messages':['1']}),('leave',{'admin':True})]:
 check('direct_bad_'+action+'_'+str(len(checks)),denied(x,action,{'id':cid,'version':g['version'],**extra}))
check('foreign_organization_denied',denied(x,'history_revoke',{'id':cid,'version':1,'period':period},f['foreign']))
rpc(x,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Historique fictif'})
rpc(x,'history_grant',{'id':cid,'version':current()['version'],'period':period,'messages':['1']})
check('grant_audited',sql(f"select exists(select 1 from public.uniion_security_events where organization_id='{org}' and event='message.history_granted' and details->>'conversation'='{cid}' and details->>'target'='{period}')")=='t')
check('grants_private',sql("select not has_table_privilege('authenticated','uniion_private.message_history_grants','select,insert,update,delete')")=='t')
check('internal_rpc_not_executable',sql("select not has_function_privilege('authenticated','uniion_private.messaging_a(uuid,text,jsonb)','execute')")=='t')
# Existing moderator with read removed cannot be the only successor.
rpc(x,'member_role',{'id':cid,'version':current()['version'],'participant':t['id'],'admin':True})
sql(f"delete from public.uniion_permissions where organization_id='{org}' and user_id='{t['id']}' and module='messagerie' and permission='read'")
try:
 check('inaccessible_successor_cannot_allow_leave',denied(x,'leave',{'id':cid,'version':current()['version']}))
 check('unreadable_recipient_history_denied',denied(x,'history_grant',{'id':cid,'version':current()['version'],'period':period,'messages':['1']}))
finally:sql(f"insert into public.uniion_permissions values('{org}','{t['id']}','messagerie','read') on conflict do nothing")
sql(f"insert into uniion_private.membership_suspensions values('{org}','{t['id']}',true) on conflict(organization_id,user_id) do update set suspended=true")
try:check('suspended_recipient_history_denied',denied(x,'history_grant',{'id':cid,'version':current()['version'],'period':period,'messages':['1']}))
finally:sql(f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}' and user_id='{t['id']}'")
# Same expected version: exactly one mutation commits.
import concurrent.futures
version=current()['version']
def edit(n):
 try:rpc(x,'group_save',{'id':cid,'version':version,'name':'Concurrent '+str(n),'desc':'','members':[t['id']]});return True
 except AccessDenied:return False
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(edit,[1,2]))
check('concurrent_versions_one_winner',sum(results)==1)
# An organization re-invitation gets a fresh conversation episode on explicit addition.
old=sql(f"select joined_at from public.uniion_memberships where organization_id='{org}' and user_id='{t['id']}'")
sql(f"update public.uniion_memberships set joined_at=now() where organization_id='{org}' and user_id='{t['id']}'")
try:
 check('stale_episode_not_exposed',all(m['id']!=t['id'] for m in current()['memberRows']))
 rpc(x,'group_save',{'id':cid,'version':current()['version'],'name':'Nouvelle période','desc':'','members':[t['id']]})
 check('org_reinvite_fresh_period',next(m['period'] for m in current()['memberRows'] if m['id']==t['id'])!=period)
finally:
 # Restore the fixture's organization date and close this test-only episode with an ordinary update.
 sql(f"update public.uniion_memberships set joined_at='{old}' where organization_id='{org}' and user_id='{t['id']}'")
 rpc(x,'group_save',{'id':cid,'version':current()['version'],'name':'Refus ciblés B','desc':'Fictif','members':[t['id']]})
(out/'access-edges.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

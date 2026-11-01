"""Additional direct-RPC refusals on the already-created local S07 fixtures."""
from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0]
exec(compile(src,__file__,'exec'))
f=json.loads((ROOT/'.local-auth/s07-fixture.json').read_text());org=f['organization'];cid=f['conversation'];a,b=accounts
mfa=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text())
x=Client();check('login',x.login(a)[0]==200);verify(x,mfa['factor'],mfa['secret'])
def rpc(action,payload):return api.request('/rest/v1/rpc/uniion_messaging',x.state()['access_token'],{'p_org':org,'p_action':action,'p_payload':payload})
def refuse(action,payload):
 try:rpc(action,payload);return False
 except AccessDenied:return True
for action,p in [('get',{'id':cid,'before':None}),('get',{'id':cid,'before':'-1'}),('get',{'id':cid,'extra':1}),('send',{'id':cid,'clientId':str(uuid.uuid4()),'text':None}),('send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'x','replyTo':None}),('send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'x','author':b['id']}),('send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'x'+' '*10000}),('create',{'participant':a['id']}),('participants',{'extra':1}),('list',{'before':None})]:
 check('direct_invalid_'+action+'_'+str(len(checks)),refuse(action,p))
check('private_tables_no_authenticated_privilege',sql("select bool_and(not has_table_privilege('authenticated',c.oid,'select,insert,update,delete')) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='uniion_private' and c.relname in ('messages','message_conversations','message_participations')")=='t')
sql(f"delete from public.uniion_permissions where organization_id='{org}' and user_id='{a['id']}' and module='messagerie' and permission='read'")
try:check('read_permission_revoked_direct',refuse('get',{'id':cid}))
finally:sql(f"insert into public.uniion_permissions values('{org}','{a['id']}','messagerie','read') on conflict do nothing")
old=sql(f"select joined_at from public.uniion_memberships where organization_id='{org}' and user_id='{a['id']}'")
sql(f"update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{a['id']}'")
try:check('organization_departure_denied',refuse('get',{'id':cid}))
finally:sql(f"update public.uniion_memberships set revoked_at=null,joined_at=now() where organization_id='{org}' and user_id='{a['id']}'")
try:check('organization_reinvite_no_old_access',refuse('get',{'id':cid}))
finally:sql(f"update public.uniion_memberships set joined_at='{old}' where organization_id='{org}' and user_id='{a['id']}'")
check('fixture_restored',len(rpc('get',{'id':cid})['messages'])>0)
(out/'access-edges.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

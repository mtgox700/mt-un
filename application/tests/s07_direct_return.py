from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0]
exec(compile(src,__file__,'exec'))
out=ROOT/'preuves/S07-B';f=json.loads((ROOT/'.local-auth/s07-a-regression-fixture.json').read_text());org=f['organization'];a,b=accounts;mf=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text())
x,y=Client(),Client()
check('author_login',x.login(a)[0]==200);verify(x,mf['factor'],mf['secret']);check('recipient_login',y.login(b)[0]==200);verify(y,mf['recipientFactor'],mf['recipientSecret'])
def rpc(c,action,payload):return api.request('/rest/v1/rpc/uniion_messaging',c.state()['access_token'],{'p_org':org,'p_action':action,'p_payload':payload})
def denied(c,action,payload):
 try:rpc(c,action,payload);return False
 except AccessDenied:return True
cid=f['conversation']
old_period=next(m['period'] for m in rpc(y,'get',{'id':cid})['memberRows'] if m['me'])
joined=sql(f"select joined_at from public.uniion_memberships where organization_id='{org}' and user_id='{b['id']}'")
sql(f"update public.uniion_memberships set joined_at=now() where organization_id='{org}' and user_id='{b['id']}'")
check('no_automatic_read_on_org_return',denied(y,'get',{'id':cid}))
check('no_automatic_send_on_org_return',denied(y,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Refus'}))
check('no_automatic_list_on_org_return',all(r['id']!=cid for r in rpc(y,'list',{})['rows']))
g=rpc(y,'create',{'participant':a['id']})
new_period=next(m['period'] for m in g['memberRows'] if m['me'])
check('explicit_direct_reinvite',g['id']==cid and new_period!=old_period)
check('no_direct_history_restored',g['messages']==[])
check('direct_renewal_idempotent',next(m['period'] for m in rpc(y,'create',{'participant':a['id']})['memberRows'] if m['me'])==new_period)
check('direct_old_reply_denied',denied(y,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Refus','replyTo':'1'}))
m=rpc(x,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Message après retour explicite'})
check('new_direct_message_visible',[r['id'] for r in rpc(y,'get',{'id':cid})['messages']]==[m['id']])
check('renewal_audited',sql(f"select exists(select 1 from public.uniion_security_events where organization_id='{org}' and event='message.direct_reinvited' and details->>'conversation'='{cid}')")=='t')
# Test-only organization remains with its explicit new period; no real membership touched.
(out/'direct-return.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

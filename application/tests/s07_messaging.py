"""Local-only S07 acceptance: real Auth/MFA + user JWT RPCs. No secrets in proof."""
from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
import uuid,subprocess,concurrent.futures
out=ROOT/'preuves/S07-A';out.mkdir(exist_ok=True)
def sql(q):
 p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if p.returncode:raise RuntimeError(p.stderr.decode())
 return p.stdout.decode().strip()
a,b=accounts
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text())
org,foreign=str(uuid.uuid4()),str(uuid.uuid4())
third={'email':'s07-'+uuid.uuid4().hex+'@uniion-local.example','password':uuid.uuid4().hex+'aA1!'}
u=api.request('/auth/v1/signup',body=third);third['id']=u.get('user',u)['id']
sql(f"update auth.users set email_confirmed_at=coalesce(email_confirmed_at,now()) where id='{third['id']}'")
sql(f"""begin;
insert into public.uniion_organizations values('{org}','S07 — échanges fictifs',true),('{foreign}','S07 — autre organisation fictive',true);
insert into public.uniion_memberships values('{org}','{a['id']}',now()-interval '1 day',null),('{org}','{b['id']}',now()-interval '1 day',null),('{org}','{third['id']}',now()-interval '1 day',null),('{foreign}','{third['id']}',now()-interval '1 day',null);
insert into public.uniion_module_access values('{org}','messagerie',true,true,'included',now()+interval '10 days'),('{foreign}','messagerie',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','messagerie','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE'),('{foreign}','messagerie','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions select '{org}',u,'messagerie',p from unnest(array['{a['id']}'::uuid,'{b['id']}'::uuid,'{third['id']}'::uuid])u cross join unnest(array['read','write'])p;
insert into public.uniion_permissions values('{foreign}','{third['id']}','messagerie','read');
insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Membre'),('{org}','{b['id']}','Alex Recette','Membre'),('{org}','{third['id']}','Sam Hors conversation','Membre');
commit;""")
x,y,z=Client(),Client(),Client()
check('author_login',x.login(a)[0]==200);verify(x,f['factor'],f['secret'])
check('recipient_login',y.login(b)[0]==200);verify(y,f['recipientFactor'],f['recipientSecret'])
check('third_login',z.login(third)[0]==200)
def call(c,action,payload=None,o=org):
 # Test instance clock only: separate logical windows, never change production limits.
 app.sessions.clock=lambda:time.time()+len(checks)*61
 return c.call('/identity/messaging',{'organization_id':o,'action':action,'payload':payload or {}})
check('aal1_denied',call(z,'list')[0]==403)
st,factor,_=z.call('/auth/mfa/enroll',{'name':'Recette S07'});check('third_mfa_enroll',st==200)
verify(z,factor['id'],factor['totp']['secret'])
def rpc(c,action,payload=None,o=org):
 return api.request('/rest/v1/rpc/uniion_messaging',c.state()['access_token'],{'p_org':o,'p_action':action,'p_payload':payload or {}})
def denied(fn):
 try:fn();return False
 except AccessDenied:return True
check('anonymous_denied',call(Client(),'list')[0]==403)
check('empty_initial_list',call(x,'list')[1]['rows']==[])
st,people,_=call(x,'participants');print({'participants_status':st,'count':len(people)},flush=True);check('participants_real',st==200 and len(people)==2)
st,r,_=call(x,'create',{'participant':b['id']});check('conversation_created',st==200);cid=r['id']
check('create_retry_same_id',call(x,'create',{'participant':b['id']})[1]['id']==cid)
check('recipient_same_conversation',call(y,'create',{'participant':a['id']})[1]['id']==cid)
p={'id':cid,'clientId':str(uuid.uuid4()),'text':'Bonjour S07 <script>inert</script>'}
st,m,_=call(x,'send',p);check('message_persisted',st==200 and m['seq']=='1')
check('recipient_reads',call(y,'get',{'id':cid})[1]['messages'][0]['text']==p['text'])
check('retry_no_duplicate',call(x,'send',p)[1]['id']==m['id'])
check('changed_retry_denied',call(x,'send',{**p,'text':'autre'})[0]==403)
check('third_list_hidden',call(z,'list')[1]['rows']==[])
check('third_get_denied',call(z,'get',{'id':cid})[0]==403)
check('third_send_denied',call(z,'send',p)[0]==403)
check('foreign_get_denied',call(z,'get',{'id':cid},foreign)[0]==403)
check('foreign_participant_denied',call(x,'create',{'participant':str(uuid.uuid4())})[0]==403)
check('forged_author_denied',call(x,'send',{**p,'author':b['id']})[0]==403)
check('private_tables_denied',denied(lambda:api.request('/rest/v1/messages?select=*',x.state()['access_token'])))
check('direct_rpc_third_denied',denied(lambda:rpc(z,'get',{'id':cid})))
# Concurrent retries on the real database, with caller JWTs.
p2={'id':cid,'clientId':str(uuid.uuid4()),'text':'Rejeu concurrent'}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rs=list(pool.map(lambda _:rpc(x,'send',p2),range(4)))
check('concurrent_single_message',len({r['id'] for r in rs})==1)
check('reply_same_thread',call(y,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Réponse','replyTo':'1'})[1]['reply']['text']==p['text'])
check('reply_missing_denied',call(y,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Réponse','replyTo':'999'})[0]==403)
for n in range(55):rpc(x,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Pagination fictive '+str(n)})
page=rpc(y,'get',{'id':cid});check('page_bound',len(page['messages'])==50 and page['next'] is not None)
rpc(x,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Arrivé entre deux pages'})
older=rpc(y,'get',{'id':cid,'before':page['next']})
check('pagination_stable',len(older['messages'])==8 and not({m['id'] for m in older['messages']}&{m['id'] for m in page['messages']}))
check('reconnect',y.call('/auth/logout',{})[0]==200)
y=Client();check('relogin',y.login(b)[0]==200);verify(y,f['recipientFactor'],f['recipientSecret'])
check('persistent_after_reconnect',len(call(y,'get',{'id':cid})[1]['messages'])==50)
sql(f"delete from public.uniion_permissions where organization_id='{org}' and user_id='{b['id']}' and module='messagerie' and permission='write'")
check('read_without_write',call(y,'get',{'id':cid})[0]==200)
check('write_permission_denied',call(y,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'interdit'})[0]==403)
sql(f"insert into public.uniion_permissions values('{org}','{b['id']}','messagerie','write');update public.uniion_module_access set enabled=false where organization_id='{org}' and module='messagerie'")
check('disabled_denied',call(x,'get',{'id':cid})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='messagerie';update uniion_private.module_entitlements set ends=now()-interval '1 second' where organization_id='{org}' and module='messagerie'")
check('expired_entitlement_denied',call(x,'list')[0]==403)
sql(f"update uniion_private.module_entitlements set ends=now()+interval '10 days' where organization_id='{org}' and module='messagerie';insert into uniion_private.membership_suspensions values('{org}','{b['id']}',true)")
check('suspended_denied',call(y,'get',{'id':cid})[0]==403)
sql(f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}' and user_id='{b['id']}';update uniion_private.message_participations set left_at=now() where organization_id='{org}' and conversation='{cid}' and user_id='{b['id']}'")
check('departed_hidden',call(y,'list')[1]['rows']==[])
check('departed_get_denied',call(y,'get',{'id':cid})[0]==403)
# New period simulates the future B membership command, without reviving the old one.
sql(f"insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at,visible_from) select '{org}','{cid}',user_id,joined_at,60 from public.uniion_memberships where organization_id='{org}' and user_id='{b['id']}'")
check('reinvited_no_history',call(y,'get',{'id':cid})[1]['messages']==[])
check('old_reply_denied',call(y,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'ancien','replyTo':'1'})[0]==403)
check('new_period_message',call(x,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Visible après réinvitation'})[0]==200)
check('new_period_only',len(call(y,'get',{'id':cid})[1]['messages'])==1)
# Non-participant platform admin has no bypass: author's third-party conversation.
other=call(y,'create',{'participant':third['id']})[1]['id']
check('admin_nonparticipant_denied',call(x,'get',{'id':other})[0]==403)
# Safe browser fixtures: no privileged token, credentials are kept in ignored local auth.
fixture={'organization':org,'conversation':cid,'other':other,'foreign':foreign,'third':third,'thirdFactor':factor['id'],'thirdSecret':factor['totp']['secret']}
path=ROOT/'.local-auth/s07-fixture.json';path.write_text(json.dumps(fixture));path.chmod(0o600)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2))
print(json.dumps({'passed':True,'count':len(checks)}))

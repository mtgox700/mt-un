"""Local group/membership/history acceptance, with real user JWTs and MFA."""
from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0]
exec(compile(src,__file__,'exec'))
out=ROOT/'preuves/S07-B';out.mkdir(exist_ok=True)
f=json.loads((ROOT/'.local-auth/s07-fixture.json').read_text());org=f['organization'];a,b=accounts;t=f['third']
mf=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text())
x,y,z=Client(),Client(),Client()
for label,c,account,factor,secret in [('author',x,a,mf['factor'],mf['secret']),('member',y,b,mf['recipientFactor'],mf['recipientSecret']),('late',z,t,f['thirdFactor'],f['thirdSecret'])]:
 check(label+'_login',c.login(account)[0]==200);verify(c,factor,secret)
sql(f"insert into public.uniion_permissions values('{org}','{a['id']}','messagerie','create') on conflict do nothing;insert into public.uniion_authorities values('{org}','{a['id']}','history',false),('{org}','{b['id']}','organization_edit',false) on conflict do nothing")
tick=0
def call(c,action,payload=None,o=org):
 global tick
 tick+=1;app.sessions.clock=lambda:time.time()+(tick//10)*61
 return c.call('/identity/messaging',{'organization_id':o,'action':action,'payload':payload or {}})
def get(c,cid):return call(c,'get',{'id':cid})[1]
def change(c,cid,action,**extra):return call(c,action,{'id':cid,'version':get(c,cid)['version'],**extra})
def send(c,cid,text,reply=None):return call(c,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':text,**({'replyTo':reply} if reply else {})})
create={'clientId':str(uuid.uuid4()),'name':'Groupe de recette B','desc':'Contenus fictifs uniquement.','members':[b['id']]}
check('no_create_permission_denied',call(y,'group_create',{**create,'members':[a['id']]})[0]==403)
st,g,_=call(x,'group_create',create);check('group_created',st==200 and g['kind']=='group');cid=g['id']
check('creation_replayed_once',call(x,'group_create',create)[1]['id']==cid)
check('creation_reuse_changed_denied',call(x,'group_create',{**create,'name':'autre'})[0]==403)
check('creator_admin',g['canManage'] and next(m for m in g['memberRows'] if m['me'])['admin'])
check('org_admin_not_group_admin',not get(y,cid)['canManage'])
check('member_change_denied',change(y,cid,'group_save',name=g['name'],desc=g['desc'],members=[a['id'],t['id']])[0]==403)
check('old_message_one',send(x,cid,'Ancien message confidentiel')[0]==200)
check('old_reply_two',send(x,cid,'Ancienne réponse','1')[0]==200)
old_version=get(x,cid)['version']
st,g,_=change(x,cid,'group_save',name=g['name'],desc=g['desc'],members=[b['id'],t['id']]);check('add_member',st==200)
period=next(m['period'] for m in g['memberRows'] if m['id']==t['id'])
check('arrival_hides_old',get(z,cid)['messages']==[])
check('arrival_sequence_boundary',next(m['visibleFrom'] for m in g['memberRows'] if m['id']==t['id'])=='3')
check('stale_members_change_denied',call(x,'group_save',{'id':cid,'version':old_version,'name':'perime','desc':'','members':[b['id']]})[0]==403)
check('future_reply_sent',send(x,cid,'Nouveau message avec citation','1')[0]==200)
new=get(z,cid)['messages'];check('reply_source_hidden',len(new)==1 and new[0]['reply'] is None)
check('history_without_authority_denied',change(y,cid,'history_grant',period=period,messages=['1'])[0]==403)
check('history_granted_one',change(x,cid,'history_grant',period=period,messages=['2'])[0]==200)
r=get(z,cid)['messages'];check('selected_only_and_quote_filtered',[m['seq'] for m in r]==['2','3'] and all(m['reply'] is None for m in r))
check('history_granted_source',change(x,cid,'history_grant',period=period,messages=['1'])[0]==200)
check('quote_visible_after_grant',get(z,cid)['messages'][-1]['reply']['text']=='Ancien message confidentiel')
check('history_revoke',change(x,cid,'history_revoke',period=period)[0]==200)
r=get(z,cid)['messages'];check('revoked_history_hidden',[m['seq'] for m in r]==['3'] and r[0]['reply'] is None)
check('history_again',change(x,cid,'history_grant',period=period,messages=['1'])[0]==200)
check('remove_member',change(x,cid,'group_save',name=g['name'],desc=g['desc'],members=[b['id']])[0]==200)
check('removed_read_denied',call(z,'get',{'id':cid})[0]==403)
check('removed_send_denied',send(z,cid,'refuse')[0]==403)
check('removed_list_hidden',all(r['id']!=cid for r in call(z,'list')[1]['rows']))
check('message_during_absence',send(x,cid,'Pendant absence')[0]==200)
st,g,_=change(x,cid,'group_save',name=g['name'],desc=g['desc'],members=[b['id'],t['id']]);check('reinvite',st==200)
new_period=next(m['period'] for m in g['memberRows'] if m['id']==t['id'])
check('fresh_episode',new_period!=period)
check('reinvite_no_restored_history',get(z,cid)['messages']==[])
check('old_episode_grant_denied',change(x,cid,'history_grant',period=period,messages=['1'])[0]==403)
check('send_after_reinvite',send(x,cid,'Depuis nouvelle arrivée')[0]==200)
check('new_boundary_only',[m['seq'] for m in get(z,cid)['messages']]==['5'])
# An authority does not let the newly invited reader grant unseen messages to anybody.
sql(f"insert into public.uniion_authorities values('{org}','{t['id']}','history',false) on conflict do nothing")
b_period=next(m['period'] for m in get(x,cid)['memberRows'] if m['id']==b['id'])
check('cannot_grant_beyond_own_access',change(z,cid,'history_grant',period=b_period,messages=['1'])[0]==403)
check('cannot_self_grant',change(z,cid,'history_grant',period=new_period,messages=['1'])[0]==403)
check('cannot_promote_self',change(y,cid,'member_role',participant=b['id'],admin=True)[0]==403)
check('creator_cannot_target_self_role',change(x,cid,'member_role',participant=a['id'],admin=False)[0]==403)
check('last_admin_cannot_leave',change(x,cid,'leave')[0]==403)
check('promote_member',change(x,cid,'member_role',participant=b['id'],admin=True)[0]==200)
check('promoted_can_manage',get(y,cid)['canManage'])
check('promoted_has_no_history_authority',not get(y,cid)['canHistory'])
check('second_admin_can_leave',change(y,cid,'leave')[0]==200)
check('left_admin_denied',call(y,'get',{'id':cid})[0]==403)
check('readd_admin_as_regular',change(x,cid,'group_save',name=g['name'],desc=g['desc'],members=[b['id'],t['id']])[0]==200)
check('role_not_restored',not get(y,cid)['canManage'])
# Same lock serializes send versus addition. Any message committed before join is hidden.
import concurrent.futures
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 ps=[pool.submit(lambda:api.request('/rest/v1/rpc/uniion_messaging',x.state()['access_token'],{'p_org':org,'p_action':'send','p_payload':{'id':cid,'clientId':str(uuid.uuid4()),'text':'Concurrence B'}})),
     pool.submit(lambda:api.request('/rest/v1/rpc/uniion_messaging',x.state()['access_token'],{'p_org':org,'p_action':'group_save','p_payload':{'id':cid,'version':get(x,cid)['version'],'name':g['name'],'desc':g['desc'],'members':[b['id']]}}))]
 for p in ps:p.result()
check('concurrent_remove_effective',call(z,'get',{'id':cid})[0]==403)
# Leave UI fixture with all three current members, third freshly joined and history hidden.
st,g,_=change(x,cid,'group_save',name='Commission S07 — membres et historique',desc='Groupe fictif de recette du lot B.',members=[b['id'],t['id']]);check('ui_group_ready',st==200)
ui=ROOT/'.local-auth/s07-b-fixture.json';ui.write_text(json.dumps({'organization':org,'group':cid,'oldPeriod':period}));ui.chmod(0o600)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

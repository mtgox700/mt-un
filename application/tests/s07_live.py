from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0];exec(compile(src,__file__,'exec'))
out=ROOT/'preuves/S07-E';a,b=accounts;mf=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());base=json.loads((ROOT/'.local-auth/s07-fixture.json').read_text());t=base['third'];org=str(uuid.uuid4())
sql(f"""begin;
insert into public.uniion_organizations values('{org}','S07 E — échanges fictifs',true);
insert into public.uniion_memberships select '{org}',u,now()-interval '1 day',null from unnest(array['{a['id']}'::uuid,'{b['id']}'::uuid,'{t['id']}'::uuid])u;
insert into public.uniion_module_access values('{org}','messagerie',true,true,'included',now()+interval '10 days');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','messagerie','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions select '{org}',u,'messagerie',p from unnest(array['{a['id']}'::uuid,'{b['id']}'::uuid,'{t['id']}'::uuid])u cross join unnest(array['read','write','create'])p;
insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Membre'),('{org}','{b['id']}','Alex Recette','Membre'),('{org}','{t['id']}','Sam Recette','Membre');commit;""")
x,y,z=Client(),Client(),Client()
for c,account,factor,secret in [(x,a,mf['factor'],mf['secret']),(y,b,mf['recipientFactor'],mf['recipientSecret']),(z,t,base['thirdFactor'],base['thirdSecret'])]:
 check('login',c.login(account)[0]==200)
 if c is z:check('aal1_live_denied',c.call('/identity/messaging',{'organization_id':org,'action':'live','payload':{}})[0]==403)
 check('mfa',verify(c,factor,secret)[0][0]==200)
def call(c,action,payload=None):
 app.sessions.attempts={} # Isolated test instance only.
 return c.call('/identity/messaging',{'organization_id':org,'action':action,'payload':payload or {}})
st,g,_=call(x,'group_create',{'clientId':str(uuid.uuid4()),'name':'Temps réel E','desc':'Recette fictive','members':[b['id']]});check('group',st==200);cid=g['id']
def send(text):return call(x,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':text})[1]
m=send('Premier message E');check('recipient_unread',call(y,'get',{'id':cid})[1]['unread']==1);check('author_no_unread',call(x,'get',{'id':cid})[1]['unread']==0)
check('outsider_no_notices',call(z,'notices')[1]==[]);check('outsider_no_live_metadata',call(z,'live')[1]['conversations']==[])
check('notice_reference_only',set(call(y,'notices')[1][0])=={'id','conversation','seq','title','created'})
check('cannot_read_hidden',call(z,'read',{'id':cid,'seq':m['seq']})[0]==403)
check('read_ack',call(y,'read',{'id':cid,'seq':m['seq']})[1]['unread']==0);check('notices_clear',call(y,'notices')[1]==[])
n=send('Deuxième message E');check('new_unread',call(y,'get',{'id':cid})[1]['unread']==1)
check('old_read_no_regression',call(y,'read',{'id':cid,'seq':m['seq']})[1]['unread']==1)
check('future_read_denied',call(y,'read',{'id':cid,'seq':'999999'})[0]==403)
check('invalid_read_input',call(y,'read',{'id':cid,'seq':2})[0]==403)
# Actual WSGI streaming iterator, including a mutation while already subscribed.
def stream(c,extra='',**headers):
 result=[];e={'REQUEST_METHOD':'GET','PATH_INFO':'/identity/messaging/events','QUERY_STRING':'organization='+org+'&id='+cid+extra,'HTTP_HOST':'127.0.0.1:5060','HTTP_ORIGIN':'http://127.0.0.1:5060','HTTP_COOKIE':c.cookie,**headers}
 it=app(e,lambda s,h:result.append((s,dict(h))));return iter(it),result
it,r=stream(y);check('sse_authenticated',r[0][0]=='200 OK' and r[0][1]['Content-Type']=='text/event-stream');check('sse_retry',b'retry' in next(it));frame=next(it);check('sse_state',b'event: state' in frame and b'Deuxi' in frame)
initial=json.loads(frame.decode().split('data: ',1)[1]);last=y.state()['last'];n=send('Direct sur canal E');frame=next(it);check('open_channel_new_message',b'Direct sur canal E' in frame);check('stream_not_user_activity',y.state()['last']==last)
resume=json.loads(frame.decode().split('data: ',1)[1])['cursor'];it.close();it,r=stream(y,'&cursor='+resume);next(it);check('resume_authoritative_snapshot',b'Direct sur canal E' in next(it));it.close()
it,r=stream(y,'&at=1');next(it);state=json.loads(next(it).decode().split('data: ',1)[1]);check('historic_focus_preserved',state['thread']['focused']=='1' and len(state['thread']['messages'])==1);it.close()
it,r=stream(y);next(it);next(it)
g=call(x,'get',{'id':cid})[1];check('remove_member',call(x,'group_save',{'id':cid,'version':g['version'],'name':g['name'],'desc':g['desc'],'members':[]})[0]==200)
frame=next(it);check('open_channel_revoked_thread_empty',json.loads(frame.decode().split('data: ',1)[1])['thread'] is None);check('no_revoked_text',b'canal E' not in frame);it.close()
check('departed_notices_empty',call(y,'notices')[1]==[])
g=call(x,'get',{'id':cid})[1];call(x,'group_save',{'id':cid,'version':g['version'],'name':g['name'],'desc':g['desc'],'members':[b['id']]});check('reinvite_no_old_counts',call(y,'get',{'id':cid})[1]['unread']==0)
new=send('Après réinvitation E');check('reinvite_new_unread',call(y,'get',{'id':cid})[1]['unread']==1)
it,r=stream(y);next(it);next(it)
sql(f"delete from public.uniion_permissions where organization_id='{org}' and user_id='{b['id']}' and module='messagerie' and permission='read'");app.message_hub.wake();check('permission_revokes_channel',b'event: revoked' in next(it));it.close()
sql(f"insert into public.uniion_permissions values('{org}','{b['id']}','messagerie','read')")
it,r=stream(y,HTTP_ORIGIN='https://other.invalid');check('foreign_origin_denied',r[0][0].startswith('403'))
it,r=stream(y,HTTP_SEC_FETCH_SITE='cross-site');check('cross_site_denied',r[0][0].startswith('403'))
it,r=stream(y,HTTP_COOKIE='');check('anonymous_stream_denied',r[0][0].startswith('403'))
it,r=stream(y);next(it);next(it);y.state()['end']=time.time()-1;app.message_hub.wake();check('expired_stream_closed',b'event: revoked' in next(it));it.close()
check('connections_released',not app.message_hub.active)
check('reads_private',sql("select has_table_privilege('authenticated','uniion_private.message_reads','select')")=='f')
(ROOT/'.local-auth/s07-e-fixture.json').write_text(json.dumps({'organization':org,'conversation':cid}));(ROOT/'.local-auth/s07-e-fixture.json').chmod(0o600)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

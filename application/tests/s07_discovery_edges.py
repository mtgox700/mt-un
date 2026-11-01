from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0];exec(compile(src,__file__,'exec'))
out=ROOT/'preuves/S07-D';f=json.loads((ROOT/'.local-auth/s07-d-fixture.json').read_text());mf=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());base=json.loads((ROOT/'.local-auth/s07-fixture.json').read_text());a,b=accounts;t=base['third'];org=f['organization'];cid=f['source'];dest=f['target'];second=f['second'];x,y,z=Client(),Client(),Client()
for c,account,factor,secret in [(x,a,mf['factor'],mf['secret']),(y,b,mf['recipientFactor'],mf['recipientSecret']),(z,t,base['thirdFactor'],base['thirdSecret'])]:
 check('login',c.login(account)[0]==200)
 if c is z:check('aal1_search_denied',c.call('/identity/messaging',{'organization_id':org,'action':'search','payload':{'query':'Aiguille'}})[0]==403)
 check('mfa',verify(c,factor,secret)[0][0]==200)
def call(c,action,payload):
 app.sessions.clock=lambda:time.time()+len(checks)*61
 return c.call('/identity/messaging',{'organization_id':org,'action':action,'payload':payload})
def rpc(c,name,args):return api.request('/rest/v1/rpc/'+name,c.state()['access_token'],args)
def denied(fn):
 try:fn();return False
 except AccessDenied:return True
check('legacy_rpc_not_exposed',denied(lambda:rpc(x,'uniion_messaging_before_search',{'p_org':org,'p_action':'list','p_payload':{}})))
def get(c,id):return call(c,'get',{'id':id})[1]
def modify(id,ids):
 g=get(x,id);return call(x,'group_save',{'id':id,'version':g['version'],'name':g['name'],'desc':g['desc'],'members':ids})
def history(id,c,seqs,grant=True):
 g=get(x,id);period=next(m['period'] for m in g['memberRows'] if m['id']==c)
 return call(x,'history_grant' if grant else 'history_revoke',{'id':id,'version':g['version'],'period':period,**({'messages':seqs} if grant else {})})
check('source_grant_for_dual_gate',history(cid,t['id'],['1'])[0]==200)
check('target_remove',modify(dest,[b['id']])[0]==200);check('target_reinvite',modify(dest,[b['id'],t['id']])[0]==200)
check('source_grant_does_not_bypass_target_period',all(m['seq']!=f['referenceSeq'] for m in get(z,dest)['messages']))
check('target_grant',history(dest,t['id'],[f['referenceSeq']])[0]==200)
check('both_history_gates_required',any(m['seq']==f['referenceSeq'] for m in get(z,dest)['messages']))
check('source_revoke',history(cid,t['id'],[],False)[0]==200)
check('target_grant_does_not_override_source_revoke',all(m['seq']!=f['referenceSeq'] for m in get(z,dest)['messages']))
# Bound chains, refusing before any destination mutation.
current,seq=cid,'1'
for depth in range(8):
 target=dest if depth%2==0 else second
 st,r,_=call(x,'forward',{'id':current,'seq':seq,'clientId':str(uuid.uuid4()),'targets':[target]});check('chain_depth_'+str(depth+1),st==200);current,seq=target,r['rows'][0]['seq']
check('ninth_reference_denied',call(x,'forward',{'id':current,'seq':seq,'clientId':str(uuid.uuid4()),'targets':[dest if current!=dest else second]})[0]==403)
# Source trash removes references and search hits, without deleting the object.
source=call(x,'locate',{'id':cid,'seq':f['fileSeq']})[1]['messages'][-1]['file']
def trash(p):
 app.sessions.clock=lambda:time.time()+len(checks)*61
 return x.call('/identity/cases',{'organization_id':org,'action':'file_trash','payload':p})
st,r,_=trash({'operation':'request','case':source['resource'],'attachment':source['id'],'expected':1,'reason':'other'});check('trash_request',st==200);ticket=r['id']
check('trash_approved',trash({'operation':'approve','request':ticket})[0]==200)
check('trashed_reference_hidden',all(not m.get('file') or m['file']['id']!=source['id'] for m in get(x,dest)['messages']))
sr=call(x,'search',{'query':'piece-source-D'})[1]['rows'];check('trashed_reference_not_searchable',all(r['conversation']==cid for r in sr))
check('trash_restore',trash({'operation':'restore','case':source['resource'],'request':ticket})[0]==200)
check('restore_still_respects_source_history',all(not m.get('file') or m['file']['id']!=source['id'] for m in get(z,dest)['messages']))
sql(f"delete from public.uniion_permissions where organization_id='{org}' and user_id='{b['id']}' and module='messagerie' and permission='write'")
check('reader_cannot_forward',call(y,'forward',{'id':cid,'seq':'1','clientId':str(uuid.uuid4()),'targets':[dest]})[0]==403)
sql(f"insert into public.uniion_permissions values('{org}','{b['id']}','messagerie','write');update public.uniion_module_access set enabled=false where organization_id='{org}' and module='messagerie'")
check('disabled_search_denied',call(x,'search',{'query':'needle'})[0]==403)
check('disabled_forward_denied',call(x,'forward',{'id':cid,'seq':'1','clientId':str(uuid.uuid4()),'targets':[dest]})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='messagerie';insert into uniion_private.membership_suspensions values('{org}','{b['id']}',true) on conflict(organization_id,user_id) do update set suspended=true")
check('suspended_search_denied',call(y,'search',{'query':'needle'})[0]==403)
sql(f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}' and user_id='{b['id']}';update uniion_private.module_entitlements set revoked_at=now() where organization_id='{org}' and module='messagerie'")
check('expired_commercial_search_denied',call(x,'search',{'query':'needle'})[0]==403)
sql(f"update uniion_private.module_entitlements set revoked_at=null where organization_id='{org}' and module='messagerie'")
check('forward_audit_minimal',sql(f"select count(*)>0 and bool_and(not(details ? 'text') and not(details ? 'body')) from public.uniion_security_events where organization_id='{org}' and event='message.forwarded_reference'")=='t')
(out/'edges.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0];exec(compile(src,__file__,'exec'))
out=ROOT/'preuves/S07-E';f=json.loads((ROOT/'.local-auth/s07-d-fixture.json').read_text());mf=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());base=json.loads((ROOT/'.local-auth/s07-fixture.json').read_text());a,b=accounts;t=base['third'];org=f['organization'];x,z=Client(),Client()
for c,ac,fac,secret in [(x,a,mf['factor'],mf['secret']),(z,t,base['thirdFactor'],base['thirdSecret'])]:
 check('login',c.login(ac)[0]==200);check('mfa',verify(c,fac,secret)[0][0]==200)
def call(c,a,p=None):
 app.sessions.attempts={};return c.call('/identity/messaging',{'organization_id':org,'action':a,'payload':p or {}})
s=call(z,'live',{'id':f['target']})[1];check('source_text_not_in_live', 'Aiguille' not in json.dumps(s));check('source_file_not_in_live','piece-source-D' not in json.dumps(s));check('no_hidden_reference_notices',all(n['seq']!=f['referenceSeq'] for n in s['notices'] if n['conversation']==f['target']))
check('mark_all',call(z,'read_all')[0]==200);check('mark_all_notices_empty',call(z,'notices')[1]==[]);check('all_authorized_counts_zero',all(c['unread']==0 for c in call(z,'live')[1]['conversations']));check('repeat_mark_all',call(z,'read_all')[0]==200);check('unexpected_mark_all_scope_denied',call(z,'read_all',{'actor':a['id']})[0]==403)
check('cannot_ack_hidden_source',call(z,'read',{'id':f['source'],'seq':'1'})[0]==403)
old=call(z,'live')[1]['cursor'];hidden=call(x,'group_create',{'clientId':str(uuid.uuid4()),'name':'Hors audience E','desc':'Fictif','members':[b['id']]})[1];call(x,'send',{'id':hidden['id'],'clientId':str(uuid.uuid4()),'text':'Texte hors audience'})
check('hidden_activity_does_not_change_cursor',call(z,'live')[1]['cursor']==old)
for name,change,restore in [
 ('module_disabled',f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='messagerie'",f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='messagerie'"),
 ('commercial_revoked',f"update uniion_private.module_entitlements set revoked_at=now() where organization_id='{org}' and module='messagerie'",f"update uniion_private.module_entitlements set revoked_at=null where organization_id='{org}' and module='messagerie'"),
 ('member_suspended',f"insert into uniion_private.membership_suspensions values('{org}','{t['id']}',true) on conflict(organization_id,user_id) do update set suspended=true",f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}' and user_id='{t['id']}'")]:
 sql(change)
 try:
  check(name+'_live_denied',call(z,'live')[0]==403);check(name+'_notices_denied',call(z,'notices')[0]==403)
 finally:sql(restore)
(out/'edges.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

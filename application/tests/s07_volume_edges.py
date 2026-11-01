"""Equivalence of optimized unread counts to the original per-message ACL."""
from pathlib import Path
src=Path(__file__).with_name('s07_live_edges.py').read_text().split("s=call(z,'live'")[0]
exec(compile(src,__file__,'exec'))
for label,actor in [('author',x),('history_restricted',z)]:
 token=actor.state()['access_token'];part=token.split('.')[1];claims=base64.urlsafe_b64decode(part+'='*((-len(part))%4)).decode()
 query="""begin;select set_config('request.jwt.claims',%s,true);
 select coalesce(bool_and(uniion_private.message_unread(c.organization_id,c.id)=(select count(*) from uniion_private.messages m where m.organization_id=c.organization_id and m.conversation=c.id and m.author<>auth.uid() and uniion_private.message_visible(m.organization_id,m.conversation,m.seq) and m.seq>coalesce((select r.seq from uniion_private.message_reads r join uniion_private.message_participations p on p.organization_id=r.organization_id and p.conversation=r.conversation and p.id=r.participation where r.organization_id=m.organization_id and r.conversation=m.conversation and p.user_id=auth.uid() and p.left_at is null),0))),true) from uniion_private.message_conversations c where c.organization_id='%s';rollback;"""%("'"+claims.replace("'","''")+"'",org)
 check('unread_equivalent_'+label,next(v for v in reversed(sql(query).splitlines()) if v in ('t','f'))=='t')
for payload in ({},{'query':'Aiguille'}):
 try:
  api.request('/rest/v1/rpc/uniion_messaging',x.state()['access_token'],{'p_org':org,'p_action':None,'p_payload':payload});blocked=False
 except AccessDenied:blocked=True
 check('null_action_denied',blocked)
check('revision_helper_private',sql("select has_function_privilege('authenticated','uniion_private.message_revision(uuid,uuid)','execute')")=='f')
# Rich file projections must still invalidate a cursor when quarantine changes.
before=call(x,'live')[1]['cursor']
status=sql(f"select scan_status||':'||ready::text from public.uniion_attachments where id='{f['attachment']}'")
try:
 sql(f"update public.uniion_attachments set scan_status='error',ready=false where id='{f['attachment']}'")
 check('file_quarantine_changes_revision',call(x,'live')[1]['cursor']!=before)
finally:
 scan,ready=status.split(':');sql(f"update public.uniion_attachments set scan_status='{scan}',ready={ready} where id='{f['attachment']}'")
check('restored_file_revision_matches',call(x,'live')[1]['cursor']==before)
(out/'volume-edges.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

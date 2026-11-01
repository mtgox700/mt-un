"""Targeted C concurrency, interruption, post-fetch revocation and direct-gateway checks."""
from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0];exec(compile(src,__file__,'exec'))
from unittest.mock import patch
from uniion.adapters import attachments,antivirus
out=ROOT/'preuves/S07-C';a,b=accounts;f=json.loads((ROOT/'.local-auth/s07-c-fixture.json').read_text());mf=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());org=f['organization'];cid=f['conversation'];aid=f['attachment'];rid=f['case'];lid=f['link'];x,y=Client(),Client()
for c,account,factor,secret in [(x,a,mf['factor'],mf['secret']),(y,b,mf['recipientFactor'],mf['recipientSecret'])]:
 check('login',c.login(account)[0]==200);check('mfa',verify(c,factor,secret)[0][0]==200)
def rpc(c,name,args):return api.request('/rest/v1/rpc/'+name,c.state()['access_token'],args)
def denied(fn):
 try:fn();return False
 except AccessDenied:return True
raw=(out/'piece-recette.png').read_bytes();key=str(uuid.uuid4());params={'p_org':org,'p_conversation':cid,'p_client':key,'p_filename':'reprise-longue.png','p_mime':'image/png','p_size':len(raw),'p_sha256':hashlib.sha256(raw).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rs=list(pool.map(lambda _:rpc(x,'uniion_message_file_prepare',params),range(4)))
check('concurrent_prepare_single_object',len({r['id'] for r in rs})==1)
ident=rs[0]['id'];sql(f"update public.uniion_attachments set created_at=now()-interval '1 hour' where id='{ident}'")
item=rpc(x,'uniion_message_file_prepare',params);check('old_interrupted_preparation_same_object',item['id']==ident and not item['uploaded'])
attachments.storage(api,x.state()['access_token'],item['path'],raw,'image/png');attachments.rescan(api,x.state()['access_token'],org,{'attachment':ident});check('old_interrupted_upload_resumed',True)
# Stale scanner completion cannot release a newer generation.
rpc(x,'uniion_scan_request',{'p_org':org,'p_attachment':ident});worker=antivirus.worker_token(api);old=api.request('/rest/v1/rpc/uniion_scan_job',worker,{'p_attachment':ident});rpc(x,'uniion_scan_request',{'p_org':org,'p_attachment':ident})
check('old_scan_generation_denied',denied(lambda:api.request('/rest/v1/rpc/uniion_scan_result',worker,{'p_attachment':ident,'p_sha256':old['sha256'],'p_status':'clean','p_engine':'fixture','p_reason':'','p_generation':old['generation']})))
check('pending_cannot_download',denied(lambda:attachments.download(api,x.state()['access_token'],org,{'attachment':ident})))
attachments.rescan(api,x.state()['access_token'],org,{'attachment':ident});check('fresh_scan_resumed',True)
check('private_file_table_denied',denied(lambda:api.request('/rest/v1/message_files?select=*',x.state()['access_token'])))
check('private_links_table_denied',denied(lambda:api.request('/rest/v1/case_links?select=*',x.state()['access_token'])))
# Post-fetch revocation: bytes must never escape the gateway.
sql(f"insert into public.uniion_authorities values('{org}','{b['id']}','download',false) on conflict do nothing")
original=attachments.storage
revoked=False
def revoke_after_fetch(*args,**kwargs):
 global revoked
 data=original(*args,**kwargs)
 if not revoked:
  sql(f"delete from public.uniion_authorities where organization_id='{org}' and user_id='{b['id']}' and permission='download'");revoked=True
 return data
with patch.object(attachments,'storage',side_effect=revoke_after_fetch):check('download_revoked_after_fetch',denied(lambda:attachments.download(api,y.state()['access_token'],org,{'attachment':aid})))
# Suspension/entitlement/permission all affect generic attachment RPCs, too.
sql(f"insert into uniion_private.membership_suspensions values('{org}','{b['id']}',true) on conflict(organization_id,user_id) do update set suspended=true")
args={'p_org':org,'p_attachment':aid,'p_preview':True,'p_audit':False}
check('suspended_direct_preview_denied',denied(lambda:rpc(y,'uniion_attachment_get',args)))
sql(f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}' and user_id='{b['id']}';delete from public.uniion_permissions where organization_id='{org}' and user_id='{b['id']}' and module='messagerie' and permission='read'")
check('read_permission_revoked',denied(lambda:rpc(y,'uniion_attachment_get',args)))
sql(f"insert into public.uniion_permissions values('{org}','{b['id']}','messagerie','read');update uniion_private.module_entitlements set revoked_at=now() where organization_id='{org}' and module='messagerie'")
check('commercial_revoked',denied(lambda:rpc(x,'uniion_attachment_get',args)))
sql(f"update uniion_private.module_entitlements set revoked_at=null where organization_id='{org}' and module='messagerie'")
check('preview_restored_current_reader',rpc(y,'uniion_attachment_get',args)['id']==aid)
projection=rpc(y,'uniion_messaging',{'p_org':org,'p_action':'get','p_payload':{'id':cid}})
file=next(m['file'] for m in projection['messages'] if m.get('file',{}).get('id')==aid)
check('authorized_recovery_projection',file['preview'] and file['uploaded'] and len(file['sha256'])==64)
(out/'edges.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

"""C acceptance against real local Auth, Storage, ClamAV and PostgreSQL."""
from pathlib import Path
src=Path(__file__).with_name('s07_messaging.py').read_text().split('a,b=accounts')[0]
exec(compile(src,__file__,'exec'))
from unittest.mock import patch
from uniion.adapters import attachments,antivirus
out=ROOT/'preuves/S07-C';out.mkdir(exist_ok=True)
a,b=accounts;f=json.loads((ROOT/'.local-auth/s07-fixture.json').read_text());t=f['third'];mf=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());org=str(uuid.uuid4());foreign=f['organization']
sql(f"""begin;
insert into public.uniion_organizations values('{org}','S07 C — pièces fictives',true);
insert into public.uniion_memberships select '{org}',u,now()-interval '1 day',null from unnest(array['{a['id']}'::uuid,'{b['id']}'::uuid,'{t['id']}'::uuid])u;
insert into public.uniion_module_access select '{org}',m,true,true,'included',now()+interval '10 days' from unnest(array['messagerie','dossiers'])m;
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) select '{org}',m,'paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE' from unnest(array['messagerie','dossiers'])m;
insert into public.uniion_permissions select '{org}',u,m,p from unnest(array['{a['id']}'::uuid,'{b['id']}'::uuid,'{t['id']}'::uuid])u cross join unnest(array['messagerie','dossiers'])m cross join unnest(array['read','write','create'])p;
insert into public.uniion_authorities values('{org}','{a['id']}','download',false),('{org}','{a['id']}','history',false);
insert into uniion_private.identity_profiles values('{org}','{a['id']}','Camille Recette','Membre'),('{org}','{b['id']}','Alex Recette','Lecteur'),('{org}','{t['id']}','Sam Recette','Membre');commit;""")
x,y,z=Client(),Client(),Client()
for label,c,account,factor,secret in [('author',x,a,mf['factor'],mf['secret']),('reader',y,b,mf['recipientFactor'],mf['recipientSecret']),('outsider',z,t,f['thirdFactor'],f['thirdSecret'])]:
 check(label+'_login',c.login(account)[0]==200);check(label+'_mfa',verify(c,factor,secret)[0][0]==200)
def call(c,action,payload=None,o=org,route='messaging'):
 app.sessions.clock=lambda:time.time()+len(checks)*61
 return c.call('/identity/'+route,{'organization_id':o,'action':action,'payload':payload or {}})
def cases(c,action,payload):return call(c,action,payload,route='cases')
def get(c=x):return call(c,'get',{'id':cid})[1]
def rpc(c,name,args):return api.request('/rest/v1/rpc/'+name,c.state()['access_token'],args)
def denied(fn):
 try:fn();return False
 except AccessDenied:return True
st,g,_=call(x,'group_create',{'clientId':str(uuid.uuid4()),'name':'Pièces et classement — recette C','desc':'Données fictives','members':[b['id']]});check('group_created',st==200);cid=g['id']
from PIL import Image,ImageDraw
buf=io.BytesIO();im=Image.new('RGB',(640,360),(245,247,250));ImageDraw.Draw(im).text((40,80),'UNIION - Recette S07 C - Piece fictive',fill=(20,40,65));im.save(buf,format='PNG');raw=buf.getvalue();(out/'piece-recette.png').write_bytes(raw)
upload={'id':cid,'clientId':str(uuid.uuid4()),'filename':'recette-C.png','content':base64.b64encode(raw).decode()}

st,r,_=call(x,'file_upload',upload);check('real_upload_scan',st==200);aid=r['id'];m=get()['messages'][-1];resource=m['file']['resource'];seq=m['seq'];check('scan_clean',m['file']['status']=='clean')
check('upload_replay',call(x,'file_upload',upload)[1]['id']==aid and len(get()['messages'])==1)
check('changed_replay_denied',call(x,'file_upload',{**upload,'filename':'changed.png'})[0]==403)
def access(c=x,preview=False,attachment=aid,o=org):return call(c,'file_preview' if preview else 'file_download',{'id':cid,'attachment':attachment,**({'page':1} if preview else {})},o)
check('exact_download',base64.b64decode(access()[1]['content'])==raw)
check('preview_without_download',access(y,True)[0]==200)
check('download_distinct',access(y)[0]==403)
check('outsider_preview',access(z,True)[0]==403)
check('foreign_scope',access(x,True,o=foreign)[0]==403)
check('wrong_conversation',call(x,'file_download',{'id':str(uuid.uuid4()),'attachment':aid})[0]==403)
check('extra_field_denied',call(x,'file_upload',{**upload,'author':a['id']})[0]==403)
check('invalid_file',call(x,'file_upload',{**upload,'clientId':str(uuid.uuid4()),'filename':'bad.pdf'})[0]!=200)
path=sql(f"select object_name from public.uniion_attachments where id='{aid}'")
check('direct_storage_denied',denied(lambda:attachments.storage(api,x.state()['access_token'],path)))
check('extra_object_denied',denied(lambda:rpc(x,'uniion_attachment_prepare',{'p_org':org,'p_resource':resource,'p_filename':'extra.txt','p_mime':'text/plain','p_size':len(raw),'p_sha256':hashlib.sha256(raw).hexdigest()})))
# Real EICAR signature, no simulated antivirus success.
eicar=b'X5O!P%@AP[4'+b'\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
check('infected_rejected',call(x,'file_upload',{**upload,'clientId':str(uuid.uuid4()),'filename':'eicar-recette.txt','content':base64.b64encode(eicar).decode()})[0]!=200)
bad=get()['messages'][-1]['file'];check('infected_quarantine',bad['status']=='infected');check('infected_download',access(attachment=bad['id'])[0]==403);check('infected_preview',access(preview=True,attachment=bad['id'])[0]==403)
# Deterministic interruption of scanner, then real scan recovery.
interrupted={**upload,'clientId':str(uuid.uuid4()),'filename':'reprise-C.png'}
with patch.object(antivirus,'scan',side_effect=antivirus.ScanUnavailable('Interruption de recette')):check('scan_interruption',call(x,'file_upload',interrupted)[0]!=200)
err=get()['messages'][-1]['file'];check('error_quarantined',err['status']=='error');check('error_download',access(attachment=err['id'])[0]==403)
check('reader_cannot_rescan',call(y,'file_rescan',{'id':cid,'attachment':err['id']})[0]==403)
check('real_scan_resume',call(x,'file_rescan',{'id':cid,'attachment':err['id']})[0]==200)
check('resume_same_object',call(x,'file_upload',interrupted)[1]['id']==err['id'])
missing={**upload,'clientId':str(uuid.uuid4()),'filename':'depot-interrompu.png'}
with patch.object(attachments,'storage',side_effect=AccessDenied()):check('upload_interruption',call(x,'file_upload',missing)[0]!=200)
missing_id=get()['messages'][-1]['file']['id'];check('upload_resume_same_object',call(x,'file_upload',missing)[1]['id']==missing_id)
# Dossiers: a reference never grants source access.
st,d,_=cases(x,'create',{'title':'Classement Messages — recette C','long':'Pièces fictives uniquement','tag':'Juridique','due':'30 j'});check('case_created',st==200);rid=d['id']
sql(f"insert into public.uniion_resource_grants select '{org}','{rid}',u,true,false,now()+interval '3 days',null from unnest(array['{b['id']}'::uuid,'{t['id']}'::uuid])u")
def caseget(c=x):return cases(c,'get',{'id':rid})[1]
def classify(c=x,file=aid,sequence=seq,expected=None):return cases(c,'message_classify',{'case':rid,'expected':caseget(c)['version'] if expected is None else expected,'conversation':cid,'seq':sequence,'file':file})
st,link,_=classify();check('file_classified',st==200);lid=link['id'];check('classification_idempotent',classify(expected=1)[1]['id']==lid)
check('text_classified',classify(file='')[0]==200)
check('stale_case_version',classify(file='',sequence='2',expected=1)[0]!=200)
check('infected_classify_denied',classify(file=bad['id'],sequence='2')[0]==403)
check('outsider_classify_denied',classify(z)[0]==403)
def files(c=x):return cases(c,'files',{'case':rid})[1]['files']
def linked(c=x,preview=False):return cases(c,'link_preview' if preview else 'link_download',{'case':rid,'link':lid,**({'page':1} if preview else {})})
check('reference_visible',any(f['id']==lid for f in files(y)))
check('source_hidden_from_destination_reader',all(f['id']!=lid for f in files(z)))
check('source_text_hidden',not any(t.get('link') for t in caseget(z)['timeline']))
check('linked_exact_bytes',base64.b64decode(linked()[1]['content'])==raw)
check('linked_preview',linked(y,True)[0]==200);check('linked_no_download',linked(y)[0]==403);check('linked_outsider',linked(z,True)[0]==403)
# Late arrival cannot see the old piece; explicit historical opening can grant it.
def members(ids):return call(x,'group_save',{'id':cid,'version':get()['version'],'name':g['name'],'desc':g['desc'],'members':ids})
check('late_join',members([b['id'],t['id']])[0]==200);check('late_file_denied',access(z,True)[0]==403)
period=next(p['period'] for p in get()['memberRows'] if p['id']==t['id'])
check('grant_old_file',call(x,'history_grant',{'id':cid,'version':get()['version'],'period':period,'messages':[seq]})[0]==200)
check('historical_file_preview',access(z,True)[0]==200 and linked(z,True)[0]==200)
check('revoke_old_file',call(x,'history_revoke',{'id':cid,'version':get()['version'],'period':period})[0]==200)
check('historical_reference_hidden',all(f['id']!=lid for f in files(z)) and linked(z,True)[0]==403)
check('source_remove',members([t['id']])[0]==200);check('source_removal_blocks_destination',linked(y,True)[0]==403 and all(f['id']!=lid for f in files(y)))
# Approved source trash blocks every byte path and hides classified metadata.
trash={'case':resource,'operation':'request','attachment':aid,'expected':1,'reason':'other'}
st,tr,_=cases(x,'file_trash',trash);check('source_trash_requested',st==200);tid=tr['id']
check('trash_pending_still_readable',access(preview=True)[0]==200)
check('non_admin_cannot_approve',cases(z,'file_trash',{'operation':'approve','request':tid})[0]==403)
check('superadmin_approval',cases(x,'file_trash',{'operation':'approve','request':tid})[0]==200)
check('source_trash_blocks_direct',access(preview=True)[0]==403 and access()[0]==403)
check('source_trash_blocks_reference',linked(preview=True)[0]==403 and all(f['id']!=lid for f in files()))
check('source_trash_status',next(m for m in get()['messages'] if m['seq']==seq)['file']['status']=='trash')
check('source_restore',cases(x,'file_trash',{'case':resource,'operation':'restore','request':tid})[0]==200)
check('restored_source_access',access(preview=True)[0]==200)
check('restore_does_not_restore_reader',linked(y,True)[0]==403)
# Module, entitlement, permissions and destination revocation, direct SQL gateways too.
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='messagerie'")
check('module_disabled_source',access(preview=True)[0]==403 and linked(preview=True)[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='messagerie';update public.uniion_resource_grants set revoked_at=now() where resource_id='{rid}' and user_id='{a['id']}'")
check('destination_revoked',linked(preview=True)[0]==403);check('source_retained',access(preview=True)[0]==200)
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{rid}' and user_id='{a['id']}'")
# Leave a reader with a new period; grant only the clean example for visual denial/download testing.
check('reader_reinvited',members([b['id'],t['id']])[0]==200)
period=next(p['period'] for p in get()['memberRows'] if p['id']==b['id'])
check('reader_example_granted',call(x,'history_grant',{'id':cid,'version':get()['version'],'period':period,'messages':[seq]})[0]==200)
(ROOT/'.local-auth/s07-c-fixture.json').write_text(json.dumps({'organization':org,'conversation':cid,'case':rid,'attachment':aid,'link':lid,'seq':seq}));(ROOT/'.local-auth/s07-c-fixture.json').chmod(0o600)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

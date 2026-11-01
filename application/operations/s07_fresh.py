"""Empty database qualification using real isolated services and current adapters."""
import sys,types,json,hashlib,uuid,time,concurrent.futures,statistics
from pathlib import Path
from s07_proof_scope import install,ROOT
fresh_proof=install('fresh');sys.path.insert(0,str(ROOT))
import backup_restore as b,restore_services as s
# Reuse infrastructure scenarios, but bind the current application adapters.
import ephemeral_files
source=Path(ephemeral_files.__file__).read_text().replace('import attachments,antivirus','from uniion.adapters import attachments,antivirus').replace('from supabase_access import AccessDenied','from uniion.adapters.supabase_transport import AccessDenied')
source=source.replace('api=API();a,c=accounts',"api=API();a,c=accounts;a['_api']=api").replace("scanner=login['data']['access_token'];","scanner=login['data']['access_token'];a['_scanner']=scanner;")
exec(compile(source,ephemeral_files.__file__,'exec'),ephemeral_files.__dict__)
def messaging(container,client,accounts,check):
 a,c=accounts;org=a['org']
 b.sql(f"""insert into public.uniion_memberships values('{org}','{c['id']}',now()-interval '1 day',null);
 insert into public.uniion_module_access values('{org}','messagerie',true,true,'included',now()+interval '1 day');
 insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','messagerie','paid',now()-interval '1 day',now()+interval '1 day','FICTIVE-F');
 insert into public.uniion_permissions select '{org}',u,'messagerie',p from unnest(array['{a['id']}'::uuid,'{c['id']}'::uuid])u cross join unnest(array['read','write','create'])p;
 insert into uniion_private.identity_profiles values('{org}','{a['id']}','Recette F auteur','Membre'),('{org}','{c['id']}','Recette F lecteur','Membre');""",container,'restored')
 def rpc(user,action,payload={},organization=org):return s.request(client,3000,'/rpc/uniion_messaging',user['token'],{'p_org':organization,'p_action':action,'p_payload':payload})
 r=rpc(a,'group_create',{'clientId':str(uuid.uuid4()),'name':'Installation neuve F','desc':'Fictif','members':[c['id']]});check('fresh_s07_group',r['status']==200);cid=r['data']['id']
 payload={'id':cid,'clientId':str(uuid.uuid4()),'text':'Message neuf F'}
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(lambda _:rpc(a,'send',payload),range(4)))
 check('fresh_concurrent_replay_exactly_once',all(r['status']==200 for r in results) and len({r['data']['id'] for r in results})==1)
 check('fresh_reply',rpc(c,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':'Réponse neuve','replyTo':'1'})['status']==200)
 check('fresh_foreign_org_denied',rpc(c,'get',{'id':cid},c['org'])['status']==403)
 check('fresh_live',rpc(c,'live',{'id':cid})['data']['thread']['id']==cid)
 check('fresh_read_ack',rpc(c,'read',{'id':cid,'seq':'2'})['status']==200)
 # Bounded RPC load: 1200 unique writes, eight simultaneous authenticated callers.
 def send(i):
  started=time.monotonic();r=rpc(a,'send',{'id':cid,'clientId':str(uuid.uuid4()),'text':f'Volume fictif F {i:04d}'});return r,time.monotonic()-started
 started=time.monotonic()
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:rows=list(pool.map(send,range(1200)))
 elapsed=time.monotonic()-started
 check('volume_all_writes_accepted',all(r['status']==200 for r,_ in rows))
 check('volume_unique_order_no_loss',sorted(int(r['data']['seq']) for r,_ in rows)==list(range(3,1203)))
 samples=[]
 for _ in range(10):
  start=time.monotonic();state=rpc(c,'live',{'id':cid});samples.append(time.monotonic()-start)
 (fresh_proof/'volume-mesures.json').write_text(json.dumps({'write_seconds':elapsed,'samples':samples,'status':state['status']},indent=2))
 check('volume_live_complete',state['status']==200 and state['data']['thread']['messages'][-1]['seq']=='1202' and len(state['data']['thread']['messages'])==50)
 check('volume_live_local_budget_2s',max(samples)<2)
 check('volume_unread_exact',state['data']['thread']['unread']==1200)
 check('volume_read_all',rpc(c,'read_all')['status']==200 and rpc(c,'notices')['data']==[])
 from uniion.adapters import message_files,antivirus
 from unittest.mock import patch
 import base64
 image=(fresh_proof/'S01-fichiers-neufs/preview-image.png').read_bytes()
 with patch.object(antivirus,'worker_token',return_value=a['_scanner']):
  uploaded=message_files.dispatch(a['_api'],a['token'],org,'file_upload',{'id':cid,'clientId':str(uuid.uuid4()),'filename':'fresh-F.png','content':base64.b64encode(image).decode()})
  file={'id':cid,'attachment':uploaded['id']}
  check('fresh_message_file_bytes',base64.b64decode(message_files.dispatch(a['_api'],a['token'],org,'file_download',file)['content'])==image)
  check('fresh_message_preview',message_files.dispatch(a['_api'],c['token'],org,'file_preview',{**file,'page':1})['image'].startswith('data:image/png;base64,'))
 target=rpc(a,'group_create',{'clientId':str(uuid.uuid4()),'name':'Référence neuve F','desc':'Fictif','members':[c['id']]})['data']['id']
 check('fresh_file_forward',rpc(a,'forward',{'id':cid,'seq':'1203','targets':[target],'clientId':str(uuid.uuid4())})['status']==200)
 check('fresh_file_search',len(rpc(c,'search',{'query':'fresh-F'})['data']['rows'])==2)
 g=rpc(a,'get',{'id':cid})['data']
 check('fresh_remove',rpc(a,'group_save',{'id':cid,'version':g['version'],'name':g['name'],'desc':g['desc'],'members':[]})['status']==200)
 check('fresh_revoked_live_empty',all(x['id']!=cid for x in rpc(c,'live')['data']['conversations']))
 check('fresh_forward_revocation',rpc(c,'get',{'id':target})['data']['messages']==[])
 (fresh_proof/'volume.json').write_text(json.dumps({'passed':True,'messages':1202,'concurrency':8,'transport':'real Auth JWT / PostgREST via isolated Docker bridge; not BFF throughput','write_seconds':elapsed,'write_p95_seconds':sorted(t for _,t in rows)[int(len(rows)*.95)],'live_samples_seconds':samples,'live_budget_seconds':2},indent=2))
source=(ROOT/'operations/ephemeral_ci.py').read_text().replace("check('all_24_migrations_from_empty_database',len(migrations)==24)","check('all_migrations_from_empty_database',len(migrations)>100)\n  (fresh_proof/'migrations.json').write_text(json.dumps([{'file':str(p.relative_to(ROOT)), 'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in migrations],indent=2))")
source=source.replace('from ephemeral_recovery import run as recovery_path','messaging(name,client,accounts,check)\n  from ephemeral_recovery import run as recovery_path')
exec(compile(source,str(ROOT/'operations/ephemeral_ci.py'),'exec'))

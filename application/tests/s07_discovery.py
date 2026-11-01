"""D: real local RPC/BFF checks for protected references and exhaustive search."""
from pathlib import Path
src=Path(__file__).with_name('s07_files.py').read_text().split('st,g,_=')[0].replace("out=ROOT/'preuves/S07-C'","out=ROOT/'preuves/S07-D'").replace('S07 C — pièces fictives','S07 D — échanges fictifs')
exec(compile(src,__file__,'exec'))
def group(c,name,members):
 st,r,_=call(c,'group_create',{'clientId':str(uuid.uuid4()),'name':name,'desc':'Recette D fictive','members':members});check('group_created',st==200);return r['id']
cid=group(x,'Source restreinte D',[b['id']]);dest=group(x,'Destination D',[b['id'],t['id']]);second=group(x,'Deuxième destination D',[b['id'],t['id']]);forbidden=group(z,'Groupe hors accès du super admin',[b['id']])
def send(c,id,text,reply=None):return call(c,'send',{'id':id,'clientId':str(uuid.uuid4()),'text':text,**({'replyTo':reply} if reply else {})})
def get(c=x,id=cid):return call(c,'get',{'id':id})[1]
def search(c,q,before=None):return call(c,'search',{'query':q,**({'before':before} if before else {})})
def forward(c,id,seq,targets,key=None):return call(c,'forward',{'id':id,'seq':seq,'targets':targets,'clientId':key or str(uuid.uuid4())})
check('anonymous_search_denied',search(Client(),'needle')[0]==403)
check('source_message',send(x,cid,'Aiguille D — message source ancien')[0]==200)
check('source_reply',send(x,cid,'Réponse source','1')[0]==200)
raw=(ROOT/'preuves/S07-C/piece-recette.png').read_bytes()
st,up,_=call(x,'file_upload',{'id':cid,'clientId':str(uuid.uuid4()),'filename':'piece-source-D.png','content':base64.b64encode(raw).decode()});check('source_file_uploaded',st==200);aid=up['id'];file_seq=get()['messages'][-1]['seq']
key=str(uuid.uuid4());st,res,_=forward(x,cid,'1',[dest,second],key);check('batch_forward',st==200 and len(res['rows'])==2)
dseq=next(r['seq'] for r in res['rows'] if r['conversation']==dest)
check('batch_replay',forward(x,cid,'1',[second,dest],key)[1]['already'])
check('changed_batch_denied',forward(x,cid,'2',[dest,second],key)[0]==403)
check('no_copy_of_source',sql(f"select bool_and(body='Référence de message') from uniion_private.messages where organization_id='{org}' and client_id='{key}'")=='t')
r=get(y,dest)['messages'];check('authorized_forward_text',len(r)==1 and r[0]['text']=='Aiguille D — message source ancien' and r[0]['fwd'])
check('outsider_cannot_read_reference',get(z,dest)['messages']==[])
check('outsider_search_no_metadata',search(z,'Aiguille')[1]['rows']==[])
check('outsider_locate_denied',call(z,'locate',{'id':dest,'seq':dseq})[0]==403)
check('outsider_cannot_reply_reference',send(z,dest,'Essai interdit',dseq)[0]==403)
check('reply_to_reference',send(y,dest,'Réponse visible avec citation protégée',dseq)[0]==200)
zrows=get(z,dest)['messages'];check('reply_quote_filtered',len(zrows)==1 and zrows[0]['reply'] is None)
yrows=get(y,dest)['messages'];check('reply_quote_resolves_source',yrows[-1]['reply']['text']=='Aiguille D — message source ancien')
# Atomicity: no partial write when one destination is inaccessible.
before=len(get(x,second)['messages']);check('inaccessible_target_denied',forward(x,cid,'1',[second,forbidden])[0]==403);check('no_partial_batch',len(get(x,second)['messages'])==before)
check('foreign_scope_denied',call(x,'forward',{'id':cid,'seq':'1','targets':[dest],'clientId':str(uuid.uuid4())},o=foreign)[0]==403)
check('duplicate_targets_denied',forward(x,cid,'1',[dest,dest])[0]==403)
check('source_as_target_denied',forward(x,cid,'1',[cid])[0]==403)
# Concurrent retries create exactly one reference in each selected destination.
p={'id':cid,'seq':'1','targets':[dest,second],'clientId':str(uuid.uuid4())}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 results=list(pool.map(lambda _:rpc(x,'uniion_messaging',{'p_org':org,'p_action':'forward','p_payload':p}),range(4)))
check('concurrent_forward_idempotent',len({json.dumps(r['rows'],sort_keys=True) for r in results})==1)
# Chain retains intermediate ACL; an audience cannot gain source access via forwarding.
st,chain,_=forward(x,dest,dseq,[second]);check('chained_forward',st==200);chain_seq=chain['rows'][0]['seq']
check('chain_unauthorized_hidden',all(m['seq']!=chain_seq for m in get(z,second)['messages']))
# A forwarded attachment uses both current destination and source gates.
st,fr,_=forward(x,cid,file_seq,[dest]);check('file_forward',st==200);fseq=fr['rows'][0]['seq'];fm=next(m for m in get(y,dest)['messages'] if m['seq']==fseq)
check('file_reference_not_copied',fm['file']['id']==aid and not fm['file']['canWrite'])
def fileget(c,preview=False):return call(c,'file_preview' if preview else 'file_download',{'id':dest,'attachment':aid,**({'page':1} if preview else {})})
check('forward_file_preview',fileget(y,True)[0]==200);check('forward_file_download_distinct',fileget(y)[0]==403);check('forward_file_outsider',fileget(z,True)[0]==403)
check('forward_cannot_rescan',call(y,'file_rescan',{'id':dest,'attachment':aid})[0]==403)
st,case,_=cases(x,'create',{'title':'Références transférées D','long':'Recette D','tag':'Juridique','due':'30 j'});check('case_created',st==200);rid=case['id']
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null)")
st,link,_=cases(x,'message_classify',{'case':rid,'expected':1,'conversation':dest,'seq':fseq,'file':aid});check('forward_file_classified',st==200);lid=link['id']
check('forward_link_preview',cases(y,'link_preview',{'case':rid,'link':lid,'page':1})[0]==200)
# Destination revocation during a byte transfer is checked after retrieving bytes.
sql(f"insert into public.uniion_authorities values('{org}','{b['id']}','download',false)")
original=attachments.storage;removed=False
def remove_after_bytes(*args,**kwargs):
 global removed
 raw=original(*args,**kwargs)
 if not removed:sql(f"update uniion_private.message_participations set left_at=now() where organization_id='{org}' and conversation='{dest}' and user_id='{b['id']}' and left_at is null");removed=True
 return raw
with patch.object(attachments,'storage',side_effect=remove_after_bytes):check('destination_revoked_during_download',fileget(y)[0]==403)
check('intermediate_chain_revoked',all(m['seq']!=chain_seq for m in get(y,second)['messages']))
sql(f"update uniion_private.message_participations set left_at=null where organization_id='{org}' and conversation='{dest}' and user_id='{b['id']}';delete from public.uniion_authorities where organization_id='{org}' and user_id='{b['id']}' and permission='download'")
# Source history grant controls target references, quotes and case links immediately.
def membership(ids):return call(x,'group_save',{'id':cid,'version':get()['version'],'name':'Source restreinte D','desc':'Recette D fictive','members':ids})
check('late_source_join',membership([b['id'],t['id']])[0]==200)
period=next(m['period'] for m in get()['memberRows'] if m['id']==t['id'])
check('late_source_no_implicit_reference',all(m['seq']!=dseq for m in get(z,dest)['messages']))
check('explicit_source_history',call(x,'history_grant',{'id':cid,'version':get()['version'],'period':period,'messages':['1']})[0]==200)
check('source_grant_reveals_reference',any(m['seq']==dseq for m in get(z,dest)['messages']))
check('source_history_revocation',call(x,'history_revoke',{'id':cid,'version':get()['version'],'period':period})[0]==200)
check('revocation_hides_reference_and_quote',all(m['seq']!=dseq and m['reply'] is None for m in get(z,dest)['messages']))
check('source_member_removed',membership([t['id']])[0]==200)
check('source_removal_hides_file',fileget(y,True)[0]==403)
check('source_removal_hides_case_link',cases(y,'link_preview',{'case':rid,'link':lid,'page':1})[0]==403)
check('source_removal_hides_search',search(y,'Aiguille')[1]['rows']==[])
check('source_reinvite',membership([b['id'],t['id']])[0]==200)
check('source_reinvite_no_old_reference',all(m['seq']!=dseq for m in get(y,dest)['messages']))
# Search beyond loaded pages, stable cursor, literal wildcard, no hidden-page leakage.
for i in range(65):rpc(x,'uniion_messaging',{'p_org':org,'p_action':'send','p_payload':{'id':cid,'clientId':str(uuid.uuid4()),'text':f'Pagination D needle {i:03}'}})
check('old_source_not_initial_page',all(m['seq']!='1' for m in get()['messages']))
st,sr,_=search(x,'needle');check('search_first_page',st==200 and len(sr['rows'])==50 and sr['next'])
st,page2,_=search(x,'needle',sr['next']);check('search_second_page',st==200 and len(page2['rows'])==15 and page2['next'] is None)
check('search_pages_no_duplicates',len({r['id'] for r in sr['rows']+page2['rows']})==65)
check('search_full_history',any(r['conversation']==cid and r['message']['seq']=='1' for r in search(x,'Aiguille')[1]['rows']))
st,located,_=call(x,'locate',{'id':cid,'seq':'1'});check('locate_old_message',st==200 and located['focused']=='1' and located['messages'][-1]['seq']=='1')
check('percent_literal',search(x,'%')[1]['rows']==[])
check('literal_percent_sent',send(x,cid,'Taux 100% fictif')[0]==200);check('percent_not_wildcard',len(search(x,'%')[1]['rows'])==1)
check('filename_search',any(r['message']['file']['id']==aid for r in search(x,'piece-source-D')[1]['rows']))
check('empty_search_denied',search(x,'   ')[0]==403)
check('forged_search_scope_denied',call(x,'search',{'query':'x','actor':a['id']})[0]==403)
check('private_forward_table_denied',denied(lambda:api.request('/rest/v1/message_forwards?select=*',x.state()['access_token'])))
check('private_batch_table_denied',denied(lambda:api.request('/rest/v1/message_forward_batches?select=*',x.state()['access_token'])))
# Keep reader eligible for UI forwarding verification, third remains source-history restricted.
period=next(m['period'] for m in get()['memberRows'] if m['id']==b['id'])
check('ui_reader_history_grant',call(x,'history_grant',{'id':cid,'version':get()['version'],'period':period,'messages':['1',file_seq]})[0]==200)
(ROOT/'.local-auth/s07-d-fixture.json').write_text(json.dumps({'organization':org,'source':cid,'target':dest,'second':second,'attachment':aid,'case':rid,'fileSeq':file_seq,'referenceSeq':dseq}));(ROOT/'.local-auth/s07-d-fixture.json').chmod(0o600)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

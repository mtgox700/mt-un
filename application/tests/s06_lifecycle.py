from pathlib import Path
source=Path(__file__).with_name('s06_documents.py').read_text().split("check('anonymous_denied'")[0]
exec(compile(source,__file__,'exec'))
out=ROOT/'preuves/S06-finalisation'
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','document_publish',false),('{org}','{a['id']}','download',false),('{org}','{b['id']}','document_review',false)")
st,row,_=call(x,'create',{'model':'courrier','document':doc});check('create',st==200);rid=row['id'];doc['charte']=row['charte']
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null)")
def work(c,action,v=1,**extra):return call(c,'publication_'+action,{'id':rid,'version':v,**extra})
check('writer_correction_denied',work(x,'correction',reason='Motif fictif')[0]==403)
check('short_reason_denied',work(y,'correction',reason='x')[0]!=200)
check('correction_allowed',work(y,'correction',reason='Préciser le contenu avant publication.')[0]==200)
check('review_same_rejected_version_denied',work(y,'review')[0]==403)
check('save_corrected_version',call(x,'save',{'id':rid,'version':1,'document':{**doc,'title':'Document corrigé S06'}})[0]==200)
check('review_new_version',work(y,'review',2)[0]==200)
check('publish_archive_and_notice',work(x,'publish',2)[0]==200)
st,h,_=call(y,'history',{'id':rid});check('history_reader',st==200 and h['rows'][0]['archived'])
check('archive_without_download_denied',call(y,'archive',{'id':rid,'version':2})[0]==403)
st,ar,_=call(x,'archive',{'id':rid,'version':2});check('archive_download',st==200 and base64.b64decode(ar['base64']).startswith(b'%PDF-'))
(out/'archive.pdf').write_bytes(base64.b64decode(ar['base64']))
check('notice_recipient',any(n['resource']==rid for n in call(y,'notices')[1]))
check('foreign_history_denied',call(y,'history',{'id':rid},foreign)[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=now() where resource_id='{rid}' and user_id='{b['id']}'")
check('notice_hidden_after_revocation',not any(n['resource']==rid for n in call(y,'notices')[1]))
check('history_revoked_denied',call(y,'history',{'id':rid})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{rid}' and user_id='{b['id']}'")
def trash(c,op,**kw):return call(c,'disposal',{'operation':op,**kw})
check('reader_trash_denied',trash(y,'request',case=rid,link=None,expected=2,reason='other')[0]==403)
st,q,_=trash(x,'request',case=rid,link=None,expected=2,reason='other');check('trash_request',st==200);qid=q['id']
check('pending_still_readable',call(y,'get',{'id':rid})[0]==200)
check('ordinary_approve_denied',trash(y,'approve',request=qid)[0]==403)
check('super_admin_approve',trash(x,'approve',request=qid)[0]==200)
check('trashed_get_denied',call(x,'get',{'id':rid})[0]==403)
check('trashed_archive_denied',call(x,'archive',{'id':rid,'version':2})[0]==403)
check('reader_restore_denied',trash(y,'restore',case=rid,request=qid)[0]==403)
check('restore_allowed',trash(x,'restore',case=rid,request=qid)[0]==200)
check('restored_archive_exact',call(x,'archive',{'id':rid,'version':2})[1]['sha256']==ar['sha256'])
check('restored_document',call(y,'get',{'id':rid})[0]==200)
# Durable queued rendering and read-time access checks.
app.sessions.clock=lambda:time.time()+122
version=call(x,'get',{'id':rid})[1]['version']
check('queued_start',call(x,'export_start',{'id':rid,'version':version})[0]==200)
for _ in range(40):
 job=call(x,'export_status',{'id':rid,'version':version})[1]
 if job.get('state')=='done':break
 time.sleep(.2)
check('queued_pdf_complete',job.get('state')=='done' and job['result']['mime']=='application/pdf')
check('reader_job_denied',call(y,'export_status',{'id':rid,'version':version})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=now() where resource_id='{rid}' and user_id='{a['id']}'")
check('completed_job_revocation_denied',call(x,'export_status',{'id':rid,'version':version})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{rid}' and user_id='{a['id']}'")
(ROOT/'.local-auth/s06-lifecycle.json').write_text(json.dumps({'organization':org,'resource':rid,'foreign':foreign,'archiveVersion':2}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

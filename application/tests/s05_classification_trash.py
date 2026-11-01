from pathlib import Path
source=Path(__file__).with_name('s05_classification_final.py').read_text().split("# Reproduce the rapid UI")[0].replace("out=ROOT/'preuves/S05-finalisation'","out=ROOT/'preuves/S05-classement-corbeille'")
exec(compile(source,__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
st,row,_=call(x,'create',{'title':'Source des pièces classées','long':'Source fictive de recette.','tag':'Juridique','due':'30 j'});check('source_case',st==200);source_case=row['id']
sql(f"insert into public.uniion_resource_grants values('{org}','{source_case}','{b['id']}',false,true,now()+interval '3 days',null)")
st,r,_=call(x,'file_upload',{'case':source_case,'filename':'source-classee.png','content':base64.b64encode(raw).decode()});check('source_upload',st==200);source_file=r['files'][0]['id']
check('source_selected',work(x,'select_files',{'version':2,'files':[source_file]})[0]==200)
check('review_new_version',work(y,'review',{'version':3})[0]==200);check('publish_new_version',work(x,'publish',{'version':3})[0]==200)
p.update(id=str(uuid.uuid4()),attachment_version=3,subject='Source classée et corbeille S05')
check('source_delivery',send(x,p)[0]==200)
st,r,_=classify(x,source_file,2);check('classify_source_file',st==200);source_link=r['id']
def linked(c,action):return call(c,action,{'case':case,'link':source_link})
def trash(c,operation,extra={}):return call(c,'file_trash',{'operation':operation,**({'case':source_case} if operation not in ('approve','reject','admin_list') else {}),**extra})
check('source_read_allowed',linked(y,'link_download')[0]==200)
st,r,_=trash(x,'request',{'attachment':source_file,'expected':1,'reason':'obsolete'});check('trash_requested',st==200);qid=r['id']
check('pending_still_readable',linked(y,'link_download')[0]==200)
check('reader_cannot_approve',trash(y,'approve',{'request':qid})[0]==403)
check('superadmin_approve',trash(x,'approve',{'request':qid})[0]==200)
app.sessions.clock=lambda:time.time()+183
check('trashed_link_hidden',all(z['id']!=source_link for z in call(y,'files',{'case':case})[1]['files']))
check('trashed_link_download_denied',linked(y,'link_download')[0]==403)
check('trashed_link_preview_denied',linked(y,'link_preview')[0]==403)
check('reader_cannot_restore',trash(y,'restore',{'request':qid})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=now() where resource_id='{source_case}' and user_id='{b['id']}'")
check('restore_by_writer',trash(x,'restore',{'request':qid})[0]==200)
check('restoration_keeps_revocation',linked(y,'link_download')[0]==403)
check('writer_restored_exact',base64.b64decode(linked(x,'link_download')[1]['content'])==raw)
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{source_case}' and user_id='{b['id']}'")
check('reader_restored_exact',base64.b64decode(linked(y,'link_download')[1]['content'])==raw)
(ROOT/'.local-auth/s05-classement-corbeille.json').write_text(json.dumps({'organization':org,'resource':case,'source':source_case,'file':source_file,'link':source_link,'convocation':p['id']}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

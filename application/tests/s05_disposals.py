from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,__file__,'exec'))
import subprocess
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());cf=json.loads((ROOT/'.local-auth/s05-cloture-restauration.json').read_text());org=cf['organization'];case=cf['resource'];aid=cf['file'];link=cf['link'];p={'id':cf['convocation']};a,b=accounts;x,y=Client(),Client();x.login(a);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret']);out=ROOT/'preuves/S05-cloture'
def sql(q):
 result=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if result.returncode:raise RuntimeError('SQL fixture error')
def call(c,action,payload):return c.call('/identity/cases',{'organization_id':org,'action':action,'payload':payload})
def classify(c,file,expected):return call(c,'classify',{'case':case,'expected':expected,'convocation':p['id'],'file':file})
st,r,_=call(y,'link_download',{'case':case,'link':link});check('original_download',st==200);raw=base64.b64decode(r['content'])
app.sessions.clock=lambda:time.time()+122
def disposal(c,operation,**kw):return call(c,'disposal',{'operation':operation,**kw})
def version():return call(x,'get',{'id':case})[1]['version']
def request(link_id=None):
 st,r,_=disposal(x,'request',case=case,link=link_id,expected=version(),reason='other');check('request_allowed',st==200);return r['id']
req=request(link)
check('reader_approve_denied',disposal(y,'approve',request=req)[0]==403)
st,r,_=disposal(x,'admin_list');check('admin_inventory_technical',st==200 and 'Classement final' not in json.dumps(r))
check('approve_reference',disposal(x,'approve',request=req)[0]==200)
check('withdrawn_reference_hidden',call(y,'files',{'case':case})[1]['files']==[])
check('withdrawn_download_denied',call(y,'link_download',{'case':case,'link':link})[0]==403)
check('reclassification_denied',classify(x,aid,version())[0]==403)
check('reader_restore_denied',disposal(y,'restore',case=case,request=req)[0]==403)
check('restore_reference',disposal(x,'restore',case=case,request=req)[0]==200)
st,r,_=call(y,'link_download',{'case':case,'link':link});check('restored_exact_bytes',st==200 and base64.b64decode(r['content'])==raw)
app.sessions.clock=lambda:time.time()+183
st,r,_=classify(x,'',version());check('classify_message',st==200);message_link=r['id']
req=request(message_link)
check('approve_message',disposal(x,'approve',request=req)[0]==200)
check('message_hidden',not any(t.get('link')==message_link for t in call(y,'get',{'id':case})[1]['timeline']))
check('restore_message',disposal(x,'restore',case=case,request=req)[0]==200)
req=request()
check('pending_case_accessible',call(y,'get',{'id':case})[0]==200)
check('approve_case',disposal(x,'approve',request=req)[0]==200)
check('disposed_get_denied',call(y,'get',{'id':case})[0]==403)
check('direct_rls_disposed_hidden',api.request('/rest/v1/uniion_resources?select=id&id=eq.'+case,y.state()['access_token'])==[])
check('direct_versions_disposed_hidden',api.request('/rest/v1/uniion_resource_versions?select=resource_id&resource_id=eq.'+case,y.state()['access_token'])==[])
check('disposed_link_denied',call(y,'link_download',{'case':case,'link':link})[0]==403)
check('reader_case_restore_denied',disposal(y,'restore',case=case,request=req)[0]==403)
app.sessions.clock=lambda:time.time()+244
sql(f"update public.uniion_resource_grants set revoked_at=now() where resource_id='{case}' and user_id='{b['id']}'")
check('restore_case',disposal(x,'restore',case=case,request=req)[0]==200)
check('revoked_reader_stays_denied',call(y,'get',{'id':case})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{case}' and user_id='{b['id']}'")
(ROOT/'.local-auth/s05-cloture.json').write_text(json.dumps({'organization':org,'resource':case,'convocation':p['id'],'file':aid,'link':link}))
(out/'disposals.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

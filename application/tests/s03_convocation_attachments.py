"""Local fictional recipients only; real Supabase, ClamAV and Mailpit."""
from pathlib import Path
source=Path(__file__).with_name('s03_agenda.py').read_text().split('x,y=Client(),Client()')[0];exec(compile(source,__file__,'exec'))
import urllib.request,urllib.parse
out=ROOT/'preuves/S03-convocations-pieces';out.mkdir(parents=True,exist_ok=True)
sql(f"""insert into public.uniion_module_access values('{org}','documents',true,true,'included',now()+interval '10 days');insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','documents','paid',now()-interval '1 day',now()+interval '10 days','RECETTE-FICTIVE');
insert into public.uniion_permissions values('{org}','{a['id']}','documents','read'),('{org}','{a['id']}','documents','create'),('{org}','{a['id']}','documents','write'),('{org}','{b['id']}','documents','read');
insert into public.uniion_authorities values('{org}','{a['id']}','agenda_convocation',false),('{org}','{a['id']}','agenda_publish',false),('{org}','{a['id']}','download',false),('{org}','{b['id']}','agenda_review',false),('{org}','{b['id']}','download',false);""")
x,y=Client(),Client();x.login(a);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret'])
e={'title':'Convocation pièces fictives S03','type':'cse','date':'2026-11-20','start':'09:00','end':'10:00','lieu':'Salle fictive','visib':'adherents','notes':'Point de recette','rappel':False}
st,row,_=x.call('/identity/agenda/save',{'organization_id':org,'event':e});check('event_created',st==200);eid=row['id']
def work(c,action,payload={},o=org):return c.call('/identity/agenda/work',{'organization_id':o,'event_id':eid,'action':action,'payload':payload})
def send(c,p):return c.call('/identity/agenda/convocations/send',{'organization_id':org,'event_id':eid,'action':'prepare','payload':p})
st,d,_=work(x,'document');check('document_created',st==200)
p={'id':str(uuid.uuid4()),'version':1,'people':[b['id']],'subject':'Pièces fictives '+org,'body':'Recette locale uniquement.','attachment_version':1}
check('anonymous_denied',send(Client(),p)[0]==403)
check('sender_without_authority_denied',send(y,p)[0]==403)
check('unapproved_document_denied',send(x,p)[0]==403)
check('review_second_actor',work(y,'review',{'version':1})[0]==200)
check('publish',work(x,'publish',{'version':1})[0]==200)
check('empty_selection_denied',send(x,{**p,'people':[]})[0]==403)
check('duplicate_selection_denied',send(x,{**p,'people':[b['id'],b['id']]})[0]==403)
check('foreign_recipient_denied',send(x,{**p,'people':[str(uuid.uuid4())]})[0]==403)
check('stale_attachment_denied',send(x,{**p,'attachment_version':2})[0]==403)
check('foreign_org_denied',work(x,'recipients',o=foreign)[0]==403)
sql(f"delete from public.uniion_authorities where organization_id='{org}' and user_id='{b['id']}' and permission='download';")
check('recipient_without_download_denied',send(x,p)[0]==403)
sql(f"insert into public.uniion_authorities values('{org}','{b['id']}','download',false);")
# Advance only the in-process test clock, never production security settings.
app.sessions.clock=lambda:time.time()+61
st,result,_=send(x,p);check('selected_recipient_sent',st==200 and result['sent']==1 and result['uncertain']==0)
check('idempotent',send(x,p)[1]['replayed'])
query=urllib.parse.quote('subject:"'+p['subject']+'"')
with urllib.request.urlopen('http://127.0.0.1:54324/api/v1/search?query='+query) as response:messages=json.load(response)['messages']
check('one_mail_only',len(messages)==1)
with urllib.request.urlopen('http://127.0.0.1:54324/api/v1/message/'+messages[0]['ID']) as response:mail=json.load(response)
check('only_selected_address',len(mail['To'])==1 and mail['To'][0]['Address']==b['email'])
check('two_attachments',len(mail['Attachments'])==2)
check('attachment_names',{v['FileName'] for v in mail['Attachments']}=={'ordre-du-jour.pdf','evenement.ics'})
# Revoke between prepare and delivery; check must deny without an email.
p2={**p,'id':str(uuid.uuid4())};token=x.state()['access_token']
api.request('/rest/v1/rpc/uniion_agenda_work',token,{'p_org':org,'p_event':eid,'p_action':'prepare','p_payload':p2})
sql(f"update uniion_private.agenda_audiences set audience='none' where organization_id='{org}' and user_id='{b['id']}';")
try:api.request('/rest/v1/rpc/uniion_agenda_work',token,{'p_org':org,'p_event':eid,'p_action':'check','p_payload':{'id':p2['id'],'user':b['id']}});refused=False
except AccessDenied:refused=True
check('revoke_before_delivery_denied',refused)
sql(f"update uniion_private.agenda_audiences set audience='adherents' where organization_id='{org}' and user_id='{b['id']}';")
(ROOT/'.local-auth/s03-convocation-attachments.json').write_text(json.dumps({'organization':org,'event':eid,'version':1}))
(out/'integration.json').write_text(json.dumps({'passed':True,'checks':checks},indent=2));print(json.dumps({'passed':True,'checks':len(checks)}))

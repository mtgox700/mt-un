from pathlib import Path
source=Path(__file__).with_name('s03_agenda.py').read_text().split('x,y=Client(),Client()')[0];exec(compile(source,__file__,'exec'))
from datetime import datetime,timedelta
from zoneinfo import ZoneInfo
from uniion.adapters.agenda import calendar
from operations import agenda_reminders as worker
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','download',false);")
x,y=Client(),Client()
def export(c,event,o=org):return c.call('/identity/agenda/export',{'organization_id':o,'event_id':event})
def notices(c,o=org):return c.call('/identity/agenda/notifications',{'organization_id':o})
check('anonymous_export_denied',export(x,str(uuid.uuid4()))[0]==403);x.login(a);check('aal1_export_denied',export(x,str(uuid.uuid4()))[0]==403);verify(x,f['factor'],f['secret']);y.login(b);verify(y,f['recipientFactor'],f['recipientSecret'])
due=datetime.now(ZoneInfo('Europe/Paris'))+timedelta(hours=24)
e={'title':'Rappel fictif S03','type':'cse','date':due.strftime('%Y-%m-%d'),'start':due.strftime('%H:00'),'end':due.strftime('%H:30'),'lieu':'Salle fictive','visib':'adherents','notes':'Note fictive','rappel':True}
st,row,_=x.call('/identity/agenda/save',{'organization_id':org,'event':e});check('create_due',st==200)
st,result,_=export(x,row['id']);check('authorized_ics',st==200 and 'BEGIN:VCALENDAR' in result['content'] and row['id'] in result['content'])
check('no_download_permission_denied',export(y,row['id'])[0]==403);check('foreign_org_denied',export(x,row['id'],foreign)[0]==403)
check('forged_event_denied',export(x,str(uuid.uuid4()))[0]==403)
# Durable scheduling and delivery are real, exclusively in Mailpit.
worker.run()
def count(condition='true'):
 return int(worker.sql(f"select count(*) from uniion_private.agenda_reminders j join uniion_private.agenda_events e on e.id=j.event_id where e.organization_id='{org}' and {condition};"))
check('two_recipient_jobs',count()==2);check('two_deliveries',count("j.status='sent'")==2);check('authorized_notification',len(notices(x)[1])==1);check('reader_notification',len(notices(y)[1])==1)
worker.run();check('no_duplicate_jobs',count()==2)
# Revoke after scheduling, before delivery; pending mail and notification must disappear.
st,row2,_=x.call('/identity/agenda/save',{'organization_id':org,'event':{**e,'title':'Rappel annulé fictif'}});check('second_due',st==200)
worker.sql('select uniion_private.agenda_enqueue();')
sql(f"update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{b['id']}';")
worker.run();check('revoked_job_cancelled',count("j.user_id='"+b['id']+"' and j.status='cancelled'")==1);check('revoked_notifications_denied',notices(y)[0]==403)
# Opt-out invalidates scheduled jobs, including previously delivered notification views.
x.call('/identity/agenda/save',{'organization_id':org,'event':{**e,'id':row['id'],'version':1,'rappel':False}})
check('optout_notification_hidden',all(n['event']!=row['id'] for n in notices(x)[1]))
# Ambiguous send is retained and never blindly resent.
st,row3,_=x.call('/identity/agenda/save',{'organization_id':org,'event':{**e,'title':'Incident fictif'}})
original=worker.deliver;worker.deliver=lambda j:(_ for _ in ()).throw(OSError('simulated'))
worker.run();worker.deliver=original;check('failure_retained',count("j.status='uncertain'")==1);worker.run();check('failure_not_blindly_retried',count("j.status='uncertain'")==1)
# Restore only the fictitious recipient membership for responsive UI checks.
sql(f"update public.uniion_memberships set revoked_at=null where organization_id='{org}' and user_id='{b['id']}';")
(ROOT/'.local-auth/s03-agenda-delivery.json').write_text(json.dumps({'organization':org,'foreign':foreign,'event':row2['id']}))
out=ROOT/'preuves/S03-rappels-ics';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

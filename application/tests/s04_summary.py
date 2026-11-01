from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
from datetime import date,timedelta
sql(f"insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}')")
app.sessions.clock=lambda:time.time()+122
check('empty_summary',call(x)[1]['financialSummary']['dueCents']==0)
check('reader_no_summary','financialSummary' not in call(y)[1])
check('foreign_no_leak','financialSummary' not in call(y,o=foreign)[1])
today=date.fromisoformat(sql("select (now() at time zone 'Europe/Paris')::date"));past=today-timedelta(days=2);future=today+timedelta(days=2)
ids=[]
for i,due in enumerate([past,today,future]):
 st,r,_=call(x,'charge',{'adherent_id':row['id'],'amount_cents':1000,'period':due.isoformat(),'due_on':due.isoformat(),'request_id':str(uuid.uuid4())})
 check('charge_'+str(i),st==200);ids.append(next(e['id'] for e in r['rows'][0]['duesLedger'] if e['dueOn']==due.isoformat()))
for i,amount in enumerate([400,200,100]):
 p={'id':ids[i],'amount_cents':amount,'request_id':str(uuid.uuid4())}
 if i!=1:p['effective_on']=today.isoformat()
 check('payment_'+str(i),call(x,'payment',p)[0]==200)
s=call(x)[1]['financialSummary'];check('due_excludes_future',s['dueCents']==2000 and s['paidDueCents']==600 and s['remainingCents']==1400)
check('overdue_excludes_today',s['overdueCents']==600 and len(s['arrears'])==1)
check('quarter_excludes_undated',s['quarterCents']==500 and s['undatedCents']==200)
check('member_assessment',s['assessedMembers']==1 and s['upToDateMembers']==0)
check('actual_mode',s['modes']==[{'label':'Virement','n':1}])
app.sessions.clock=lambda:time.time()+183
payment=next(e for e in call(x)[1]['rows'][0]['duesLedger'] if e['id']==ids[0])['payments'][0]
q={'id':payment['id'],'revision':0,'amount_cents':100,'effective_on':today.isoformat(),'reason':'Correction fictive synthèse','request_id':str(uuid.uuid4())}
st,r,_=call(x,'correct',q);s=r['financialSummary'];check('correction_updates_summary',st==200 and s['overdueCents']==900 and s['quarterCents']==200)
check('cancel_updates_summary',call(x,'correct',{**q,'revision':1,'amount_cents':0,'request_id':str(uuid.uuid4())})[1]['financialSummary']['overdueCents']==1000)
check('reader_cannot_supply_summary',call(y,'list',{'financialSummary':s})[0]==403)
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('module_disabled_hides_summary','financialSummary' not in call(x)[1])
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
check('reload_persisted',call(x)[1]['financialSummary']['remainingCents']==1800)
try:api.request('/rest/v1/rpc/dues_summary',x.state()['access_token'],{'rows':[],'as_of':today.isoformat()});ok=False
except AccessDenied:ok=True
check('private_helper_denied',ok)
# Known quarter boundary, no date-dependent expectation.
fixture=[{'id':'m','mode':'','duesLedger':[{'cents':1000,'paidCents':600,'dueOn':'2026-10-28','payments':[{'cents':100,'effectiveOn':'2026-09-30'},{'cents':200,'effectiveOn':'2026-10-01'},{'cents':300,'effectiveOn':None}]}]}]
s=json.loads(sql("select uniion_private.dues_summary('"+json.dumps(fixture)+"'::jsonb,'2026-10-28')"))
check('quarter_boundary',s['quarterCents']==200 and s['undatedCents']==300 and s['overdueCents']==0)
out=ROOT/'preuves/S04-syntheses';out.mkdir(parents=True,exist_ok=True)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2))
(ROOT/'.local-auth/s04-summary.json').write_text(json.dumps({'organization':org,'adherent':row['id']}))
print(json.dumps({'passed':True,'count':len(checks)}))

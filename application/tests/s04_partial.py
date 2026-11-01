from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split("out=ROOT/")[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
p={'adherent_id':row['id'],'amount_cents':2000,'period':'2026-12-01','due_on':'2026-12-05','request_id':str(uuid.uuid4())}
st,res,_=call(x,'charge',p);check('charge_for_partial',st==200);e=res['rows'][0]['duesLedger'][0];pid=e['id']
pay={'id':pid,'amount_cents':750,'request_id':str(uuid.uuid4())}
check('no_right_payment',call(y,'payment',pay)[0]==403)
check('foreign_payment',call(y,'payment',pay,o=foreign)[0]==403)
st,res,_=call(x,'payment',pay);v=res['rows'][0]['duesLedger'][0];check('partial_persisted',st==200 and v['paidCents']==750 and v['paidAt'] is None and len(v['payments'])==1)
check('retry_does_not_duplicate',len(call(x,'payment',pay)[1]['rows'][0]['duesLedger'][0]['payments'])==1)
check('changed_retry_denied',call(x,'payment',{**pay,'amount_cents':700})[0]==403)
for i,amount in enumerate([0,-1,1.5,1251]):check('invalid_payment_'+str(i),call(x,'payment',{**pay,'amount_cents':amount,'request_id':str(uuid.uuid4())})[0]==403)
check('sum_unchanged_on_refusal',call(x)[1]['rows'][0]['duesLedger'][0]['paidCents']==750)
check('finance_hidden', 'duesLedger' not in call(y)[1]['rows'][0])
st,res,_=call(x,'payment',{**pay,'amount_cents':1250,'request_id':str(uuid.uuid4())});v=res['rows'][0]['duesLedger'][0];check('remaining_settled',st==200 and v['paidCents']==2000 and bool(v['paidAt']) and len(v['payments'])==2)
check('overpay_closed_denied',call(x,'payment',{**pay,'amount_cents':1,'request_id':str(uuid.uuid4())})[0]==403)
app.sessions.clock=lambda:time.time()+183
p.update(period='2027-01-01',due_on='2027-01-05',request_id=str(uuid.uuid4()));res=call(x,'charge',p)[1];race=res['rows'][0]['duesLedger'][-1]['id']
from concurrent.futures import ThreadPoolExecutor
def concurrent_pay(_):
 try:api.request('/rest/v1/rpc/uniion_adherents',x.state()['access_token'],{'p_org':org,'p_action':'payment','p_payload':{'id':race,'amount_cents':1500,'request_id':str(uuid.uuid4())}});return True
 except AccessDenied:return False
with ThreadPoolExecutor(2) as pool:results=list(pool.map(concurrent_pay,range(2)))
check('concurrent_overpayment_prevented',sorted(results)==[False,True]);check('concurrent_sum_exact',call(x)[1]['rows'][0]['duesLedger'][-1]['paidCents']==1500)
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations';")
check('revoked_payment_denied',call(x,'payment',{'id':race,'amount_cents':500,'request_id':str(uuid.uuid4())})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations';insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}');")
p.update(period='2027-02-01',due_on='2027-02-05',request_id=str(uuid.uuid4()));call(x,'charge',p)
out=ROOT/'preuves/S04-reglements-partiels';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-partial.json').write_text(json.dumps({'organization':org,'adherent':row['id']}));print(json.dumps({'passed':True,'count':len(checks)}))

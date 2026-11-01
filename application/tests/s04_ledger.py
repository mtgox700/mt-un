from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split("out=ROOT/")[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
payload={'adherent_id':row['id'],'amount_cents':1250,'period':'2026-10-01','due_on':'2026-10-05','request_id':str(uuid.uuid4())}
check('charge_without_finance_denied',call(y,'charge',payload)[0]==403)
st,res,_=call(x,'charge',payload);check('charge_created',st==200 and len(res['rows'][0]['duesLedger'])==1)
e=res['rows'][0]['duesLedger'][0]
check('charge_replay_idempotent',len(call(x,'charge',payload)[1]['rows'][0]['duesLedger'])==1)
check('charge_replay_altered_denied',call(x,'charge',{**payload,'amount_cents':1500})[0]==403)
check('ledger_hidden', 'duesLedger' not in call(y)[1]['rows'][0])
check('foreign_settle_denied',call(y,'settle',{'id':e['id']},o=foreign)[0]==403)
check('readonly_settle_denied',call(y,'settle',{'id':e['id']})[0]==403)
st,res,_=call(x,'settle',{'id':e['id']});paid=res['rows'][0]['duesLedger'][0]['paidAt'];check('settled_persisted',st==200 and bool(paid))
check('settle_replay_same_timestamp',call(x,'settle',{'id':e['id']})[1]['rows'][0]['duesLedger'][0]['paidAt']==paid)
check('single_audit',sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event='dues.settled'")=='1')
for i,patch in enumerate([{'amount_cents':0},{'amount_cents':-1},{'amount_cents':1.5},{'period':'31/02/2026'},{'adherent_id':str(uuid.uuid4())}]):check('invalid_charge_'+str(i),call(x,'charge',{**payload,'request_id':str(uuid.uuid4()),**patch})[0]==403)
app.sessions.clock=lambda:time.time()+183
payload['request_id']=str(uuid.uuid4());payload['period']='2026-11-01';payload['due_on']='2026-11-05'
check('null_request_denied',call(x,'charge',{**payload,'request_id':None})[0]==403)
check('next_explicit_charge',call(x,'charge',payload)[0]==200)
sql(f"insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}');update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations';")
check('disabled_finance_settle_denied',call(x,'settle',{'id':e['id']})[0]==403)
check('disabled_finance_hidden','duesLedger' not in call(x)[1]['rows'][0])
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations';")
out=ROOT/'preuves/S04-reglements';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2))
(ROOT/'.local-auth/s04-ledger.json').write_text(json.dumps({'organization':org,'adherent':row['id']}));print(json.dumps({'passed':True,'count':len(checks)}))

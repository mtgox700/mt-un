from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
from datetime import date
app.sessions.clock=lambda:time.time()+122
sql(f"insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}')")
today=sql("select (now() at time zone 'Europe/Paris')::date")
check('historical_import_no_backfill',call(x)[1]['rows'][0]['duesLedger']==[])
new={**record,'prenom':'Auto','nom':'Échéancier','email':'auto@uniion-local.example','since':today,'montant':'12,50 €/mois'}
check('reader_cannot_activate',call(y,'import',[new])[0]==403)
st,r,_=call(x,'import',[new]);a_row=next(v for v in r['rows'] if v['email']==new['email']);mid=a_row['id']
check('automatic_first_due',st==200 and len(a_row['duesLedger'])==1 and a_row['duesLedger'][0]['cents']==1250 and a_row['duesLedger'][0]['dueOn']==today)
check('no_payment_created',a_row['duesLedger'][0]['paidCents']==0)
check('schedule_persisted',a_row['schedule']['state']=='active' and a_row['schedule']['months']==1)
check('worker_replay_no_duplicate',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==0)
check('reader_schedule_hidden','schedule' not in call(y)[1]['rows'][0])
check('anonymous_pause_denied',call(Client(),'schedule_pause',{'id':mid})[0]==403)
check('reader_pause_denied',call(y,'schedule_pause',{'id':mid})[0]==403)
check('foreign_pause_denied',call(y,'schedule_pause',{'id':mid},o=foreign)[0]==403)
check('month_end_anchor',sql("select uniion_private.dues_occurrence('2024-01-31',1,1)||','||uniion_private.dues_occurrence('2024-01-31',1,2)")=='2024-02-29,2024-03-31')
check('annual_leap_anchor',sql("select uniion_private.dues_occurrence('2024-02-29',12,1)||','||uniion_private.dues_occurrence('2024-02-29',12,4)")=='2025-02-28,2028-02-29')
check('quarter_anchor',sql("select uniion_private.dues_occurrence('2026-01-31',3,1)")=='2026-04-30')
future={**new,'prenom':'Future','email':'future@uniion-local.example','since':str(date.fromisoformat(today).replace(year=date.fromisoformat(today).year+1))}
st,r,_=call(x,'import',[future]);fr=next(v for v in r['rows'] if v['email']==future['email']);check('future_not_generated_early',st==200 and fr['duesLedger']==[])
app.sessions.clock=lambda:time.time()+183
check('authorized_pause',call(x,'schedule_pause',{'id':mid})[0]==200)
check('paused_persisted',next(v for v in call(x)[1]['rows'] if v['id']==mid)['schedule']['state']=='paused')
check('pause_preserves_charges',sql(f"select count(*) from uniion_private.dues_entries where adherent_id='{mid}'")=='1')
sql(f"update uniion_private.dues_schedules set state='active',next_index=0 where adherent_id='{mid}';update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('disabled_worker_no_write',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==0)
check('disabled_schedule_hidden','schedule' not in call(x)[1]['rows'][0])
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
check('existing_period_conflict',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['blocked']==1)
check('conflict_keeps_single_entry',sql(f"select count(*) from uniion_private.dues_entries where adherent_id='{mid}'")=='1')
sql(f"update uniion_private.dues_schedules set state='active',next_index=1 where adherent_id='{mid}';update uniion_private.adherents set data=jsonb_set(data,'{{montant}}','\"15,00 €/mois\"') where id='{mid}'")
check('changed_terms_require_review',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['blocked']==1)
check('old_amount_preserved',sql(f"select amount_cents from uniion_private.dues_entries where adherent_id='{mid}'")=='1250')
sql(f"update uniion_private.adherents set data=jsonb_set(data,'{{montant}}','\"12,50 €/mois\"') where id='{mid}';update uniion_private.dues_schedules set state='active' where adherent_id='{mid}'")
try:api.request('/rest/v1/rpc/run_dues_schedules',x.state()['access_token'],{});ok=False
except AccessDenied:ok=True
check('private_worker_denied',ok)
check('cron_installed',sql("select count(*) from cron.job where jobname='uniion-dues-hourly' and active")=='1')
out=ROOT/'preuves/S04-echeanciers';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-schedules.json').write_text(json.dumps({'organization':org,'adherent':mid}));print(json.dumps({'passed':True,'count':len(checks)}))

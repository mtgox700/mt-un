from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
sql(f"insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}')")
today=sql("select (now() at time zone 'Europe/Paris')::date");tomorrow=sql("select (now() at time zone 'Europe/Paris')::date+1")
def new(name):
 st,r,_=call(x,'import',[{**record,'prenom':name,'email':name.lower()+'@uniion-local.example','since':today}]);check('new_'+name,st==200);return next(v for v in r['rows'] if v['prenom']==name)
member=new('Fin');mid=member['id'];entry=member['duesLedger'][0]['id']
p={'id':mid,'version':member['version'],'date':today,'reason':'Départ confirmé en recette','request_id':str(uuid.uuid4())}
check('anonymous_end_denied',call(Client(),'membership_end',p)[0]==403)
check('nonfinancial_editor_denied',call(y,'membership_end',p)[0]==403)
check('foreign_end_denied',call(y,'membership_end',p,o=foreign)[0]==403)
for name,extra in [('reason_empty',{'reason':''}),('reason_long',{'reason':'x'*501}),('bad_date',{'date':'2026-99-99'}),('before_join',{'date':'2020-01-01'}),('stale',{'version':0}),('extra',{'erase':True})]:check(name,call(x,'membership_end',{**p,**extra})[0]==403)
before=sql(f"select jsonb_agg(to_jsonb(e) order by id) from uniion_private.dues_entries e where adherent_id='{mid}'")
st,r,_=call(x,'membership_end',p);ended=next(v for v in r['rows'] if v['id']==mid);check('end_saved',st==200 and ended['endedOn']==today and not ended['membershipActive'])
check('schedule_stopped',ended['schedule']['state']=='stopped')
check('history_preserved',before==sql(f"select jsonb_agg(to_jsonb(e) order by id) from uniion_private.dues_entries e where adherent_id='{mid}'"))
check('end_retry',call(x,'membership_end',p)[0]==200)
check('replay_modified_denied',call(x,'membership_end',{**p,'reason':'Autre raison'})[0]==403)
check('second_ending_denied',call(x,'membership_end',{**p,'version':ended['version'],'request_id':str(uuid.uuid4())})[0]==403)
check('audit_once',sql(f"select count(*) from uniion_private.adherent_endings where adherent_id='{mid}'")=='1')
check('worker_after_end',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==0)
app.sessions.clock=lambda:time.time()+183
for action in ('schedule_pause','schedule_preview','schedule_resume','schedule_resolve_preview','schedule_resolve'):check(action+'_stopped_denied',call(x,action,{'id':mid,'start':tomorrow})[0]==403)
check('manual_new_charge_denied',call(x,'charge',{'adherent_id':mid,'amount_cents':500,'period':tomorrow,'due_on':tomorrow,'request_id':str(uuid.uuid4())})[0]==403)
# Existing debts can still be paid.
check('existing_payment_allowed',call(x,'payment',{'id':entry,'amount_cents':500,'request_id':str(uuid.uuid4()),'effective_on':today})[0]==200)
check('status_visible_reader',next(v for v in call(y)[1]['rows'] if v['id']==mid)['endedOn']==today)
# Future end: today still active, no due date at/after cutoff accepted.
future=new('Future');fp={**p,'id':future['id'],'version':future['version'],'date':tomorrow,'request_id':str(uuid.uuid4())};st,r,_=call(x,'membership_end',fp);fr=next(v for v in r['rows'] if v['id']==future['id']);check('future_still_active',st==200 and fr['membershipActive'] and fr['schedule']['state']=='active')
check('future_boundary_charge_denied',call(x,'charge',{'adherent_id':future['id'],'amount_cents':500,'period':tomorrow,'due_on':tomorrow,'request_id':str(uuid.uuid4())})[0]==403)
# Exercise worker expiry using only this fictional record, then restore exact future date.
sql(f"update uniion_private.adherents set ended_on='{today}' where id='{future['id']}'")
check('worker_stops_at_boundary',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==0 and sql(f"select state from uniion_private.dues_schedules where adherent_id='{future['id']}'")=='stopped')
sql(f"update uniion_private.adherents set ended_on='{tomorrow}' where id='{future['id']}'")
check('worker_no_implicit_resume',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==0 and sql(f"select state from uniion_private.dues_schedules where adherent_id='{future['id']}'")=='stopped')
# UI receives three untouched fictional adherents, one per viewport.
ui=[new(n)['id'] for n in ('Mobile','Tablette','Desktop')]
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('disabled_module_end_denied',call(x,'membership_end',{**p,'id':ui[0],'version':1,'request_id':str(uuid.uuid4())})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
check('private_audit_not_granted',sql("select has_table_privilege('authenticated','uniion_private.adherent_endings','select')")=='f')
out=ROOT/'preuves/S04-fin-adhesion';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-end.json').write_text(json.dumps({'organization':org,'today':today,'members':ui}));print(json.dumps({'passed':True,'count':len(checks)}))

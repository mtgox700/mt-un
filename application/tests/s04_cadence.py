from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
sql(f"insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}')")
today=sql("select (now() at time zone 'Europe/Paris')::date")
def month(n):return sql(f"select (date_trunc('month',now() at time zone 'Europe/Paris')+interval '{n} months')::date")
new={**record,'prenom':'Cadence','nom':'Recette','email':'cadence@uniion-local.example','since':today,'montant':'12,50 €/mois'}
st,r,_=call(x,'import',[new]);member=next(v for v in r['rows'] if v['email']==new['email']);mid=member['id'];check('new_schedule_after_migration',st==200 and len(member['duesLedger'])==1)
check('automatic_coverage',sql(f"select coverage_end from uniion_private.dues_entries where adherent_id='{mid}'")==month(1))
changed={**new,'montant':'30,00 €/trimestre'}
check('quarterly_terms_saved',call(x,'save',{'id':mid,'version':member['version'],'data':changed})[0]==200)
def preview(c=x,start=None,o=org):return call(c,'schedule_resolve_preview',{'id':mid,'start':start or month(1)},o=o)
check('anonymous_denied',preview(Client())[0]==403);check('reader_denied',preview(y)[0]==403);check('foreign_denied',preview(y,o=foreign)[0]==403)
check('past_date_denied',preview(start=today)[0]==403)
pr=preview()[1]['preview'];check('quarterly_proposal',pr['months']==3 and pr['oldMonths']==1 and pr['canConfirm'])
# Existing manual future charge: unknown coverage blocks every resumption.
p={'adherent_id':mid,'amount_cents':500,'period':month(2),'due_on':month(2),'request_id':str(uuid.uuid4())}
st,r,_=call(x,'charge',p);manual=next(e for e in next(v for v in r['rows'] if v['id']==mid)['duesLedger'] if e['period']==month(2))['id'];check('manual_charge_created',st==200)
pr=preview()[1]['preview'];check('unknown_blocks',not pr['canConfirm'] and len(pr['unknown'])==1)
cover={'id':mid,'entry':manual,'lastDay':sql(f"select '{month(3)}'::date-1")}
check('reader_coverage_denied',call(y,'schedule_coverage',cover)[0]==403)
check('foreign_coverage_denied',call(y,'schedule_coverage',cover,o=foreign)[0]==403)
check('invalid_end_denied',call(x,'schedule_coverage',{**cover,'lastDay':'2020-01-01'})[0]==403)
check('explicit_coverage',call(x,'schedule_coverage',cover)[0]==200)
check('same_coverage_retry',call(x,'schedule_coverage',cover)[0]==200)
check('coverage_not_silently_rewritten',call(x,'schedule_coverage',{**cover,'lastDay':month(4)})[0]==403)
app.sessions.clock=lambda:time.time()+183
pr=preview()[1]['preview'];check('known_conflict_blocks',not pr['canConfirm'] and len(pr['conflicts'])==1)
def payload(pr):return {'id':mid,'start':pr['start'],'revision':pr['revision'],'memberVersion':pr['memberVersion'],'request_id':str(uuid.uuid4())}
check('direct_overlap_confirm_denied',call(x,'schedule_resolve',payload(pr))[0]==403)
pr=preview(start=month(3))[1]['preview'];p=payload(pr);check('first_free_period',pr['canConfirm'])
check('reader_confirm_denied',call(y,'schedule_resolve',p)[0]==403)
check('foreign_confirm_denied',call(y,'schedule_resolve',p,o=foreign)[0]==403)
check('cadence_confirmed',call(x,'schedule_resolve',p)[0]==200)
check('replay_no_duplicate_audit',call(x,'schedule_resolve',p)[0]==200 and sql(f"select count(*) from uniion_private.schedule_changes where organization_id='{org}'")=='1')
check('stale_confirm_denied',call(x,'schedule_resolve',{**p,'request_id':str(uuid.uuid4())})[0]==403)
r=next(v for v in call(x)[1]['rows'] if v['id']==mid);check('new_cadence_stable',r['schedule']['months']==3 and r['schedule']['nextDue']==month(3) and not r['schedule']['needsReview'])
check('historical_amounts_preserved',sorted(e['cents'] for e in r['duesLedger'])==[500,1250])
check('unique_occurrence_offset',sql(f"select occurrence_offset from uniion_private.dues_schedules where adherent_id='{mid}'")=='1')
check('worker_preserves_new_anchor',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==0 and sql(f"select state from uniion_private.dues_schedules where adherent_id='{mid}'")=='active')
check('coverage_audit_once',sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event='dues.coverage_confirmed'")=='1')
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('revoked_preview_denied',preview()[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
# Leave a second unknown future charge for actual GUI conflict resolution.
p={'adherent_id':mid,'amount_cents':500,'period':month(7),'due_on':month(7),'request_id':str(uuid.uuid4())};check('ui_manual_fixture',call(x,'charge',p)[0]==200)
app.sessions.clock=lambda:time.time()+244
r=next(v for v in call(x)[1]['rows'] if v['id']==mid);check('ui_annual_terms',call(x,'save',{'id':mid,'version':r['version'],'data':{**changed,'montant':'100,00 €/an'}})[0]==200)
out=ROOT/'preuves/S04-cadence-conflits';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-cadence.json').write_text(json.dumps({'organization':org,'adherent':mid,'conflictStart':month(3),'manualLastDay':sql(f"select '{month(8)}'::date-1"),'freeStart':month(8)}));print(json.dumps({'passed':True,'count':len(checks)}))

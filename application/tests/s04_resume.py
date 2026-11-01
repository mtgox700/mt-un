from pathlib import Path
exec(compile(Path(__file__).with_name('s04_schedules.py').read_text().split("out=ROOT/'preuves/S04-echeanciers'")[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+244
check('pause_for_resume',call(x,'schedule_pause',{'id':mid})[0]==200)
check('anonymous_preview_denied',call(Client(),'schedule_preview',{'id':mid})[0]==403)
check('reader_preview_denied',call(y,'schedule_preview',{'id':mid})[0]==403)
check('foreign_preview_denied',call(y,'schedule_preview',{'id':mid},o=foreign)[0]==403)
st,r,_=call(x,'schedule_preview',{'id':mid});pr=r['preview'];check('preview_no_write',st==200 and sql(f"select state from uniion_private.dues_schedules where adherent_id='{mid}'")=='paused')
payload={'id':mid,'revision':pr['revision'],'memberVersion':pr['memberVersion'],'nextDue':pr['nextDue'],'request_id':str(uuid.uuid4())}
check('reader_resume_denied',call(y,'schedule_resume',payload)[0]==403)
check('null_request_denied',call(x,'schedule_resume',{**payload,'request_id':None})[0]==403)
check('resume_authorized',call(x,'schedule_resume',payload)[0]==200)
check('same_request_idempotent',call(x,'schedule_resume',payload)[0]==200 and sql(f"select count(*) from uniion_private.schedule_changes where organization_id='{org}'")=='1')
check('altered_replay_denied',call(x,'schedule_resume',{**payload,'nextDue':'2099-01-01'})[0]==403)
check('stale_revision_denied',call(x,'schedule_resume',{**payload,'request_id':str(uuid.uuid4())})[0]==403)
app.sessions.clock=lambda:time.time()+305
ar=next(v for v in call(x)[1]['rows'] if v['id']==mid)
changed={**new,'montant':'15,00 €/mois'}
check('edit_tariff',call(x,'save',{'id':mid,'version':ar['version'],'data':changed})[0]==200)
ar=next(v for v in call(x)[1]['rows'] if v['id']==mid);check('tariff_not_silently_applied',ar['schedule']['cents']==1250 and ar['schedule']['needsReview'])
pr=call(x,'schedule_preview',{'id':mid})[1]['preview'];check('both_tariffs_shown',pr['oldCents']==1250 and pr['cents']==1500)
payload={'id':mid,'revision':pr['revision'],'memberVersion':pr['memberVersion'],'nextDue':pr['nextDue'],'request_id':str(uuid.uuid4())}
# Any subsequent member edit invalidates confirmation.
check('intervening_edit',call(x,'save',{'id':mid,'version':ar['version'],'data':{**changed,'poste':'Recette'}})[0]==200)
check('stale_member_denied',call(x,'schedule_resume',payload)[0]==403)
pr=call(x,'schedule_preview',{'id':mid})[1]['preview'];payload.update(revision=pr['revision'],memberVersion=pr['memberVersion'],nextDue=pr['nextDue'],request_id=str(uuid.uuid4()))
check('new_tariff_confirmed',call(x,'schedule_resume',payload)[0]==200)
check('historical_charge_unchanged',sql(f"select amount_cents from uniion_private.dues_entries where adherent_id='{mid}'")=='1250')
check('audit_has_before_after',sql(f"select count(*) from uniion_private.schedule_changes where organization_id='{org}' and before_state->>'amount_cents'='1250' and after_state->>'amount_cents'='1500'")=='1')
# Synthetic paused index in the past: proposal skips to today/future, without creating charges.
sql(f"update uniion_private.dues_schedules set state='paused',anchor=anchor-interval '3 months',member_anchor=member_anchor-interval '3 months',next_index=0 where adherent_id='{mid}';update uniion_private.adherents set data=jsonb_set(data,'{{since}}',to_jsonb((joined_on-interval '3 months')::date::text)) where id='{mid}'")
# Today already has a charge: keep the already-consumed future index to exercise the clamp without conflict.
sql(f"update uniion_private.dues_schedules set next_index=4 where adherent_id='{mid}'")
pr=call(x,'schedule_preview',{'id':mid})[1]['preview'];check('resume_never_moves_backwards',pr['nextIndex']==4 and pr['nextDue']>today)
# Pure proposal with past anchor and no entries, on the separate future member.
sql(f"update uniion_private.dues_schedules set state='paused',anchor=current_date-interval '4 months',member_anchor=current_date-interval '4 months',next_index=0 where adherent_id='{fr['id']}';update uniion_private.adherents set data=jsonb_set(data,'{{since}}',to_jsonb((current_date-interval '4 months')::date::text)) where id='{fr['id']}'")
pr=call(x,'schedule_preview',{'id':fr['id']})[1]['preview'];check('paused_periods_skipped',pr['skipped']==4 and pr['nextDue']==today)
app.sessions.clock=lambda:time.time()+366
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('disabled_preview_denied',call(x,'schedule_preview',{'id':mid})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
sql(f"update uniion_private.adherents set data=jsonb_set(data,'{{montant}}','\"18,00 €/mois\"') where id='{fr['id']}'")
pr=call(x,'schedule_preview',{'id':fr['id']})[1]['preview']
check('resume_new_tariff_due_today',call(x,'schedule_resume',{'id':fr['id'],'revision':pr['revision'],'memberVersion':pr['memberVersion'],'nextDue':pr['nextDue'],'request_id':str(uuid.uuid4())})[0]==200)
check('worker_uses_confirmed_tariff',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==1 and sql(f"select amount_cents from uniion_private.dues_entries where adherent_id='{fr['id']}'")=='1800')
check('no_missed_period_backfill',sql(f"select count(*) from uniion_private.dues_entries where adherent_id='{fr['id']}'")=='1')
out=ROOT/'preuves/S04-reprise-tarifs';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-resume.json').write_text(json.dumps({'organization':org,'adherent':mid}));print(json.dumps({'passed':True,'count':len(checks)}))

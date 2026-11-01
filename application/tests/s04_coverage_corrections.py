from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
sql(f"insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}')")
def month(n):return sql(f"select (date_trunc('month',now() at time zone 'Europe/Paris')+interval '{n} months')::date")
def last(n):return sql(f"select '{month(n)}'::date-1")
today=sql("select (now() at time zone 'Europe/Paris')::date")
st,r,_=call(x,'import',[{**record,'prenom':'Couverture','email':'couverture@uniion-local.example','since':today}]);mid=next(v['id'] for v in r['rows'] if v['email']=='couverture@uniion-local.example')
check('member_created',st==200)
def charge(n):
 st,r,_=call(x,'charge',{'adherent_id':mid,'amount_cents':500,'period':month(n),'due_on':month(n),'request_id':str(uuid.uuid4())});check('charge_created_'+str(n),st==200)
 return next(e['id'] for e in next(v for v in r['rows'] if v['id']==mid)['duesLedger'] if e['period']==month(n))
e1,e2=charge(2),charge(4)
check('initial_coverage',call(x,'schedule_coverage',{'id':mid,'entry':e1,'lastDay':last(3)})[0]==200)
def listing(c=x,o=org):return call(c,'coverage_list',{'id':mid},o=o)
st,r,_=listing();check('confirmed_manual_only',st==200 and len(r['coverages'])==1 and r['coverages'][0]['id']==e1)
version=r['coverages'][0]['revision']
p={'id':mid,'entry':e1,'revision':version,'lastDay':last(4),'reason':'Correction de la fin saisie','request_id':str(uuid.uuid4())}
check('anonymous_denied',call(Client(),'coverage_correct',p)[0]==403)
check('reader_list_denied',listing(y)[0]==403);check('reader_write_denied',call(y,'coverage_correct',p)[0]==403)
check('foreign_list_denied',listing(y,foreign)[0]==403);check('foreign_write_denied',call(y,'coverage_correct',p,o=foreign)[0]==403)
# Even a fully authorized actor in another organization cannot address this entry.
sql(f"insert into public.uniion_module_access values('{foreign}','cotisations',true,true,'included',now()+interval '10 days');insert into public.uniion_permissions values('{foreign}','{b['id']}','cotisations','write'),('{foreign}','{b['id']}','cotisations','read')")
check('foreign_financial_writer_denied',call(y,'coverage_correct',p,o=foreign)[0]==403)
for name,extra in [('empty_reason',{'reason':''}),('long_reason',{'reason':'x'*501}),('not_string',{'reason':123}),('bad_date',{'lastDay':'not-date'}),('before_start',{'lastDay':'2020-01-01'}),('no_change',{'lastDay':last(3)}),('stale',{'revision':version-1}),('extra_field',{'amount_cents':1}),('unknown_period',{'entry':e2}),('overlap_unknown',{'lastDay':month(4)})]:check(name+'_denied',call(x,'coverage_correct',{**p,**extra})[0]==403)
app.sessions.clock=lambda:time.time()+183
before=sql(f"select jsonb_agg(to_jsonb(e)-'coverage_end'-'coverage_revision' order by id) from uniion_private.dues_entries e where adherent_id='{mid}'")
state=sql(f"select state from uniion_private.dues_schedules where adherent_id='{mid}'")
pr=call(x,'schedule_resolve_preview',{'id':mid,'start':month(6)})[1]['preview']
st,r,_=call(x,'coverage_correct',p);check('correction_saved',st==200 and r['coverages'][0]['lastDay']==last(4))
check('history_before_after',len(r['coverages'][0]['history'])==1 and r['coverages'][0]['history'][0]['before']['lastDay']==last(3) and r['coverages'][0]['history'][0]['actor']==a['id'])
check('state_not_resumed',sql(f"select state from uniion_private.dues_schedules where adherent_id='{mid}'")==state)
check('old_schedule_proposal_invalidated',sql(f"select revision from uniion_private.dues_schedules where adherent_id='{mid}'")!=str(pr['revision']))
check('identical_retry',call(x,'coverage_correct',p)[0]==200)
check('changed_replay_denied',call(x,'coverage_correct',{**p,'reason':'Autre motif'})[0]==403)
check('stale_new_request_denied',call(x,'coverage_correct',{**p,'request_id':str(uuid.uuid4())})[0]==403)
check('financial_history_unchanged',before==sql(f"select jsonb_agg(to_jsonb(e)-'coverage_end'-'coverage_revision' order by id) from uniion_private.dues_entries e where adherent_id='{mid}'"))
check('audit_once',sql(f"select count(*) from uniion_private.coverage_corrections where organization_id='{org}'")=='1' and sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event='dues.coverage_corrected'")=='1')
check('reloaded_history',len(listing()[1]['coverages'][0]['history'])==1)
check('second_coverage',call(x,'schedule_coverage',{'id':mid,'entry':e2,'lastDay':last(5)})[0]==200)
p2={**p,'revision':version+1,'lastDay':month(4),'request_id':str(uuid.uuid4())}
check('known_overlap_denied',call(x,'coverage_correct',p2)[0]==403)
auto=sql(f"select id from uniion_private.dues_entries where adherent_id='{mid}' and schedule_id is not null")
check('automatic_coverage_denied',call(x,'coverage_correct',{**p2,'entry':auto,'revision':1})[0]==403)
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('disabled_module_denied',listing()[0]==403 and call(x,'coverage_correct',p)[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations';update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{a['id']}'")
check('revoked_membership_denied',listing()[0]==403)
sql(f"update public.uniion_memberships set revoked_at=null where organization_id='{org}' and user_id='{a['id']}'")
check('private_history_no_grants',sql("select has_table_privilege('authenticated','uniion_private.coverage_corrections','select')")=='f')
check('old_rpc_no_execute',sql("select has_function_privilege('authenticated','public.uniion_adherents_before_coverage_correction(uuid,text,jsonb)','execute')")=='f')
# Keep fixture ready for real UI: correction from March to February end, harmless shrink.
out=ROOT/'preuves/S04-corrections-couvertures';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-coverage.json').write_text(json.dumps({'organization':org,'adherent':mid,'newEnd':last(3),'oldEnd':last(4),'overlapEnd':month(4)}));print(json.dumps({'passed':True,'count':len(checks)}))

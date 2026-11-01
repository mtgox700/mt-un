from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
sql(f"insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}')")
today=sql("select (now() at time zone 'Europe/Paris')::date");tomorrow=sql("select (now() at time zone 'Europe/Paris')::date+1");first=sql("select (date_trunc('month',now() at time zone 'Europe/Paris')+interval '1 month')::date")
def get(mid):return next(v for v in call(x)[1]['rows'] if v['id']==mid)
def new(name):
 st,r,_=call(x,'import',[{**record,'prenom':name,'email':name.lower()+'@uniion-local.example','since':today}]);check('new_'+name,st==200);return next(v for v in r['rows'] if v['prenom']==name)
def end(a,date=today):return call(x,'membership_end',{'id':a['id'],'version':a['version'],'date':date,'reason':'Fin fictive confirmée','request_id':str(uuid.uuid4())})
a1=new('Retour');mid=a1['id'];check('end_first_cycle',end(a1)[0]==200)
a1=get(mid);p={'id':mid,'version':a1['version'],'date':tomorrow,'reason':'Correction fictive de date','request_id':str(uuid.uuid4())}
for c,o,n in [(Client(),org,'anonymous'),(y,org,'reader'),(y,foreign,'foreign')]:check(n+'_correction_denied',call(c,'membership_end_correct',p,o=o)[0]==403)
check('correction_before_join_denied',call(x,'membership_end_correct',{**p,'date':'2020-01-01'})[0]==403)
check('correct_future',call(x,'membership_end_correct',p)[0]==200 and get(mid)['schedule']['state']=='paused')
check('correct_retry',call(x,'membership_end_correct',p)[0]==200)
check('modified_retry_denied',call(x,'membership_end_correct',{**p,'reason':'Autre motif'})[0]==403)
check('stale_correction_denied',call(x,'membership_end_correct',{**p,'request_id':str(uuid.uuid4())})[0]==403)
a1=get(mid);check('correct_back',call(x,'membership_end_correct',{**p,'version':a1['version'],'date':today,'request_id':str(uuid.uuid4())})[0]==200)
def preview(mode='paused',date=today,due='',c=x,o=org):return call(c,'membership_return_preview',{'id':mid,'date':date,'mode':mode,'firstDue':due},o=o)
for c,o,n in [(Client(),org,'anonymous'),(y,org,'reader'),(y,foreign,'foreign')]:check(n+'_preview_denied',preview(c=c,o=o)[0]==403)
check('past_return_denied',preview(date='2020-01-01')[0]==403)
pr=preview('resume',due=today)[1]['preview'];check('overlap_preview_blocks',not pr['canConfirm'])
def payload(pr):return {'id':mid,'date':pr['date'],'mode':pr['mode'],'firstDue':pr['firstDue'] or '', 'version':pr['version'],'scheduleRevision':pr['scheduleRevision'],'reason':'Réadhésion fictive validée','request_id':str(uuid.uuid4())}
check('direct_overlap_denied',call(x,'membership_return',payload(pr))[0]==403)
pr=preview()[1]['preview'];p=payload(pr);before=sql(f"select jsonb_agg(to_jsonb(e) order by id) from uniion_private.dues_entries e where adherent_id='{mid}'")
check('reader_confirm_denied',call(y,'membership_return',p)[0]==403)
check('foreign_confirm_denied',call(y,'membership_return',p,o=foreign)[0]==403)
check('paused_return',call(x,'membership_return',p)[0]==200 and get(mid)['schedule']['state']=='paused' and get(mid)['requiresReanchor'])
check('paused_retry',call(x,'membership_return',p)[0]==200)
check('no_automatic_work',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==0)
check('simple_resume_not_allowed',call(x,'schedule_preview',{'id':mid})[0]==403)
check('paused_preserves_entries',before==sql(f"select jsonb_agg(to_jsonb(e) order by id) from uniion_private.dues_entries e where adherent_id='{mid}'"))
app.sessions.clock=lambda:time.time()+183
# A new ending is possible in a new cycle, without deleting the original.
check('end_second_cycle',end(get(mid))[0]==200)
check('two_endings_preserved',sql(f"select count(*) from uniion_private.adherent_endings where adherent_id='{mid}'")=='2')
pr=preview('resume',due=first)[1]['preview'];p=payload(pr)
check('terms_preview',pr['canConfirm'] and pr['months']==1 and pr['cents']==1250)
check('schedule_stale_denied',call(x,'membership_return',{**p,'scheduleRevision':0})[0]==403)
check('resume_return',call(x,'membership_return',p)[0]==200)
a1=get(mid);check('resume_explicit_schedule',a1['schedule']['state']=='active' and a1['schedule']['nextDue']==first and not a1['requiresReanchor'])
check('resume_retry',call(x,'membership_return',p)[0]==200)
check('resume_preserves_entries',before==sql(f"select jsonb_agg(to_jsonb(e) order by id) from uniion_private.dues_entries e where adherent_id='{mid}'"))
check('old_end_retry_does_not_end_new_cycle',call(x,'membership_return',p)[0]==200 and get(mid)['endedOn'] is None)
check('history_loaded',len(a1['membershipHistory'])==4)
check('history_hidden_reader','membershipHistory' not in next(v for v in call(y)[1]['rows'] if v['id']==mid))
check('audit_count',sql(f"select count(*) from uniion_private.membership_changes where adherent_id='{mid}'")=='4')
# Future return cannot create dues before the new membership date.
check('end_third_cycle',end(get(mid))[0]==200)
pr=preview(date=tomorrow)[1]['preview'];check('future_paused_return',call(x,'membership_return',payload(pr))[0]==200 and not get(mid)['membershipActive'])
check('future_manual_charge_denied',call(x,'charge',{'adherent_id':mid,'amount_cents':500,'period':first,'due_on':first,'request_id':str(uuid.uuid4())})[0]==403)
rp=call(x,'schedule_resolve_preview',{'id':mid,'start':first})[1]['preview']
check('separate_resume',call(x,'schedule_resolve',{'id':mid,'start':first,'revision':rp['revision'],'memberVersion':rp['memberVersion'],'request_id':str(uuid.uuid4())})[0]==200)
check('separate_resume_clears_flag',not get(mid)['requiresReanchor'] and get(mid)['schedule']['state']=='active')
app.sessions.clock=lambda:time.time()+244
# Six independent fictitious flows for the two modes at each viewport.
ui=[]
for name in ['Mobilepause','Mobileresume','Tablettepause','Tabletteresume','Desktoppause','Desktopresume']:
 a1=new(name);check('ui_end_'+name,end(a1,tomorrow)[0]==200);ui.append(a1['id'])
check('private_history',sql("select has_table_privilege('authenticated','uniion_private.membership_changes','select')")=='f')
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
cp={'id':ui[0],'version':get(ui[0])['version'],'date':today,'reason':'Correction fictive contrôlée','request_id':str(uuid.uuid4())}
check('disabled_correction',call(x,'membership_end_correct',cp)[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
sql(f"update public.uniion_memberships set revoked_at=now() where organization_id='{org}' and user_id='{a['id']}'")
check('revoked_member_correction',call(x,'membership_end_correct',cp)[0]==403)
sql(f"update public.uniion_memberships set revoked_at=null where organization_id='{org}' and user_id='{a['id']}'")
out=ROOT/'preuves/S04-readhesion';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-return.json').write_text(json.dumps({'organization':org,'today':today,'tomorrow':tomorrow,'firstDue':first,'members':ui}));print(json.dumps({'passed':True,'count':len(checks)}))

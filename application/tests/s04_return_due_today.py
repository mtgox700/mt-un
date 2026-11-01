from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
today=sql("select (now() at time zone 'Europe/Paris')::date");yesterday=sql("select (now() at time zone 'Europe/Paris')::date-1")
st,r,_=call(x,'import',[{**record,'prenom':'Immediat','email':'immediat@uniion-local.example','since':yesterday}]);a1=next(v for v in r['rows'] if v['prenom']=='Immediat');mid=a1['id'];check('no_prior_occurrence',not a1['duesLedger'])
st,r,_=call(x,'membership_end',{'id':mid,'version':a1['version'],'date':today,'reason':'Fin de recette','request_id':str(uuid.uuid4())});check('ended',st==200)
pr=call(x,'membership_return_preview',{'id':mid,'mode':'resume','date':today,'firstDue':today})[1]['preview'];check('free_today_preview',pr['canConfirm'])
p={'id':mid,'mode':'resume','date':today,'firstDue':today,'version':pr['version'],'scheduleRevision':pr['scheduleRevision'],'reason':'Réadhésion avec échéance du jour','request_id':str(uuid.uuid4())}
st,r,_=call(x,'membership_return',p);v=next(v for v in r['rows'] if v['id']==mid);check('today_occurrence_created',st==200 and len(v['duesLedger'])==1 and v['duesLedger'][0]['dueOn']==today)
st,r,_=call(x,'membership_return',p);check('retry_exactly_once',st==200 and len(next(v for v in r['rows'] if v['id']==mid)['duesLedger'])==1)
check('worker_no_duplicate',json.loads(sql(f"select uniion_private.run_dues_schedules('{org}')"))['created']==0)
(ROOT/'preuves/S04-readhesion/due-today.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

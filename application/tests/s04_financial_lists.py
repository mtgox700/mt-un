from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
p={'name':'Retards fictifs','description':'Liste financière','criteria':{'statut':'retard'},'request_id':str(uuid.uuid4())}
check('nonfinancial_editor_cannot_create',call(y,'list_create',p)[0]==403)
st,r,_=call(x,'list_create',p);check('financial_list_created',st==200);g=r['groups'][0]
check('financial_list_hidden',call(y)[1]['groups']==[])
check('financial_status_hidden','statut' not in call(y)[1]['rows'][0])
check('financial_target_denied',call(y,'campaign_targets',{'list':g['id']})[0]==403)
check('financial_list_edit_denied',call(y,'list_update',{'id':g['id'],'version':g['version'],'name':'Refus','description':''})[0]==403)
check('initial_empty',call(x,'campaign_targets',{'list':g['id']})[1]['rows']==[])
today=sql("select (now() at time zone 'Europe/Paris')::date");yesterday=sql("select (now() at time zone 'Europe/Paris')::date-1")
charge={'adherent_id':row['id'],'amount_cents':500,'period':today[:7]+'-01','due_on':yesterday,'request_id':str(uuid.uuid4())}
check('charge',call(x,'charge',charge)[0]==200)
r=call(x)[1]['rows'][0];check('overdue_status_real',r['statut']=='retard')
check('dynamic_target_appears',len(call(x,'campaign_targets',{'list':g['id']})[1]['rows'])==1)
pay={'id':r['duesLedger'][0]['id'],'amount_cents':500,'effective_on':today,'request_id':str(uuid.uuid4())}
check('payment',call(x,'payment',pay)[0]==200)
check('paid_status_real',call(x)[1]['rows'][0]['statut']=='ajour')
check('dynamic_target_removed',call(x,'campaign_targets',{'list':g['id']})[1]['rows']==[])
sql(f"insert into public.uniion_authorities values('{org}','{b['id']}','download',false)")
check('download_does_not_grant_financial_target',call(y,'directory_export',{'list':g['id']})[0]==403)
check('foreign_targets_denied',call(y,'campaign_targets',{'list':g['id']},o=foreign)[0]==403)
out=ROOT/'preuves/S04-cloture';(out/'financial-lists.json').write_text(json.dumps({'passed':True,'checks':checks,'count':len(checks)},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

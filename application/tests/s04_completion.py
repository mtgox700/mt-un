from pathlib import Path
exec(compile(Path(__file__).with_name('s04_adherents.py').read_text().split('out=ROOT/')[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
sql(f"insert into uniion_private.organization_details values('{org}','{{\"type\":\"section\"}}');delete from public.uniion_permissions where organization_id='{org}' and user_id='{b['id']}' and permission='write'")
p={'name':'Liste de recette','description':'Destinataires fictifs','criteria':{'ent':'Entreprise fictive','statut':'Tous'},'request_id':str(uuid.uuid4())}
for c,o,n in [(Client(),org,'anonymous'),(y,org,'reader'),(y,foreign,'foreign')]:check(n+'_list_denied',call(c,'list_create',p,o=o)[0]==403)
st,r,_=call(x,'list_create',p);check('list_create',st==200 and len(r['groups'])==1);g=r['groups'][0]
check('list_retry',len(call(x,'list_create',p)[1]['groups'])==1)
check('list_mutated_retry_denied',call(x,'list_create',{**p,'name':'Autre'})[0]==403)
check('list_second_actor',call(y)[1]['groups'][0]['id']==g['id'])
check('list_isolated',call(y,o=foreign)[1]['groups']==[])
u={'id':g['id'],'version':g['version'],'name':'Liste durable','description':'Usage confirmé'}
check('reader_update_denied',call(y,'list_update',u)[0]==403)
check('foreign_update_denied',call(y,'list_update',u,o=foreign)[0]==403)
check('list_update',call(x,'list_update',u)[0]==200)
check('stale_update_denied',call(x,'list_update',u)[0]==403)
check('targets_contract',call(x,'campaign_targets',{'list':g['id']})[1]['rows'][0]['id']==row['id'])
check('targets_no_finance','duesLedger' not in call(x,'campaign_targets',{'list':g['id']})[1]['rows'][0])
check('foreign_targets_denied',call(y,'campaign_targets',{'list':g['id']},o=foreign)[0]==403)
check('export_permission',call(x,'directory_export',{})[0]==403)
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','download',false)")
check('export_authorized',call(x,'directory_export',{})[0]==200)
check('export_audited',sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event='adherents.directory_export'")=='1')
check('private_lists',sql("select has_table_privilege('authenticated','uniion_private.member_lists','select')")=='f')
app.sessions.clock=lambda:time.time()+183
today=sql("select (now() at time zone 'Europe/Paris')::date");future=sql("select (date_trunc('month',now() at time zone 'Europe/Paris')+interval '2 months')::date")
ui=[]
for name in ['Mobile','Tablette','Desktop','Ancien']:
 data={**record,'prenom':name,'email':name.lower()+'@uniion-local.example'}
 st,r,_=call(x,'import',[{**data,'montant':''}]);check('import_'+name,st==200)
 member=next(v for v in r['rows'] if v['prenom']==name);check('no_plan_'+name,member['schedule'] is None)
 check('terms_'+name,call(x,'save',{'id':member['id'],'version':member['version'],'data':data})[0]==200);ui.append(member['id'])
mid=ui[-1];pr=call(x,'schedule_activate_preview',{'id':mid,'start':future})[1]['preview'];check('preview',pr['canConfirm'] and pr['months']==1)
p={'id':mid,'start':future,'memberVersion':pr['memberVersion'],'request_id':str(uuid.uuid4())}
for c,o,n in [(Client(),org,'anonymous'),(y,org,'reader'),(y,foreign,'foreign')]:check(n+'_activation_denied',call(c,'schedule_activate',p,o=o)[0]==403)
check('past_denied',call(x,'schedule_activate',{**p,'start':today})[0]==403)
check('stale_denied',call(x,'schedule_activate',{**p,'memberVersion':0})[0]==403)
check('activate',call(x,'schedule_activate',p)[0]==200)
check('activate_retry',call(x,'schedule_activate',p)[0]==200)
check('no_retroactivity',sql(f"select count(*) from uniion_private.dues_entries where adherent_id='{mid}'")=='0')
check('activation_audited',sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event='dues.schedule_activated'")=='1')
app.sessions.clock=lambda:time.time()+244
mid=ui[0];charge={'adherent_id':mid,'amount_cents':500,'period':today[:7]+'-01','due_on':today,'request_id':str(uuid.uuid4())}
check('historical_charge',call(x,'charge',charge)[0]==200)
pr=call(x,'schedule_activate_preview',{'id':mid,'start':future})[1]['preview'];check('unknown_blocks',not pr['canConfirm'] and len(pr['unknown'])==1)
e=pr['unknown'][0];last=sql("select (date_trunc('month',now() at time zone 'Europe/Paris')+interval '1 month -1 day')::date")
check('coverage_without_plan',call(x,'schedule_coverage',{'id':mid,'entry':e['id'],'lastDay':last})[0]==200)
check('coverage_list_without_plan',len(call(x,'coverage_list',{'id':mid})[1]['coverages'])==1)
check('activation_unblocked',call(x,'schedule_activate_preview',{'id':mid,'start':future})[1]['preview']['canConfirm'])
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='adherents'")
check('disabled_contract',call(x,'campaign_targets',{'list':g['id']})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='adherents'")
out=ROOT/'preuves/S04-cloture';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-completion.json').write_text(json.dumps({'organization':org,'foreign':foreign,'members':ui,'firstDue':future}));print(json.dumps({'passed':True,'count':len(checks)}))

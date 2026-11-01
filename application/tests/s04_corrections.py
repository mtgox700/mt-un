from pathlib import Path
exec(compile(Path(__file__).with_name('s04_partial.py').read_text().rsplit("out=ROOT/",1)[0],__file__,'exec'))
app.sessions.clock=lambda:time.time()+244
entry=call(x)[1]['rows'][0]['duesLedger'][0];payment=entry['payments'][0]
p={'id':payment['id'],'revision':0,'amount_cents':500,'reason':'Erreur de saisie fictive','request_id':str(uuid.uuid4())}
check('correction_without_rights_denied',call(y,'correct',p)[0]==403)
check('correction_foreign_denied',call(y,'correct',p,o=foreign)[0]==403)
# The first payment can be either 750 or 1250: cap correction within its own amount.
p['amount_cents']=payment['cents']-250
st,res,_=call(x,'correct',p);e=res['rows'][0]['duesLedger'][0];corrected=next(i for i in e['payments'] if i['id']==payment['id'])
check('correction_reopens_balance',st==200 and e['paidCents']==1750 and e['paidAt'] is None)
check('original_and_reason_preserved',corrected['originalCents']==payment['cents'] and corrected['revision']==1 and corrected['corrections'][0]['reason']==p['reason'] and corrected['corrections'][0]['actor']==a['id'])
check('retry_idempotent',len(next(i for i in call(x,'correct',p)[1]['rows'][0]['duesLedger'][0]['payments'] if i['id']==payment['id'])['corrections'])==1)
check('retry_altered_denied',call(x,'correct',{**p,'reason':'Motif modifié'})[0]==403)
check('stale_version_denied',call(x,'correct',{**p,'request_id':str(uuid.uuid4())})[0]==403)
for i,patch in enumerate([{'reason':''},{'amount_cents':-1},{'amount_cents':1.5},{'amount_cents':3000},{'revision':None}]):check('invalid_correction_'+str(i),call(x,'correct',{**p,'revision':1,'request_id':str(uuid.uuid4()),**patch})[0]==403)
check('cancel_without_delete',call(x,'correct',{**p,'revision':1,'amount_cents':0,'reason':'Annulation de déclaration erronée','request_id':str(uuid.uuid4())})[0]==200)
check('initial_payment_retained',sql(f"select amount_cents from uniion_private.dues_payments where id='{payment['id']}'")==str(payment['cents']))
check('restore_by_new_revision',call(x,'correct',{**p,'revision':2,'amount_cents':payment['cents'],'reason':'Rétablissement après contrôle','request_id':str(uuid.uuid4())})[0]==200)
check('fully_paid_again',call(x)[1]['rows'][0]['duesLedger'][0]['paidCents']==2000)
check('three_audit_events',sql(f"select count(*) from public.uniion_security_events where organization_id='{org}' and event='dues.corrected'")=='3')
app.sessions.clock=lambda:time.time()+305
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('disabled_correction_denied',call(x,'correct',{**p,'revision':3,'request_id':str(uuid.uuid4())})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
check('corrections_hidden_from_reader','duesLedger' not in call(y)[1]['rows'][0])
out=ROOT/'preuves/S04-corrections-reglements';out.mkdir(parents=True,exist_ok=True);(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-corrections.json').write_text(json.dumps({'organization':org,'adherent':row['id']}));print(json.dumps({'passed':True,'count':len(checks)}))

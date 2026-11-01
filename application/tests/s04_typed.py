"""Local fictional S04 register: structured dates/dues and financial revocation."""
from pathlib import Path
base=Path(__file__).with_name('s04_adherents.py').read_text().split("out=ROOT/")[0]
exec(compile(base,__file__,'exec'))
app.sessions.clock=lambda:time.time()+122
row=call(x)[1]['rows'][0]
check('date_typed',row['joinedOn']=='2026-10-01' and not row['dateNeedsReview'])
check('dues_exact_cents',row['dues']=={'status':'valid','cents':1250,'currency':'EUR','period':'month'})
check('dues_hidden_for_nonfinancial', 'dues' not in call(y)[1]['rows'][0])
for index,(field,value) in enumerate([('since','31/02/2026'),('since','2026-02-29'),('since','0000-01-01'),('since','septembre 2026'),('montant','12.345 €'),('montant','-2 €'),('montant','12'),('montant','12 $'),('montant','1e3 €'),('montant','12 €/jour')]):
 app.sessions.clock=lambda:time.time()+250+index*61
 before=call(x)[1]['rows'][0]['version']
 status,_,_=call(x,'save',{'id':row['id'],'version':before,'data':{**record,field:value}})
 check('invalid_typed_'+str(index),status==403)
 check('unchanged_after_invalid_'+str(index),call(x)[1]['rows'][0]['version']==before)

app.sessions.clock=lambda:time.time()+900
check('invalid_batch_atomic',call(x,'import',[{**record,'email':'valid@uniion-local.example'},{**record,'email':'bad@uniion-local.example','montant':'oops'}])[0]==403)
check('invalid_batch_no_partial',len(call(x)[1]['rows'])==1)
for i,(value,cents,period) in enumerate([('9.5 EUR/trimestre',950,'quarter'),('150 €/an',15000,'year'),('0 €',0,None),('',None,None)]):
 app.sessions.clock=lambda:time.time()+1000+i*61
 row=call(x)[1]['rows'][0]
 st,res,_=call(x,'save',{'id':row['id'],'version':row['version'],'data':{**record,'since':'2024-02-29','montant':value}})
 check('valid_typed_'+str(i),st==200 and res['rows'][0]['joinedOn']=='2024-02-29' and res['rows'][0]['dues'].get('cents')==cents and res['rows'][0]['dues'].get('period')==period)
app.sessions.clock=lambda:time.time()+1300
row=call(x)[1]['rows'][0]
call(x,'save',{'id':row['id'],'version':row['version'],'data':record})
for column,off,on in [('enabled','false','true'),('authorized','false','true'),('valid_until',"now()-interval '1 day'","now()+interval '10 days'")]:
 sql(f"update public.uniion_module_access set {column}={off} where organization_id='{org}' and module='cotisations'")
 row=call(x)[1]['rows'][0]
 check('financial_'+column+'_hidden',not {'dues','montant','mode'}&set(row))
 check('financial_'+column+'_write_denied',call(x,'save',{'id':row['id'],'version':row['version'],'data':record})[0]==403)
 sql(f"update public.uniion_module_access set {column}={on} where organization_id='{org}' and module='cotisations'")
check('typed_in_database',sql(f"select joined_on::text||':'||(dues_terms->>'cents') from uniion_private.adherents where organization_id='{org}'")=='2026-10-01:1250')
check('legacy_parser_preserves_ambiguity',sql("select uniion_private.adherent_date('septembre 2026') is null and uniion_private.adherent_dues('à définir')->>'status'='review'")=='t')
check('foreign_still_isolated',call(y,o=foreign)[1]['rows']==[])
out=ROOT/'preuves/S04-cotisations-structurees';out.mkdir(parents=True,exist_ok=True)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2))
(ROOT/'.local-auth/s04-typed.json').write_text(json.dumps({'organization':org,'adherent':row['id']}))
print(json.dumps({'passed':True,'count':len(checks)}))

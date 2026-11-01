"""All migrations from zero, real isolated Auth/MFA and S08 default-deny."""
import sys,json,hashlib
from pathlib import Path
from s08_proof_scope import install,ROOT
fresh_proof=install('fresh');sys.path.insert(0,str(ROOT))
import backup_restore as b,restore_services as services

def ai_checks(name,client,accounts,check):
 a=accounts[0];org=a['org']
 b.sql(f"""insert into public.uniion_module_access values('{org}','assistant',true,true,'included',now()+interval '1 day');
 insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) values('{org}','assistant','paid',now()-interval '1 day',now()+interval '1 day','S08-F-fictif');
 insert into public.uniion_permissions select '{org}','{a['id']}','assistant',p from unnest(array['read','write'])p;""",name,'restored')
 def rpc(action,payload={}):return services.request(client,3000,'/rpc/uniion_ai_policy',a['token'],{'p_org':org,'p_action':action,'p_payload':payload})
 status=rpc('status');check('fresh_provider_unapproved',status['status']==200 and status['data']['approved'] is False)
 check('fresh_authorize_denied',rpc('authorize')['status']==403)
 check('fresh_member_cannot_approve',rpc('approve',{'enabled':True,'version':1})['status']==403)
 check('fresh_private_registry_not_exposed',services.request(client,3000,'/ai_recipe_sources?select=*',a['token'])['status'] in (403,404))
 check('fresh_registry_empty',b.sql('select count(*) from uniion_private.ai_recipe_sources',name,'restored')=='0')
 check('fresh_no_activation',b.sql('select count(*) from uniion_private.ai_activations',name,'restored')=='0')
 from uniion.adapters.ai_runs import RunLedger
 import tempfile
 with tempfile.TemporaryDirectory() as temp:
  ledger=RunLedger(Path(temp)/'new-runs.sqlite3')
  check('fresh_ledger_schema2',ledger.db.execute('pragma user_version').fetchone()[0]==2)
  check('fresh_history_empty',ledger.history.rows(org,a['id'])==[])
  ledger.close()
source=(ROOT/'operations/ephemeral_ci.py').read_text()
source=source.replace("check('all_24_migrations_from_empty_database',len(migrations)==24)","check('all_139_migrations_from_empty_database',len(migrations)==139)\n  (fresh_proof/'migrations.json').write_text(json.dumps([{'file':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in migrations],indent=2))")
source=source.replace('  from ephemeral_files import run as file_paths\n  file_paths(name,client,accounts,credentials[\'service_token\'],check)\n  from ephemeral_recovery import run as recovery_path\n  recovery_path(name,client,accounts,credentials[\'service_token\'],check)','  ai_checks(name,client,accounts,check)')
exec(compile(source,str(ROOT/'operations/ephemeral_ci.py'),'exec'))

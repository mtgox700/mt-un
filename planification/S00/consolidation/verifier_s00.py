# -*- coding: utf-8 -*-
"""Contrôles documentaires et invariants de migration S00. Aucun accès réseau/base."""
from pathlib import Path
import json,csv,re,hashlib,unittest
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def read(n):return json.loads((HERE/n).read_text())
def cleanup_allowed(local_version,local_hash,receipt):
 return bool(receipt and receipt.get('committed') and receipt.get('version')==local_version and receipt.get('sha256')==local_hash)
def sync_preflight(command,context):
 # Reference contract, not production authorization or RLS.
 if not all(context.get(x) for x in ['session_active','membership_active','module_authorized','entitlement_valid','module_enabled','resource_write']):return 'deny'
 if command['org_id']!=context['org_id']:return 'deny'
 if context.get('deleted'):return 'deleted'
 previous=context.get('receipt')
 if previous and command['operation_id']==previous['operation_id']:return 'retry' if command['digest']==previous['digest'] else 'invalid-replay'
 return 'conflict' if command['base_version']!=context['server_version'] else 'apply'
class Checks(unittest.TestCase):
 def test_57_keys_exact(self):
  text=(ROOT/'prototype-local/public/uniion App v3.dc.html').read_text()
  keys=re.search(r'const PERSIST_KEYS = \[(.*?)\];',text).group(1)
  self.assertEqual(set(re.findall("'([^']+)'",keys)),{x['cle'] for x in read('migration-57-champs.json')})
 def test_all_targets_exist(self):
  entities={e['entity'] for e in read('schema-consolide.json')}
  for m in read('migration-57-champs.json'):
   self.assertTrue(set(m['cibles'].split(','))<=entities,m)
 def test_security_fields_never_imported(self):
  m={x['cle']:x for x in read('migration-57-champs.json')}
  for k in ['signed','admKeys','uniiRole','devices','plan','planCycle','planCard','extCfg']:self.assertEqual(m[k]['action'],'ne_pas_importer')
  self.assertEqual(m['flags']['action'],'split_controlé')
 def test_no_duplicate_entities_or_permissions(self):
  for file,key in [('schema-consolide.json','entity'),('droits-consolides.json','permission')]:
   rows=read(file);self.assertEqual(len(rows),len({r[key] for r in rows}))
 def test_source_unchanged(self):
  before=json.loads((HERE.parent/'empreintes-avant.json').read_text())
  for n,h in before.items():self.assertEqual(hashlib.sha256((ROOT/n).read_bytes()).hexdigest(),h,n)
 def test_cleanup_rejects_newer_or_unconfirmed(self):
  receipt={'version':4,'sha256':'h','committed':True}
  self.assertTrue(cleanup_allowed(4,'h',receipt))
  for ver,digest,r in [(5,'h',receipt),(4,'other',receipt),(4,'h',None),(4,'h',dict(receipt,committed=False))]:self.assertFalse(cleanup_allowed(ver,digest,r))
 def test_sync_contract_adversarial(self):
  context={k:True for k in ['session_active','membership_active','module_authorized','entitlement_valid','module_enabled','resource_write']};context.update(org_id='A',server_version=4)
  command=dict(org_id='A',base_version=4,operation_id='op1',digest='h')
  self.assertEqual(sync_preflight(command,context),'apply')
  for k in ['session_active','membership_active','module_authorized','entitlement_valid','module_enabled','resource_write']:self.assertEqual(sync_preflight(command,dict(context,**{k:False})),'deny')
  self.assertEqual(sync_preflight(dict(command,org_id='B'),context),'deny')
  self.assertEqual(sync_preflight(command,dict(context,server_version=5)),'conflict')
  self.assertEqual(sync_preflight(command,dict(context,deleted=True)),'deleted')
  r=dict(operation_id='op1',digest='h')
  self.assertEqual(sync_preflight(command,dict(context,receipt=r)),'retry')
  self.assertEqual(sync_preflight(dict(command,digest='other'),dict(context,receipt=r)),'invalid-replay')
if __name__=='__main__':
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks))
 (HERE/'verification-technique.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'portee':'Contrôles S00 et modèles de contrat uniquement ; aucun test Supabase, chiffrement ou restauration effectué'},ensure_ascii=False,indent=2))
 raise SystemExit(not result.wasSuccessful())

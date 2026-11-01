import json,tempfile,unittest,uuid,sqlite3
from pathlib import Path
from uniion.adapters.ai_runs import RunLedger
from uniion.adapters.ai_gateway import AIGateway
from uniion.adapters.ai_assistant import Assistant
from uniion.core.contracts import Denied

class Context:
    def __init__(self):self.allowed=True;self.certified=True;self.version=1;self.seen=[]
    def check(self,org,snapshot):
        self.seen.append(snapshot)
        if not self.allowed or snapshot[0]['fingerprint']!=str(self.version)*64:raise Denied()
        return snapshot
    def recipe(self,org,sources):
        if not self.certified:raise Denied()
    def generate(self,org,values,provider,check,cancelled):
        check();text=provider.complete('fictif',(),cancelled=cancelled);check()
        return {'text':text,'snapshot':[{'kind':'case','id':values[0]['id'],'fingerprint':str(self.version)*64}], 'excerpts':[{'source':'S1','passage':'P1','quote':text,'title':'Fictif','location':'description','version':self.version}],'persistent':False}

class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name)/'ai/runs.db';self.ledger=RunLedger(self.path)
        self.context=Context();self.org=str(uuid.uuid4());self.actor='actor';self.ref={'kind':'case','id':str(uuid.uuid4())};self.effect=lambda:None
        owner=self
        class Provider:
            def complete(self,*a,**k):owner.effect();return 'EXTRAIT_FICTIF_CONFIDENTIEL'
        self.gateway=AIGateway(Provider,self.ledger)
        self.policy={'actor':self.actor,'scope':'fixture-only','provider':'codex-local','ready':True}
        self.service=Assistant(self.gateway,self.context,lambda org:self.policy.copy(),self.actor)
    def tearDown(self):self.ledger.close();self.tmp.cleanup()
    def generate(self):
        rid=str(uuid.uuid4());self.service.generate('session',self.org,rid,[self.ref]);return rid
    def test_history_encrypted_and_persisted(self):
        rid=self.generate();self.assertNotIn(b'EXTRAIT_FICTIF_CONFIDENTIEL',self.path.read_bytes())
        self.assertNotIn(self.ref['id'].encode(),self.path.read_bytes())
        other=RunLedger(self.path);self.assertEqual(other.history.read(self.org,self.actor,rid)['response']['text'],'EXTRAIT_FICTIF_CONFIDENTIEL');other.close()
    def test_no_cross_actor_or_org_history(self):
        rid=self.generate()
        for org,actor in [('other',self.actor),(self.org,'other')]:
            self.assertEqual(self.ledger.history.rows(org,actor),[])
            with self.assertRaises(Denied):self.ledger.history.read(org,actor,rid)
    def test_revoke_removes_list_and_read_and_memory(self):
        rid=self.generate();self.service.change(self.org,{'action':'remember','id':rid,'version':1,'enabled':True});self.context.allowed=False
        result=self.service.list(self.org);self.assertEqual(result['items'],[]);self.assertEqual(result['memories'],[])
        with self.assertRaises(Denied):self.service.read(self.org,rid)
    def test_version_change_blocks_old_response(self):
        rid=self.generate();self.context.version=2
        with self.assertRaises(Denied):self.service.read(self.org,rid)
    def test_certificate_revoked_blocks_history(self):
        rid=self.generate();self.context.certified=False
        with self.assertRaises(Denied):self.service.read(self.org,rid)
    def test_memory_requires_explicit_optin(self):
        rid=self.generate();self.service.change(self.org,{'action':'remember','id':rid,'version':1,'enabled':True})
        self.assertEqual(self.ledger.history.signature(self.org,self.actor)[1],[])
        self.ledger.history.configure(self.org,self.actor,True,0)
        self.assertEqual(self.ledger.history.signature(self.org,self.actor)[1],[(rid,2)])
    def test_revoked_memory_blocks_generation_not_silently_dropped(self):
        rid=self.generate();self.service.change(self.org,{'action':'remember','id':rid,'version':1,'enabled':True});self.ledger.history.configure(self.org,self.actor,True,0)
        self.context.allowed=False
        with self.assertRaises(Denied):self.generate()
        self.assertEqual(len(self.ledger.history.rows(self.org,self.actor)),1)
    def test_memory_disabled_midcall_discards_response(self):
        self.ledger.history.configure(self.org,self.actor,True,0)
        self.effect=lambda:self.ledger.history.configure(self.org,self.actor,False,1)
        with self.assertRaises(Denied):self.generate()
        self.assertEqual(self.ledger.history.rows(self.org,self.actor),[])
    def test_remembered_version_changed_midcall_discards_response(self):
        rid=self.generate();self.service.change(self.org,{'action':'remember','id':rid,'version':1,'enabled':True});self.ledger.history.configure(self.org,self.actor,True,0)
        self.effect=lambda:self.ledger.history.change(self.org,self.actor,rid,2,'remember',False)
        with self.assertRaises(Denied):self.generate()
        self.assertEqual(len(self.ledger.history.rows(self.org,self.actor)),1)
    def test_archive_retains_ciphertext_and_disables_memory(self):
        rid=self.generate();self.service.change(self.org,{'action':'remember','id':rid,'version':1,'enabled':True});self.service.change(self.org,{'action':'archive','id':rid,'version':2})
        self.assertEqual(self.service.list(self.org)['items'],[])
        r=self.ledger.db.execute('SELECT archived,remembered,length(payload) FROM responses').fetchone();self.assertEqual(tuple(r)[:2],(1,0));self.assertGreater(r[2],20)
    def test_stale_mutation_rejected(self):
        rid=self.generate();self.service.change(self.org,{'action':'remember','id':rid,'version':1,'enabled':True})
        with self.assertRaises(Denied):self.service.change(self.org,{'action':'archive','id':rid,'version':1})
    def test_invalid_preference_types(self):
        for enabled,version in [(1,0),(True,True),(None,0),(True,-1)]:
            with self.assertRaises(Denied):self.ledger.history.configure(self.org,self.actor,enabled,version)
    def test_response_save_and_success_are_atomic(self):
        self.ledger.history.seal=lambda *a:(_ for _ in ()).throw(RuntimeError('disk/cipher failure'))
        with self.assertRaises(RuntimeError):self.generate()
        self.assertEqual(self.ledger.history.rows(self.org,self.actor),[])
        self.assertEqual(self.ledger.status(self.org,self.actor)['runs'][0]['state'],'uncertain')
    def test_ciphertext_swapping_fails_closed(self):
        one=self.generate();two=self.generate();payload=self.ledger.db.execute('SELECT payload FROM responses WHERE id=?',(one,)).fetchone()[0]
        self.ledger.db.execute('UPDATE responses SET payload=? WHERE id=?',(payload,two))
        with self.assertRaises(Exception):self.service.read(self.org,two)
    def test_missing_key_never_replaced(self):
        self.generate();key=self.path.with_suffix('.history.key');key.rename(key.with_suffix('.saved'))
        with self.assertRaises(RuntimeError):RunLedger(self.path)
        self.assertFalse(key.exists())
    def test_memory_limit(self):
        for _ in range(8):
            rid=self.generate();self.service.change(self.org,{'action':'remember','id':rid,'version':1,'enabled':True})
        rid=self.generate()
        with self.assertRaises(Denied):self.service.change(self.org,{'action':'remember','id':rid,'version':1,'enabled':True})
    def test_success_duplicate_never_adds_history(self):
        rid=self.generate()
        with self.assertRaises(Denied):self.service.generate('newsession',self.org,rid,[self.ref])
        self.assertEqual(len(self.service.list(self.org)['items']),1)
    def test_v1_migration_preserves_ledger(self):
        p=Path(self.tmp.name)/'old.sqlite3'
        with sqlite3.connect(p) as db:db.executescript(Path('uniion/adapters/ai_runs_v1.sql').read_text())
        p.chmod(0o600);other=RunLedger(p);self.assertEqual(other.db.execute('PRAGMA user_version').fetchone()[0],2);other.close()

    def test_archived_during_source_check_is_not_returned(self):
        rid=self.generate();original=self.context.recipe
        def change(org,sources):
            original(org,sources);self.ledger.history.change(self.org,self.actor,rid,1,'archive')
        self.context.recipe=change
        with self.assertRaises(Denied):self.service.read(self.org,rid)

    def test_encrypted_backup_restores_with_original_key(self):
        import shutil
        rid=self.generate();backup=Path(self.tmp.name)/'restore/runs.db';backup.parent.mkdir(mode=0o700)
        with sqlite3.connect(backup) as target:self.ledger.db.backup(target)
        backup.chmod(0o600);shutil.copyfile(self.path.with_suffix('.history.key'),backup.with_suffix('.history.key'));backup.with_suffix('.history.key').chmod(0o600)
        restored=RunLedger(backup)
        self.assertEqual(restored.history.read(self.org,self.actor,rid)['response']['text'],'EXTRAIT_FICTIF_CONFIDENTIEL')
        with self.assertRaises(Denied):restored.reserve(self.org,self.actor,rid,'different')
        restored.close()

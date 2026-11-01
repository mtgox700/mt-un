import multiprocessing
import tempfile
import unittest
from pathlib import Path
from uniion.adapters.ai_runs import RunLedger
from uniion.adapters.ai_gateway import AIGateway
from uniion.core.contracts import Denied,Unavailable
from uniion.adapters.sessions import RateLimited
import uuid

def reserve_process(path,rid,queue):
    ledger=RunLedger(path,daily=1,concurrent=2)
    try:ledger.reserve('org','actor',rid,'hash');queue.put('reserved')
    except RateLimited:queue.put('limited')
    finally:ledger.close()

def crash_process(path,dispatched):
    import os
    ledger=RunLedger(path,clock=lambda:1000000)
    owner=ledger.reserve('o','a','r','hash')
    if dispatched:ledger.start('o','a','r',owner)
    os._exit(0)

class LedgerTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name)/'ai/runs.db';self.now=1000000
        self.l=RunLedger(self.path,clock=lambda:self.now)
    def tearDown(self):self.l.close();self.tmp.cleanup()
    def reserve(self):return self.l.reserve('o','a','r','hash')
    def test_restart_retains_id_and_counter(self):
        owner=self.reserve();self.l.start('o','a','r',owner);self.l.finish('o','a','r',owner,'succeeded')
        other=RunLedger(self.path,clock=lambda:self.now)
        with self.assertRaises(Denied):other.reserve('o','a','r','different')
        self.assertEqual(other.status('o','a')['reservedOrDispatched'],1)
        self.assertEqual(other.status('o','a')['runs'][0]['state'],'succeeded');other.close()
    def test_processes_atomically_reserve_last_unit(self):
        ctx=multiprocessing.get_context('spawn');queue=ctx.Queue()
        workers=[ctx.Process(target=reserve_process,args=(str(self.path),str(i),queue)) for i in range(6)]
        for w in workers:w.start()
        for w in workers:w.join(15);self.assertEqual(w.exitcode,0)
        self.assertEqual(sorted(queue.get(timeout=2) for _ in workers),['limited']*5+['reserved'])
    def test_global_connector_concurrency_spans_organizations(self):
        self.l.reserve('one','a','1','h');self.l.reserve('two','b','2','h')
        with self.assertRaises(RateLimited):self.l.reserve('three','c','3','h')
    def test_pending_crash_releases_reservation_without_retry(self):
        self.reserve();self.now+=181;s=self.l.status('o','a')
        self.assertEqual(s['runs'][0]['state'],'failed');self.assertEqual(s['remaining'],100)
        with self.assertRaises(Denied):self.reserve()
    def test_dispatched_crash_is_uncertain_and_charged(self):
        owner=self.reserve();self.l.start('o','a','r',owner);self.now+=181
        s=self.l.status('o','a');self.assertEqual(s['runs'][0]['state'],'uncertain');self.assertEqual(s['remaining'],99)
        self.assertEqual(self.l.finish('o','a','r',owner,'succeeded'),'uncertain')
    def test_pre_cancel_survives_restart(self):
        self.l.cancel('o','a','r');other=RunLedger(self.path)
        with self.assertRaises(Denied):other.reserve('o','a','r','h')
        other.close();self.assertEqual(self.l.status('o','a')['remaining'],100)
    def test_cancel_running_keeps_slot_until_worker_stops(self):
        owner=self.reserve();self.l.start('o','a','r',owner);self.l.cancel('o','a','r')
        self.assertFalse(self.l.live('o','a','r',owner));self.assertEqual(self.l.status('o','a')['remaining'],99)
        self.assertEqual(self.l.db.execute('SELECT held FROM runs').fetchone()[0],1)
        self.assertEqual(self.l.finish('o','a','r',owner,'succeeded'),'cancelled')
        self.assertEqual(self.l.db.execute('SELECT held FROM runs').fetchone()[0],0)
    def test_scope_and_owner_cannot_be_forged(self):
        owner=self.reserve()
        for org,actor in [('o','other'),('other','a')]:self.assertEqual(self.l.status(org,actor)['runs'],[])
        with self.assertRaises(Denied):self.l.start('o','a','r','forged')
        self.l.cancel('o','other','r');self.assertTrue(self.l.live('o','a','r',owner))
    def test_terminal_transitions_are_immutable(self):
        owner=self.reserve();self.l.start('o','a','r',owner);self.l.finish('o','a','r',owner,'succeeded');self.l.cancel('o','a','r')
        self.assertEqual(self.l.finish('o','a','r',owner,'failed'),'succeeded')
    def test_day_rollover_does_not_reset_idempotency(self):
        owner=self.reserve();self.l.start('o','a','r',owner);self.l.finish('o','a','r',owner,'uncertain');self.now+=86400
        self.assertEqual(self.l.status('o','a')['remaining'],100)
        with self.assertRaises(Denied):self.reserve()
    def test_schema_and_private_permissions(self):
        self.assertEqual(self.path.stat().st_mode&0o777,0o600)
        self.assertEqual(self.path.parent.stat().st_mode&0o777,0o700)
        self.assertEqual(self.l.db.execute('PRAGMA user_version').fetchone()[0],2)
    def test_pre_send_failure_refunds(self):
        owner=self.reserve();self.l.finish('o','a','r',owner,'failed');self.assertEqual(self.l.status('o','a')['remaining'],100)
    def test_unknown_cost_never_zero(self):
        s=self.l.status('o','a');self.assertIsNone(s['usage']);self.assertIsNone(s['cost'])
    def test_backup_restore_retains_terminal_tombstones(self):
        import sqlite3
        self.l.cancel('o','a','r');copy=Path(self.tmp.name)/'backup.sqlite3'
        with sqlite3.connect(copy) as target:self.l.db.backup(target)
        copy.chmod(0o600);restored=RunLedger(copy)
        with self.assertRaises(Denied):restored.reserve('o','a','r','h')
        restored.close()
    def test_gateway_recreated_never_resends(self):
        calls=[]
        class Provider:
            def complete(self,*a,**k):calls.append(1);return 'Fixture only'
        policy=lambda org:{'actor':'actor','scope':'fixture-only','provider':'codex-local','ready':True}
        data={'organization_id':str(uuid.uuid4()),'request_id':str(uuid.uuid4()),'fixture':'connection'}
        g=AIGateway(Provider,self.l);g.generate('sid',data,policy)
        other=RunLedger(self.path,clock=lambda:self.now)
        with self.assertRaises(Denied):AIGateway(Provider,other).generate('new-sid',data,policy)
        self.assertEqual(len(calls),1);other.close()
    def test_gateway_timeout_uncertain_no_refund(self):
        class Provider:
            def complete(self,*a,**k):raise Unavailable('timeout')
        data={'organization_id':str(uuid.uuid4()),'request_id':str(uuid.uuid4()),'fixture':'connection'}
        g=AIGateway(Provider,self.l)
        with self.assertRaises(Unavailable):g.generate('sid',data,lambda org:{'actor':'a','scope':'fixture-only','provider':'codex-local','ready':True})
        status=self.l.status(data['organization_id'],'a');self.assertEqual(status['runs'][0]['state'],'uncertain');self.assertEqual(status['remaining'],99)

    def test_process_exit_after_dispatch_preserves_uncertainty(self):
        worker=multiprocessing.get_context('spawn').Process(target=crash_process,args=(str(self.path),True))
        worker.start();worker.join(10);self.assertEqual(worker.exitcode,0)
        self.now+=181;s=self.l.status('o','a')
        self.assertEqual(s['runs'][0]['state'],'uncertain');self.assertEqual(s['remaining'],99)
        with self.assertRaises(Denied):self.reserve()
    def test_process_exit_before_dispatch_releases_only_quota(self):
        worker=multiprocessing.get_context('spawn').Process(target=crash_process,args=(str(self.path),False))
        worker.start();worker.join(10);self.assertEqual(worker.exitcode,0)
        self.now+=181;s=self.l.status('o','a')
        self.assertEqual(s['runs'][0]['state'],'failed');self.assertEqual(s['remaining'],100)
        with self.assertRaises(Denied):self.reserve()

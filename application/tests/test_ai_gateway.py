import threading
import unittest
import uuid
from uniion.adapters.ai_gateway import AIGateway
from uniion.core.contracts import Denied, Unavailable
class Provider:
    def __init__(self): self.calls=0; self.effect=lambda:None
    def complete(self, question, sources, cancelled):
        self.calls+=1;self.effect();return 'Fictif'
class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.provider=Provider();self.gateway=AIGateway(lambda:self.provider)
        self.data={'organization_id':str(uuid.uuid4()),'request_id':str(uuid.uuid4()),'fixture':'connection'}
        self.policy={'actor':'a','scope':'fixture-only','provider':'codex-local','ready':True,'version':1}
    def run_call(self): return self.gateway.generate('session',self.data,lambda org:self.policy.copy())
    def test_success_has_no_invented_usage(self):
        r=self.run_call();self.assertIsNone(r['usage']);self.assertIsNone(r['cost'])
    def test_client_text_rejected(self):
        self.data['question']='secret'
        with self.assertRaises(Denied):self.run_call()
        self.assertEqual(self.provider.calls,0)
    def test_replay_never_regenerates(self):
        self.run_call()
        with self.assertRaises(Denied):self.run_call()
        self.assertEqual(self.provider.calls,1)
    def test_provider_change_discards_output(self):
        self.provider.effect=lambda:self.policy.update(version=2)
        with self.assertRaises(Denied):self.run_call()
    def test_cancellation_discards_output(self):
        self.provider.effect=lambda:self.gateway.cancel('session',self.data['organization_id'],self.data['request_id'])
        with self.assertRaises(Denied):self.run_call()
    def test_other_session_cannot_cancel(self):
        self.provider.effect=lambda:self.gateway.cancel('other',self.data['organization_id'],self.data['request_id'])
        self.assertEqual(self.run_call()['text'],'Fictif')
    def test_provider_not_ready_never_called(self):
        self.policy['ready']=False
        with self.assertRaises(Denied):self.run_call()
        self.assertEqual(self.provider.calls,0)
    def test_failure_releases_slot_but_no_retry(self):
        def fail():raise Unavailable()
        self.provider.effect=fail
        with self.assertRaises(Unavailable):self.run_call()
        self.assertFalse(self.gateway.active)
        with self.assertRaises(Denied):self.run_call()
    def test_concurrent_same_id(self):
        started=threading.Event();finish=threading.Event()
        self.provider.effect=lambda:(started.set(),finish.wait(3))
        worker=threading.Thread(target=self.run_call);worker.start();self.assertTrue(started.wait(2))
        try:
            with self.assertRaises(Denied):self.run_call()
        finally:finish.set();worker.join()
        self.assertEqual(self.provider.calls,1)

    def test_cancellation_arriving_before_generate(self):
        self.gateway.cancel('session',self.data['organization_id'],self.data['request_id'])
        with self.assertRaises(Denied):self.run_call()
        self.assertEqual(self.provider.calls,0)

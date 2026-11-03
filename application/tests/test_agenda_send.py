import threading,time,unittest
from unittest import mock
from uuid import UUID
from uniion.adapters import agenda
from uniion.core.contracts import Denied
ORG=str(UUID(int=1));EVENT=str(UUID(int=2));CONV=str(UUID(int=3))
class FakeApi:
    def __init__(self,people,refuse=()):
        self.people=people;self.refuse=set(refuse);self.finished={};self.lock=threading.Lock()
    def request(self,path,token,body):
        action=body['p_action'];payload=body['p_payload']
        if action=='prepare':return {'deliveries':[{'user':u,'email':u+'@example.invalid'} for u in self.people],'subject':'Convocation','body':'Texte','replayed':False}
        if action=='check':
            if payload['user'] in self.refuse:raise Denied()
            return {}
        if action=='finish':
            with self.lock:self.finished[payload['user']]=payload['ok']
            return {}
        raise AssertionError(action)
def run(api):
    return agenda.workflow(api,'jeton',{'organization_id':ORG,'event_id':EVENT,'action':'prepare','payload':{'id':CONV,'version':1,'people':api.people,'subject':'s','body':'b'}},send=True)
class ConvocationSendTests(unittest.TestCase):
    def test_contract_and_counts(self):
        api=FakeApi(['a','b','c']);outcome={'a':True,'b':False,'c':True}
        with mock.patch.object(agenda,'send_mail',lambda m:outcome[m['To'][0]['Email'].split('@')[0]]):
            result=run(api)
        self.assertEqual(result,{'sent':2,'uncertain':1,'replayed':False})
        self.assertEqual(api.finished,outcome)
    def test_bounded_parallel_delivery(self):
        # R24 : 20 envois de 0,2 s ne doivent pas prendre 4 s, ni ouvrir plus de SEND_WORKERS connexions.
        api=FakeApi([str(i) for i in range(20)]);active=[0];peak=[0];guard=threading.Lock()
        def slow(message):
            with guard:active[0]+=1;peak[0]=max(peak[0],active[0])
            time.sleep(0.2)
            with guard:active[0]-=1
            return True
        with mock.patch.object(agenda,'send_mail',slow):
            started=time.monotonic();result=run(api);elapsed=time.monotonic()-started
        self.assertEqual(result['sent'],20);self.assertLessEqual(peak[0],agenda.SEND_WORKERS);self.assertGreater(peak[0],1)
        self.assertLess(elapsed,2.0)
    def test_refused_recipient_is_not_sent_and_fails_request(self):
        api=FakeApi(['a','b','c'],refuse=['b']);mailed=[]
        with mock.patch.object(agenda,'send_mail',lambda m:mailed.append(m['To'][0]['Email']) or True):
            with self.assertRaises(Denied):run(api)
        self.assertNotIn('b@example.invalid',mailed);self.assertNotIn('b',api.finished)
    def test_replay_sends_nothing(self):
        api=FakeApi([]);api.request=lambda p,t,b:{'deliveries':[],'subject':'s','body':'b','replayed':True}
        with mock.patch.object(agenda,'send_mail',lambda m:self.fail('aucun envoi attendu')):
            self.assertEqual(run(api),{'sent':0,'uncertain':0,'replayed':True})

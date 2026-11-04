import unittest
from uniion.adapters.sessions import SessionStore,RateLimited
from uniion.adapters.supabase_transport import AccessDenied
FACTOR='00000000-0000-4000-8000-0000000000f1'
class Api:
    def __init__(self):self.verifications=0;self.good='123456'
    def request(self,path,token=None,body=None,method=None):
        if path=='/auth/v1/user':return {'id':'00000000-0000-4000-8000-000000000001','factors':[{'id':FACTOR,'status':'verified','factor_type':'totp'}]}
        if path.endswith('uniion_session_status'):return {'active':True,'aal':'aal1','required':True,'allowed':False}
        if path.endswith('/challenge'):return {'id':'chal'}
        if path.endswith('/verify'):
            self.verifications+=1
            if body['code']!=self.good:raise AccessDenied()
            return {'access_token':'aal2','refresh_token':'r','expires_at':10**10}
        if path.endswith('uniion_require_mfa'):return {}
        raise AssertionError(path)
class MfaFailureTests(unittest.TestCase):
    def setUp(self):
        self.now=[1000.0];self.api=Api();self.store=SessionStore(self.api,clock=lambda:self.now[0])
        self.sid,self.s=self.store.find('',create=True)
        self.s.update(access_token='aal1',refresh_token='r',expires_at=10**10,end=10**10,idle=10**9)
    def attempt(self,code):
        self.store.post('/auth/mfa/challenge',self.sid,self.s,{'factor_id':FACTOR},'ip')
        return self.store.post('/auth/mfa/verify',self.sid,self.s,{'factor_id':FACTOR,'challenge_id':'chal','code':code},'ip')
    def test_ten_failures_lock_verification_for_an_hour(self):
        # R4 : au-delà de 10 échecs en une heure, plus aucun code n'est soumis, même le bon.
        for i in range(10):
            self.now[0]+=61
            with self.assertRaises(AccessDenied):self.attempt('000000')
        self.now[0]+=61
        with self.assertRaises(RateLimited):self.attempt('123456')
        self.assertEqual(self.api.verifications,10)
        self.now[0]+=3600
        self.sid,_=self.attempt('123456')
    def test_failures_survive_minute_window_pruning(self):
        for i in range(5):
            self.now[0]+=300
            with self.assertRaises(AccessDenied):self.attempt('000000')
        self.assertEqual(len(self.store.attempts['mfa-fail:00000000-0000-4000-8000-000000000001']),5)

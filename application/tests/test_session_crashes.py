"""Abrupt exits are confined to child processes and synthetic session state."""
import unittest,tempfile,pathlib,subprocess,sys,os,json
from uniion.adapters.durable_sessions import DurableSessionStore
from uniion.adapters.supabase_transport import AccessDenied
CHILD=r'''
import sys,os
from uniion.adapters.durable_sessions import DurableSessionStore
from uniion.adapters.supabase_transport import AccessDenied
path,key,sid,mode,marker=sys.argv[1:]
class Api:
 def logout(self,token,scope='local'):
  if mode in ('logout-after','global-after'):open(marker,'w').write('provider-completed')
  os._exit(71)
 def request(self,path,token=None,body=None,method=None):
  if mode=='password-during' and path=='/auth/v1/user' and method=='PUT':
   open(marker,'w').write('password-updated');os._exit(78)
  if mode=='mfa-during' and path.endswith('/verify'):
   open(marker,'w').write('factor-verified');os._exit(77)
  if 'grant_type=refresh_token' in path:
   if mode=='refresh-before-save':
    open(marker,'w').write('provider-rotated');os._exit(72)
   return {'access_token':'new-access','refresh_token':'new-refresh','expires_at':3000}
  if path=='/auth/v1/user':
   if mode=='refresh-after-save':os._exit(73)
   return {'id':'owner','factors':[{'id':'00000000-0000-4000-8000-000000000001','status':'verified','factor_type':'totp'}]}
  if path.endswith('uniion_session_status'):return {'active':True,'allowed':mode!='mfa-during','required':mode=='mfa-during','aal':'aal1'}
  raise RuntimeError('Unexpected child request')
s=DurableSessionStore(Api(),path,key,clock=lambda:1000)
with s.lock:
 row=s.sessions[sid]
 if mode.startswith('refresh'):s.authenticate(row)
 elif mode=='password-during':s.post('/auth/password',sid,row,{'password':'fictional-new-password'},'local')
 elif mode=='mfa-during':s.post('/auth/mfa/verify',sid,row,{'factor_id':'00000000-0000-4000-8000-000000000001','challenge_id':'fixture-challenge','code':'123456'},'local')
 else:s.revoke(row,scope='global' if mode=='global-after' else 'local')
'''
class Api:
 def __init__(self,marker):self.marker=marker
 def logout(self,token,scope='local'):
  if self.marker.exists():raise AccessDenied()
 def request(self,path,token=None,body=None):
  if 'refresh_token' in path:raise AccessDenied()
  if path.endswith('uniion_session_status'):return {'active':False}
  return {'id':'owner'}
class CrashTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.temp.name);self.now=1000;self.marker=self.root/'provider';self.api=Api(self.marker)
 def tearDown(self):self.temp.cleanup()
 def store(self):return DurableSessionStore(self.api,self.root/'db/state.sqlite3',self.root/'key/session.key',clock=lambda:self.now)
 def seed(self,expired=False,user='owner'):
  s=self.store()
  with s.lock:
   sid,row=s.find('',True);row.update(access_token='old-access',refresh_token='old-refresh',expires_at=0 if expired else 2000,user_id=user,recovery_until=2000,challenge={'factor':'00000000-0000-4000-8000-000000000001','id':'fixture-challenge','end':2000})
  return sid
 def crash(self,sid,mode):
  env={**os.environ,'PYTHONPATH':str(pathlib.Path(__file__).resolve().parents[1])}
  result=subprocess.run([sys.executable,'-B','-c',CHILD,str(self.root/'db/state.sqlite3'),str(self.root/'key/session.key'),sid,mode,str(self.marker)],env=env,capture_output=True,timeout=20)
  self.assertIn(result.returncode,(71,72,73,77,78))
 def test_logout_crash_before_provider_does_not_resurrect(self):
  sid=self.seed();self.crash(sid,'logout-before');s=self.store()
  with s.lock:self.assertNotIn(sid,s.sessions);self.assertEqual(len(s.pending),1)
 def test_logout_crash_after_provider_is_reconciled(self):
  sid=self.seed();self.crash(sid,'logout-after');self.now+=31;s=self.store();s.maintain()
  with s.lock:self.assertNotIn(sid,s.sessions);self.assertFalse(s.pending)
 def test_refresh_rotated_but_not_saved_closes_session(self):
  sid=self.seed(True);self.crash(sid,'refresh-before-save');s=self.store()
  with s.lock:self.assertNotIn(sid,s.sessions);self.assertEqual(len(s.pending),1)
  self.assertTrue(self.marker.exists())
 def test_refresh_saved_before_later_crash_survives(self):
  sid=self.seed(True);self.crash(sid,'refresh-after-save');s=self.store()
  with s.lock:
   self.assertEqual(s.sessions[sid]['refresh_token'],'new-refresh');self.assertNotIn('refresh_in_flight',s.sessions[sid])
 def test_uncertain_global_revocation_keeps_work_and_closes_all_local(self):
  sid=self.seed();other=self.seed();unrelated=self.seed(user='other');self.crash(sid,'global-after');self.now+=31;s=self.store();s.maintain()
  with s.lock:
   self.assertNotIn(sid,s.sessions);self.assertNotIn(other,s.sessions);self.assertIn(unrelated,s.sessions);self.assertEqual(len(s.pending),1)
   self.assertEqual(next(iter(s.pending.values()))['scope'],'global')
 def test_expired_global_credentials_not_mistaken_for_global_success(self):
  s=self.store();sid=self.seed(expired=True)
  with s.lock:
   with self.assertRaises(AccessDenied):s.revoke(s.sessions[sid],scope='global')
  self.now+=31;s=self.store();s.maintain()
  with s.lock:self.assertEqual(len(s.pending),1);self.assertNotIn(sid,s.sessions)

 def test_crash_during_mfa_verification_closes_old_cookie(self):
  sid=self.seed();self.crash(sid,'mfa-during');s=self.store()
  with s.lock:self.assertNotIn(sid,s.sessions);self.assertEqual(len(s.pending),1)
 def test_crash_during_password_change_preserves_global_intent(self):
  sid=self.seed();other=self.seed();self.crash(sid,'password-during');s=self.store()
  with s.lock:
   self.assertNotIn(sid,s.sessions);self.assertNotIn(other,s.sessions);self.assertEqual(next(iter(s.pending.values()))['scope'],'global')

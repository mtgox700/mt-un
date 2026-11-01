import unittest,tempfile,pathlib,sqlite3,threading
from uniion.adapters.durable_sessions import DurableSessionStore
from uniion.adapters.supabase_transport import SupabaseUnavailable
class Api:
 def __init__(self):self.down=False;self.revoked=[]
 def logout(self,token,scope='local'):
  if self.down:raise SupabaseUnavailable()
  self.revoked.append((token,scope))
class DurableTests(unittest.TestCase):
 def setUp(self):self.temp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.temp.name);self.api=Api();self.now=1000
 def tearDown(self):self.temp.cleanup()
 def store(self,key=None):return DurableSessionStore(self.api,self.root/'db/state.sqlite3',key or self.root/'keys/session.key',clock=lambda:self.now)
 def fill(self,s):
  with s.lock:
   sid,row=s.find('',True);row.update(access_token='sensitive-access',refresh_token='sensitive-refresh',expires_at=2000)
  return sid
 def test_restart_retains_session(self):
  sid=self.fill(self.store());s=self.store()
  with s.lock:self.assertEqual(s.find('uniion_s01='+sid)[1]['access_token'],'sensitive-access')
 def test_ciphertext_at_rest(self):
  self.fill(self.store());raw=(self.root/'db/state.sqlite3').read_bytes();self.assertNotIn(b'sensitive-access',raw);self.assertNotIn(b'sensitive-refresh',raw)
 def test_key_and_state_permissions(self):
  self.store()
  for p in [self.root/'db/state.sqlite3',self.root/'keys/session.key']:self.assertEqual(p.stat().st_mode&0o777,0o600)
 def test_wrong_key_fails_closed(self):
  self.fill(self.store());s=self.store(self.root/'other/key')
  with self.assertRaises(Exception):
   with s.lock:pass
 def test_tamper_fails_closed(self):
  s=self.store();self.fill(s)
  with sqlite3.connect(s.path) as db:db.execute('UPDATE state SET payload=?',(b'tampered encrypted state',))
  with self.assertRaises(Exception):
   with s.lock:pass
 def test_logout_survives_restart(self):
  s=self.store();sid=self.fill(s)
  with s.lock:s.post('/auth/logout',sid,s.sessions[sid],{},'local')
  fresh=self.store()
  with fresh.lock:self.assertIsNone(fresh.find('uniion_s01='+sid)[1])
 def test_failed_logout_retried_after_restart(self):
  s=self.store();sid=self.fill(s);self.api.down=True
  with s.lock:
   with self.assertRaises(SupabaseUnavailable):s.post('/auth/logout',sid,s.sessions[sid],{},'local')
   self.assertNotIn(sid,s.sessions);self.assertEqual(len(s.pending),1)
  self.api.down=False;self.now+=31;fresh=self.store();fresh.maintain()
  with fresh.lock:self.assertFalse(fresh.pending);self.assertNotIn(sid,fresh.sessions)
  self.assertEqual(self.api.revoked,[('sensitive-access','local')])
 def test_global_revocation_scope_persisted(self):
  s=self.store();sid=self.fill(s);self.api.down=True
  with s.lock:
   with self.assertRaises(SupabaseUnavailable):s.revoke(s.sessions[sid],scope='global')
   s.sessions.pop(sid,None)
  self.api.down=False;self.now+=31;self.store().maintain();self.assertEqual(self.api.revoked,[('sensitive-access','global')])
 def test_idle_expiry_persists(self):
  s=self.store();sid=self.fill(s);self.now+=601;s.maintain();fresh=self.store()
  with fresh.lock:self.assertNotIn(sid,fresh.sessions)
 def test_rate_limit_shared(self):
  s=self.store()
  with s.lock:s.limit('account',1)
  fresh=self.store()
  from uniion.adapters.sessions import RateLimited
  with fresh.lock:
   with self.assertRaises(RateLimited):fresh.limit('account',1)
 def test_two_instances_serialize_updates(self):
  s=self.store();self.fill(s);other=self.store();errors=[]
  def work(store):
   try:
    for _ in range(10):
     with store.lock:store.attempts.setdefault('counter',[]).append(1000)
   except Exception as exc:errors.append(type(exc).__name__)
  ts=[threading.Thread(target=work,args=(x,)) for x in (s,other)]
  for t in ts:t.start()
  for t in ts:t.join()
  self.assertFalse(errors)
  with s.lock:self.assertEqual(len(s.attempts['counter']),20)
 def test_transaction_rollback(self):
  s=self.store();self.fill(s)
  with self.assertRaises(RuntimeError):
   with s.lock:s.sessions.clear();raise RuntimeError('fixture')
  with s.lock:self.assertEqual(len(s.sessions),1)
 def test_separate_processes_share_transaction_lock(self):
  import subprocess,sys,os
  s=self.store();self.fill(s)
  code="from uniion.adapters.durable_sessions import DurableSessionStore;import sys;s=DurableSessionStore(None,sys.argv[1],sys.argv[2]);\nfor i in range(20):\n with s.lock:s.attempts.setdefault('process_counter',[]).append(i)"
  env={**os.environ,'PYTHONPATH':str(pathlib.Path(__file__).resolve().parents[1])}
  ps=[subprocess.Popen([sys.executable,'-B','-c',code,str(s.path),str(self.root/'keys/session.key')],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE) for _ in range(2)]
  for p in ps:
   p.communicate(timeout=20);self.assertEqual(p.returncode,0)
  with s.lock:self.assertEqual(len(s.attempts['process_counter']),40)
 def test_expiration_batch_never_calls_provider_inline(self):
  s=self.store()
  with s.lock:
   for i in range(100):
    _,row=s.find('',True);row.update(access_token='fake-access',refresh_token='fake-refresh',expires_at=3000)
  self.now=2000
  def forbidden(*args,**kwargs):raise AssertionError('Network call during expiration batch')
  self.api.logout=forbidden
  with s.lock:s.find('',False);self.assertFalse(s.sessions);self.assertEqual(len(s.pending),100)
if __name__=='__main__':unittest.main()

import unittest,pathlib,tempfile,sys,json,fcntl
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'operations'))
from session_watchdog import tick
class WatchdogTests(unittest.TestCase):
 def setUp(self):self.tmp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.tmp.name);self.health=self.root/'health';self.state=self.root/'state';self.notifications=[]
 def tearDown(self):self.tmp.cleanup()
 def put(self,**data):self.health.write_text(json.dumps({'ok':True,'checked_at':1000,'pending_revocations':0,'oldest_pending_seconds':0,**data}))
 def run_tick(self):return tick(self.health,self.state,lambda kind:self.notifications.append(kind) or True,now=1030)
 def test_healthy_silent(self):
  self.put();self.assertFalse(self.run_tick()['changed']);self.assertFalse(self.notifications)
 def test_stale_alert_deduplicated(self):
  self.put(checked_at=500);self.assertTrue(self.run_tick()['changed']);self.assertFalse(self.run_tick()['changed']);self.assertEqual(self.notifications,['alert'])
 def test_recovery_not_old_incident(self):
  self.put(ok=False);self.run_tick();self.put();self.assertEqual(self.run_tick()['issues'],[]);self.assertEqual(self.notifications,['alert','recovery']);self.assertFalse(self.run_tick()['changed'])
 def test_transient_queue_notifies_only_after_delay(self):
  self.put(pending_revocations=1,oldest_pending_seconds=10);self.run_tick();self.assertFalse(self.notifications)
  self.put(pending_revocations=1,oldest_pending_seconds=301);self.run_tick();self.assertEqual(self.notifications,['alert'])
 def test_missing_health_alert(self):self.assertIn('health_unavailable',self.run_tick()['issues'])
 def test_private_persistent_state(self):
  self.put(ok=False);self.run_tick();self.assertEqual((self.state/'state.json').stat().st_mode&0o777,0o600);self.assertFalse(self.run_tick()['changed'])
 def test_concurrent_runner_refused(self):
  self.put();self.run_tick()
  with open(self.state/'runner.lock','a') as lock:
   fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);self.assertEqual(self.run_tick()['status'],'already_running')
 def test_secrets_never_in_events(self):
  self.put(ok=False,secret='sensitive-test-fixture');self.run_tick();self.assertNotIn('sensitive-test-fixture',(self.state/'events.jsonl').read_text())

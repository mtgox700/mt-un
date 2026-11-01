import unittest,tempfile,pathlib,json,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'operations'))
from session_health import monitor
class HealthTests(unittest.TestCase):
 def setUp(self):self.temp=tempfile.TemporaryDirectory();self.path=pathlib.Path(self.temp.name)/'health.json'
 def tearDown(self):self.temp.cleanup()
 def read(self,**changes):
  self.path.write_text(json.dumps({'checked_at':1000,'ok':True,'pending_revocations':0,'oldest_pending_seconds':0,**changes}));return monitor(self.path,now=1030)
 def test_healthy(self):self.assertTrue(self.read()['ok'])
 def test_stale(self):self.assertIn('maintenance_stale',self.read(checked_at=500)['issues'])
 def test_failed(self):self.assertIn('maintenance_failed',self.read(ok=False)['issues'])
 def test_waiting(self):self.assertIn('revocations_pending',self.read(pending_revocations=1,oldest_pending_seconds=20)['issues'])
 def test_delayed(self):self.assertIn('revocations_delayed',self.read(pending_revocations=1,oldest_pending_seconds=500)['issues'])
 def test_missing(self):self.assertIn('health_unavailable',monitor(self.path,now=1030)['issues'])
 def test_no_unexpected_fields(self):self.assertNotIn('secret',self.read(secret='not-for-output'))
 def test_future_clock(self):self.assertIn('clock_inconsistent',self.read(checked_at=2000)['issues'])

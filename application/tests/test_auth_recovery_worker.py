import pathlib,sys,uuid,unittest,tempfile,json,os
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'operations'))
from auth_recovery_worker import run_job,ServerTransport,NoRedirect
class WorkerTests(unittest.TestCase):
 def setUp(self):self.job,self.user,self.factor,self.lease=[str(uuid.uuid4()) for _ in range(4)];self.deleted=[]
 def rpc(self,name,data):
  if name.endswith('claim'):return {'user_id':self.user,'factors':[self.factor],'lease':self.lease}
  if name.endswith('check'):return True
  return {'ok':True}
 def delete(self,user,factor):self.deleted.append((user,factor))
 def test_only_claimed_factor_deleted(self):
  self.assertTrue(run_job(self.job,self.rpc,self.delete)['ok']);self.assertEqual(self.deleted,[(self.user,self.factor)])
 def test_cancelled_before_delete(self):
  def rpc(n,d):return False if n.endswith('check') else self.rpc(n,d)
  with self.assertRaises(RuntimeError):run_job(self.job,rpc,self.delete)
  self.assertFalse(self.deleted)
 def test_unapproved_job_denied(self):
  def rpc(n,d):raise PermissionError()
  with self.assertRaises(PermissionError):run_job(self.job,rpc,self.delete)
  self.assertFalse(self.deleted)
 def test_invalid_identifier_denied(self):
  with self.assertRaises(ValueError):run_job('../users/all',self.rpc,self.delete)
  self.assertFalse(self.deleted)
 def test_provider_failure_cannot_finish(self):
  calls=[]
  def rpc(n,d):calls.append(n);return self.rpc(n,d)
  def delete(u,f):raise RuntimeError('fixture failure')
  with self.assertRaises(RuntimeError):run_job(self.job,rpc,delete)
  self.assertNotIn('uniion_lost_factor_finish',calls)
 def test_configuration_missing_fails_closed(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(RuntimeError):ServerTransport(pathlib.Path(d)/'missing')
 def test_arbitrary_origin_denied(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'config';p.write_text(json.dumps({'supabase_url':'https://untrusted.example','service_key':'fictional-test-key-with-no-privilege'}));p.chmod(0o600)
   with self.assertRaises(RuntimeError):ServerTransport(p)

 def test_privileged_credentials_never_follow_redirect(self):
  self.assertIsNone(NoRedirect().redirect_request(None,None,302,'redirect',{},'https://untrusted.example'))

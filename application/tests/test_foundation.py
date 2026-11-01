import unittest,json
from dataclasses import replace
from uniion.app import create_resource_app as create_app
from uniion.config import Config
from uniion.core.contracts import Manifest,Denied,Principal
from uniion.core.registry import Registry
from uniion.modules.resources.module import ResourceModule
from uniion.adapters.resources import SupabaseResources
from uniion.adapters.supabase_transport import AccessDenied,SupabaseUnavailable
A='10000000-0000-4000-8000-000000000100';B='10000000-0000-4000-8000-000000000200';R='20000000-0000-4000-8000-000000000100'
class Fake:
 def __init__(self):self.member=True;self.rows=[{'id':R,'organization_id':A,'body':{'title':'fictif'}}];self.fail=None
 def user(self,token):
  if token!='valid':raise AccessDenied()
  return {'id':'user'}
 def request(self,path,token,body=None):
  if self.fail:raise self.fail()
  if path.endswith('uniion_context'):return {'organizations':[{'id':A}] if self.member else []}
  return self.rows
class Tests(unittest.TestCase):
 def setUp(self):self.api=Fake();self.config=Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':'http://127.0.0.1:54321'});self.app=create_app(self.config,self.api)
 def call(self,org=A,resource=R,token='valid',method='GET',path=None,extra=None):
  e={'REQUEST_METHOD':method,'PATH_INFO':path or f'/api/organizations/{org}/resources/{resource}','HTTP_AUTHORIZATION':'Bearer '+token,**(extra or {})};response=[]
  raw=b''.join(self.app(e,lambda s,h:response.append((s,dict(h)))))
  return int(response[0][0][:3]),json.loads(raw),response[0][1]
 def test_authorized_read(self):self.assertEqual(self.call()[0],200)
 def test_wrong_org(self):self.assertEqual(self.call(org=B)[0],403)
 def test_invalid_token(self):self.assertEqual(self.call(token='invalid')[0],403)
 def test_anonymous(self):self.assertEqual(self.call(token='')[0],403)
 def test_rls_empty(self):self.api.rows=[];self.assertEqual(self.call()[0],403)
 def test_defensive_cross_tenant_response(self):self.api.rows[0]['organization_id']=B;self.assertEqual(self.call()[0],403)
 def test_defensive_wrong_id(self):self.api.rows[0]['id']=B;self.assertEqual(self.call()[0],403)
 def test_fake_superadmin_header_no_bypass(self):self.assertEqual(self.call(org=B,extra={'HTTP_X_ROLE':'superadmin'})[0],403)
 def test_revocation_no_cache(self):
  self.assertEqual(self.call()[0],200);self.api.member=False;self.assertEqual(self.call()[0],403)
 def test_revocation_between_dispatch_and_read(self):
  port=SupabaseResources(self.api,'valid');p=port.principal(A);self.api.member=False
  with self.assertRaises(Denied):port.read(p,R)
 def test_dependency_outage(self):self.api.fail=SupabaseUnavailable;self.assertEqual(self.call()[0],503)
 def test_no_internal_error_or_token_echo(self):self.api.fail=RuntimeError;self.assertEqual(self.call()[1],{'error':'Service indisponible'})
 def test_no_write_route(self):self.assertEqual(self.call(method='POST')[0],405)
 def test_unknown_route(self):self.assertEqual(self.call(path='/api/admin')[0],404)
 def test_cache_and_token_protection(self):s,b,h=self.call();self.assertEqual(h['Cache-Control'],'no-store');self.assertNotIn('valid',json.dumps(b))
 def test_health_has_no_business_data(self):self.assertFalse(self.call(path='/health')[1]['production_ready'])
 def test_no_implicit_environment(self):
  with self.assertRaises(ValueError):Config.load({})
 def test_no_production_launch(self):
  with self.assertRaises(ValueError):create_app(replace(self.config,environment='production'))
 def test_secret_key_rejected(self):
  with self.assertRaises(ValueError):Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':self.config.supabase_url,'UNIION_SUPABASE_PUBLISHABLE_KEY':'not-allowed'})
 def test_registry_duplicate(self):
  with self.assertRaises(ValueError):Registry((ResourceModule(),ResourceModule()))
 def test_registry_missing_dependency(self):
  m=ResourceModule();m.manifest=replace(m.manifest,dependencies=('missing',))
  with self.assertRaises(ValueError):Registry((m,))
 def test_registry_cycle(self):
  m=ResourceModule();m.manifest=replace(m.manifest,dependencies=('core.resources',))
  with self.assertRaises(ValueError):Registry((m,))
 def test_unknown_command_denied(self):
  with self.assertRaises(Denied):Registry((ResourceModule(),)).execute('admin.read',Principal('x',A),{},None)
 def test_no_client_principal_override(self):
  with self.assertRaises(Denied):ResourceModule().execute('resource.read.v1',Principal('x',A),{'resource_id':R,'organization_id':B},None)
if __name__=='__main__':unittest.main(verbosity=2)

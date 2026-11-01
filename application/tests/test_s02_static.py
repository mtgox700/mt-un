import unittest
from uniion.s02_static import serve
class StaticTests(unittest.TestCase):
 def run_request(self,path,host='127.0.0.1:5060',query=''):
  result=[];body=serve({'PATH_INFO':path,'HTTP_HOST':host,'REQUEST_METHOD':'GET','QUERY_STRING':query},lambda s,h:result.append(s));return result,b''.join(body or [])
 def test_invalid_org(self):self.assertEqual(self.run_request('/s02')[0],['400 Bad Request'])
 def test_host(self):self.assertEqual(self.run_request('/s02','evil')[0],['403 Forbidden'])
 def test_no_arbitrary_file(self):self.assertEqual(self.run_request('/.local-auth/auth-admin.json'),([],b''))
 def test_bridge_before_demo(self):
  status,html=self.run_request('/s02',query='organization=11111111-1111-1111-1111-111111111111');self.assertEqual(status,['200 OK']);self.assertLess(html.index(b'window.uniionS01'),html.index(b'/host/demo.js'))

 def test_reference_logo_served(self):
  status,body=self.run_request('/uniion-logo.png');self.assertEqual(status,['200 OK']);self.assertTrue(body.startswith(b'\x89PNG\r\n\x1a\n'));self.assertEqual(self.run_request('/uniion-logo.png','evil')[0],['403 Forbidden'])

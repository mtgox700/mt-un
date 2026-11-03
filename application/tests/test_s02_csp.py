import re,unittest
from uniion.http_sessions import PORT
from uniion.s02_static import serve
class S02ContentSecurityPolicyTests(unittest.TestCase):
    def page(self,path='/s02'):
        out={}
        def start(status,headers):out['status']=status;out['headers']=dict(headers)
        body=b''.join(serve({'PATH_INFO':path,'REQUEST_METHOD':'GET','HTTP_HOST':'127.0.0.1:'+PORT,'QUERY_STRING':'organization=00000000-0000-4000-8000-000000000001'},start)).decode()
        return out,body
    def test_application_page_has_nonce_csp(self):
        # R43 : seul le pont inline du serveur s'exécute, avec un nonce propre à la réponse.
        out,body=self.page()
        policy=out['headers']['Content-Security-Policy']
        nonce=re.search(r"'nonce-([A-Za-z0-9_-]+)'",policy)[1]
        self.assertIn('<script nonce="'+nonce+'">window.uniionS01',body)
        self.assertNotIn("'unsafe-inline' blob:",policy.split('script-src',1)[1].split(';')[0]+';')
        self.assertNotIn('unsafe-eval',policy)
        for directive in ("object-src 'none'","base-uri 'none'","frame-ancestors 'none'"):self.assertIn(directive,policy)
    def test_nonce_changes_per_response(self):
        a=self.page()[0]['headers']['Content-Security-Policy'];b=self.page()[0]['headers']['Content-Security-Policy']
        self.assertNotEqual(a,b)
    def test_rights_page_also_protected(self):
        self.assertIn('Content-Security-Policy',self.page('/s02/rights')[0]['headers'])

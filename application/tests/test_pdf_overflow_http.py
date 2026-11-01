import io,json,threading,unittest
from uniion.http_sessions import wrap,ORIGIN,PORT
from uniion.core.contracts import PDFOverflow
class Store:
 def __init__(self):self.lock=threading.RLock();self.called=False
 def find(self,*a,**k):return 'fictif',{'csrf':'recette'}
 def post(self,*a):self.called=True;raise PDFOverflow()
class PDFOverflowHTTPTests(unittest.TestCase):
 def call(self,origin):
  store=Store();status=[];app=wrap(None,None,store);raw=b'{}'
  env={'PATH_INFO':'/identity/agenda/work','REQUEST_METHOD':'POST','HTTP_HOST':'127.0.0.1:'+PORT,'HTTP_ORIGIN':origin,'HTTP_X_UNIION_CSRF':'recette','CONTENT_TYPE':'application/json','CONTENT_LENGTH':str(len(raw)),'wsgi.input':io.BytesIO(raw)}
  body=b''.join(app(env,lambda s,h:status.append(s)))
  return status[0],json.loads(body),store.called
 def test_overflow_is_actionable(self):
  status,data,called=self.call(ORIGIN);self.assertTrue(called);self.assertTrue(status.startswith('422'));self.assertEqual(data['code'],'pdf_overflow')
 def test_origin_denial_precedes_layout(self):
  status,data,called=self.call('https://example.invalid');self.assertFalse(called);self.assertTrue(status.startswith('403'));self.assertNotIn('code',data)

import io,json,threading,unittest
from uniion.http_sessions import wrap,ORIGIN,PORT
from uniion.core.contracts import PDFOverflow
class Store:
 def __init__(self):self.lock=threading.RLock();self.called=False
 def find(self,*a,**k):return 'fictif',{'csrf':'recette'}
 def cookie(self,sid):return 'uniion_s01='+sid
 def identity_token(self,s):return 'jeton-fictif'
 def identity_dispatch(self,*a):self.called=True;raise PDFOverflow()
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

class LockReleasedDuringBusinessCall(unittest.TestCase):
 def test_identity_dispatch_runs_without_session_lock(self):
  # R1 : un traitement métier lent ne doit pas bloquer les autres requêtes de session.
  store=Store();seen=[]
  def dispatch(path,token,data):
   other=threading.Thread(target=lambda:seen.append(store.lock.acquire(timeout=1) and (store.lock.release() or True)))
   other.start();other.join();return {'ok':True,'token':token}
  store.identity_dispatch=dispatch;app=wrap(None,None,store);raw=b'{}';status=[]
  env={'PATH_INFO':'/identity/agenda/work','REQUEST_METHOD':'POST','HTTP_HOST':'127.0.0.1:'+PORT,'HTTP_ORIGIN':ORIGIN,'HTTP_X_UNIION_CSRF':'recette','CONTENT_TYPE':'application/json','CONTENT_LENGTH':str(len(raw)),'wsgi.input':io.BytesIO(raw)}
  body=json.loads(b''.join(app(env,lambda s,h:status.append(s))))
  self.assertTrue(status[0].startswith('200'));self.assertEqual(body['token'],'jeton-fictif');self.assertEqual(seen,[True])

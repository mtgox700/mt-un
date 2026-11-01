import io,json,tempfile,time,unittest,uuid
from pathlib import Path
from uniion.app import create_app
from uniion.config import Config
from uniion.adapters.durable_sessions import DurableSessionStore

class API:
    def request(self,path,token=None,body=None):
        if path=='/auth/v1/user':return {'id':'actor'}
        if path=='/rest/v1/rpc/uniion_session_status':return {'allowed':True,'required':True,'active':True}
        if path=='/rest/v1/rpc/uniion_ai_policy':return {'actor':'actor','scope':'fixture-only','provider':'codex-local','ready':True}
        raise AssertionError(path)

class AIHTTPTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();root=Path(self.tmp.name);self.api=API()
        self.store=DurableSessionStore(self.api,root/'state/data.sqlite3',root/'keys/key')
        with self.store.lock:
            self.sid,s=self.store.find('',True);self.csrf=s['csrf'];s.update(access_token='fake',refresh_token='fake',expires_at=time.time()+3600)
        self.app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':'http://127.0.0.1:54321'}),self.api,self.store)
        class Provider:
            def complete(self,*args,**kwargs):return 'Fictif'
        self.app.ai_gateway.provider_factory=Provider
        self.data={'organization_id':str(uuid.uuid4()),'request_id':str(uuid.uuid4()),'fixture':'connection'}
    def tearDown(self):self.tmp.cleanup()
    def call(self,path='/identity/ai/generate',data=None,**extra):
        raw=json.dumps(self.data if data is None else data).encode();r=[]
        e={'REQUEST_METHOD':'POST','PATH_INFO':path,'HTTP_HOST':'127.0.0.1:5060','HTTP_ORIGIN':'http://127.0.0.1:5060','HTTP_COOKIE':'uniion_s01='+self.sid,'HTTP_X_UNIION_CSRF':self.csrf,'CONTENT_TYPE':'application/json','CONTENT_LENGTH':str(len(raw)),'wsgi.input':io.BytesIO(raw),**extra}
        body=b''.join(self.app(e,lambda status,headers:r.append(status)))
        return int(r[0][:3]),json.loads(body)
    def test_durable_session_reload_accepts_same_identity(self):
        status,r=self.call();self.assertEqual(status,200);self.assertEqual(r['text'],'Fictif')
    def test_cancel_before_start_blocks_provider(self):
        self.assertEqual(self.call('/identity/ai/cancel',{k:v for k,v in self.data.items() if k!='fixture'})[0],200)
        self.assertEqual(self.call()[0],403)
    def test_content_type_refused(self):self.assertEqual(self.call(CONTENT_TYPE='text/plain')[0],403)
    def test_foreign_origin_refused(self):self.assertEqual(self.call(HTTP_ORIGIN='https://example.invalid')[0],403)
    def test_oversized_body_refused(self):self.assertEqual(self.call(CONTENT_LENGTH='999999')[0],403)
    def test_cancellation_has_independent_rate_budget(self):
        with self.store.lock:
            for _ in range(10):self.store.limit('ai:actor',10)
        self.assertEqual(self.call()[0],429)
        self.assertEqual(self.call('/identity/ai/cancel',{k:v for k,v in self.data.items() if k!='fixture'})[0],200)

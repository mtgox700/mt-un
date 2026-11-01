import unittest,io,json,time,threading
from uniion.http_sessions import wrap
from uniion.adapters.sessions import SessionStore,RateLimited
from uniion.adapters.supabase_transport import AccessDenied
class Fake:
 def __init__(self):self.revoked=[];self.refreshes=0;self.active=True
 def login(self,email,password):
  if password!='correct':raise AccessDenied()
  return {'access_token':'private-access','refresh_token':'private-refresh','expires_at':time.time()+3600}
 def user(self,token):return {'id':'actor','email':'fixture@example.invalid','factors':[]}
 def logout(self,token):self.revoked.append(token)
 def request(self,path,token=None,body=None,method=None):
  if 'refresh_token' in path:self.refreshes+=1;return self.login('','correct')
  if path.endswith('/user'):return self.user(token)
  if path.endswith('uniion_session_status'):return {'active':self.active,'aal':'aal1','required':False,'allowed':self.active}
  raise AccessDenied()
class Tests(unittest.TestCase):
 def setUp(self):self.api=Fake();self.app=wrap(lambda e,s:[],self.api);self.cookie='';self.csrf='';self.call('/auth/session')
 def call(self,path,data=None,**extra):
  body=json.dumps(data).encode() if data is not None else b'';out=[]
  e={'REQUEST_METHOD':'GET' if data is None else 'POST','PATH_INFO':path,'HTTP_HOST':'127.0.0.1:5060','HTTP_ORIGIN':'http://127.0.0.1:5060','HTTP_COOKIE':self.cookie,'HTTP_X_UNIION_CSRF':self.csrf,'CONTENT_TYPE':'application/json','CONTENT_LENGTH':str(len(body)),'wsgi.input':io.BytesIO(body),'REMOTE_ADDR':'local',**extra}
  raw=b''.join(self.app(e,lambda s,h:out.append((int(s[:3]),dict(h)))));status,headers=out[0];d=json.loads(raw)
  if 'Set-Cookie' in headers:self.cookie=headers['Set-Cookie'].split(';')[0]
  self.csrf=d.get('csrf',self.csrf);return status,d,headers
 def login(self):return self.call('/auth/login',{'email':'fixture@example.invalid','password':'correct'})
 def session(self):return self.app.sessions.sessions[self.cookie.split('=',1)[1]]
 def test_csrf(self):self.assertEqual(self.call('/auth/login',{},HTTP_X_UNIION_CSRF='')[0],403)
 def test_origin(self):self.assertEqual(self.call('/auth/login',{},HTTP_ORIGIN='https://evil.example')[0],403)
 def test_host_logout(self):self.assertEqual(self.call('/auth/logout',{},HTTP_HOST='evil.example')[0],403)
 def test_bearer(self):self.assertEqual(self.call('/auth/session',HTTP_AUTHORIZATION='Bearer anything')[0],403)
 def test_rotation(self):before=self.cookie;self.assertEqual(self.login()[0],200);self.assertNotEqual(before,self.cookie)
 def test_no_tokens(self):self.assertNotIn('private-',json.dumps(self.login()))
 def test_logout(self):self.login();self.assertEqual(self.call('/auth/logout',{})[0],200);self.assertEqual(self.api.revoked,['private-access'])
 def test_logout_after_jwt_expiry(self):
  self.login();self.session()['expires_at']=0;self.assertEqual(self.call('/auth/logout',{})[0],200);self.assertEqual(self.api.refreshes,1);self.assertTrue(self.api.revoked)
 def test_idle_expiry(self):self.login();self.session()['last']=time.time()-1801;self.assertFalse(self.call('/auth/session')[1]['authenticated']);self.assertTrue(self.api.revoked)
 def test_absolute_expiry(self):self.login();self.session()['end']=time.time()-1;self.assertFalse(self.call('/auth/session')[1]['authenticated'])
 def test_remote_revocation(self):
  self.login();old=self.cookie;self.api.active=False
  status,data,_=self.call('/auth/session');self.assertEqual(status,200);self.assertFalse(data['authenticated']);self.assertNotEqual(old,self.cookie)
  self.assertNotIn(old.split('=',1)[1],self.app.sessions.sessions)
  self.assertEqual(self.call('/identity/invitations/send',{'organization_id':'org','email':'fixture@example.invalid'})[0],403)
 def test_refresh(self):self.login();self.session()['expires_at']=0;self.assertEqual(self.call('/auth/session')[0],200);self.assertEqual(self.api.refreshes,1)
 def test_serial_refresh(self):
  self.login();self.session()['expires_at']=0;responses=[]
  threads=[threading.Thread(target=lambda:responses.append(self.call('/auth/session')[0])) for _ in range(5)]
  for t in threads:t.start()
  for t in threads:t.join()
  self.assertEqual(responses,[200]*5);self.assertEqual(self.api.refreshes,1)
 def test_switch_identity(self):self.login();self.assertEqual(self.login()[0],403)
 def test_bad_json(self):self.assertEqual(self.call('/auth/login',{},**{'wsgi.input':io.BytesIO(b'!!')})[0],400)
 def test_large_body(self):self.assertEqual(self.call('/auth/login',{},CONTENT_LENGTH='20000')[0],403)
 def test_content_type(self):self.assertEqual(self.call('/auth/login',{},CONTENT_TYPE='text/plain')[0],403)
 def test_rate_per_account(self):
  for _ in range(10):self.call('/auth/login',{'email':'bad@example.invalid','password':'bad'})
  self.assertEqual(self.call('/auth/login',{'email':'bad@example.invalid','password':'bad'})[0],429);self.assertEqual(self.login()[0],200)
 def test_quota(self):
  store=SessionStore(self.api)
  for _ in range(256):store.find('',True)
  with self.assertRaises(RateLimited):store.find('',True)
 def test_wrong_factor(self):self.login();self.assertEqual(self.call('/auth/mfa/challenge',{'factor_id':'00000000-0000-4000-8000-000000000000'})[0],403)
 def test_foreign_cookie(self):self.login();self.assertFalse(self.call('/auth/session',HTTP_COOKIE='uniion_s01=invented')[1]['authenticated'])
 def test_recovery_window_expired(self):
  self.login();self.session()['recovery_until']=time.time()-1
  self.assertEqual(self.call('/auth/password',{'password':'a-long-fictional-password'})[0],403)
 def test_recovery_cannot_be_used_from_logged_in_session(self):
  self.login();self.assertEqual(self.call('/auth/recovery/verify',{'token_hash':'a'*64})[0],403)
 def test_recovery_request_csrf(self):
  self.assertEqual(self.call('/auth/recovery/request',{'email':'fixture@example.invalid'},HTTP_X_UNIION_CSRF='')[0],403)
 def test_recovery_invalid_email(self):
  self.assertEqual(self.call('/auth/recovery/request',{'email':'invalid'})[0],403)
 def test_password_requires_recovery(self):
  self.login();self.assertEqual(self.call('/auth/password',{'password':'a-long-fictional-password'})[0],403)
 def test_recovery_rate_limit(self):
  for _ in range(3):self.assertEqual(self.call('/auth/recovery/request',{'email':'fixture@example.invalid'})[0],200)
  self.assertEqual(self.call('/auth/recovery/request',{'email':'fixture@example.invalid'})[0],429)
if __name__=='__main__':unittest.main(verbosity=2)

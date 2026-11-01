import unittest,threading,time,json
from uniion.adapters.message_stream import MessageHub
from uniion.core.contracts import Denied
class Store:
 def __init__(self):self.lock=threading.RLock();self.sessions={'s':{'last':12,'access_token':'test'}}
 def find(self,c):
  s=self.sessions.get('s')
  if s:s['last']=99
  return 's',s
 def authenticate(self,s):return {},{'allowed':True}
class API:
 def request(self,*a):return {'cursor':'a'*32,'conversations':[]}
class Streams(unittest.TestCase):
 def setUp(self):self.h=MessageHub();self.s=Store();self.api=API();self.e={'QUERY_STRING':'organization=00000000-0000-0000-0000-000000000001','HTTP_COOKIE':'uniion_s01=s'}
 def open(self):return self.h.stream(self.e,lambda *a:None,self.s,self.api)
 def test_idle_not_extended_and_real_activity_preserved(self):
  it=self.open();next(it);next(it);self.assertEqual(self.s.sessions['s']['last'],12)
  self.s.sessions['s']['last']=45;self.h.wake();next(it);self.assertEqual(self.s.sessions['s']['last'],45);it.close()
 def test_subscription_cap_and_release(self):
  its=[self.open() for _ in range(3)]
  for it in its:next(it)
  with self.assertRaises(Denied):self.open()
  for it in its:it.close()
  self.assertEqual(self.h.active,{})
 def test_cursor_does_not_suppress_reconnect_snapshot(self):
  self.e['HTTP_LAST_EVENT_ID']='a'*32;it=self.open();next(it);self.assertIn(b'event: state',next(it));it.close()
 def test_arbitrary_subscription_rejected(self):
  for suffix in ('&token=secret','&id=wrong','&at=1','&cursor=not-a-cursor','&organization=x'):
   with self.assertRaises(Denied):self.h.stream({**self.e,'QUERY_STRING':self.e['QUERY_STRING']+suffix},lambda *a:None,self.s,self.api)
 def test_session_removed_closes_open_stream(self):
  it=self.open();next(it);next(it);self.s.sessions.clear();self.h.wake();self.assertIn(b'event: revoked',next(it));it.close()
 def test_unrelated_wakeups_emit_no_extra_events(self):
  it=self.open();next(it);next(it);calls=[]
  def wake(v,timeout):
   calls.append(v)
   if len(calls)==3:self.api.request=lambda *a:{'cursor':'b'*32,'conversations':[]}
   return v+1
  self.h.wait=wake
  frame=next(it);self.assertEqual(len(calls),3);self.assertIn(b'event: state',frame);self.assertIn(b'b'*32,frame);it.close()

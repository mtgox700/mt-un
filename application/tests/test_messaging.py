import unittest
from uuid import uuid4
from uniion.adapters.messaging import dispatch
from uniion.core.contracts import Denied
class API:
 def request(self,*args):self.args=args;return {'ok':True}
class MessagingTests(unittest.TestCase):
 def setUp(self):self.api=API();self.org=str(uuid4());self.cid=str(uuid4())
 def call(self,action,payload):return dispatch(self.api,'user-jwt',{'organization_id':self.org,'action':action,'payload':payload})
 def test_caller_token_and_exact_payload(self):
  p={'id':self.cid,'text':'Bonjour','clientId':str(uuid4())}
  self.assertEqual(self.call('send',p),{'ok':True})
  self.assertEqual(self.api.args,('/rest/v1/rpc/uniion_messaging','user-jwt',{'p_org':self.org,'p_action':'send','p_payload':p}))
 def test_untrusted_shapes(self):
  for action,payload in [('send',{}),('send',{'id':self.cid,'text':'x','clientId':str(uuid4()),'author':str(uuid4())}),('get',{'id':self.cid,'before':None}),('get',{'id':self.cid,'before':'-1'}),('get',{'id':self.cid,'before':1}),('list',{'before':'bad'}),('participants',{'org':'other'}),([],{}),('send',{'id':self.cid,'text':{},'clientId':str(uuid4())})]:
   with self.subTest(action=action,payload=payload),self.assertRaises(Denied):self.call(action,payload)
 def test_text_bounds(self):
  for t in ['', '  ', 'a'*10001]:
   with self.assertRaises(Denied):self.call('send',{'id':self.cid,'text':t,'clientId':str(uuid4())})
 def test_pagination_and_reply(self):
  self.call('get',{'id':self.cid,'before':'51'})
  self.call('send',{'id':self.cid,'text':'Réponse','clientId':str(uuid4()),'replyTo':'1'})

class MemberPayloadTests(unittest.TestCase):
 setUp=MessagingTests.setUp
 call=MessagingTests.call
 def test_group_and_history_shapes(self):
  self.call('group_create',{'clientId':str(uuid4()),'name':'Groupe','desc':'','members':[str(uuid4())]})
  self.call('group_save',{'id':self.cid,'version':1,'name':'Groupe','desc':'','members':[]})
  self.call('history_grant',{'id':self.cid,'version':1,'period':str(uuid4()),'messages':['1','2']})
 def test_invalid_management_payloads(self):
  for action,p in [('group_create',{'clientId':str(uuid4()),'name':'G','desc':'','members':[]}),('group_save',{'id':self.cid,'version':True,'name':'G','desc':'','members':[]}),('member_role',{'id':self.cid,'version':1,'participant':str(uuid4()),'admin':'true'}),('history_grant',{'id':self.cid,'version':1,'period':str(uuid4()),'messages':['1','1']}),('history_grant',{'id':self.cid,'version':1,'period':str(uuid4()),'messages':[None]})]:
   with self.subTest(action=action),self.assertRaises(Denied):self.call(action,p)

class MessageFilePayloadTests(unittest.TestCase):
 setUp=MessagingTests.setUp
 call=MessagingTests.call
 def test_strict_file_payloads(self):
  for action,p in [('file_download',{'id':self.cid,'attachment':str(uuid4()),'share':str(uuid4())}),('file_preview',{'id':self.cid,'attachment':str(uuid4()),'page':True}),('file_preview',{'id':self.cid,'attachment':str(uuid4()),'page':0}),('file_rescan',{'id':self.cid,'attachment':'bad'}),('file_upload',{'id':self.cid,'clientId':'bad','filename':'x.txt','content':'YQ=='}),('file_upload',{'id':self.cid,'clientId':str(uuid4()),'filename':'x.txt','content':None}),('file_remove',{})]:
   with self.subTest(action=action),self.assertRaises(Denied):self.call(action,p)
 def test_file_context_rechecked_after_download(self):
  from unittest.mock import patch
  from uniion.adapters import attachments
  seen=[]
  def req(*args):seen.append(args);return {'write':True}
  self.api.request=req
  with patch.object(attachments,'download',return_value=({'filename':'x.txt','mime':'text/plain'},b'abc')):
   r=self.call('file_download',{'id':self.cid,'attachment':str(uuid4())})
  self.assertEqual(r['content'],'YWJj');self.assertEqual(len(seen),2)
  self.assertTrue(all(x[1]=='user-jwt' for x in seen))
 def test_recheck_failure_never_returns_bytes(self):
  from unittest.mock import patch
  from uniion.adapters import attachments
  self.api.request=unittest.mock.Mock(side_effect=[{'write':False},Denied()])
  with patch.object(attachments,'download',return_value=({'filename':'x.txt','mime':'text/plain'},b'abc')),self.assertRaises(Denied):
   self.call('file_download',{'id':self.cid,'attachment':str(uuid4())})

class DiscoveryPayloadTests(unittest.TestCase):
 setUp=MessagingTests.setUp
 call=MessagingTests.call
 def test_search_locate_and_reference_payloads(self):
  self.call('search',{'query':'100%','before':str(uuid4())})
  self.call('targets',{'query':''})
  self.call('locate',{'id':self.cid,'seq':'123'})
  self.call('forward',{'id':self.cid,'seq':'1','clientId':str(uuid4()),'targets':[str(uuid4())]})
 def test_untrusted_discovery_payloads(self):
  target=str(uuid4())
  for a,p in [('search',{'query':''}),('search',{'query':'x'*201}),('search',{'query':'x','before':'bad'}),('locate',{'id':self.cid,'seq':1}),('locate',{'id':self.cid,'seq':'0'}),('forward',{'id':self.cid,'seq':'1','clientId':str(uuid4()),'targets':[target,target]}),('forward',{'id':self.cid,'seq':'1','clientId':str(uuid4()),'targets':[self.cid]}),('forward',{'id':self.cid,'seq':'1','clientId':str(uuid4()),'targets':[target],'text':'copie'})]:
   with self.subTest(action=a),self.assertRaises(Denied):self.call(a,p)

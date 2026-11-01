import unittest
from uniion.adapters.identity import dispatch
from uniion.core.contracts import Denied
class IdentityTests(unittest.TestCase):
 def test_extra_role_rejected(self):
  with self.assertRaises(Denied):dispatch(None,'token','/identity/invitations/create',{'organization_id':'org','email':'a@b.test','role':'admin'})
 def test_unknown_command_rejected(self):
  with self.assertRaises(Denied):dispatch(None,'token','/identity/global-grant',{})
 def test_missing_argument_rejected(self):
  with self.assertRaises(Denied):dispatch(None,'token','/identity/invitations/accept',{})
 def test_exact_user_token_and_parameters(self):
  class Api:
   def request(self,path,token,body):return path,token,body
  self.assertEqual(dispatch(Api(),'user-token','/identity/invitations/accept',{'token':'nonce'}),('/rest/v1/rpc/uniion_invite_accept','user-token',{'p_token':'nonce'}))
 def test_invalid_type_rejected(self):
  with self.assertRaises(Denied):dispatch(None,'token','/identity/memberships/revoke',{'organization_id':{},'user_id':'id'})

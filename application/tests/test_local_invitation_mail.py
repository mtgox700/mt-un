import unittest
from unittest.mock import patch,MagicMock
from uniion.adapters.local_invitation_mail import send
from uniion.core.contracts import Denied,Unavailable
class Tests(unittest.TestCase):
 def test_external_recipient_refused_before_rpc(self):
  with patch('uniion.adapters.local_invitation_mail.dispatch') as rpc:
   with self.assertRaises(Denied):send(None,'t',{'organization_id':'o','email':'real@external.fr'})
   rpc.assert_not_called()
 def test_role_escalation_refused(self):
  with self.assertRaises(Denied):send(None,'t',{'organization_id':'o','email':'test@example.invalid','role':'admin'})
 def test_failure_revokes_undelivered_ticket(self):
  with patch('uniion.adapters.local_invitation_mail.dispatch',return_value={'id':'id','token':'nonce'}) as rpc,patch('urllib.request.urlopen',side_effect=OSError()):
   with self.assertRaises(Unavailable):send(None,'t',{'organization_id':'o','email':'test@example.invalid'})
   self.assertEqual(rpc.call_args.args[2],'/identity/invitations/revoke')
 def test_success_does_not_expose_token(self):
  response=MagicMock();response.__enter__.return_value.status=200
  with patch('uniion.adapters.local_invitation_mail.dispatch',return_value={'id':'id','token':'nonce'}),patch('urllib.request.urlopen',return_value=response):
   result=send(None,'t',{'organization_id':'o','email':'test@example.invalid'});self.assertTrue(result['delivered']);self.assertNotIn('token',result);self.assertFalse(result['business_rights_granted'])
 def test_resend_failure_revokes_replacement(self):
  with patch('uniion.adapters.local_invitation_mail.dispatch',return_value={'id':'id','token':'nonce','email':'test@example.invalid'}) as rpc,patch('urllib.request.urlopen',side_effect=OSError()):
   with self.assertRaises(Unavailable):send(None,'t',{'organization_id':'o','invitation_id':'id'},resend=True)
   self.assertEqual(rpc.call_args_list[0].args[2],'/identity/invitations/resend')
   self.assertEqual(rpc.call_args_list[-1].args[2],'/identity/invitations/revoke')
 def test_resend_does_not_accept_recipient_override(self):
  with self.assertRaises(Denied):send(None,'t',{'organization_id':'o','invitation_id':'id','email':'test@example.invalid'},resend=True)

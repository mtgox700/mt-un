import unittest
from unittest.mock import patch
from uniion.adapters.agenda import workflow
from uniion.adapters import antivirus
class API:
 def __init__(self):self.actions=[]
 def request(self,path,token,data):
  self.actions.append(data['p_action'])
  if data['p_action']=='attachments':return {'document':{},'version':1,'event':{}}
  raise AssertionError('No delivery may be prepared')
class AttachmentGate(unittest.TestCase):
 def test_infected_pdf_never_prepares_delivery(self):
  api=API();data={'organization_id':'00000000-0000-0000-0000-000000000001','event_id':'00000000-0000-0000-0000-000000000002','action':'prepare','payload':{'attachment_version':1,'people':[]}}
  with patch('uniion.adapters.agenda_pdf.render',return_value=b'%PDF-test'),patch('uniion.adapters.antivirus.scan',return_value=('infected','test','test')):
   with self.assertRaises(antivirus.FileBlocked):workflow(api,'token',data,send=True)
  self.assertEqual(api.actions,['attachments'])
 def test_unavailable_scanner_never_prepares_delivery(self):
  api=API();data={'organization_id':'00000000-0000-0000-0000-000000000001','event_id':'00000000-0000-0000-0000-000000000002','action':'prepare','payload':{'attachment_version':1,'people':[]}}
  with patch('uniion.adapters.agenda_pdf.render',return_value=b'%PDF-test'),patch('uniion.adapters.antivirus.scan',side_effect=antivirus.ScanUnavailable):
   with self.assertRaises(antivirus.ScanUnavailable):workflow(api,'token',data,send=True)
  self.assertEqual(api.actions,['attachments'])

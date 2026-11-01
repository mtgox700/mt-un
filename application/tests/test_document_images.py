import unittest,base64
from unittest.mock import patch,Mock
from uniion.adapters.document_images import image_bytes,certify
from uniion.adapters import antivirus
from uniion.core.contracts import Denied,Unavailable
class DocumentImagesTests(unittest.TestCase):
 def test_disallowed_sources(self):
  for value in ('https://example.invalid/logo.png','file:///etc/passwd','data:image/svg+xml;base64,PHN2Zz4=','data:image/png;base64,YQ==',None,'data:image/png;base64,'+'a'*2800001):
   with self.assertRaises(Denied):image_bytes(value)
 def test_infected_no_receipt(self):
  value='data:image/png;base64,'+base64.b64encode(b'\x89PNG\r\n\x1a\n'+b'fake').decode();api=Mock()
  with patch.object(antivirus,'scan',return_value=('infected','test','blocked')):
   with self.assertRaises(Denied):certify(api,'user','event',{'charte':{'logo':value}}, {})
  api.request.assert_not_called()
 def test_scanner_unavailable_no_receipt(self):
  value='data:image/png;base64,'+base64.b64encode(b'\x89PNG\r\n\x1a\n').decode();api=Mock()
  with patch.object(antivirus,'scan',side_effect=antivirus.ScanUnavailable()):
   with self.assertRaises(Unavailable):certify(api,'user','event',{'charte':{'logo':value}}, {})
  api.request.assert_not_called()

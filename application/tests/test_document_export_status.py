import unittest,base64
from io import BytesIO
from unittest.mock import patch
from pypdf import PdfWriter,PdfReader
from uniion.adapters.document_exports import export
class ExportStatus(unittest.TestCase):
 def test_publication_status_is_not_labeled_draft(self):
  class API:
   def request(self,path,token,p):return {'version':2,'document':{'title':'Fictif','status':'Diffusé'}}
  w=PdfWriter();w.add_blank_page(width=200,height=200);b=BytesIO();w.write(b)
  with patch('uniion.adapters.document_exports.render',return_value=b.getvalue()):r=export(API(),'fictional','org',{'id':'00000000-0000-0000-0000-000000000001','version':2})
  self.assertEqual(PdfReader(BytesIO(base64.b64decode(r['base64']))).metadata.subject,'Document — version 2 — diffusé')

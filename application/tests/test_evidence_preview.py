import unittest,io
from docx import Document
from openpyxl import Workbook
from uniion.adapters.evidence_preview import render
from uniion.adapters.office_files import MIMES
from uniion.core.contracts import Denied
class EvidencePreviewTests(unittest.TestCase):
 def test_plain_text_is_inert_and_paginated(self):
  value='<script>not executed</script>'+('é'*7000)
  p=render(value.encode(),'text/plain',1);q=render(value.encode(),'text/plain',2)
  self.assertEqual(p['pages'],2);self.assertEqual(p['image'],'');self.assertEqual(p['text']+q['text'],value)
  with self.assertRaises(Denied):render(b'x','text/plain',2)
 def test_invalid_pages(self):
  for page in (0,-1,True,1.5,201):
   with self.assertRaises(Denied):render(b'x','text/plain',page)
 def test_word_and_excel_text_only(self):
  for ext in ('docx','xlsx'):
   buf=io.BytesIO();d=Document() if ext=='docx' else Workbook()
   if ext=='docx':d.add_paragraph('<b>fictif</b>')
   else:d.active['A1']='<b>fictif</b>';d.active['B1']='=1+1'
   d.save(buf);r=render(buf.getvalue(),MIMES[ext],1)
   self.assertIn('<b>fictif</b>',r['text']);self.assertEqual(r['image'],'')
 def test_bounded_text(self):
  r=render(b'a'*130000,'text/plain',20)
  self.assertEqual(r['pages'],20);self.assertIn('limité',r['note'])

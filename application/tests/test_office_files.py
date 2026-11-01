import unittest,io,zipfile
from docx import Document
from openpyxl import Workbook
from uniion.adapters.office_files import validate
class OfficeTests(unittest.TestCase):
 def sample(self,ext):
  b=io.BytesIO();d=Document() if ext=='docx' else Workbook();d.save(b);return b.getvalue()
 def altered(self,raw,name,content):
  b=io.BytesIO()
  with zipfile.ZipFile(io.BytesIO(raw)) as src,zipfile.ZipFile(b,'w') as dst:
   for i in src.infolist():dst.writestr(i,src.read(i))
   dst.writestr(name,content)
  return b.getvalue()
 def test_valid_and_wrong_extension(self):
  for ext in ('docx','xlsx'):
   raw=self.sample(ext);self.assertIn('openxmlformats',validate(raw,ext))
   with self.assertRaises(ValueError):validate(raw,'xlsx' if ext=='docx' else 'docx')
 def test_active_and_traversal(self):
  for name in ('word/vbaProject.bin','word/embeddings/object.bin','../escape.xml'):
   with self.assertRaises(ValueError):validate(self.altered(self.sample('docx'),name,b'x'),'docx')
 def test_entities_and_external_template(self):
  for data in (b'<!DOCTYPE a [<!ENTITY x "x">]><a>&x;</a>',b'<Relationships><Relationship Type="x/attachedTemplate" Target="https://invalid.example/a" TargetMode="External"/></Relationships>'):
   with self.assertRaises(ValueError):validate(self.altered(self.sample('docx'),'word/extra.rels',data),'docx')
 def test_zip_bomb_and_forgery(self):
  with self.assertRaises(ValueError):validate(b'PKfake','docx')
  with self.assertRaises(ValueError):validate(self.altered(self.sample('xlsx'),'xl/huge.xml',b'x'*(10*1024*1024+1)),'xlsx')

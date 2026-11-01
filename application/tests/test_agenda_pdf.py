import unittest
from io import BytesIO
from pypdf import PdfReader
from uniion.adapters.agenda_pdf import render
from uniion.core.contracts import Denied
CHARTER={'accent':'#DC2626','ink':'#111827','titleFont':'philosopher','bodyFont':'inter','density':'standard','header':True,'footer':True,'caps':False,'logo':'uniion-logo.png','emetteur':'Recette','section':'Section fictive','email':'','phone':''}
class AgendaPDFTests(unittest.TestCase):
 def test_all_pages_and_escaped_content(self):
  blocks=[{'type':'h1','text':'Première page <script>'},{'type':'p','text':'Élus & représentants'},{'type':'pagebreak','text':''},{'type':'p','text':'Deuxième page finale'}]
  pdf=PdfReader(BytesIO(render({'charte':CHARTER,'title':'Recette','format':'a4','blocks':blocks},7)))
  self.assertEqual(len(pdf.pages),2)
  self.assertIn('Première page <script>',pdf.pages[0].extract_text())
  self.assertIn('Deuxième page finale',pdf.pages[1].extract_text())
  self.assertIn('version 7',pdf.metadata.subject)
  self.assertIn('Page 2 / 2',pdf.pages[1].extract_text())
 def test_reference_blocks_and_formats(self):
  blocks=[{'type':k,'text':v} for k,v in [('tag','Section'),('h1','Ordre du jour'),('h2','Points'),('h3','Détail'),('ul','Premier\nSecond'),('quote','Échange & décision'),('table','Sujet|Pilote\nBudget|Élu')]]
  for fmt in ('a4','a5','wide'):
   pdf=PdfReader(BytesIO(render({'charte':CHARTER,'title':'Recette','format':fmt,'blocks':blocks},1)))
   self.assertIn('Budget',pdf.pages[0].extract_text())
   self.assertIn('Second',pdf.pages[0].extract_text())
 def test_missing_charter_and_overflow_fail_closed(self):
  with self.assertRaises(Denied):render({'title':'X','format':'a4','blocks':[]},1)
  with self.assertRaises(Denied):render({'title':'X','format':'a5','charte':CHARTER,'blocks':[{'type':'p','text':'Longue ligne. '*2000}]},1)
 def test_embedded_font_variants(self):
  for family in ('philosopher','inter','montserrat','lora'):
   pdf=PdfReader(BytesIO(render({'title':'X','format':'a4','charte':{**CHARTER,'titleFont':family,'bodyFont':family},'blocks':[{'type':'h1','text':'Élus'},{'type':'quote','text':'Décision'}]},1)))
   self.assertIn('Élus',pdf.pages[0].extract_text())

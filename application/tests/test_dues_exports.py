import unittest,io,csv
from pypdf import PdfReader
from uniion.adapters.dues_exports import csv_bytes,receipt_pdf
class DuesExportTests(unittest.TestCase):
 def data(self):return {'organization':'Organisation fictive','member':'Camille Recette','memberId':'member','payments':[{'id':'payment','period':'2026-10-01','dueOn':'2026-10-05','originalCents':2000,'cents':1250,'effectiveOn':'2026-10-20','recordedAt':'2026-10-28T12:00:00Z','revision':2}]}
 def test_csv_quotes_unicode_and_formulas(self):
  for name in ('=1+1',' +CMD','@SUM(A1)','\t=2+2','-2+3'):
   d=self.data();d['member']=name;rows=list(csv.reader(io.StringIO(csv_bytes(d).decode('utf-8-sig')),delimiter=';'));self.assertTrue(rows[1][1].startswith("'"));self.assertEqual(rows[1][7],'12,50')
 def test_pdf_wraps_names_and_is_deterministic(self):
  d=self.data();d['payment']=d.pop('payments')[0];d['member']='Nom très long & <texte> '*20
  r={'id':'00000000-0000-0000-0000-000000000000','createdAt':'2026-10-28','revision':2,'data':d};raw=receipt_pdf(r);self.assertEqual(raw,receipt_pdf(r));pdf=PdfReader(io.BytesIO(raw));text=''.join(p.extract_text() for p in pdf.pages);self.assertIn('Document non fiscal',text);self.assertIn('12,50 EUR',text);self.assertIn('<texte>',text)

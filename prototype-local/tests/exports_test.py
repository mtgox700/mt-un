import io,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from exports import export_file
from openpyxl import load_workbook
from pypdf import PdfReader
class Exports(unittest.TestCase):
 def setUp(self):self.sheets=[{'name':'Synthèse','rows':[['Été','=1+1'],['Dossiers',3]]}]
 def test_xlsx(self):
  data,_=export_file({'format':'xlsx','sheets':self.sheets});w=load_workbook(io.BytesIO(data));self.assertEqual(w.active['A1'].value,'Été');self.assertEqual(w.active['B1'].data_type,'s')
 def test_csv(self):
  data,_=export_file({'format':'csv','sheets':self.sheets});self.assertIn("'=1+1",data.decode('utf-8-sig'))
 def test_pdf(self):
  data,_=export_file({'format':'pdf','sheets':self.sheets,'title':'Recette française'});self.assertIn('Recette française',PdfReader(io.BytesIO(data)).pages[0].extract_text())
 def test_bad_format(self):
  with self.assertRaises(ValueError):export_file({'format':'exe'})
if __name__=='__main__':unittest.main()

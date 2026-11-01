from pathlib import Path
import json,io
from pypdf import PdfReader
from uniion.adapters.agenda_pdf import render
from uniion.core.contracts import PDFOverflow
from test_agenda_pdf import CHARTER
out=Path(__file__).resolve().parents[1]/'preuves/S03-debordements';results=[]
for style in ('journal','institutionnel','bulletin'):
 for kind,text in [('vertical','Paragraphe fictif très long. '*2000),('horizontal','W'*600)]:
  doc={'title':'Recette limites','format':'a4','style':style,'charte':CHARTER,'blocks':[{'type':'h1','text':'Réunion'},{'type':'p','text':'Chapô court'},{'type':'p','text':text}]}
  try:render(doc,1);blocked=False
  except PDFOverflow:blocked=True
  assert blocked,(style,kind);results.append({'style':style,'case':kind,'blocked':True})
doc={'title':'Deux pages','format':'a4','style':'institutionnel','charte':CHARTER,'blocks':[{'type':'h1','text':'Première page'},{'type':'p','text':'Réunion fictive.'},{'type':'pagebreak','text':''},{'type':'h1','text':'Dernière page'},{'type':'p','text':'Fin du document.'}]}
raw=render(doc,2);pdf=PdfReader(io.BytesIO(raw));assert len(pdf.pages)==2;assert 'Première page' in pdf.pages[0].extract_text();assert 'Dernière page' in pdf.pages[1].extract_text();(out/'deux-pages.pdf').write_bytes(raw)
(out/'limites.json').write_text(json.dumps({'cases':results,'pagebreak_export':True},indent=2));print('6 dépassements bloqués, document de 2 pages exporté')

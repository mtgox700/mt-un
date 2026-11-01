from pathlib import Path
import json,base64,io
from pypdf import PdfReader
from uniion.adapters.agenda_pdf import render
from test_agenda_pdf import CHARTER
root=Path(__file__).resolve().parents[1];out=root/'preuves/S03-logos-styles';catalog=json.loads((root/'uniion/assets/studio-catalog.json').read_text());logo='data:image/png;base64,'+base64.b64encode((out/'logo-recette.png').read_bytes()).decode()
results=[]
for style in catalog['styles']:
 for fmt in ('a4','a5','wide'):
  doc={'title':'Recette du style '+style['id'],'format':fmt,'style':style['id'],'styleOpts':{},'charte':{**CHARTER,'logo':logo},'blocks':[{'type':'tag','text':'Section fictive'},{'type':'h1','text':'Ensemble pour nos droits'},{'type':'p','text':'Réunion des représentants. Échanges et décisions.'},{'type':'h2','text':'Ordre du jour'},{'type':'ul','text':'Conditions de travail\nQuestions diverses'}]}
  raw=render(doc,4);pdf=PdfReader(io.BytesIO(raw));assert len(pdf.pages)==1,(style['id'],fmt,len(pdf.pages));assert len(raw)>5000
  (out/(style['id']+'-'+fmt+'.pdf')).write_bytes(raw);results.append({'style':style['id'],'format':fmt,'pages':1,'bytes':len(raw),'passed':True})
(out/'styles-render.json').write_text(json.dumps(results,indent=2));print('PDF render cases:',len(results))

from pathlib import Path
import sys,json,io,base64,collections
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from uniion.adapters.agenda_pdf import render
from uniion.core.contracts import PDFOverflow
from pypdf import PdfReader
from test_agenda_pdf import CHARTER
root=Path(__file__).resolve().parents[1];out=root/'preuves/S06-pages-complementaires';catalog=json.loads((root/'uniion/assets/studio-catalog.json').read_text());results=[]
logo='data:image/png;base64,'+base64.b64encode((root/'preuves/S03-logos-styles/logo-recette.png').read_bytes()).decode()
blocks=[{'type':'tag','text':'Section fictive'},{'type':'h1','text':'Ensemble pour nos droits'},{'type':'p','text':'Réunion des représentants. Échanges et décisions.'},{'type':'h2','text':'Ordre du jour'},{'type':'ul','text':'Conditions de travail\nQuestions diverses'}]
for style in catalog['styles']:
 for fmt in ('a4','a5','wide'):
  doc={'title':'Recette du style '+style['id'],'format':fmt,'style':style['id'],'styleOpts':{},'charte':{**CHARTER,'logo':logo},'blocks':blocks}
  try:raw=render(doc,4)
  except PDFOverflow:results.append({'style':style['id'],'format':fmt,'blocked':'PDFOverflow'});continue
  pdf=PdfReader(io.BytesIO(raw));(out/(style['id']+'-'+fmt+'.pdf')).write_bytes(raw);results.append({'style':style['id'],'format':fmt,'pages':len(pdf.pages),'passed':True})
(out/'matrix.json').write_text(json.dumps(results,indent=2));print(dict(collections.Counter(x.get('blocked','passed') for x in results)))
# Missing partial extension content, image, and long text: all retained in continuations.
long=' '.join('Phrase '+str(i)+' de recette.' for i in range(120))
for fmt in ('a4','a5','wide'):
 doc={'title':'Compléments S06','format':fmt,'style':'bd','styleOpts':{},'charte':{**CHARTER,'logo':logo},'blocks':[{'type':'tag','text':'Recette'},{'type':'h1','text':'Titre complémentaire'},{'type':'studio.chiffre','text':'68 %\nParticipation complète'},{'type':'p','text':'Court'},{'type':'p','text':'Deux'},{'type':'p','text':'Trois'},{'type':'p','text':long},{'type':'studio.photo','text':'Légende image','img':logo}]}
 raw=render(doc,1);pdf=PdfReader(io.BytesIO(raw));assert len(pdf.pages)>3
 text=''.join(p.extract_text() for p in pdf.pages);assert 'Phrase 119' in text and 'Participation complète' in text
 (out/('complements-'+fmt+'.pdf')).write_bytes(raw)
print('Three multi-page image/extension/long-text cases passed')

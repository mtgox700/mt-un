from pathlib import Path
import json,io
from pypdf import PdfReader
from uniion.adapters.agenda_pdf import render
from uniion.core.contracts import Denied
from test_agenda_pdf import CHARTER
root=Path(__file__).resolve().parents[1];out=root/'preuves/S03-paysage';catalog=json.loads((root/'uniion/assets/studio-catalog.json').read_text());results=[]
for style in catalog['styles']:
 for fmt in ('a4','a5','wide'):
  for kind,title in [('court','Unis'),('long','Un très long titre qui dépasse le cadre. '*60)]:
   doc={'title':'Recette débordement','format':fmt,'style':style['id'],'styleOpts':{},'charte':CHARTER,'blocks':[{'type':'h1','text':title},{'type':'p','text':'Réunion fictive.'}]}
   try:
    raw=render(doc,1);pdf=PdfReader(io.BytesIO(raw));assert len(pdf.pages)==1
    (out/(style['id']+'-'+fmt+'-'+kind+'.pdf')).write_bytes(raw);status='exported'
   except Denied:status='blocked'
   results.append({'style':style['id'],'format':fmt,'content':kind,'result':status});print(style['id'],fmt,kind,status,flush=True)
(out/'rendus.json').write_text(json.dumps(results,indent=2))
assert all(x['result']=='blocked' for x in results if x['content']=='long')

assert all(x['result']=='exported' for x in results if x['content']=='court')

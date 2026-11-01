from pathlib import Path
import sys,json,io
from pypdf import PdfReader
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from uniion.adapters.agenda_pdf import render
from uniion.core.contracts import PDFOverflow
from test_agenda_pdf import CHARTER
root=Path(__file__).resolve().parents[1]; results=[]
for style in ('choc','retro','serigraphie','journal'):
 for fmt in ('a4','a5','wide'):
  doc={'title':'Limite volontaire','format':fmt,'style':style,'styleOpts':{},'charte':CHARTER,'blocks':[{'type':'h1','text':'Un très long titre qui dépasse le cadre. '*60},{'type':'p','text':'Recette fictive.'}]}
  try:
   raw=render(doc,1);blocked=False
   pdf=PdfReader(io.BytesIO(raw));text=' '.join(p.extract_text() for p in pdf.pages)
   normalized=''.join(c.lower() for c in text if c.isalnum())
   assert normalized.count('untrèslongtitre')==60,(style,fmt,'content missing',normalized.count('untrèslongtitre'))
   (root/'preuves/S06-cloture-finale'/('oversized-'+style+'-'+fmt+'.pdf')).write_bytes(raw)
  except PDFOverflow:blocked=True
  results.append({'style':style,'format':fmt,'blocked':blocked})
(root/'preuves/S06-cloture-finale/oversized.json').write_text(json.dumps(results,indent=2))
print(json.dumps({'blocked':sum(x['blocked'] for x in results),'complete_exports':sum(not x['blocked'] for x in results)}))

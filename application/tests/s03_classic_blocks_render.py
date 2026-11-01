from pathlib import Path
import base64,json,io
from pypdf import PdfReader
from uniion.adapters.agenda_pdf import render
from uniion.core.contracts import Denied
from test_agenda_pdf import CHARTER
root=Path(__file__).resolve().parents[1];out=root/'preuves/S03-svg-classique';samples=json.loads((out/'blocs-fixtures.json').read_text());logo='data:image/svg+xml;base64,'+base64.b64encode((out/'logo-fictif.svg').read_bytes()).decode();results=[]
for fmt in ('a4','a5','wide'):
 blocks=[]
 for i,original in enumerate(samples):
  sample=dict(original)
  # Five columns fit landscape; four larger portraits exceed the reference layout.
  if fmt=='wide' and sample['type']=='studio.trombi':sample['text']+='\nCamille F. | Élu fictif'
  if i:blocks.append({'id':'pb'+str(i),'type':'pagebreak','text':''})
  blocks.extend([{'id':'h'+str(i),'type':'h2','text':sample['type']},sample])
  if sample['type']=='studio.photo':sample['img']=logo
 doc={'title':'Les 12 blocs en mode Classique','format':fmt,'style':None,'blocks':blocks,'charte':{**CHARTER,'logo':logo}}
 raw=render(doc,1);pdf=PdfReader(io.BytesIO(raw));assert len(pdf.pages)==12
 for i,sample in enumerate(samples):assert sample['type'] in pdf.pages[i].extract_text()
 (out/(fmt+'-12-blocs.pdf')).write_bytes(raw);results.append({'format':fmt,'pages':12,'blocks':12,'passed':True})
try:render({**doc,'blocks':[{'id':'huge','type':'studio.chiffre','text':'68 %\n'+('Texte trop long. '*2000)}]},1);overflow=False
except Denied:overflow=True
assert overflow
(out/'rendus.json').write_text(json.dumps({'renders':results,'overflow_denied':overflow},indent=2));print('36 blocs/pages vérifiés, dépassement refusé')

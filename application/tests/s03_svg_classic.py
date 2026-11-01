from pathlib import Path
exec(compile(Path(__file__).with_name('s03_workflows.py').read_text().split("st,ctx,_=work(x,'recipients')")[0],__file__,'exec'))
import base64,io
from pypdf import PdfReader
app.sessions.clock=lambda:time.time()+61
out=ROOT/'preuves/S03-svg-classique';out.mkdir(exist_ok=True)
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','download',false);")
svg=b'<svg xmlns="http://www.w3.org/2000/svg" width="300" height="100" viewBox="0 0 300 100"><defs><linearGradient id="g"><stop offset="0" stop-color="#173861"/><stop offset="1" stop-color="#d45224"/></linearGradient></defs><rect width="300" height="100" rx="12" fill="url(#g)"/><path d="M15 50 L30 20 L45 50 L30 80 Z" fill="white"/><text x="60" y="57" fill="white" font-size="20">SECTION FICTIVE</text></svg>'
(out/'logo-fictif.svg').write_bytes(svg);uri='data:image/svg+xml;base64,'+base64.b64encode(svg).decode();chr=work(x,'document')[1]['document']['charte']
doc={**doc,'charte':{**chr,'logo':uri},'style':None,'styleOpts':{},'blocks':[{'id':'h1','type':'h1','text':'Ordre du jour — blocs mixtes'},{'id':'p','type':'p','text':'Recette fictive : les blocs conservent leur présentation.'},{'id':'chiffre','type':'studio.chiffre','text':'68 %\nParticipation'},{'id':'compare','type':'studio.compare','text':'Proposition | 0,8 %\nDemande | 4,5 %'},{'id':'pb','type':'pagebreak','text':''},{'id':'h2','type':'h2','text':'Deuxième page'},{'id':'frise','type':'studio.frise','text':'2 oct. | Ouverture | fait\n13 nov. | Assemblée'},{'id':'qr','type':'studio.qr','text':'https://example.invalid/recette\nInformation fictive'}]}
def save(c=x,value=doc,v=2):return work(c,'save_document',{'version':v,'document':value})
try:api.request('/rest/v1/rpc/uniion_agenda_work',x.state()['access_token'],{'p_org':org,'p_event':eid,'p_action':'save_document','p_payload':{'version':2,'document':doc}});direct=True
except AccessDenied:direct=False
check('unscanned_svg_direct_denied',not direct)
check('reader_svg_denied',save(y)[0]==403)
check('foreign_svg_denied',work(x,'save_document',{'version':2,'document':doc},o=foreign)[0]==403)
for name,content in [('script','<script>alert(1)</script>'),('external','<image href="https://example.invalid/a"/>'),('entity','<!DOCTYPE svg>')]:
 attack=('<svg xmlns="http://www.w3.org/2000/svg">'+content+'</svg>').encode();value={**doc,'charte':{**chr,'logo':'data:image/svg+xml;base64,'+base64.b64encode(attack).decode()}};check(name+'_svg_denied',save(value=value)[0]==403)
st,result,_=save();check('svg_and_mixed_saved',st==200);loaded=work(x,'document')[1];check('reloaded_svg',loaded['document']['charte']['logo']==uri);check('reloaded_blocks',loaded['document']['blocks']==doc['blocks'])
st,result,_=work(x,'export',{'version':3});check('mixed_pdf_export',st==200);raw=base64.b64decode(result['base64']);(out/'classique-mixte.pdf').write_bytes(raw);pdf=PdfReader(io.BytesIO(raw));check('both_pages',len(pdf.pages)==2);check('first_page_content','Participation' in pdf.pages[0].extract_text());check('last_page_content','Deuxième page' in pdf.pages[1].extract_text());check('reader_export_denied',work(y,'export',{'version':3})[0]==403);check('stale_export_denied',work(x,'export',{'version':2})[0]==403)
(ROOT/'.local-auth/s03-svg-classique.json').write_text(json.dumps({'organization':org,'event':eid,'document':d['document']['id'],'version':3}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

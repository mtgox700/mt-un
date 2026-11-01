from pathlib import Path
source=Path(__file__).with_name('s06_documents.py').read_text().split("check('anonymous_denied'")[0]
exec(compile(source,__file__,'exec'))
from pypdf import PdfReader
from unittest.mock import patch
from uniion.adapters.document_exports import render as real_render
out=ROOT/'preuves/S06-exports';out.mkdir(exist_ok=True)
doc['blocks']=[{'id':'t1','type':'h1','text':'Première page — recette'},{'id':'p','type':'p','text':'Contenu fictif S06.'},{'id':'break','type':'pagebreak','text':''},{'id':'t2','type':'h1','text':'Deuxième page — fin du document'}]
st,row,_=call(x,'create',{'model':'courrier','document':doc});check('create_document',st==200);rid=row['id']
def export(c=x,o=org,v=1):return call(c,'export',{'id':rid,'version':v},o)
check('anonymous_denied',export(Client())[0]==403)
check('writer_without_download_denied',export()[0]==403)
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null);insert into public.uniion_authorities values('{org}','{a['id']}','download',false)")
check('reader_without_download_denied',export(y)[0]==403);check('foreign_denied',export(o=foreign)[0]==403)
st,r,_=export();check('authorized_pdf',st==200 and r['mime']=='application/pdf');raw=base64.b64decode(r['base64']);(out/'classique.pdf').write_bytes(raw);pdf=PdfReader(io.BytesIO(raw));check('two_pages',len(pdf.pages)==2);check('last_page_preserved','fin du document' in pdf.pages[1].extract_text());check('document_metadata','brouillon' in pdf.metadata.subject)
check('stale_denied',export(v=99)[0]==403)
# Revocation during rendering must prevent bytes from being returned.
def revoke(d,v):
 sql(f"update public.uniion_resource_grants set revoked_at=now() where organization_id='{org}' and resource_id='{rid}' and user_id='{a['id']}'")
 return raw
with patch('uniion.adapters.document_exports.render',side_effect=revoke):check('revoked_during_render_denied',export()[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null where organization_id='{org}' and resource_id='{rid}' and user_id='{a['id']}'")
newdoc={k:row[k] for k in ('title','format','blocks','charte')};newdoc['title']='Nouvelle version'
def change(d,v):
 check('edit_during_render',call(x,'save',{'id':rid,'version':1,'document':newdoc})[0]==200)
 return raw
with patch('uniion.adapters.document_exports.render',side_effect=change):check('changed_during_render_denied',export()[0]==403)
app.sessions.clock=lambda:time.time()+61
from PIL import Image
buf=io.BytesIO();Image.new('RGB',(140,40),'#A23E20').save(buf,format='PNG');logo='data:image/png;base64,'+base64.b64encode(buf.getvalue()).decode()
newdoc['charte']['logo']=logo;newdoc['style']='institutionnel';newdoc['styleOpts']={'palette':1,'font':0};newdoc['blocks'].insert(1,{'id':'key','type':'studio.chiffre','text':'42\nRecette'})
check('logo_style_saved',call(x,'save',{'id':rid,'version':2,'document':newdoc})[0]==200)
st,r,_=export(v=3);check('extension_pdf',st==200);(out/'extension.pdf').write_bytes(base64.b64decode(r['base64']));pdf=PdfReader(io.BytesIO(base64.b64decode(r['base64'])));check('extension_two_pages',len(pdf.pages)==2);check('extension_last_page','fin du document' in __import__('unicodedata').normalize('NFKC',pdf.pages[-1].extract_text()));check('custom_logo_embedded',len(pdf.pages[0].images)>0)
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='documents'");check('disabled_module_denied',export(v=3)[0]==403);sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='documents'")
(ROOT/'.local-auth/s06-exports.json').write_text(json.dumps({'organization':org,'resource':rid,'version':3}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

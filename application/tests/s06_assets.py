from pathlib import Path
source=Path(__file__).with_name('s06_documents.py').read_text().split("check('anonymous_denied'")[0]
exec(compile(source,__file__,'exec'))
import base64,io
from PIL import Image
out=ROOT/'preuves/S06-logos-extensions';out.mkdir(exist_ok=True)
st,row,_=call(x,'create',{'model':'courrier','document':doc});check('created',st==200);rid=row['id']
sql(f"insert into public.uniion_resource_grants values('{org}','{rid}','{b['id']}',false,false,now()+interval '3 days',null)")
charte={'accent':'#DA441A','ink':'#182030','titleFont':'philosopher','bodyFont':'inter','density':'standard','logo':'','header':True,'footer':True,'caps':False,'emetteur':'Recette','section':'Fictive','email':'','phone':'','emetteurOverride':True}
buf=io.BytesIO();Image.new('RGB',(120,50),'orange').save(buf,format='PNG');raw=buf.getvalue();(out/'logo.png').write_bytes(raw)
logo='data:image/png;base64,'+base64.b64encode(raw).decode();doc.update(charte={**charte,'logo':logo},style='institutionnel',styleOpts={'palette':1,'font':1});doc['blocks'].append({'id':'ext','type':'studio.chiffre','text':'42|adhérents fictifs'})
def save(value=doc,c=x,o=org,version=1):return call(c,'save',{'id':rid,'version':version,'document':value},o)
def direct(value):
 try:api.request('/rest/v1/rpc/uniion_documents',x.state()['access_token'],{'p_org':org,'p_action':'save','p_payload':{'id':rid,'version':1,'document':value}});return True
 except AccessDenied:return False
check('unscanned_direct_denied',not direct(doc));check('reader_denied',save(c=y)[0]==403);check('foreign_denied',save(o=foreign)[0]==403)
check('remote_logo_denied',save({**doc,'charte':{**charte,'logo':'https://example.invalid/logo'}})[0]==403)
check('fake_image_denied',save({**doc,'charte':{**charte,'logo':'data:image/png;base64,'+base64.b64encode(b'fake').decode()}})[0]==403)
st,r,_=save();check('scanned_image_extensions_saved',st==200)
check('reload_identical',call(y,'get',{'id':rid})[1]['charte']['logo']==logo and call(y,'get',{'id':rid})[1]['styleOpts']==doc['styleOpts'])
check('stale_denied',save()[0]==403)
check('unknown_style_denied',save({**doc,'style':'remote'},version=2)[0]==403)
check('invalid_options_denied',save({**doc,'styleOpts':{'palette':999}},version=2)[0]==403)
check('external_photo_denied',save({**doc,'blocks':[{'id':'x','type':'studio.photo','text':' https://example.invalid/p'}]},version=2)[0]==403)
svg=b'<svg xmlns="http://www.w3.org/2000/svg" width="120" height="50"><rect width="120" height="50" fill="#ee5500"/></svg>';(out/'logo.svg').write_bytes(svg)
doc['charte']['logo']='data:image/svg+xml;base64,'+base64.b64encode(svg).decode();check('svg_saved',save(version=2)[0]==200)
bad=b'<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>';check('active_svg_denied',save({**doc,'charte':{**charte,'logo':'data:image/svg+xml;base64,'+base64.b64encode(bad).decode()}},version=3)[0]==403)
try:api.request('/rest/v1/rpc/uniion_document_image_receipt',x.state()['access_token'],{'p_document':rid,'p_image':logo,'p_engine':'forged'});forged=True
except AccessDenied:forged=False
check('receipt_forgery_denied',not forged)
plain={**doc,'charte':charte};st,other,_=call(x,'create',{'model':'courrier','document':plain});check('other_created',st==200)
try:api.request('/rest/v1/rpc/uniion_documents',x.state()['access_token'],{'p_org':org,'p_action':'save','p_payload':{'id':other['id'],'version':1,'document':doc}});reused=True
except AccessDenied:reused=False
check('receipt_other_document_denied',not reused)
sql(f"update public.uniion_resource_grants set revoked_at=now() where resource_id='{rid}' and user_id='{b['id']}'")
check('revocation_read_denied',call(y,'get',{'id':rid})[0]==403)
sql(f"update public.uniion_resource_grants set revoked_at=null where resource_id='{rid}' and user_id='{b['id']}'")
from uniion.adapters import antivirus
check('real_eicar_blocked',antivirus.scan(b'X5O!P%@AP[4'+bytes([92])+b'PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*')[0]=='infected')
# New photo bytes exercise the image slot, not only the logo slot.
jpeg=io.BytesIO();Image.new('RGB',(80,60),'blue').save(jpeg,format='JPEG');photo='data:image/jpeg;base64,'+base64.b64encode(jpeg.getvalue()).decode()
photo_doc={**doc,'blocks':[{'id':'photo','type':'studio.photo','text':'Photo fictive','img':photo}]}
from unittest.mock import patch
with patch.object(antivirus,'scan',side_effect=antivirus.ScanUnavailable()):
 check('scanner_unavailable_fails_closed',save(photo_doc,version=3)[0]==503)
check('jpeg_photo_scanned_saved',save(photo_doc,version=3)[0]==200)
check('jpeg_photo_reloaded',call(y,'get',{'id':rid})[1]['blocks'][0]['img']==photo)
(ROOT/'.local-auth/s06-assets.json').write_text(json.dumps({'organization':org,'resource':rid}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

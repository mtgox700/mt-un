from pathlib import Path
exec(compile(Path(__file__).with_name('s03_workflows.py').read_text().split("st,ctx,_=work(x,'recipients')")[0],__file__,'exec'))
import base64,io
from PIL import Image,ImageDraw
from pypdf import PdfReader
app.sessions.clock=lambda: time.time()+61
out=ROOT/'preuves/S03-logos-styles';out.mkdir(exist_ok=True)
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','download',false);")
img=Image.new('RGBA',(300,100),'white');draw=ImageDraw.Draw(img);draw.rounded_rectangle((2,2,298,98),radius=15,fill='#173861');draw.text((55,40),'SECTION RECETTE',fill='white');buf=io.BytesIO();img.save(buf,format='PNG');raw=buf.getvalue();(out/'logo-recette.png').write_bytes(raw)
logo='data:image/png;base64,'+base64.b64encode(raw).decode();charte=work(x,'document')[1]['document']['charte'];doc={**doc,'charte':{**charte,'logo':logo},'style':'institutionnel','styleOpts':{'palette':1,'font':1}}
def save(c=x,value=doc,version=2):return work(c,'save_document',{'version':version,'document':value})
def direct(value,version=2):
 try:api.request('/rest/v1/rpc/uniion_agenda_work',x.state()['access_token'],{'p_org':org,'p_event':eid,'p_action':'save_document','p_payload':{'version':version,'document':value}});return True
 except AccessDenied:return False
check('direct_unscanned_logo_denied',not direct(doc))
check('reader_logo_write_denied',save(y)[0]==403)
check('foreign_logo_write_denied',work(x,'save_document',{'version':2,'document':doc},o=foreign)[0]==403)
check('remote_logo_denied',save(value={**doc,'charte':{**charte,'logo':'https://example.invalid/logo.png'}})[0]==403)
check('fake_png_denied',save(value={**doc,'charte':{**charte,'logo':'data:image/png;base64,'+base64.b64encode(b'not a png').decode()}})[0]==403)
check('malformed_png_denied',save(value={**doc,'charte':{**charte,'logo':'data:image/png;base64,'+base64.b64encode(b'\x89PNG\r\n\x1a\ninvalid').decode()}})[0]==403)
st,result,_=save();check('scanned_logo_and_style_saved',st==200)
check('logo_style_reloaded',work(x,'document')[1]['document']['charte']['logo']==logo and work(x,'document')[1]['document']['styleOpts']==doc['styleOpts'])
check('unlisted_style_denied',save(value={**doc,'style':'remote-extension'},version=3)[0]==403)
check('invalid_palette_denied',save(value={**doc,'styleOpts':{'palette':90}},version=3)[0]==403)
check('unknown_options_denied',save(value={**doc,'styleOpts':{'css':'url(https://example.invalid)'}},version=3)[0]==403)
check('reader_export_denied',work(y,'export',{'version':3})[0]==403)
st,pdf,_=work(x,'export',{'version':3});check('extension_pdf_export',st==200);binary=base64.b64decode(pdf['base64']);(out/'institutionnel.pdf').write_bytes(binary);p=PdfReader(io.BytesIO(binary));check('pdf_content',len(p.pages)==1 and 'Points' in p.pages[0].extract_text());check('pdf_logo',len(p.pages[0].images)>0)
check('stale_export_denied',work(x,'export',{'version':2})[0]==403)
sql(f"update uniion_private.agenda_audiences set audience='none' where organization_id='{org}' and user_id='{b['id']}';")
check('revoked_logo_read_denied',work(y,'document')[0]==403)
sql(f"update uniion_private.agenda_audiences set audience='adherents' where organization_id='{org}' and user_id='{b['id']}';")
app.sessions.clock=lambda: time.time()+122
from uniion.adapters import antivirus
check('real_antivirus_eicar_blocked',antivirus.scan(b'X5O!P%@AP[4'+bytes([92])+b'PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*')[0]=='infected')
try:api.request('/rest/v1/rpc/uniion_agenda_image_receipt',x.state()['access_token'],{'p_event':eid,'p_image':logo,'p_engine':'forged'});forged=True
except AccessDenied:forged=False
check('user_cannot_forge_scan_receipt',not forged)
st,other,_=x.call('/identity/agenda/save',{'organization_id':org,'event':{**e,'title':'Autre événement fictif — isolation logo'}});check('second_event_created',st==200)
otherdoc=work(x,'document',event=other['id'])[1]
try:api.request('/rest/v1/rpc/uniion_agenda_work',x.state()['access_token'],{'p_org':org,'p_event':other['id'],'p_action':'save_document','p_payload':{'version':1,'document':doc}});reused=True
except AccessDenied:reused=False
check('receipt_cannot_cross_events',not reused)
check('external_photo_url_denied',save(value={**doc,'blocks':[{'id':'photo','type':'studio.photo','text':'  https://example.invalid/image.png'}]},version=3)[0]==403)
from uniion.adapters.agenda_pdf import render
classic=render({**doc,'style':None},3);(out/'logo-classique.pdf').write_bytes(classic);check('classic_custom_logo_embedded',len(PdfReader(io.BytesIO(classic)).pages[0].images)>0)
(ROOT/'.local-auth/s03-logos-styles.json').write_text(json.dumps({'organization':org,'event':eid,'document':d['document']['id'],'version':3}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

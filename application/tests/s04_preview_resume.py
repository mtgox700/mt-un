from pathlib import Path
exec(compile(Path(__file__).with_name('s04_evidence.py').read_text().split("(out/'justificatif-fictif.txt')")[0],__file__,'exec'))
from unittest.mock import patch
from uniion.adapters import antivirus
from PIL import Image
from reportlab.pdfgen import canvas
from docx import Document
from openpyxl import Workbook
out=ROOT/'preuves/S04-apercu-reprise';out.mkdir(parents=True,exist_ok=True)
app.sessions.clock=lambda:time.time()+488
# A fictional interruption after bytes reached private Storage; real scanner resumed later.
def interrupted(name,content):
 p={'filename':name,'content':base64.b64encode(content).decode(),'request_id':str(uuid.uuid4())}
 with patch('uniion.adapters.antivirus.scan',side_effect=antivirus.ScanUnavailable('Recette interruption')):st,_,_=evidence(x,'upload',p)
 check('interruption_'+name,st==503)
 return next(f['id'] for f in evidence(x,'list')[1]['files'] if f['filename']==name)
buf=io.BytesIO();pdf=canvas.Canvas(buf);pdf.drawString(72,770,'Justificatif fictif - page 1');pdf.showPage();pdf.drawString(72,770,'Justificatif fictif - page 2');pdf.save();pdfraw=buf.getvalue();pending=interrupted('justificatif-deux-pages.pdf',pdfraw)
check('pending_preview_denied',evidence(x,'preview',{'id':pending,'page':1})[0]==403)
check('reader_resume_denied',evidence(y,'resume',{'id':pending})[0]==403)
check('foreign_resume_denied',evidence(y,'resume',{'id':pending},o=foreign)[0]==403)
check('resume_clean_success',evidence(x,'resume',{'id':pending})[0]==200)
count=sql(f"select count(*) from public.uniion_security_events where event='dues.evidence.scanned' and details->>'file'='{pending}'")
check('resume_idempotent',evidence(x,'resume',{'id':pending})[0]==200)
check('no_duplicate_result_audit',sql(f"select count(*) from public.uniion_security_events where event='dues.evidence.scanned' and details->>'file'='{pending}'")==count)
sql(f"delete from public.uniion_authorities where organization_id='{org}' and user_id='{a['id']}' and permission='download'")
st,v,_=evidence(x,'preview',{'id':pending,'page':1});check('preview_without_download',st==200 and v['pages']==2 and v['image'].startswith('data:image/png;base64,'))
check('download_still_denied',evidence(x,'download',{'id':pending})[0]==403)
for page in [0,-1,True,1.5,201]:check('bad_page_'+str(page),evidence(x,'preview',{'id':pending,'page':page})[0]==403)
st,v2,_=evidence(x,'preview',{'id':pending,'page':2});check('second_pdf_page',st==200 and v2['page']==2 and v2['image']!=v['image'])
check('nonfinancial_preview_denied',evidence(y,'preview',{'id':pending,'page':1})[0]==403)
check('foreign_preview_denied',evidence(y,'preview',{'id':pending,'page':1},o=foreign)[0]==403)
app.sessions.clock=lambda:time.time()+549
# Active-looking text is returned as inert text, not rendered HTML.
st,textview,_=evidence(x,'preview',{'id':aid,'page':1});check('plain_text_preview',st==200 and textview['text']==raw.decode() and textview['image']=='')
buf=io.BytesIO();Image.new('RGB',(100,80),(200,90,30)).save(buf,format='PNG');pngraw=buf.getvalue()
def upload_clean(name,content):
 st,ctx,_=evidence(x,'upload',{'filename':name,'content':base64.b64encode(content).decode(),'request_id':str(uuid.uuid4())});check('upload_'+name,st==200);return next(f['id'] for f in ctx['files'] if f['filename']==name)
imageid=upload_clean('image-fictive.png',pngraw)
check('image_preview',evidence(x,'preview',{'id':imageid,'page':1})[1]['image'].startswith('data:image/png'))
for ext in ('docx','xlsx'):
 buf=io.BytesIO();doc=Document() if ext=='docx' else Workbook()
 if ext=='docx':doc.add_paragraph('Justificatif Word fictif')
 else:doc.active['A1']='Justificatif Excel fictif';doc.active['B1']=12.5
 doc.save(buf);fid=upload_clean('document-fictif.'+ext,buf.getvalue());st,r,_=evidence(x,'preview',{'id':fid,'page':1});check('inert_office_'+ext,st==200 and 'Justificatif' in r['text'] and r['image']=='')
# A file interrupted before a positive scan still gets blocked on actual restart.
infected=interrupted('interruption-eicar.txt',eicar)
check('resume_detects_infection',evidence(x,'resume',{'id':infected})[0]==403)
check('blocked_resume_denied',evidence(x,'resume',{'id':infected})[0]==403)
check('blocked_preview_denied',evidence(x,'preview',{'id':infected,'page':1})[0]==403)
app.sessions.clock=lambda:time.time()+610
# Prepare three real pending PDFs for the responsive UI recipe; no rights are broadened.
pending_ui=[interrupted('reprise-'+label+'.pdf',pdfraw) for label in ('mobile','tablette','desktop')]
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('revoked_preview_denied',evidence(x,'preview',{'id':pending,'page':1})[0]==403)
check('revoked_resume_denied',evidence(x,'resume',{'id':pending_ui[0]})[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
(out/'justificatif-deux-pages.pdf').write_bytes(pdfraw);(out/'image-fictive.png').write_bytes(pngraw)
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2))
(ROOT/'.local-auth/s04-preview.json').write_text(json.dumps({'organization':org,'payment':pid,'adherent':row['id'],'pdf':pending,'pending':pending_ui}))
print(json.dumps({'passed':True,'count':len(checks)}))

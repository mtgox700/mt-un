"""Isolated product PDF process for the bundled extension; not browser/UI automation."""
import base64,json,os,re,subprocess,tempfile,threading,unicodedata
from pathlib import Path
from io import BytesIO
from pypdf import PdfReader,PdfWriter
from .document_images import image_bytes
from uniion.core.contracts import Denied,Unavailable,PDFOverflow,PDFContentMissing
ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'uniion/assets'
LOCK=threading.BoundedSemaphore(2)
def _tool(variable,default,*names):
 # Configurable path (R2): explicit variable, then historical local path, then PATH lookup.
 import shutil
 value=os.environ.get(variable)
 if value:return value
 if os.path.exists(default):return default
 return next((found for found in map(shutil.which,names) if found),default)
NODE=_tool('UNIION_NODE','/Users/mt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node','node')
CHROME=_tool('UNIION_PDF_CHROME','/Applications/Google Chrome.app/Contents/MacOS/Google Chrome','chromium','chromium-browser','google-chrome')
GEORGIA_DIR=Path(os.environ.get('UNIION_GEORGIA_DIR','/System/Library/Fonts/Supplemental'))

def render(document,version):
 catalog=json.loads((ASSETS/'studio-catalog.json').read_text())
 if document.get('style') and document.get('style') not in {x['id'] for x in catalog['styles']}:raise Denied()
 for block in document['blocks']:
  if block.get('img'):image_bytes(block['img'])
  # Photo URLs cannot create implicit data transfers or silently disappear from the PDF.
  if block['type']=='studio.photo' and re.match(r'(https?:|data:)',block.get('text','').lstrip()):raise Denied()
 logo=document['charte']['logo']
 if logo=='uniion-logo.png':logo='data:image/png;base64,'+base64.b64encode((ASSETS/'uniion-logo.png').read_bytes()).decode()
 elif logo:image_bytes(logo)
 fonts=(ASSETS/'fonts/studio/fonts.css').read_text()
 fonts=re.sub(r'url\(([a-f0-9]+\.ttf)\)',lambda m:'url(data:font/ttf;base64,'+base64.b64encode((ASSETS/'fonts/studio'/m[1]).read_bytes()).decode()+')',fonts)
 if not document.get('style'):
  for family in ('Philosopher','Inter','Montserrat','Lora','Georgia'):
   for variant,weight,italic in [('Regular',400,'normal'),('Bold',700,'normal'),('Italic',400,'italic')]:
    path=ASSETS/'fonts'/f'{family}-{variant}.ttf'
    if family=='Georgia':path=GEORGIA_DIR/('Georgia'+({'Regular':'','Bold':' Bold','Italic':' Italic'}[variant])+'.ttf')
    if path.exists():fonts+='@font-face{font-family:'+family+';font-weight:'+str(weight)+';font-style:'+italic+';src:url(data:font/ttf;base64,'+base64.b64encode(path.read_bytes()).decode()+')}';
 if not LOCK.acquire(blocking=False):raise Unavailable()
 try:
  payload=json.dumps({'document':document,'fonts':fonts,'logo':logo}).encode()
  result=subprocess.run([NODE,str(ROOT/'frontend/extensions/pdf-render.mjs')],input=payload,capture_output=True,timeout=20)
  if result.returncode or len(result.stdout)>20*1024*1024:raise Denied()
  with tempfile.TemporaryDirectory(prefix='uniion-pdf-') as folder:
   directory=Path(folder);source=directory/'document.html';source.write_bytes(result.stdout);target=directory/'document.pdf'
   # Dedicated ephemeral profile, no user profile, no remote debugging port, no external URL.
   args=[CHROME,'--headless','--disable-gpu','--no-first-run','--disable-extensions','--disable-background-networking','--disable-component-update','--disable-sync','--no-pdf-header-footer','--run-all-compositor-stages-before-draw','--virtual-time-budget=3000','--host-resolver-rules=MAP * ~NOTFOUND','--proxy-server=http://127.0.0.1:9','--user-data-dir='+str(directory/'profile'),'--print-to-pdf='+str(target),source.as_uri()]
   process=subprocess.run(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=40)
   if process.returncode or not target.exists() or target.stat().st_size>20*1024*1024:raise Unavailable()
   pdf=PdfReader(target)
   if any('UNIION_PDF_OVERFLOW_BLOCKED' in page.extract_text() for page in pdf.pages):raise PDFOverflow()
   norm=lambda text: ''.join(c for c in unicodedata.normalize('NFKC',text).casefold() if c.isalnum())
   text=norm(' '.join(page.extract_text() for page in pdf.pages))
   parts=re.search(rb'<meta name="uniion-text-parts" content="([A-Za-z0-9+/=]+)">',result.stdout)
   if not parts:raise PDFContentMissing()
   for value in json.loads(base64.b64decode(parts[1])):
    for line in value.splitlines():
     if norm(line) and norm(line) not in text:raise PDFContentMissing()
   writer=PdfWriter();writer.append_pages_from_reader(pdf);writer.add_metadata({'/Title':document['title'],'/Subject':'Ordre du jour — version '+str(version)})
   output=BytesIO();writer.write(output);return output.getvalue()
 except (OSError,subprocess.TimeoutExpired):raise Unavailable() from None
 finally:LOCK.release()

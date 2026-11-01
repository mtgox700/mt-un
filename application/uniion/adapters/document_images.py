"""Event-scoped scanner receipts: direct database writes cannot bypass image validation."""
import base64,re
from . import antivirus
from uniion.core.contracts import Denied,Unavailable

def image_bytes(value):
 if not isinstance(value,str) or len(value)>2800000:raise Denied()
 match=re.fullmatch(r'data:image/(png|jpeg|svg\+xml);base64,([A-Za-z0-9+/]+={0,2})',value)
 if not match:raise Denied()
 try:raw=base64.b64decode(match[2],validate=True)
 except ValueError:raise Denied() from None
 if len(raw)>2*1024*1024:raise Denied()
 if match[1]=='png' and not raw.startswith(b'\x89PNG\r\n\x1a\n'):raise Denied()
 if match[1]=='jpeg' and not raw.startswith(b'\xff\xd8\xff'):raise Denied()
 if match[1]=='svg+xml':
  from .safe_svg import validate
  validate(raw)
 return raw,'image/'+match[1]

def certify(api,token,event,document,current,scope="agenda"):
 if scope not in ("agenda","document","document_defaults"):raise Denied()
 if not isinstance(document,dict) or not isinstance(document.get("blocks",[]),list) or any(not isinstance(b,dict) for b in document.get("blocks",[])) or not isinstance(document.get("charte",{}),dict):raise Denied()
 images=[document.get('charte',{}).get('logo','')]+[b.get('img','') for b in document.get('blocks',[])]
 if any(not isinstance(value,str) for value in images):raise Denied()
 known={current.get('charte',{}).get('logo',''),*(b.get('img','') for b in current.get('blocks',[]))}
 for value in set(images):
  if value in ('','uniion-logo.png') or value in known:continue
  raw,mime=image_bytes(value)
  try:
   status,engine,_=antivirus.scan(raw)
   if status!='clean':raise Denied()
   if mime!='image/svg+xml':antivirus.renderer(raw,mime)
  except antivirus.FileBlocked:raise Denied() from None
  except antivirus.ScanUnavailable:raise Unavailable() from None
  # Receipt only follows the existing isolated, networkless decoder.
  api.request('/rest/v1/rpc/uniion_'+scope+'_image_receipt',antivirus.worker_token(api),{('p_event' if scope=='agenda' else 'p_document'):event,'p_image':value,'p_engine':engine})

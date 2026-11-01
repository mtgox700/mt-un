"""Reference document geometry in CSS pixels, rendered at 96 dpi with embedded fonts.
No remote URL, HTML input or arbitrary filesystem resource is accepted.
"""
from io import BytesIO
from pathlib import Path
from html import escape
from reportlab.pdfgen.canvas import Canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor,Color
from uniion.core.contracts import Denied,PDFOverflow

ASSETS=Path(__file__).resolve().parents[1]/'assets'
FORMATS={'a4':(794,1123,54,1),'a5':(559,794,38,.92),'wide':(1123,632,58,1.22)}
for family in ('Philosopher','Inter','Montserrat','Lora'):
 for weight in ('Regular','Bold','Italic'):
  pdfmetrics.registerFont(TTFont(family+'-'+weight,str(ASSETS/'fonts'/f'{family}-{weight}.ttf')))

for weight,suffix in [('Regular',''),('Bold',' Bold'),('Italic',' Italic')]:
 path=Path('/System/Library/Fonts/Supplemental/Georgia'+suffix+'.ttf')
 if path.exists():pdfmetrics.registerFont(TTFont('Georgia-'+weight,str(path)))

def render(document,version):
 if document.get('style') or 'svg+xml' in document.get('charte',{}).get('logo','') or any(b['type'].startswith('studio.') for b in document['blocks']):
  from .studio_pdf import render as studio_render
  return studio_render(document,version)
 if document['format'] not in FORMATS:raise Denied()
 charte=document.get('charte')
 if not charte:raise Denied() # Never silently export an older document with an invented charter.
 if any(name.title()+'-Regular' not in pdfmetrics.getRegisteredFontNames() for name in (charte['titleFont'],charte['bodyFont'])):raise Denied()
 w,h,pad,scale=FORMATS[document['format']];scale*= {'compact':.92,'confort':1.1}.get(charte['density'],1)
 pages=[[]]
 for block in document['blocks']:
  if block['type']=='pagebreak':pages.append([])
  else:pages[-1].append(block)
 if len(pages)>1 and not pages[-1]:pages.pop()
 out=BytesIO();canvas=Canvas(out,pagesize=(w*.75,h*.75));canvas.setTitle(document['title']);canvas.setSubject('Ordre du jour — version '+str(version))
 accent=HexColor(charte['accent']);ink=HexColor(charte['ink']);muted=HexColor('#6b7280');border=HexColor('#e5e7eb')
 head=charte['titleFont'].title();body=charte['bodyFont'].title()
 def paragraph(text,x,y,width,size,leading,font,color=ink):
  st=ParagraphStyle('block',fontName=font,fontSize=size,leading=size*leading,textColor=color,spaceBefore=0,spaceAfter=0)
  para=Paragraph(escape(text).replace('\n','<br/>') or ' ',st);_,height=para.wrap(width,h*10)
  para.drawOn(canvas,x,h-y-height);return height
 def rule(y,color,thickness=1,x=pad,width=None):
  canvas.setStrokeColor(color);canvas.setLineWidth(thickness);canvas.line(x,h-y,x+(w-2*pad if width is None else width),h-y)
 for number,blocks in enumerate(pages,1):
  canvas.saveState();canvas.scale(.75,.75);y=pad;width=w-2*pad
  if charte['header']:
   hh=paragraph(charte['emetteur'].upper(),pad,y,width-154*scale,12.5*scale,1.2,head+'-Bold')
   hh+=2*scale+paragraph(charte['section'],pad,y+hh+2*scale,width-154*scale,10.5*scale,1.2,body+'-Regular',muted)
   headerheight=max(hh,38*scale if charte['logo'] else 0)
   if charte['logo']:
    logo=str(ASSETS/'uniion-logo.png')
    if charte['logo']!='uniion-logo.png':
     from .document_images import image_bytes
     from reportlab.lib.utils import ImageReader
     logo=ImageReader(BytesIO(image_bytes(charte['logo'])[0]))
    canvas.drawImage(logo,w-pad-140*scale,h-y-38*scale,width=140*scale,height=38*scale,preserveAspectRatio=True,anchor='e',mask='auto')
   y+=headerheight+9*scale;rule(y,accent,2);y+=2+18*scale
  limit=h-pad-(36*scale if charte['footer'] else 0)
  previous_margin=0
  for block in blocks:
   typ,text=block['type'],block['text'];font=body+'-Regular'
   top=(13 if typ=='h2' else 10 if typ=='h3' else 0)*scale
   y-=min(previous_margin,top)
   previous_margin={'h1':11,'h2':6,'h3':5,'p':9,'ul':11,'quote':12,'table':12,'tag':9}.get(typ,9)*scale
   if typ=='h1':
    y+=paragraph(text.upper() if charte['caps'] else text,pad,y,width,26*scale,1.18,head+'-Bold',accent)+6*scale;rule(y,accent,2);y+=2+11*scale
   elif typ in ('h2','h3'):
    y+=(13 if typ=='h2' else 10)*scale;y+=paragraph(text,pad,y,width,(18.5 if typ=='h2' else 15)*scale,1.3 if typ=='h2' else 1.35,head+'-Bold',ink if typ=='h2' else accent)+(6 if typ=='h2' else 5)*scale
   elif typ=='ul':
    for line in filter(str.strip,text.splitlines()):
     paragraph('■',pad,y,width,7*scale,20/7,font,accent);y+=paragraph(line.strip(),pad+15*scale,y,width-15*scale,13*scale,1.55,font)+5*scale
    y+=6*scale
   elif typ=='quote':
    st=ParagraphStyle('quote',fontName=body+'-Italic',fontSize=12.5*scale,leading=20*scale,textColor=ink)
    para=Paragraph(escape(text).replace('\n','<br/>'),st);_,ph=para.wrap(width-28*scale,h*10);height=ph+22*scale
    canvas.setFillColor(Color(accent.red,accent.green,accent.blue,alpha=.07));canvas.roundRect(pad,h-y-height,width,height,10,stroke=0,fill=1);canvas.setFillColor(accent);canvas.rect(pad,h-y-height,3,height,stroke=0,fill=1);para.drawOn(canvas,pad+14*scale,h-y-11*scale-ph);y+=height+12*scale
   elif typ=='table':
    rows=[line.split('|') for line in text.splitlines() if line.strip()];cols=len(rows[0]) if rows else 1;cw=width/cols
    for ri,row in enumerate(rows):
     cells=[];rh=0
     for ci in range(cols):
      value=row[ci].strip() if ci<len(row) else '';value=value.upper() if ri==0 else value
      st=ParagraphStyle('cell',fontName=body+('-Bold' if ri==0 else '-Regular'),fontSize=(10 if ri==0 else 11.5)*scale,leading=(12 if ri==0 else 16.675)*scale,textColor=HexColor('#ffffff') if ri==0 else ink)
      para=Paragraph(escape(value) or ' ',st);_,ph=para.wrap(cw-18*scale,h*10);cells.append((para,ph));rh=max(rh,ph+14*scale)
     canvas.setFillColor(accent if ri==0 else HexColor('#f9fafb' if ri%2==0 else '#ffffff'));canvas.rect(pad,h-y-rh,width,rh,stroke=0,fill=1)
     for ci,(para,ph) in enumerate(cells):para.drawOn(canvas,pad+ci*cw+9*scale,h-y-7*scale-ph)
     y+=rh;rule(y,border)
    y+=12*scale
   elif typ=='tag':
    tw=min(width,pdfmetrics.stringWidth(text.upper(),body+'-Bold',9.5*scale)+16*scale);th=18*scale
    canvas.setFillColor(Color(accent.red,accent.green,accent.blue,alpha=.1));canvas.setStrokeColor(accent);canvas.rect(pad,h-y-th,tw,th,stroke=1,fill=1);paragraph(text.upper(),pad+8*scale,y+3*scale,tw-16*scale,9.5*scale,1.2,body+'-Bold',accent);y+=th+9*scale
   else:y+=paragraph(text,pad,y,width,13*scale,1.62,font)+9*scale
   if y>limit:raise PDFOverflow() # Explicit page breaks, as in the editor; never truncate a page.
  if charte['footer']:
   fy=h-pad-22*scale;rule(fy,border);paragraph(charte['email']+' — '+charte['phone'],pad,fy+9*scale,width-100*scale,9.5*scale,1.2,body+'-Regular',muted)
   label=f'Page {number} / {len(pages)}';tw=pdfmetrics.stringWidth(label,body+'-Bold',9.5*scale);paragraph(label,w-pad-tw,fy+9*scale,tw+1,9.5*scale,1.2,body+'-Bold',accent)
  canvas.restoreState();canvas.showPage()
 canvas.save();return out.getvalue()

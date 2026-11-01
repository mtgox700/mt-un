"""Read-only previews: raster images or bounded inert text, never source HTML."""
import base64,io,math,zipfile,xml.etree.ElementTree as ET
from . import antivirus,office_files
from uniion.core.contracts import Denied
PAGE=6000
LIMIT=120000

def render(raw,mime,page):
 if type(page) is not int or not 1<=page<=200:raise Denied()
 if mime in ('application/pdf','image/png','image/jpeg'):
  result=antivirus.renderer(raw,mime,page,True)
  return {'page':result['page'],'pages':result['pages'],'image':'data:image/png;base64,'+result['png'],'text':'','note':'Aperçu rendu sur le serveur.'}
 if mime=='text/plain':text=raw.decode('utf-8');note='Aperçu texte.'
 elif mime in office_files.MIMES.values():
  ext=next(k for k,v in office_files.MIMES.items() if v==mime);office_files.validate(raw,ext)
  with zipfile.ZipFile(io.BytesIO(raw)) as archive:
   if ext=='docx':
    root=ET.fromstring(archive.read('word/document.xml'))
    text='\n'.join(''.join(e.text or '' for e in p.iter() if e.tag.rsplit('}',1)[-1]=='t') for p in root.iter() if p.tag.rsplit('}',1)[-1]=='p')
   else:
    shared=[]
    if 'xl/sharedStrings.xml' in archive.namelist():
     shared=[''.join(e.text or '' for e in si.iter() if e.tag.rsplit('}',1)[-1]=='t') for si in ET.fromstring(archive.read('xl/sharedStrings.xml'))]
    lines=[];length=0
    for name in sorted(n for n in archive.namelist() if n.startswith('xl/worksheets/') and n.endswith('.xml')):
     lines.append(name)
     for row in ET.fromstring(archive.read(name)).iter():
      if row.tag.rsplit('}',1)[-1]!='row':continue
      cells=[]
      for c in row:
       val=''.join(e.text or '' for e in c.iter() if e.tag.rsplit('}',1)[-1] in ('v','t'))
       if c.get('t')=='s':
        try:val=shared[int(val)]
        except (ValueError,IndexError):val='[valeur indisponible]'
       if any(e.tag.rsplit('}',1)[-1]=='f' for e in c):val+=' [résultat mémorisé, non recalculé]'
       cells.append(c.get('r','')+': '+val)
      line=' | '.join(cells);lines.append(line);length+=len(line)
      if length>LIMIT:break
     if length>LIMIT:break
    text='\n'.join(lines)
  note='Aperçu texte extrait ; mise en page, images et calculs du document non reproduits.'
 else:raise Denied()
 truncated=len(text)>LIMIT;text=text[:LIMIT];pages=max(1,math.ceil(len(text)/PAGE))
 if page>pages:raise Denied()
 return {'page':page,'pages':pages,'image':'','text':text[(page-1)*PAGE:page*PAGE] or '(Document sans texte extractible)','note':note+(' Extrait limité à 120 000 caractères.' if truncated else '')}

"""Bounded, non-executing validation of macro-free OOXML attachments."""
import io,zipfile,xml.etree.ElementTree as ET
MIMES={'docx':'application/vnd.openxmlformats-officedocument.wordprocessingml.document','xlsx':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}
def validate(raw,extension):
 try:
  with zipfile.ZipFile(io.BytesIO(raw)) as archive:
   entries=archive.infolist();names=[i.filename for i in entries]
   if not 3<=len(entries)<=1000 or len(set(names))!=len(names) or sum(i.file_size for i in entries)>25*1024*1024:raise ValueError()
   for item in entries:
    n=item.filename
    if n.startswith('/') or '\\' in n or '..' in n.split('/') or item.flag_bits&1 or item.compress_type not in (0,8) or item.file_size>10*1024*1024 or item.file_size>max(1,item.compress_size)*200:raise ValueError()
    if any(t in n.lower() for t in ('vbaproject','activex','embeddings/','externallinks/','macrosheets/','dialogsheets/')):raise ValueError()
   main='word/document.xml' if extension=='docx' else 'xl/workbook.xml'
   if main not in names or '[Content_Types].xml' not in names or '_rels/.rels' not in names:raise ValueError()
   roots={}
   for item in entries:
    data=archive.read(item)
    if item.filename.lower().endswith('.bin'):raise ValueError()
    if item.filename.endswith(('.xml','.rels')):
     if b'<!DOCTYPE' in data.upper() or b'<!ENTITY' in data.upper() or b'\x00' in data:raise ValueError()
     root=ET.fromstring(data);roots[item.filename]=root
     for el in root.iter():
      if 'macroenabled' in el.attrib.get('ContentType','').lower() or 'vba' in el.attrib.get('ContentType','').lower():raise ValueError()
      if el.tag.endswith('Relationship'):
       target=el.attrib.get('Target','');kind=el.attrib.get('Type','').rsplit('/',1)[-1]
       if el.attrib.get('TargetMode')=='External' and kind!='hyperlink':raise ValueError()
       if kind in ('oleObject','package','attachedTemplate','aFChunk','control'):raise ValueError()
      if el.tag.rsplit('}',1)[-1] in ('DDE','ddeLink','oleLink','altChunk'):raise ValueError()
      if el.tag.rsplit('}',1)[-1] in ('instrText','f') and any(t in (el.text or '').upper() for t in ('DDE','WEBSERVICE(', 'RTD(')):raise ValueError()
   types=roots['[Content_Types].xml']
   expected='application/vnd.openxmlformats-officedocument.'+('wordprocessingml.document.main+xml' if extension=='docx' else 'spreadsheetml.sheet.main+xml')
   if not any(e.attrib.get('PartName')=='/'+main and e.attrib.get('ContentType')==expected for e in types):raise ValueError()
   if not any(e.attrib.get('Type','').endswith('/officeDocument') and e.attrib.get('Target','').lstrip('/')==main for e in roots['_rels/.rels']):raise ValueError()
   return MIMES[extension]
 except (ValueError,KeyError,zipfile.BadZipFile,RuntimeError,ET.ParseError,NotImplementedError):raise ValueError('Document Office invalide, actif, chiffré ou hors limites') from None

"""Local, dependency-free exports. No network and no macros/formulas."""
import csv, io, textwrap, zipfile
from xml.sax.saxutils import escape

def pdf(title, lines):
    text = [title, ''] + [str(x) for x in lines]
    wrapped = []
    for line in text:
        wrapped.extend(textwrap.wrap(line, 92) or [''])
    pages = [wrapped[i:i+48] for i in range(0,len(wrapped),48)] or [[]]
    objects = [b'', b'', b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>']
    kids=[]
    for page in pages:
        pid=len(objects)+1; cid=pid+1; kids.append(f'{pid} 0 R')
        commands=['BT /F1 11 Tf 48 790 Td 15 TL']
        for line in page:
            encoded=line.encode('cp1252','replace').decode('latin1').replace('\\','\\\\').replace('(','\\(').replace(')','\\)')
            commands.append('('+encoded+') Tj T*')
        commands.append('ET'); stream='\n'.join(commands).encode('latin1')
        objects.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents {cid} 0 R >>'.encode())
        objects.append(b'<< /Length '+str(len(stream)).encode()+b' >>\nstream\n'+stream+b'\nendstream')
    objects[0]=b'<< /Type /Catalog /Pages 2 0 R >>'
    objects[1]=f'<< /Type /Pages /Count {len(pages)} /Kids [{" ".join(kids)}] >>'.encode()
    data=bytearray(b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n'); offsets=[0]
    for i,obj in enumerate(objects,1):
        offsets.append(len(data));data.extend(f'{i} 0 obj\n'.encode()+obj+b'\nendobj\n')
    xref=len(data);data.extend(f'xref\n0 {len(offsets)}\n0000000000 65535 f \n'.encode())
    for off in offsets[1:]:data.extend(f'{off:010d} 00000 n \n'.encode())
    data.extend(f'trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode())
    return bytes(data)

def xlsx(sheets):
    def clean(v):return escape(''.join(c for c in str(v if v is not None else '') if ord(c)>=32 or c in '\n\t\r'))
    stream=io.BytesIO()
    with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml','<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'+''.join(f'<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for i in range(1,len(sheets)+1))+'</Types>')
        z.writestr('_rels/.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        z.writestr('xl/workbook.xml','<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'+''.join(f'<sheet name="{clean(s["name"]).replace(chr(34),"&quot;")}" sheetId="{i}" r:id="rId{i}"/>' for i,s in enumerate(sheets,1))+'</sheets></workbook>')
        z.writestr('xl/_rels/workbook.xml.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+''.join(f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>' for i in range(1,len(sheets)+1))+'</Relationships>')
        for i,s in enumerate(sheets,1):
            rows=''.join('<row>'+''.join('<c t="inlineStr"><is><t xml:space="preserve">'+clean(v)+'</t></is></c>' for v in row)+'</row>' for row in s['rows'])
            z.writestr(f'xl/worksheets/sheet{i}.xml','<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'+rows+'</sheetData></worksheet>')
    return stream.getvalue()

def export_file(data):
    fmt=data.get('format');sheets=data.get('sheets',[])
    if not isinstance(sheets,list) or len(sheets)>20:raise ValueError('Onglets invalides')
    for sheet in sheets:
        if not isinstance(sheet,dict) or not isinstance(sheet.get('rows'),list) or not isinstance(sheet.get('name'),str):raise ValueError('Tableau invalide')
        if any(not isinstance(r,list) for r in sheet['rows']):raise ValueError('Ligne invalide')
    if fmt=='xlsx':return xlsx(sheets),'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    if fmt=='csv':
        stream=io.StringIO();writer=csv.writer(stream,delimiter=';')
        for s in sheets:
            writer.writerow([s['name']])
            for row in s['rows']:
                writer.writerow([("'"+str(x)) if str(x).lstrip().startswith(('=','+','-','@')) else x for x in row])
            writer.writerow([])
        return ('\ufeff'+stream.getvalue()).encode('utf-8'),'text/csv; charset=utf-8'
    if fmt=='pdf':
        lines=data.get('lines',[])
        if not isinstance(lines,list):raise ValueError('Texte invalide')
        for s in sheets:lines=lines+[s['name']]+[' | '.join(str(v) for v in r) for r in s['rows']]
        return pdf(str(data.get('title','Export uniion')),lines),'application/pdf'
    raise ValueError('Format non pris en charge')

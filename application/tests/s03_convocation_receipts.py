"""Inspect only the three fictional messages created by the UI recipe."""
import json,urllib.request,urllib.parse,email,email.policy,io
from pathlib import Path
from pypdf import PdfReader
root=Path(__file__).resolve().parents[1];out=root/'preuves/S03-convocations-pieces'
f=json.loads((root/'.local-auth/s02-browser-fixture.json').read_text());results=[]
for size in ('mobile','tablette','desktop'):
 subject='Recette UI '+size+' — convocations pièces S03'
 q=urllib.parse.quote('subject:"'+subject+'"')
 with urllib.request.urlopen('http://127.0.0.1:54324/api/v1/search?query='+q) as r:rows=json.load(r)['messages']
 assert len(rows)==1
 with urllib.request.urlopen('http://127.0.0.1:54324/api/v1/message/'+rows[0]['ID']+'/raw') as r:message=email.message_from_bytes(r.read(),policy=email.policy.default)
 assert f['recipient'] in str(message['To']) and f['email'] not in str(message['To'])
 parts={a.get_filename():a.get_payload(decode=True) for a in message.iter_attachments()}
 assert set(parts)=={'ordre-du-jour.pdf','evenement.ics'}
 pdf=PdfReader(io.BytesIO(parts['ordre-du-jour.pdf']));assert len(pdf.pages)>=1 and 'Ordre du jour' in pdf.pages[0].extract_text()
 assert b'BEGIN:VCALENDAR' in parts['evenement.ics'] and b'DTSTART:' in parts['evenement.ics']
 (out/(size+'.pdf')).write_bytes(parts['ordre-du-jour.pdf']);(out/(size+'.ics')).write_bytes(parts['evenement.ics'])
 results.append({'viewport':size,'one_message':True,'selected_recipient_only':True,'pdf_pages':len(pdf.pages),'ics_valid':True})
(out/'mail-receipts.json').write_text(json.dumps(results,indent=2));print('3 messages vérifiés, PDF et ICS décodés, destinataire unique confirmé.')

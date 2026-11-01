from pathlib import Path
import json,io
from pypdf import PdfReader
from uniion.adapters.agenda_pdf import render
from uniion.core.contracts import PDFOverflow
from test_agenda_pdf import CHARTER
out=Path(__file__).resolve().parents[1]/'preuves/S03-paysage';results=[]
fixtures={
'choc':[('tag','Section fictive'),('h1','Ensemble pour nos droits'),('studio.chiffre','68 %\nParticipation'),('ul','Des salaires justes\nDe meilleures conditions'),('quote','Assemblée le 20 novembre')],
'satirique':[('tag','La Gazette'),('h1','Réunion : les élus prennent la parole'),('p','Un échange fictif pour préparer les prochaines négociations.'),('studio.bulles','La direction : Nous vous écoutons.\nLes élus : Passons aux actes.'),('h2','Nos priorités'),('p','Salaires et conditions de travail.'),('studio.exige','FO exige !\nUn calendrier clair\nDes réponses concrètes')],
'bd':[('h1','Les aventures de la section'),('studio.bulles','La direction : Une question ?\nUn collègue : Et les salaires ?\nLes élus : Négocions ensemble.'),('quote','À vous de jouer !\nAssemblée le 20 novembre')]}
for style,pairs in fixtures.items():
 blocks=[{'id':str(i),'type':t,'text':v} for i,(t,v) in enumerate(pairs)]
 doc={'title':'Recette paysage '+style,'format':'wide','style':style,'charte':CHARTER,'blocks':blocks}
 raw=render(doc,1);pdf=PdfReader(io.BytesIO(raw));assert len(pdf.pages)==1;(out/(style+'.pdf')).write_bytes(raw);results.append({'style':style,'normal':True})
 long={**doc,'blocks':[{'type':'h1','text':'Un très long titre qui dépasse le cadre. '*60}]}
 try:render(long,2);blocked=False
 except PDFOverflow:blocked=True
 assert blocked;results[-1]['overflow_blocked']=True
(out/'representatifs.json').write_text(json.dumps(results,indent=2));print('3 paysages représentatifs exportés ; 3 débordements refusés')

"""Authorized, version-checked receipts and CSVs. No external delivery."""
import base64,csv,io
from pathlib import Path
from html import escape
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from uniion.core.contracts import Denied

def money(cents):return f'{cents//100},{cents%100:02d}'
def csv_cell(value):
 text=str(value if value is not None else '').replace('\x00','')
 if text and (text[0] in '\t\r\n' or text.lstrip()[:1] in ('=','+','-','@')):text="'"+text
 return text

def csv_bytes(data):
 out=io.StringIO(newline='');writer=csv.writer(out,delimiter=';',quoting=csv.QUOTE_ALL,lineterminator='\r\n')
 writer.writerow(['Organisation','Adhérent','Règlement','Période','Date effective','Date de déclaration','Montant initial EUR','Montant retenu EUR','Révision','État'])
 for p in data['payments']:
  writer.writerow([csv_cell(v) for v in [data['organization'],data['member'],p['id'],p['period'],p['effectiveOn'] or 'Non renseignée',p['recordedAt'],money(p['originalCents']),money(p['cents']),p['revision'],'Annulé' if p['cents']==0 else 'Déclaré']])
 return ('\ufeff'+out.getvalue()).encode('utf-8')

def receipt_pdf(receipt):
 fonts=Path(__file__).resolve().parents[1]/'assets/fonts'
 for family in ('Inter','Philosopher'):
  for weight in ('Regular','Bold'):pdfmetrics.registerFont(TTFont(family+'-'+weight,str(fonts/(family+'-'+weight+'.ttf'))))
 body=ParagraphStyle('body',fontName='Inter-Regular',fontSize=10,leading=16,textColor=colors.HexColor('#27323b'),spaceAfter=10)
 title=ParagraphStyle('title',parent=body,fontName='Philosopher-Bold',fontSize=25,leading=30,spaceAfter=18)
 muted=ParagraphStyle('muted',parent=body,fontSize=8,leading=12,textColor=colors.HexColor('#66717d'))
 def p(value,style=body):return Paragraph(escape(str(value)).replace('\n','<br/>'),style)
 d=receipt['data'];pay=d['payment'];out=io.BytesIO()
 doc=SimpleDocTemplate(out,pagesize=(595.28,841.89),rightMargin=48,leftMargin=48,topMargin=48,bottomMargin=50,title='Reçu de règlement',author='uniion',invariant=1)
 rows=[('Organisation',d['organization']),('Adhérent',d['member']),('Montant déclaré',money(pay['cents'])+' EUR'),('Date effective',pay['effectiveOn']),('Période de cotisation',pay['period']),('Date de déclaration',pay['recordedAt'][:10]),('Révision du règlement',str(pay['revision'])),('Référence du règlement',pay['id'])]
 table=Table([[p(k,muted),p(v)] for k,v in rows],colWidths=[145,354.28],hAlign='LEFT')
 table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#f7f8fa')),('LEFTPADDING',(0,0),(-1,-1),12),('RIGHTPADDING',(0,0),(-1,-1),12),('TOPPADDING',(0,0),(-1,-1),9),('BOTTOMPADDING',(0,0),(-1,-1),6),('LINEBELOW',(0,0),(-1,-1),.4,colors.HexColor('#e4e7eb'))]))
 story=[p('uniion',ParagraphStyle('brand',parent=title,textColor=colors.HexColor('#ce4d2c'),fontSize=22)),p('Reçu de règlement',title),p('Document non fiscal',ParagraphStyle('badge',parent=body,textColor=colors.HexColor('#b73e27'),fontName='Inter-Bold')),p('Référence : '+receipt['id'],muted),p('Établi le '+receipt['createdAt'][:10],muted),Spacer(1,12),table,Spacer(1,20),p('Ce reçu reprend un règlement déclaré dans uniion. Il ne constitue ni une preuve de transaction bancaire ni une attestation fiscale.'),p('Il correspond à la révision indiquée ci-dessus. Une correction ultérieure peut modifier ou annuler les informations déclarées ; consultez le registre à jour.',muted)]
 def footer(canvas,doc):
  canvas.setStrokeColor(colors.HexColor('#dc6835'));canvas.line(48,38,547,38);canvas.setFont('Inter-Regular',8);canvas.setFillColor(colors.HexColor('#66717d'));canvas.drawString(48,25,'uniion · Reçu de règlement non fiscal');canvas.drawRightString(547,25,str(doc.page))
 doc.build(story,onFirstPage=footer,onLaterPages=footer);return out.getvalue()

def dispatch(api,token,org,action,payload):
 def rpc(action,p):return api.request('/rest/v1/rpc/uniion_dues_export',token,{'p_org':org,'p_action':action,'p_payload':p})
 if action=='export_csv':
  if set(payload)!={'member'}:raise Denied()
  result=rpc('csv',payload);raw=csv_bytes(result['data']);rpc('csv_finish',{**payload,'hash':result['hash']});name='reglements-'+result['data']['memberId']+'.csv';mime='text/csv;charset=utf-8'
 elif action=='receipt':
  if set(payload)!={'payment'}:raise Denied()
  result=rpc('receipt',payload);raw=receipt_pdf(result);rpc('receipt_finish',{**payload,'receipt':result['id']});name='recu-'+result['id']+'.pdf';mime='application/pdf'
 else:raise Denied()
 return {'filename':name,'mime':mime,'content':base64.b64encode(raw).decode()}

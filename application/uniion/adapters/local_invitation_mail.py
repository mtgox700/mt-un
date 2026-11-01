"""Delivery to the local capture mailbox only; never an external SMTP service."""
import json,re,urllib.request
from uniion.core.contracts import Denied,Unavailable
from .identity import dispatch

def send(api,token,data,resend=False):
 if set(data)!=({'organization_id','invitation_id'} if resend else {'organization_id','email'}):raise Denied()
 ticket=dispatch(api,token,'/identity/invitations/resend',data) if resend else None
 email=ticket['email'] if resend else data.get('email','')
 if not isinstance(email,str) or not re.fullmatch(r'[^\s@]+@(?:uniion-local\.example|example\.invalid)',email,re.I):raise Denied()
 if not resend:ticket=dispatch(api,token,'/identity/invitations/create',data)
 from uniion.http_sessions import ORIGIN
 link=ORIGIN+'/s02?organization='+data['organization_id']+'#invitation='+ticket['token']
 body={'From':{'Email':'invitations@uniion-local.example','Name':'uniion — recette locale'},'To':[{'Email':email}],'Subject':'Invitation uniion — recette locale','Text':'Vous êtes invité à rejoindre une organisation de recette. Connectez-vous avec le compte destinataire pour accepter :\n'+link+'\nAucun droit métier n’est attribué automatiquement.'}
 try:
  request=urllib.request.Request('http://127.0.0.1:54324/api/v1/send',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'},method='POST')
  with urllib.request.urlopen(request,timeout=8) as response:
   if response.status!=200:raise ValueError('Delivery failed')
   response.read()
 except Exception:
  dispatch(api,token,'/identity/invitations/revoke',{'organization_id':data['organization_id'],'invitation_id':ticket['id']})
  raise Unavailable() from None
 return {'id':ticket['id'],'delivered':True,'business_rights_granted':False}

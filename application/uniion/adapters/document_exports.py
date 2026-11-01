"""Export the committed version only; reauthorize before returning any bytes."""
import base64,hashlib
from io import BytesIO
from uuid import UUID
from pypdf import PdfReader,PdfWriter
from uniion.core.contracts import Denied
from .agenda_pdf import render

def export(api,token,org,payload):
 if set(payload)!={'id','version'} or type(payload['version']) is not int or payload['version']<1:raise Denied()
 try:rid=str(UUID(payload['id']))
 except (ValueError,TypeError,AttributeError):raise Denied() from None
 params={'p_org':org,'p_id':rid,'p_version':payload['version'],'p_action':'prepare'}
 snapshot=api.request('/rest/v1/rpc/uniion_document_export',token,params)
 raw=render(snapshot['document'],snapshot['version'])
 writer=PdfWriter();writer.append_pages_from_reader(PdfReader(BytesIO(raw)));writer.add_metadata({'/Title':snapshot['document']['title'],'/Subject':'Document — version '+str(snapshot['version'])+' — '+snapshot['document'].get('status','Brouillon').lower()})
 output=BytesIO();writer.write(output);raw=output.getvalue()
 api.request('/rest/v1/rpc/uniion_document_export',token,{**params,'p_action':'complete'})
 return {'filename':f'document-{rid}-v{snapshot["version"]}.pdf','mime':'application/pdf','base64':base64.b64encode(raw).decode(),'version':snapshot['version'],'sha256':hashlib.sha256(raw).hexdigest()}


def publish(api,token,org,payload):
 from .antivirus import worker_token
 if set(payload)!={'id','version'}:raise Denied()
 params={'p_org':org,'p_payload':payload}
 snap=api.request('/rest/v1/rpc/uniion_document_publication',token,{**params,'p_action':'prepare'})
 raw=render(snap['document'],snap['version'])
 writer=PdfWriter();writer.append_pages_from_reader(PdfReader(BytesIO(raw)));writer.add_metadata({'/Title':snap['document']['title'],'/Subject':'Document — version '+str(snap['version'])+' — publié'})
 output=BytesIO();writer.write(output);raw=output.getvalue()
 api.request('/rest/v1/rpc/uniion_document_archive_store',worker_token(api),{'p_org':org,'p_id':payload['id'],'p_version':snap['version'],'p_pdf':base64.b64encode(raw).decode()})
 return api.request('/rest/v1/rpc/uniion_document_publication',token,{**params,'p_action':'publish'})

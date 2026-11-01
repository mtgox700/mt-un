"""Read only the contracts owned by Dossiers/Documents/Messages, with user JWT."""
import re
from .ai_native import KINDS,native_read
from uuid import UUID
from uniion.core.contracts import Denied
from uniion.core.ai_context import digest


def refs(values):
    if not isinstance(values,list) or not 1<=len(values)<=8:raise Denied()
    result=[]
    for ref in values:
        if not isinstance(ref,dict) or ref.get('kind') not in ('case','document','message')+KINDS:raise Denied()
        fields={'kind','id','seq'} if ref['kind']=='message' else {'kind','id'}
        if set(ref)!=fields:raise Denied()
        try:r={**ref,'id':str(UUID(ref['id']))}
        except (ValueError,TypeError,AttributeError):raise Denied() from None
        if r['kind']=='message' and (not isinstance(r['seq'],str) or not re.fullmatch(r'[1-9][0-9]{0,17}',r['seq'])):raise Denied()
        if r in result:raise Denied()
        result.append(r)
    return result


def read(call,org,ref):
    kind=ref['kind'];payload={'id':ref['id']}
    if kind=='case':
        row=call('/rest/v1/rpc/uniion_cases',{'p_org':org,'p_action':'get','p_payload':payload})
        passages=[{'location':'description','text':row['long']}]
        # Notes and classified messages are already filtered by the dossier contract.
        for i,note in enumerate(row.get('timeline',[]),1):
            passages.append({'location':f'historique/{i}','text':' · '.join(str(note[k]) for k in ('date','title','body') if note.get(k))})
        title=row['title'];version=str(row['version']);names=[row.get('owner','')]
    elif kind=='document':
        row=call('/rest/v1/rpc/uniion_documents',{'p_org':org,'p_action':'get','p_payload':payload})
        passages=[]
        for i,block in enumerate(row.get('blocks',[]),1):
            if block.get('type') in ('tag','h1','h2','h3','p','ul','quote','table'):
                passages.append({'location':f'bloc/{i}','text':block.get('text','')})
        title=row['title'];version=str(row['version']);names=[]
        # No logo, image, attachment, layout, signature, profile or file fetching.
    elif kind=='message':
        row=call('/rest/v1/rpc/uniion_messaging',{'p_org':org,'p_action':'locate','p_payload':{**payload,'seq':ref['seq']}})
        message=next((m for m in row['messages'] if m['seq']==ref['seq']),None)
        if message is None:raise Denied()
        # No implicit expansion of replies, forwards or attachments.
        passages=[{'location':'message/'+ref['seq'],'text':message['text']}]
        title='Message '+ref['seq'];version=message['created'];names=[message.get('who','')]
    else:
        title,version,passages,names=native_read(call,org,ref)
    source={'ref':ref,'title':title,'version':version,'passages':passages,'names':names}
    if len(passages)>120 or sum(len(p['text']) for p in passages)>24000:raise Denied('ai_source_too_large')
    source['fingerprint']=digest(source)
    return source

"""Human-reviewed private proposals; no model-selected destination or command."""
from uuid import UUID
from uniion.core.contracts import Denied
from .ai_assistant import Assistant
from .ai_proposals import ACTIONS

def dispatch(gateway,context,authorize,actor,data):
    org=str(UUID(data['organization_id']));action=data['action'];rid=str(UUID(data['id']))
    base={'organization_id','action','id','version'}
    if action not in ('edit','review','apply') or set(data)!=base|({'text'} if action=='edit' else set()):raise Denied()
    if type(data['version'])!=int or data['version']<1:raise Denied('ai_version_conflict')
    service=Assistant(gateway,context,authorize,actor)
    if action=='apply':
        authorize(org)
        receipt=context.call('/rest/v1/rpc/uniion_ai_draft_apply',{'p_org':org,'p_action':'status','p_payload':{'id':rid}})
        if receipt.get('applied'):return receipt
    item=service.read(org,rid)
    if type(data['version'])!=int or item['version']!=data['version']:raise Denied('ai_version_conflict')
    response=item['response']
    if response.get('mode')!='business-draft':raise Denied()
    if action!='apply':
        return gateway.ledger.history.draft(org,actor,rid,data['version'],action,data.get('text'))
    if not response.get('reviewed') or len(response['snapshot'])!=1:raise Denied()
    spec=ACTIONS[response['action']];snapshot=response['snapshot'];source=context.check(org,snapshot)[0]
    kind=source['ref']['kind']
    operations={('case','timeline'):'case',('document','docinsert'):'document',('mobile','mobpage'):'mobile-page',('mobile','mobreplace'):'mobile-short',('mobile','mobpush'):'mobile-push',('communication','complan'):'communication-plan'}
    operation=operations.get((kind,spec.get('apply')))
    if not operation:raise Denied()
    # Keep the history row version locked until the authorized business transaction finishes.
    with gateway.ledger.transaction():
        row=gateway.ledger.db.execute('select version,archived from responses where org=? and actor=? and id=?',(org,actor,rid)).fetchone()
        if not row or row['version']!=data['version'] or row['archived']:raise Denied()
        authorize(org);context.recipe(org,[source])
        # R12 : le brouillon a été rédigé sur une source masquée ; les jetons sont remplacés par
        # les valeurs de la source actuelle (même empreinte, lue avec les droits de l'utilisateur).
        from uniion.core.ai_context import token_map,reidentify
        text=reidentify(response['text'],token_map([source]))
        return context.call('/rest/v1/rpc/uniion_ai_draft_apply',{'p_org':org,'p_action':'apply','p_payload':{'id':rid,'source':source['ref']['id'],'kind':operation,'version':int(source['version']),'text':text}})

"""Module recipe actions are private proposals, never business commands.

Only certified source references cross this boundary. No browser instruction,
memory expansion, generated command, destination or arbitrary apply operation.
"""
from uuid import UUID
from uniion.core.contracts import Denied
from .ai_context import refs


def generate_action(gateway, context, authorize, sid, data):
    if set(data) != {'organization_id', 'request_id', 'action', 'source'}:
        raise Denied()
    source = refs([data['source']])[0]
    selected=[source]
    from .ai_proposals import ACTIONS,ProposalContext,check_action_access
    action=ACTIONS.get(data['action'])
    if action:
        expected={'dossiers':'case','documents':'document','messagerie':'message','accueil':'workspace','params':'workspace'}.get(action['mod'],action['mod'])
        if expected and source['kind']!=expected:raise Denied()
        if action.get('scope')=='list':
            selected += [ref for ref in context.catalog(str(UUID(data['organization_id'])),64) if ref['kind']==source['kind'] and ref!=source][:7]
        base_context=context;base_authorize=authorize
        def authorize(current_org):
            policy=base_authorize(current_org)
            access=check_action_access(base_context,current_org,action['id'])
            return {**policy,'actionPolicy':access}
        context=ProposalContext(context,action)
    elif data['action'] != source['kind'] + '-excerpts':
        raise Denied()
    org, rid = str(UUID(data['organization_id'])), str(UUID(data['request_id']))
    return gateway.generate(sid, {'organization_id': org, 'request_id': rid,
                                 'sources': selected}, authorize, context, record=True)

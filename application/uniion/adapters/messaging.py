"""Private messages use the caller's JWT; PostgreSQL owns all resource checks."""
import re
from uuid import UUID
from uniion.core.contracts import Denied

def dispatch(api, token, data):
    if not isinstance(data, dict) or set(data) != {'organization_id', 'action', 'payload'}:
        raise Denied()
    action, payload = data['action'], data['payload']
    if isinstance(action, str) and action.startswith('file_'):
        from .message_files import dispatch as files
        try: org = str(UUID(data['organization_id']))
        except (ValueError, TypeError, AttributeError): raise Denied() from None
        if not isinstance(payload, dict): raise Denied()
        return files(api, token, org, action, payload)
    fields = {'read_all': (set(),set()), 'read': ({'id','seq'},set()), 'live': (set(),{'id','at'}), 'notices': (set(),set()), 'search': ({'query'}, {'before'}), 'targets': ({'query'}, {'before'}),
              'locate': ({'id','seq'}, set()), 'forward': ({'id','seq','clientId','targets'}, set()), 'participants': (set(), set()), 'list': (set(), {'before'}),
              'create': ({'participant'}, set()), 'get': ({'id'}, {'before'}),
              'send': ({'id', 'clientId', 'text'}, {'replyTo'}),
              'group_create': ({'clientId', 'name', 'desc', 'members'}, set()),
              'group_save': ({'id', 'version', 'name', 'desc', 'members'}, set()),
              'member_role': ({'id', 'version', 'participant', 'admin'}, set()),
              'leave': ({'id', 'version'}, set()),
              'history_grant': ({'id', 'version', 'period', 'messages'}, set()),
              'history_revoke': ({'id', 'version', 'period'}, set())}
    if not isinstance(action, str) or action not in fields or not isinstance(payload, dict):
        raise Denied()
    required, optional = fields[action]
    if not required <= payload.keys() or payload.keys() - required - optional:
        raise Denied()
    try:
        org = str(UUID(data['organization_id']))
        for key in ('id', 'participant', 'clientId', 'period'):
            if key in payload:
                UUID(payload[key])
        if action in ('list','search','targets') and 'before' in payload:
            UUID(payload['before'])
    except (ValueError, TypeError, AttributeError):
        raise Denied() from None
    for key in ({'before'} if action == 'get' else {'replyTo'} if action == 'send' else {'seq'} if action in ('forward','locate','read') else set()):
        if key in payload and (not isinstance(payload[key], str) or not re.fullmatch(r'[1-9][0-9]{0,17}', payload[key])):
            raise Denied()
    if 'at' in payload and ('id' not in payload or not isinstance(payload['at'],str) or not re.fullmatch(r'[1-9][0-9]{0,17}',payload['at'])):raise Denied()
    if action in ('search','targets') and (not isinstance(payload['query'],str) or len(payload['query'])>200 or (action=='search' and not payload['query'].strip())):
        raise Denied()
    if action == 'forward':
        if not isinstance(payload['targets'],list) or not 1<=len(payload['targets'])<=20: raise Denied()
        try:
            targets=[str(UUID(v)) for v in payload['targets']]
            if len(set(targets))!=len(targets) or payload['id'] in targets: raise Denied()
        except (ValueError,TypeError,AttributeError): raise Denied() from None
    if action == 'send' and (not isinstance(payload['text'], str) or not 1 <= len(payload['text'].strip()) <= 10000 or len(payload['text']) > 10000):
        raise Denied()
    if 'version' in payload and (type(payload['version']) is not int or not 1 <= payload['version'] <= 999999999):
        raise Denied()
    if action in ('group_create', 'group_save'):
        if (not isinstance(payload['name'], str) or not payload['name'].strip() or len(payload['name']) > 120
                or not isinstance(payload['desc'], str) or len(payload['desc']) > 2000
                or not isinstance(payload['members'], list) or not (1 if action == 'group_create' else 0) <= len(payload['members']) <= 99):
            raise Denied()
        try:
            ids = [str(UUID(v)) for v in payload['members']]
            if len(set(ids)) != len(ids): raise Denied()
        except (ValueError, TypeError, AttributeError):
            raise Denied() from None
    if action == 'member_role' and type(payload['admin']) is not bool:
        raise Denied()
    if action == 'history_grant':
        values = payload['messages']
        if (not isinstance(values, list) or not 1 <= len(values) <= 100
                or any(not isinstance(v, str) or not re.fullmatch(r'[1-9][0-9]{0,17}', v) for v in values)
                or len(set(values)) != len(values)):
            raise Denied()
    return api.request('/rest/v1/rpc/uniion_messaging', token,
                       {'p_org': org, 'p_action': action, 'p_payload': payload})

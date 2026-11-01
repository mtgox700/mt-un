"""Message-owned objects reuse the private quarantine and checked byte gateway."""
import base64
from uuid import UUID
from uniion.core.contracts import Denied
from . import attachments

def dispatch(api, token, org, action, payload):
    fields = {'file_upload': {'id', 'clientId', 'filename', 'content'},
              'file_preview': {'id', 'attachment', 'page'},
              'file_download': {'id', 'attachment'}, 'file_rescan': {'id', 'attachment'}}
    if action not in fields or set(payload) != fields[action]:
        raise Denied()
    try:
        for k in ('id', 'clientId' if action == 'file_upload' else 'attachment'):
            UUID(payload[k])
    except (ValueError, TypeError, AttributeError):
        raise Denied() from None
    if action == 'file_preview' and (type(payload['page']) is not int or not 1 <= payload['page'] <= 200):
        raise Denied()
    if action == 'file_upload':
        if not isinstance(payload['filename'], str) or not isinstance(payload['content'], str) or len(payload['content']) > 6990510:
            raise Denied()
        name, mime, raw, sha = attachments.validate_upload(payload)
        item = api.request('/rest/v1/rpc/uniion_message_file_prepare', token, {
            'p_org': org, 'p_conversation': payload['id'], 'p_client': payload['clientId'],
            'p_filename': name, 'p_mime': mime, 'p_size': len(raw), 'p_sha256': sha})
        # Immutable upload: a retry reconciles the object before requesting another scan.
        if not item['uploaded']:
            attachments.storage(api, token, item['path'], raw, mime)
        if item['status'] != 'clean':
            attachments.rescan(api, token, org, {'attachment': item['id']})
        api.request('/rest/v1/rpc/uniion_message_file_context', token, {
            'p_org': org, 'p_conversation': payload['id'], 'p_attachment': item['id']})
        return {'id': item['id']}
    def context():
        return api.request('/rest/v1/rpc/uniion_message_file_context', token, {
            'p_org': org, 'p_conversation': payload['id'], 'p_attachment': payload['attachment']})
    state = context()
    if action == 'file_rescan':
        if not state['write']:
            raise Denied()
        result = attachments.rescan(api, token, org, payload)
    elif action == 'file_preview':
        result = attachments.preview(api, token, org, payload)
    else:
        meta, raw = attachments.download(api, token, org, payload)
        result = {'filename': meta['filename'], 'mime': meta['mime'], 'content': base64.b64encode(raw).decode()}
    context()  # Parent rights again after scan, transfer or rendering.
    return result

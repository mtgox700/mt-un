"""Meeting-owned immutable audio, checked private storage and explicit audio ACL."""
import base64
import hashlib
import re
import struct
import io
import wave
from uuid import UUID
from uniion.core.contracts import Denied
from . import attachments, antivirus
from .supabase_transport import AccessDenied


def validate_audio(payload):
    name, content = payload['filename'], payload['content']
    if not isinstance(name, str) or not re.fullmatch(r'[^\x00-\x1f\x7f/\\]{1,176}\.wav', name, re.I):
        raise Denied()
    if not isinstance(content, str) or len(content) > 6990510:
        raise Denied()
    try:
        raw = base64.b64decode(content, validate=True)
        if not 44 <= len(raw) <= attachments.LIMIT or raw[:4] != b'RIFF' or raw[8:12] != b'WAVE' or struct.unpack_from('<I', raw, 4)[0] != len(raw)-8:
            raise ValueError()
        # Deliberately narrow PCM WAV profile; no arbitrary codec or embedded metadata.
        pos = 12; fmt = None; frames = None
        while pos < len(raw):
            if pos+8 > len(raw): raise ValueError()
            kind, size = raw[pos:pos+4], struct.unpack_from('<I', raw, pos+4)[0]
            pos += 8
            if pos+size > len(raw): raise ValueError()
            if kind == b'fmt ' and fmt is None and frames is None and size == 16:
                fmt = struct.unpack_from('<HHIIHH', raw, pos)
            elif kind == b'data' and fmt is not None and frames is None:
                frames = size
            else: raise ValueError()
            pos += size + (size % 2)
        if pos != len(raw) or fmt is None or not frames: raise ValueError()
        codec, channels, rate, byte_rate, align, bits = fmt
        if codec != 1 or channels not in (1,2) or rate not in (8000,16000,22050,24000,44100,48000) or bits not in (8,16,24,32) or align != channels*bits//8 or byte_rate != rate*align or frames % align:
            raise ValueError()
    except (ValueError, TypeError, struct.error):
        raise Denied() from None
    return name, raw, hashlib.sha256(raw).hexdigest()


def duration_ms(raw):
    """Only called after strict PCM validation; floor to an existing audio instant."""
    with wave.open(io.BytesIO(raw), 'rb') as wav:
        return wav.getnframes() * 1000 // wav.getframerate()


def dispatch(api, token, org, action, payload):
    fields = {'audio_upload': {'id','request_id','consentVersion','filename','content'},
              'audio_list': {'id'}, 'audio_listen': {'id','audio'},
              'audio_download': {'id','audio'},
              'audio_markers_get': {'id','audio'},
              'audio_markers_save': {'id','audio','version','markers'},
              'audio_policy': {'id'}, 'audio_policy_set': {'id','hours'},
              'audio_sequence': {'id','audio','recording','position'},
              'audio_source_begin': {'id','audio','filename','size','sha256'},
              'audio_source_part': {'id','audio','part','content'},
              'audio_source_progress': {'id','audio'}, 'audio_source_complete': {'id','audio'},
              'audio_source_download': {'id','audio'},
              'audio_setup': {'id'}, 'audio_manage': {'id','email','mode'},
              'audio_begin': {'id','request_id','consentVersion','filename','size','sha256'},
              'audio_part': {'id','audio','part','content'},
              'audio_progress': {'id','audio'}, 'audio_complete': {'id','audio'},
              'audio_grant': {'id','user','version','read','write','download'}}
    if action not in fields or not isinstance(payload,dict) or set(payload) != fields[action]: raise Denied()
    try:
        UUID(payload['id'])
        for k in ('request_id','audio','user'):
            if k in payload: UUID(payload[k])
    except (ValueError, TypeError, AttributeError): raise Denied() from None
    def rpc(operation, data):
        return api.request('/rest/v1/rpc/uniion_meeting_audio', token, {'p_org':org,'p_meeting':payload['id'],'p_action':operation,'p_payload':data})
    if action in ('audio_policy','audio_policy_set'):
        if action=='audio_policy_set' and (type(payload['hours']) is not int or not 1<=payload['hours']<=168): raise Denied()
        return api.request('/rest/v1/rpc/uniion_audio_policy',token,{'p_org':org,'p_hours':payload.get('hours')})
    if action=='audio_sequence':
        return api.request('/rest/v1/rpc/uniion_audio_sequence',token,{'p_org':org,'p_meeting':payload['id'],'p_action':'link','p_payload':{k:v for k,v in payload.items() if k!='id'}})
    if action.startswith('audio_source_'):
        operation={'audio_source_begin':'begin','audio_source_part':'put','audio_source_progress':'progress','audio_source_complete':'assemble','audio_source_download':'download'}[action]
        def original(op,data):
            return api.request('/rest/v1/rpc/uniion_audio_original',token,{'p_org':org,'p_meeting':payload['id'],'p_action':op,'p_payload':data})
        data={k:v for k,v in payload.items() if k!='id'}
        result=original(operation,data)
        if operation not in ('assemble','download'):return result
        raw=base64.b64decode(''.join(result['content'].split()),validate=True)
        if len(raw)!=result['size'] or hashlib.sha256(raw).hexdigest()!=result['sha256']:raise Denied()
        if operation=='download':
            return {'filename':result['filename'],'mime':'application/octet-stream','content':base64.b64encode(raw).decode()}
        # Preserved originals are opaque, never executed or served inline. Playback uses validated PCM.
        status=antivirus.scan(raw)[0]
        api.request('/rest/v1/rpc/uniion_audio_original_finish',antivirus.worker_token(api),{'p_audio':payload['audio'],'p_sha':result['sha256'],'p_status':'clean' if status=='clean' else 'blocked'})
        if status!='clean':raise Denied()
        return original('receipt',data)
    if action in ('audio_setup','audio_manage'):
        return api.request('/rest/v1/rpc/uniion_meeting_audio_setup',token,{
            'p_org':org,'p_meeting':payload['id'],'p_action':'status' if action=='audio_setup' else 'manage',
            'p_payload':{k:v for k,v in payload.items() if k!='id'}})
    if action == 'audio_begin':
        meta=rpc('prepare',{k:v for k,v in payload.items() if k!='id'})
        return {'audio':meta['id'],'status':meta['status']}
    if action in ('audio_part','audio_progress','audio_complete'):
        operation={'audio_part':'put','audio_progress':'status','audio_complete':'assemble'}[action]
        result=api.request('/rest/v1/rpc/uniion_meeting_audio_transfer',token,{
            'p_org':org,'p_meeting':payload['id'],'p_action':operation,'p_payload':{k:v for k,v in payload.items() if k!='id'}})
        if action!='audio_complete':return result
        result['content']=''.join(result['content'].split())
        name,raw,sha=validate_audio(result)
        if sha!=result.pop('sha256'):raise Denied()
        return dispatch(api,token,org,'audio_upload',{'id':payload['id'],**result})
    if action in ('audio_markers_get','audio_markers_save'):
        return api.request('/rest/v1/rpc/uniion_meeting_audio_markers',token,{
            'p_org':org,'p_meeting':payload['id'],'p_action':action.removeprefix('audio_markers_'),
            'p_payload':{k:v for k,v in payload.items() if k!='id'}})
    if action == 'audio_grant': return rpc('grant',{k:v for k,v in payload.items() if k!='id'})
    if action == 'audio_list':
        result=rpc('list',{})
        sequences=api.request('/rest/v1/rpc/uniion_audio_sequence',token,{'p_org':org,'p_meeting':payload['id'],'p_action':'list','p_payload':{}})
        indexed={row['audio']:row for row in sequences}
        for row in result['files']:row.update(indexed.get(row['id'],{}))
        return result
    if action == 'audio_upload':
        rpc('write',{})  # Refuse before decoding/scanning bytes.
        if type(payload['consentVersion']) is not int or payload['consentVersion'] < 1: raise Denied()
        name, raw, sha = validate_audio(payload)
        meta = rpc('prepare', {'request_id':payload['request_id'],'consentVersion':payload['consentVersion'],'filename':name,'size':len(raw),'sha256':sha})
        if meta['status'] == 'blocked': raise Denied()
        worker = antivirus.worker_token(api)
        if meta['status'] != 'clean':
            try: attachments.storage(api,worker,meta['path'],raw,'audio/wav')
            except AccessDenied:
                if attachments.storage(api,worker,meta['path']) != raw: raise Denied()
            stored = attachments.storage(api,worker,meta['path'])
            if stored != raw: raise Denied()
            status = antivirus.scan(stored)[0]
            api.request('/rest/v1/rpc/uniion_meeting_audio_finish',worker,{'p_id':meta['id'],'p_sha':sha,'p_status':'clean' if status=='clean' else 'blocked'})
            if status != 'clean': raise Denied()
        else:
            # A replay must still verify the durable bytes, not just the receipt.
            if attachments.storage(api,worker,meta['path']) != raw: raise Denied()
        api.request('/rest/v1/rpc/uniion_meeting_audio_duration',worker,{
            'p_id':meta['id'],'p_sha':sha,'p_duration_ms':duration_ms(raw)})
        rpc('write',{})
        # Final consent/version/ACL check also covers withdrawal while scanning.
        return rpc('uploaded',{'audio':meta['id']})
    operation = 'listen' if action == 'audio_listen' else 'download'
    meta = rpc(operation,{'audio':payload['audio'],'audit':False})
    raw = attachments.storage(api,antivirus.worker_token(api),meta['path'])
    if len(raw)!=meta['size'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']: raise Denied()
    rpc(operation,{'audio':payload['audio'],'audit':True})
    return {'id':meta['id'],'filename':meta['filename'],'mime':'audio/wav','content':base64.b64encode(raw).decode()}

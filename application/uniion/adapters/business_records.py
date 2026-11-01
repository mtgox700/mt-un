"""Versioned module objects; all ACL and payload validation remain in PostgreSQL."""
from uuid import UUID
from uniion.core.contracts import Denied
MODULES=('reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis')
def dispatch(api,token,data):
    if isinstance(data,dict) and data.get('action')=='retention_receipts':
        if set(data)!={'organization_id','module','action','payload'} or data['module']!='reunions' or data['payload']!={}:raise Denied()
        return api.request('/rest/v1/rpc/uniion_audio_local_receipts',token,{'p_org':str(UUID(data['organization_id']))})
    if isinstance(data,dict) and data.get('action') in ('retention_status','retention_collect','retention_list','retention_approve','retention_hold','retention_refresh'):
        if set(data)!={'organization_id','module','action','payload'} or data['module']!='reunions' or not isinstance(data['payload'],dict):raise Denied()
        payload=dict(data['payload']);meeting=payload.pop('meeting',None)
        try:
            org=str(UUID(data['organization_id']));meeting=str(UUID(meeting)) if meeting else None
        except (ValueError,TypeError,AttributeError):raise Denied() from None
        return api.request('/rest/v1/rpc/uniion_audio_retention',token,{'p_org':org,'p_meeting':meeting,'p_action':data['action'].removeprefix('retention_'),'p_payload':payload})
    if isinstance(data,dict) and data.get('action') in ('pv_prepare','pv_status','pv_publications'):
        if set(data)!={'organization_id','module','action','payload'} or data['module']!='reunions' or not isinstance(data['payload'],dict) or set(data['payload'])!=({'id'} if data['action']=='pv_publications' else {'id','audio'}):raise Denied()
        if data['action']=='pv_publications':
            return api.request('/rest/v1/rpc/uniion_meeting_minutes',token,{'p_org':str(UUID(data['organization_id'])),'p_meeting':str(UUID(data['payload']['id'])),'p_audio':None,'p_action':'publications'})
        try: org,meeting,audio=(str(UUID(v)) for v in (data['organization_id'],data['payload']['id'],data['payload']['audio']))
        except (ValueError,TypeError,AttributeError):raise Denied() from None
        return api.request('/rest/v1/rpc/uniion_meeting_minutes',token,{'p_org':org,'p_meeting':meeting,'p_audio':audio,'p_action':data['action'].removeprefix('pv_')})
    if isinstance(data,dict) and data.get('action') in ('transcription_start','transcription_status','transcription_cancel','transcription_retry'):
        if set(data)!={'organization_id','module','action','payload'} or data['module']!='reunions' or not isinstance(data['payload'],dict) or set(data['payload'])!={'id','audio'}:raise Denied()
        try: org,meeting,audio=(str(UUID(v)) for v in (data['organization_id'],data['payload']['id'],data['payload']['audio']))
        except (ValueError,TypeError,AttributeError):raise Denied() from None
        return api.request('/rest/v1/rpc/uniion_transcription',token,{'p_org':org,'p_meeting':meeting,'p_audio':audio,'p_action':data['action'].removeprefix('transcription_')})
    if isinstance(data,dict) and isinstance(data.get('action'),str) and data['action'].startswith('audio_'):
        if set(data)!={'organization_id','module','action','payload'} or data['module']!='reunions':raise Denied()
        from .meeting_audio import dispatch as audio
        return audio(api,token,str(UUID(data['organization_id'])),data['action'],data['payload'])
    if isinstance(data,dict) and data.get('action') in ('consent_get','consent_set'):
        if set(data)!={'organization_id','module','action','payload'} or data['module']!='reunions' or not isinstance(data['payload'],dict):raise Denied()
        return api.request('/rest/v1/rpc/uniion_meeting_consent',token,{'p_org':str(UUID(data['organization_id'])),'p_action':data['action'].removeprefix('consent_'),'p_payload':data['payload']})
    if set(data)!={'organization_id','module','action','payload'} or data['module'] not in MODULES or data['action'] not in ('list','get','create','save','publication_status','publication_review','publication_publish','publication_revoke','publication_feed') or not isinstance(data['payload'],dict):raise Denied()
    if data['action'].startswith('publication_'):
        return api.request('/rest/v1/rpc/uniion_business_publication',token,{'p_org':str(UUID(data['organization_id'])),'p_module':data['module'],'p_action':data['action'].removeprefix('publication_'),'p_payload':data['payload']})
    return api.request('/rest/v1/rpc/uniion_business_records',token,{'p_org':str(UUID(data['organization_id'])),'p_module':data['module'],'p_action':data['action'],'p_payload':data['payload']})

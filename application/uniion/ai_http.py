"""Long-running AI requests release the session lock so logout/cancel can proceed."""
import json
import secrets
from uuid import UUID
from uniion.core.contracts import Denied, Unavailable
from uniion.adapters.sessions import RateLimited
from uniion.adapters.supabase_transport import AccessDenied, SupabaseUnavailable


def serve(e, start, store, api, gateway, origin, port):
    path = e.get('PATH_INFO')
    if path not in ('/identity/ai/generate', '/identity/ai/cancel', '/identity/ai/context', '/identity/ai/runs', '/identity/ai/assistant', '/identity/ai/actions', '/identity/ai/drafts', '/identity/ai/chat'): return None
    status, result = '200 OK', {}
    try:
        if (e.get('REQUEST_METHOD') != 'POST' or e.get('HTTP_HOST') != '127.0.0.1:'+port
                or e.get('HTTP_ORIGIN') != origin or e.get('HTTP_AUTHORIZATION')
                or e.get('CONTENT_TYPE','').split(';')[0] != 'application/json'):
            raise Denied()
        n = int(e.get('CONTENT_LENGTH','0'))
        if not 0 < n <= (40000 if path.endswith(('/drafts','/chat')) else 2048): raise Denied()
        data = json.loads(e['wsgi.input'].read(n))
        if not isinstance(data, dict): raise Denied()
        with store.lock:
            sid, session = store.find(e.get('HTTP_COOKIE',''))
            if not session or not secrets.compare_digest(e.get('HTTP_X_UNIION_CSRF',''), session['csrf']): raise Denied()
            user, auth = store.authenticate(session)
            if not auth['allowed']: raise Denied()
            actor = user['id']
            store.limit(('ai-history:' if path.endswith('/assistant') and data.get('action')!='generate' else 'ai-context:' if path.endswith(('/context','/runs')) else 'ai-cancel:' if path.endswith('/cancel') else 'ai:')+actor, 30 if path.endswith(('/cancel','/context','/runs')) or (path.endswith('/assistant') and data.get('action')!='generate') else 10)
        def authorize(org):
            with store.lock:
                current_sid, current = store.find(e.get('HTTP_COOKIE',''))
                if current_sid != sid or not current or not secrets.compare_digest(current['csrf'], session['csrf']): raise Denied()
                user, auth = store.authenticate(current)
                if user['id'] != actor or not auth['allowed']: raise Denied()
                return api.request('/rest/v1/rpc/uniion_ai_policy',current['access_token'],
                                   {'p_org':org,'p_action':'authorize','p_payload':{}})
        def source_call(endpoint,payload):
            # Endpoints are chosen by our source adapters, never by request input.
            with store.lock:
                current_sid,current=store.find(e.get('HTTP_COOKIE',''))
                if current_sid!=sid or not current or not secrets.compare_digest(current['csrf'],session['csrf']):raise Denied()
                user,auth=store.authenticate(current)
                if user['id']!=actor or not auth['allowed']:raise Denied()
                return api.request(endpoint,current['access_token'],payload)
        from uniion.adapters.ai_context_service import ContextService
        context=ContextService(source_call)
        if path.endswith('/chat'):
            from uniion.adapters.ai_conversation import generate,interactive
            if set(data)=={'organization_id','action'} and data['action']=='status':
                org=str(UUID(data['organization_id']));authorize(org);result=interactive(context,org)
            else:result=generate(gateway,context,authorize,actor,sid,data)
        elif path.endswith('/drafts'):
            from uniion.adapters.ai_drafts import dispatch
            result=dispatch(gateway,context,authorize,actor,data)
        elif path.endswith('/actions'):
            from uniion.adapters.ai_actions import generate_action
            if set(data)=={'organization_id','action','payload'} and data['action'] in ('settings','configure','assign_role'):
                org=str(UUID(data['organization_id']));authorize(org)
                result=context.call('/rest/v1/rpc/uniion_ai_action_policy',{'p_org':org,'p_action':'list' if data['action']=='settings' else data['action'],'p_payload':data['payload']})
                authorize(org)
            elif set(data)=={'organization_id','action'} and data['action']=='catalog':
                org=str(UUID(data['organization_id']));authorize(org)
                from uniion.adapters.ai_proposals import CATALOG
                result={'actions':[{k:a[k] for k in ('id','mod','label','desc','scope') if k in a} for a in CATALOG],
                        'sources':[{'ref':s['ref'],'title':s['title']} for s in context.catalog_sources(org,64)]}
                authorize(org)
            else:result=generate_action(gateway,context,authorize,sid,data)
        elif path.endswith('/assistant'):
            from uniion.adapters.ai_assistant import Assistant
            service=Assistant(gateway,context,authorize,actor)
            org=str(UUID(data['organization_id']));action=data.get('action')
            base={'organization_id','action'}
            if action=='list' and set(data)==base:result=service.list(org)
            elif action=='read' and set(data)==base|{'id'}:result=service.read(org,str(UUID(data['id'])))
            elif action=='create_case' and set(data)==base|{'id','version'}:
                item=service.read(org,str(UUID(data['id'])))
                if type(data['version']) is not int or item['version']!=data['version']:raise Denied()
                r=item['response'];text=('Question : '+r.get('question','')+'\n\n'+r['text'])
                if len(text)>4900:text=text[:4800]+'\n[Extrait — réponse complète dans l’historique privé.]'
                dependencies=list(r['snapshot'])
                for ref in r['snapshot']:
                    if ref['kind']=='workspace':
                        workspace=context.call('/rest/v1/rpc/uniion_ai_native',{'p_org':org,'p_kind':'workspace','p_id':org})
                        dependencies.extend(workspace.get('dependencies',[]))
                context.check(org,r['snapshot'])
                result=context.call('/rest/v1/rpc/uniion_ai_case_create',{'p_org':org,'p_request':item['id'],'p_refs':dependencies,'p_title':r.get('title',r.get('actionLabel','Conversation privée'))[:200],'p_text':text})
                service.read(org,item['id'])
            elif action in ('remember','archive') and set(data)==base|{'id','version'}|({'enabled'} if action=='remember' else set()):
                data['id']=str(UUID(data['id']));result=service.change(org,data)
            elif action=='configure' and set(data)==base|{'enabled','version'}:
                authorize(org);result=gateway.ledger.history.configure(org,actor,data['enabled'],data['version'])
            elif action=='generate' and set(data)==base|{'request_id','sources'}:
                result=service.generate(sid,org,str(UUID(data['request_id'])),data['sources'])
            else:raise Denied()
        elif path.endswith('/runs'):
            if set(data) not in ({'organization_id'},{'organization_id','request_id'}):raise Denied()
            org=str(UUID(data['organization_id']));authorize(org)
            rid=str(UUID(data['request_id'])) if 'request_id' in data else None
            result=gateway.ledger.status(org,actor,rid)
            authorize(org)
        elif path.endswith('/context'):
            org=str(UUID(data['organization_id']));initial=authorize(org)
            if data.get('action')=='catalog' and set(data)=={'organization_id','action'}:
                result={'sources':context.catalog(org)}
            elif data.get('action')=='preview' and set(data)=={'organization_id','action','sources'}:
                result=context.preview(org,data['sources'])
            elif data.get('action')=='check' and set(data)=={'organization_id','action','snapshot'}:
                context.check(org,data['snapshot']);result={'valid':True}
            else:raise Denied()
            if authorize(org)!=initial:raise Denied()
        elif path.endswith('/cancel'):
            if set(data) != {'organization_id','request_id'}: raise Denied()
            org,rid=str(UUID(data['organization_id'])),str(UUID(data['request_id']))
            # Authenticated identity owns the tombstone; no source access granted.
            result=gateway.ledger.cancel(org,actor,rid)
            gateway.cancel(sid,org,rid)
        else:
            result = gateway.generate(sid, data, authorize, context)
    except (Denied, AccessDenied):
        status, result = '403 Forbidden', {'error':'Accès refusé, demande annulée ou autorisation modifiée.','code':'ai_denied'}
    except RateLimited:
        status, result = '429 Too Many Requests', {'error':'Limite de requêtes atteinte. Réessayez plus tard.','code':'ai_rate_limited'}
    except (ValueError, KeyError, TypeError, AttributeError):
        status, result = '400 Bad Request', {'error':'Requête invalide.','code':'ai_invalid_request'}
    except (Unavailable, SupabaseUnavailable):
        status, result = '503 Service Unavailable', {'error':'Aucune réponse disponible. Le traitement peut avoir été engagé ; aucune relance automatique.','code':'ai_unavailable'}
    except Exception:
        status, result = '503 Service Unavailable', {'error':'Passerelle IA indisponible.','code':'ai_unavailable'}
    raw = json.dumps(result,ensure_ascii=False).encode()
    start(status,[('Content-Type','application/json; charset=utf-8'),('Content-Length',str(len(raw))),
                  ('Cache-Control','no-store'),('Pragma','no-cache'),('X-Content-Type-Options','nosniff'),
                  ('Referrer-Policy','no-referrer'),('Content-Security-Policy',"default-src 'none'; frame-ancestors 'none'")])
    return [raw]

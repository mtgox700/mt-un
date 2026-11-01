"""Loopback BFF: strict origin, CSRF, opaque cookie, server-side refresh and MFA."""
import json,secrets,os
from uniion.core.contracts import Denied,Unavailable,PDFOverflow,PDFContentMissing
from uniion.adapters.sessions import SessionStore,RateLimited
from uniion.adapters.supabase_transport import AccessDenied,SupabaseUnavailable
PORT=os.environ.get('UNIION_HTTP_PORT','5060')
if PORT not in ('5060','5068'):raise ValueError('Local port not approved')
ORIGIN='http://127.0.0.1:'+PORT
POSTS={'/identity/ai','/identity/messaging','/identity/documents','/identity/business','/identity/cases','/identity/adherents','/identity/agenda/convocations/files','/identity/agenda/convocations/history','/identity/agenda/publication-notices','/identity/agenda/work','/identity/agenda/convocations/send','/identity/agenda/audiences','/identity/agenda/export','/identity/agenda/notifications','/identity/agenda','/identity/agenda/save','/identity/partners','/identity/partners/save','/identity/modules','/identity/modules/config','/identity/modules/commercial','/identity/modules/revoke','/identity/modules/use','/identity/platform-role','/identity/support-agents','/identity/support-agents/save','/identity/support/approve-files','/identity/support/files/preview','/identity/support/files/download','/identity/support/assign','/identity/support/request','/identity/support/reject','/identity/support/approve','/identity/support/revoke','/identity/support/read','/identity/support','/identity/support/create','/identity/support/status','/identity/collections/create','/identity/collections','/identity/collections/change','/identity/attachments/preview','/identity/attachments/download','/identity/organizations','/identity/console','/identity/shares/create','/identity/shares/accept','/identity/shares/revoke','/identity/shares/read','/identity/consents','/identity/consents/change','/identity/rights','/identity/rights/change','/identity/memberships/status','/identity/invitations/resend','/identity/profile/save','/identity/organization/save','/identity/profile','/identity/directory','/identity/invitations/send','/auth/mfa/lost/cancel','/auth/mfa/lost/request','/auth/mfa/lost/approve','/auth/mfa/recovery/enroll','/auth/mfa/recovery/request','/auth/mfa/recovery/approve','/identity/invitations/create','/identity/invitations/accept','/identity/invitations/revoke','/identity/memberships/revoke','/auth/login','/auth/logout','/auth/mfa/enroll','/auth/mfa/challenge','/auth/mfa/verify','/auth/mfa/remove','/auth/recovery/request','/auth/recovery/verify','/auth/password'}
def wrap(resource_app,api,store=None,ai_ledger=None):
    store=store or SessionStore(api)
    from uniion.adapters.message_stream import MessageHub
    hub=MessageHub()
    from uniion.adapters.ai_gateway import AIGateway
    from uniion.ai_http import serve as serve_ai
    ai_gateway=AIGateway(ledger=ai_ledger)
    def app(e,start):
        from uniion.s02_static import serve
        static=serve(e,start)
        if static is not None:return static
        if e.get('PATH_INFO')=='/identity/messaging/events' and e.get('REQUEST_METHOD')=='GET':
            try:
                if e.get('HTTP_HOST')!='127.0.0.1:'+PORT or e.get('HTTP_AUTHORIZATION') or e.get('HTTP_ORIGIN',ORIGIN)!=ORIGIN or e.get('HTTP_SEC_FETCH_SITE','same-origin') not in ('same-origin','none'):raise Denied()
                return hub.stream(e,start,store,api)
            except (Denied,AccessDenied,ValueError):
                start('403 Forbidden',[('Content-Type','application/json'),('Cache-Control','no-store')]);return [b'{}']
            except Exception:
                start('503 Service Unavailable',[('Content-Type','application/json'),('Cache-Control','no-store')]);return [b'{}']
        ai_response=serve_ai(e,start,store,api,ai_gateway,ORIGIN,PORT)
        if ai_response is not None:return ai_response
        status='200 OK';cookie=None;result={};sid=None;s=None;path=e.get('PATH_INFO','');method=e.get('REQUEST_METHOD')
        with store.lock:
            try:
                if e.get('HTTP_HOST')!='127.0.0.1:'+PORT:raise Denied()
                if e.get('HTTP_AUTHORIZATION'):raise Denied() # no external bearer bypass of session lifecycle
                if path=='/health' and method=='GET':return resource_app(e,start)
                sid,s=store.find(e.get('HTTP_COOKIE',''),create=path=='/auth/session' and method=='GET')
                if path=='/auth/session' and method=='GET':
                    try:result=store.public(s)
                    except (Denied,AccessDenied):
                        store.sessions.pop(sid,None)
                        sid,s=store.find('',create=True)
                        result=store.public(s)
                    cookie=store.cookie(sid)
                elif path in POSTS and method=='POST':
                    if not s or e.get('HTTP_ORIGIN')!=ORIGIN or not secrets.compare_digest(e.get('HTTP_X_UNIION_CSRF',''),s['csrf']):raise Denied()
                    if e.get('CONTENT_TYPE','').split(';')[0]!='application/json':raise Denied()
                    n=int(e.get('CONTENT_LENGTH','0'))
                    limit=8*1024*1024 if path in ('/identity/agenda/work','/identity/adherents','/identity/cases') else (8*1024*1024 if path in ('/identity/documents','/identity/business') else (8*1024*1024 if path=='/identity/messaging' else 16384))
                    if not 0<n<=limit:raise Denied()
                    data=json.loads(e['wsgi.input'].read(n))
                    if not isinstance(data,dict):raise Denied()
                    sid,result=store.post(path,sid,s,data,e.get('REMOTE_ADDR','unknown'));cookie=store.cookie(sid);hub.wake()
                elif path.startswith('/api/') and method=='GET':
                    _,auth=store.authenticate(s)
                    if not auth['allowed']:raise Denied()
                    inner={**e,'HTTP_AUTHORIZATION':'Bearer '+s['access_token']}
                    return resource_app(inner,start)
                else:status='404 Not Found';result={'error':'Route inconnue'}
            except PDFContentMissing:status='422 Unprocessable Entity';result={'error':'Ce style ne restitue pas tous les blocs. Choisissez le style Classique.','code':'pdf_content_missing'}
            except PDFOverflow:status='422 Unprocessable Entity';result={'error':'Le contenu dépasse le gabarit PDF. Raccourcissez-le ou ajoutez un saut de page.','code':'pdf_overflow'}
            except (Denied,AccessDenied):status='403 Forbidden';result={'error':'Accès refusé ou vérification requise'}
            except RateLimited:status='429 Too Many Requests';result={'error':'Trop de tentatives. Réessayez plus tard.'}
            except (ValueError,KeyError,TypeError):status='400 Bad Request';result={'error':'Requête invalide'}
            except (Unavailable,SupabaseUnavailable):status='503 Service Unavailable';result={'error':'Service indisponible'}
            except Exception:status='503 Service Unavailable';result={'error':'Service indisponible'}
            if path in ('/auth/logout','/auth/password') and method=='POST' and s is not None and sid not in store.sessions:cookie=store.cookie('')
        raw=json.dumps(result,ensure_ascii=False).encode();headers=[('Content-Type','application/json; charset=utf-8'),('Content-Length',str(len(raw))),('Cache-Control','no-store'),('Pragma','no-cache'),('X-Content-Type-Options','nosniff'),('Referrer-Policy','no-referrer'),('Content-Security-Policy',"default-src 'none'; frame-ancestors 'none'")]
        if cookie:headers.append(('Set-Cookie',cookie))
        start(status,headers);return [raw]
    app.sessions=store
    app.message_hub=hub
    app.ai_gateway=ai_gateway
    return app

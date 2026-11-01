"""Composition root. Local foundation, no prototype rendering or production launch."""
import json,re
from uniion.core.contracts import Denied,Unavailable
from uniion.core.registry import Registry
from uniion.modules.resources.module import ResourceModule
from uniion.adapters.resources import SupabaseResources
from uniion.adapters.supabase_transport import SupabaseAccess
from uniion.config import Config

def create_resource_app(config,api=None):
    if config.environment!='development-local' or config.supabase_url!='http://127.0.0.1:54321' or config.publishable_key:raise ValueError('Configuration non qualifiée')
    api=api or SupabaseAccess(config.supabase_url,'',local=True)
    registry=Registry((ResourceModule(),))
    def app(environ,start_response):
        status='200 OK';result={}
        try:
            if environ.get('REQUEST_METHOD')!='GET':status='405 Method Not Allowed';result={'error':'Méthode refusée'}
            elif environ.get('PATH_INFO')=='/health':result={'status':'ok','environment':'development-local','sprint':'S01','production_ready':False}
            else:
                match=re.fullmatch(r'/api/organizations/([0-9a-fA-F-]{36})/resources/([0-9a-fA-F-]{36})',environ.get('PATH_INFO',''))
                if not match:status='404 Not Found';result={'error':'Route inconnue'}
                else:
                    authorization=environ.get('HTTP_AUTHORIZATION','')
                    if not authorization.startswith('Bearer ') or len(authorization)>8192:raise Denied()
                    token=authorization[7:]
                    if not token or any(c.isspace() for c in token):raise Denied()
                    resources=SupabaseResources(api,token)
                    principal=resources.principal(match[1])
                    result=registry.execute('resource.read.v1',principal,{'resource_id':match[2]},resources)
        except Denied:status='403 Forbidden';result={'error':'Accès refusé'}
        except Unavailable:status='503 Service Unavailable';result={'error':'Service indisponible'}
        except Exception:status='503 Service Unavailable';result={'error':'Service indisponible'}
        raw=json.dumps(result,ensure_ascii=False).encode()
        start_response(status,[('Content-Type','application/json; charset=utf-8'),('Content-Length',str(len(raw))),('Cache-Control','no-store'),('X-Content-Type-Options','nosniff'),('Content-Security-Policy',"default-src 'none'; frame-ancestors 'none'"),('Referrer-Policy','no-referrer')])
        return [raw]
    return app
def create_app(config,api=None,session_store=None,ai_ledger=None):
    from uniion.http_sessions import wrap
    api=api or SupabaseAccess(config.supabase_url,'',local=True)
    return wrap(create_resource_app(config,api),api,session_store,ai_ledger)

if __name__=='__main__':
    from wsgiref.simple_server import make_server,WSGIRequestHandler,WSGIServer
    from socketserver import ThreadingMixIn
    class ThreadedServer(ThreadingMixIn,WSGIServer):
        daemon_threads=True
    class Quiet(WSGIRequestHandler):
        def log_message(self,*args):pass
    import pathlib,threading
    from uniion.adapters.durable_sessions import DurableSessionStore
    root=pathlib.Path(__file__).resolve().parents[1]
    config=Config.load();api=SupabaseAccess(config.supabase_url,'',local=True)
    store=DurableSessionStore(api,root/'.local-sessions/state.sqlite3',root/'.local-auth/session-encryption.key')
    store.maintain() # Validate the encrypted state before accepting HTTP traffic.
    stopping=threading.Event()
    def maintain():
        while not stopping.wait(30):
            try:store.maintain()
            except Exception:
                try:store.write_health(False)
                except Exception:pass # A stale health file is detected independently.
    threading.Thread(target=maintain,daemon=True).start()
    from uniion.adapters.ai_runs import RunLedger
    ledger=RunLedger(root/'.local-ai/runs.sqlite3')
    from uniion.http_sessions import PORT
    with make_server('127.0.0.1',int(PORT),create_app(config,api,store,ledger),handler_class=Quiet,server_class=ThreadedServer) as server:
        print('Fondation S01 locale : http://127.0.0.1:'+PORT+'/health',flush=True);server.serve_forever()

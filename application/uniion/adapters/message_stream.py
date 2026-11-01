"""Local SSE hub. Empty wakeups; every projection is authorized using the subscriber JWT.

Mutations on this BFF push immediately. A bounded reconciliation heartbeat covers
other processes/administrative changes; not a distributed production event bus.
"""
import threading,json,re,time
from urllib.parse import parse_qs
from uuid import UUID
from uniion.core.contracts import Denied
from .supabase_transport import AccessDenied

class MessageHub:
    def __init__(self):self.condition=threading.Condition();self.version=0;self.active={}
    def wake(self):
        with self.condition:self.version+=1;self.condition.notify_all()
    def wait(self,version,timeout):
        with self.condition:
            if self.version==version:self.condition.wait(timeout)
            return self.version
    def stream(self,e,start,store,api):
        q=parse_qs(e.get('QUERY_STRING',''),keep_blank_values=True)
        if set(q)-{'organization','id','cursor','at'} or any(len(v)!=1 for v in q.values()):raise Denied()
        try:
            org=str(UUID(q['organization'][0]));payload={}
            if 'id' in q:payload['id']=str(UUID(q['id'][0]))
            if 'at' in q:
                if 'id' not in q or not re.fullmatch('[1-9][0-9]{0,17}',q['at'][0]):raise Denied()
                payload['at']=q['at'][0]
        except (ValueError,KeyError):raise Denied() from None
        cursor=e.get('HTTP_LAST_EVENT_ID') or q.get('cursor',[''])[0]
        if cursor and not re.fullmatch('[0-9a-f]{32}',cursor):raise Denied()
        cookie=e.get('HTTP_COOKIE','')
        def snapshot():
            with store.lock:
                # A stream is not user activity: it must not extend idle expiry.
                prior=store.sessions.get(key_id)
                last=prior['last'] if prior else None
                sid,s=store.find(cookie)
                if not s:raise Denied()
                s['last']=last
                _,auth=store.authenticate(s)
                if not auth['allowed']:raise Denied()
                return sid,api.request('/rest/v1/rpc/uniion_messaging',s['access_token'],{'p_org':org,'p_action':'live','p_payload':payload})
        # Preserve last activity before find() refreshes it.
        from http.cookies import SimpleCookie
        jar=SimpleCookie();jar.load(cookie);key=jar.get('uniion_s01');sid=key.value if key else ''
        key_id=sid
        sid,initial=snapshot()
        with self.condition:
            if self.active.get(sid,0)>=3 or sum(self.active.values())>=64:raise Denied()
            self.active[sid]=self.active.get(sid,0)+1
        start('200 OK',[('Content-Type','text/event-stream'),('Cache-Control','no-store'),('X-Accel-Buffering','no'),('X-Content-Type-Options','nosniff')])
        def generate():
            nonlocal cursor
            version=self.version;state=initial;first=True;deadline=time.monotonic()+120;heartbeat=time.monotonic()+10
            try:
                yield b'retry: 3000\n\n'
                while True:
                    if first or state['cursor']!=cursor:
                        first=False;cursor=state['cursor'];yield ('id: '+cursor+'\nevent: state\ndata: '+json.dumps(state,separators=(',',':'))+'\n\n').encode()
                    elif time.monotonic()>=heartbeat:
                        heartbeat=time.monotonic()+10;yield b'event: heartbeat\ndata: {}\n\n'
                    if time.monotonic()>=deadline:return
                    version=self.wait(version,max(0,heartbeat-time.monotonic()))
                    try:_,state=snapshot()
                    except (Denied,AccessDenied):yield b'event: revoked\ndata: {}\n\n';return
                    except Exception:yield b'event: unavailable\ndata: {}\n\n';return
            finally:
                with self.condition:
                    self.active[sid]=max(0,self.active.get(sid,1)-1)
                    if not self.active[sid]:self.active.pop(sid,None)
        return generate()

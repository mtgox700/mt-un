"""Encrypted local session state, serialized across processes on one host.

No browser tokens. Not a multi-host store and not part of business backups.
"""
import hashlib,json,os,pathlib,secrets,sqlite3,threading,time,fcntl
from http.cookies import SimpleCookie
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from .sessions import SessionStore,RateLimited
from uniion.core.contracts import Denied
from .supabase_transport import AccessDenied,SupabaseUnavailable

AAD=b'uniion-local-sessions-v1'

def private_file(path,initial=None):
    path=pathlib.Path(path)
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    if path.parent.is_symlink() or path.is_symlink():raise RuntimeError('Private state path required')
    path.parent.chmod(0o700)
    try:
        fd=os.open(path,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
    except FileExistsError:
        if not path.is_file() or path.stat().st_mode&0o077:raise RuntimeError('Private file permissions required')
    else:
        with os.fdopen(fd,'wb') as output:
            if initial is not None:output.write(initial)
            output.flush();os.fsync(output.fileno())
    return path

class Transaction:
    def __init__(self,store):self.store=store;self.local=threading.RLock();self.connection=None;self.file_lock=None
    def __enter__(self):
        if not self.local.acquire(timeout=30):raise TimeoutError('Session transaction busy')
        try:
            self.file_lock=open(self.store.lock_path,'r+b');until=time.monotonic()+30
            while True:
                try:fcntl.flock(self.file_lock,fcntl.LOCK_EX|fcntl.LOCK_NB);break
                except BlockingIOError:
                    if time.monotonic()>=until:raise TimeoutError('Session transaction busy')
                    time.sleep(.02)
            self.connection=sqlite3.connect(self.store.path,timeout=30,isolation_level=None)
            self.connection.execute('PRAGMA synchronous=FULL')
            self.connection.execute('PRAGMA fullfsync=ON')
            self.connection.execute('BEGIN IMMEDIATE')
            row=self.connection.execute('SELECT payload FROM state WHERE id=1').fetchone()
            state=json.loads(self.store.cipher.decrypt(row[0][:12],row[0][12:],AAD)) if row else {}
            self.store.sessions=state.get('sessions',{});self.store.attempts=state.get('attempts',{});self.store.pending=state.get('pending',{})
            self.store.recover_interrupted()
            return self
        except Exception:
            self.close();raise
    def save(self):
        raw=json.dumps({'sessions':self.store.sessions,'attempts':self.store.attempts,'pending':self.store.pending},separators=(',',':')).encode()
        nonce=secrets.token_bytes(12);blob=nonce+self.store.cipher.encrypt(nonce,raw,AAD)
        self.connection.execute('INSERT INTO state(id,payload) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',(blob,))
    def checkpoint(self):
        # The cross-process lock remains held across COMMIT/BEGIN. Other stores
        # cannot observe a gap and overwrite state while an Auth call is in flight.
        self.save();self.connection.execute('COMMIT');self.connection.execute('BEGIN IMMEDIATE')
    def close(self):
        if self.connection:self.connection.close();self.connection=None
        if self.file_lock:self.file_lock.close();self.file_lock=None
        self.local.release()
    def __exit__(self,kind,value,traceback):
        try:
            if kind is None:self.save();self.connection.execute('COMMIT')
            elif self.connection.in_transaction:self.connection.execute('ROLLBACK')
        finally:self.close()
        return False

class DurableSessionStore(SessionStore):
    def __init__(self,api,path,key_path,clock=time.time):
        super().__init__(api,clock)
        self.path=private_file(path)
        self.lock_path=private_file(self.path.with_suffix('.lock'))
        key=private_file(key_path,secrets.token_bytes(32)).read_bytes()
        if len(key)!=32:raise RuntimeError('Invalid session encryption key')
        self.cipher=AESGCM(key);self.pending={}
        with sqlite3.connect(self.path,timeout=30) as db:
            db.execute('CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK(id=1),payload BLOB NOT NULL)')
        self.lock=Transaction(self)
    def find(self,header,create=False):
        now=self.clock();changed=False
        for sid,row in list(self.sessions.items()):
            if now>=row['end'] or now-row['last']>=row['idle']:
                self.sessions.pop(sid,None);changed=True
                if row.get('access_token'):self.queue_revocation(row)
        if changed:self.lock.checkpoint()
        if create and len(self.pending)>=2048:raise RateLimited()
        cookie=SimpleCookie()
        try:cookie.load(header)
        except Exception:raise Denied() from None
        sid=cookie['uniion_s01'].value if 'uniion_s01' in cookie else None
        row=self.sessions.get(sid)
        if not row and create:
            if len(self.sessions)>=2048 or sum(not x.get('access_token') for x in self.sessions.values())>=256:raise RateLimited()
            sid=secrets.token_urlsafe(32);row={'csrf':secrets.token_urlsafe(32),'end':now+600,'last':now,'idle':600};self.sessions[sid]=row
        if row:row['last']=now
        return sid,row
    def queue_revocation(self,session,scope="local"):
        ident=hashlib.sha256(session['csrf'].encode()).hexdigest()
        copy=dict(session);copy.pop('auth_in_flight',None);copy.pop('refresh_in_flight',None)
        self.pending[ident]={'session':copy,'scope':scope,'retry_at':self.clock()+30,'created_at':self.clock(),'failures':0}
        return ident
    def recover_interrupted(self):
        changed=False
        for sid,session in list(self.sessions.items()):
            if session.get('auth_in_flight') or session.get('refresh_in_flight'):
                self.sessions.pop(sid,None);changed=True
                if session.get('access_token'):
                    scope='global' if session.get('auth_in_flight')=='global' else 'local'
                    self.queue_revocation(session,scope)
                    if scope=='global' and session.get('user_id'):
                        for key,row in list(self.sessions.items()):
                            if row.get('user_id')==session['user_id']:self.sessions.pop(key,None)
        if changed:self.lock.checkpoint()
    def update(self,session,data):
        refreshing=session.pop('refresh_in_flight',False)
        super().update(session,data)
        if refreshing or any(entry['session'] is session for entry in self.pending.values()):self.lock.checkpoint()
    def authenticate(self,session):
        if session and session.get('access_token') and session['expires_at']<self.clock()+30:
            session['refresh_in_flight']=True;self.lock.checkpoint()
        user,status=super().authenticate(session)
        session['user_id']=user['id']
        if session.get('auth_in_flight')=='global':self.lock.checkpoint()
        if any(e.get('scope')=='global' and e['session'].get('user_id')==user['id'] for e in self.pending.values()):
            from uniion.core.contracts import Denied
            raise Denied()
        return user,status
    def rotate(self,sid,session):
        marked=session.pop('auth_in_flight',False)
        sid=super().rotate(sid,session)
        if marked:self.lock.checkpoint()
        return sid
    def post(self,path,sid,session,data,ip):
        if path in ('/auth/login','/auth/recovery/verify','/auth/mfa/verify','/auth/password') and session:
            previous_token=session.get('access_token')
            session['auth_in_flight']='global' if path=='/auth/password' else 'local';self.lock.checkpoint()
            try:result=super().post(path,sid,session,data,ip)
            except (AccessDenied,Denied,RateLimited,ValueError,KeyError,TypeError):
                if session.get('access_token')==previous_token:session.pop('auth_in_flight',None)
                raise
            except Exception:
                # A provider side effect may already have happened. Keep the
                # marker: the next transaction closes this uncertain session.
                raise
            session.pop('auth_in_flight',None)
            return result
        return super().post(path,sid,session,data,ip)
    def revoke(self,session,scope="local"):
        ident=self.queue_revocation(session,scope)
        for sid,row in list(self.sessions.items()):
            if row is session or row.get('csrf')==session.get('csrf') or (scope=='global' and session.get('user_id') and row.get('user_id')==session['user_id']):self.sessions.pop(sid)
        # Record local closure and the outbox BEFORE the irreversible Auth call.
        self.lock.checkpoint()
        try:super().revoke(self.pending[ident]['session'],scope)
        except (SupabaseUnavailable,AccessDenied):raise
        else:
            self.pending.pop(ident,None);self.lock.checkpoint()
    def retry_pending(self):
        due=[k for k,v in self.pending.items() if v['retry_at']<=self.clock()][:1]
        for key in due:
            entry=self.pending[key]
            try:super().revoke(entry['session'],entry.get('scope','local'))
            except SupabaseUnavailable:
                entry['failures']+=1;entry['retry_at']=self.clock()+min(300,30*2**min(entry['failures'],4))
            except AccessDenied:
                closed=False
                if entry.get('scope','local')=='local':
                    try:closed=self.api.request('/rest/v1/rpc/uniion_session_status',entry['session']['access_token'],{}).get('active') is False
                    except (AccessDenied,SupabaseUnavailable):pass
                if closed:self.pending.pop(key,None)
                else:entry['failures']+=1;entry['retry_at']=self.clock()+300
            else:self.pending.pop(key,None)
            self.lock.checkpoint()
    def maintain(self):
        with self.lock:
            self.retry_pending()
            self.find('',False)
            pending=len(self.pending)
            oldest=max((max(0,self.clock()-e.get('created_at',self.clock())) for e in self.pending.values()),default=0)
        self.write_health(True,pending,oldest)
    def write_health(self,ok,pending=None,oldest=None):
        data={'checked_at':time.time(),'ok':ok,'pending_revocations':pending,'oldest_pending_seconds':oldest}
        target=self.path.parent/'health.json';temp=target.with_suffix('.tmp-'+secrets.token_hex(8))
        fd=os.open(temp,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
        with os.fdopen(fd,'w') as output:json.dump(data,output);output.flush();os.fsync(output.fileno())
        os.replace(temp,target)

"""Local durable execution ledger. One shared server file, no prompts/results/tokens.

SQLite BEGIN IMMEDIATE serializes reservation and transitions across processes.
Not a multi-host ledger. Never automatically retry or delete executions.
"""
import contextlib
import sqlite3
import threading
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from .durable_sessions import private_file
from .sessions import RateLimited
from uniion.core.contracts import Denied

SCHEMA = Path(__file__).with_name('ai_runs_v1.sql').read_text()

class RunLedger:
    def __init__(self,path=':memory:',daily=100,concurrent=2,clock=time.time):
        if not isinstance(daily,int) or not 1<=daily<=10000 or not isinstance(concurrent,int) or not 1<=concurrent<=16:raise ValueError('Invalid quota')
        self.path=str(private_file(path)) if str(path)!=':memory:' else ':memory:'
        self.daily=daily;self.concurrent=concurrent;self.clock=clock;self.lock=threading.RLock()
        self.db=sqlite3.connect(self.path,timeout=15,isolation_level=None,check_same_thread=False)
        self.db.row_factory=sqlite3.Row
        self.db.execute('PRAGMA synchronous=FULL');self.db.execute('PRAGMA fullfsync=ON')
        version=self.db.execute('PRAGMA user_version').fetchone()[0]
        if version not in (0,1,2):raise RuntimeError('Unsupported AI ledger schema')
        if version==0:self.db.executescript(SCHEMA)
        if version<2:self.db.executescript(Path(__file__).with_name("ai_history_v2.sql").read_text())
        from .ai_history import History
        self.history=History(self)
    def close(self):self.db.close()
    def event(self,row,state,now):
        self.db.execute('INSERT INTO events(org,actor,id,state,at) VALUES(?,?,?,?,?)',(row['org'],row['actor'],row['id'],state,now))
    @contextlib.contextmanager
    def transaction(self):
        with self.lock:
            self.db.execute('BEGIN IMMEDIATE')
            try:
                now=self.clock()
                for r in self.db.execute('SELECT * FROM runs WHERE held=1 AND deadline<=?',(now,)).fetchall():
                    state=('uncertain' if r['dispatched'] else 'failed') if r['state']!='cancelled' else 'cancelled'
                    self.db.execute('UPDATE runs SET state=?,held=0,charged=dispatched,updated=? WHERE org=? AND actor=? AND id=?',(state,now,r['org'],r['actor'],r['id']))
                    self.event(r,state,now)
                yield now
                self.db.execute('COMMIT')
            except BaseException:
                self.db.execute('ROLLBACK');raise
    def row(self,org,actor,rid):
        return self.db.execute('SELECT * FROM runs WHERE org=? AND actor=? AND id=?',(org,actor,rid)).fetchone()
    def reserve(self,org,actor,rid,fingerprint):
        with self.transaction() as now:
            old=self.row(org,actor,rid)
            if old:raise Denied('ai_cancelled' if old['state']=='cancelled' else 'ai_replay')
            day=datetime.fromtimestamp(now,timezone.utc).date().isoformat()
            used=self.db.execute('SELECT coalesce(sum(charged),0) FROM runs WHERE org=? AND day=?',(org,day)).fetchone()[0]
            active=self.db.execute('SELECT count(*) FROM runs WHERE held=1').fetchone()[0]
            if used>=self.daily or active>=self.concurrent:raise RateLimited()
            owner=str(uuid.uuid4())
            self.db.execute('INSERT INTO runs VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)',(org,actor,rid,fingerprint,owner,'pending',day,1,0,1,now+180,now,now))
            self.event(self.row(org,actor,rid),'pending',now)
            return owner
    def start(self,org,actor,rid,owner):
        with self.transaction() as now:
            r=self.row(org,actor,rid)
            if not r or r['owner']!=owner or r['state']!='pending' or not r['held']:raise Denied('ai_not_pending')
            self.db.execute("UPDATE runs SET state='running',dispatched=1,updated=?,deadline=? WHERE org=? AND actor=? AND id=?",(now,now+180,org,actor,rid))
            self.event(r,'running',now)
    def live(self,org,actor,rid,owner):
        with self.transaction():
            r=self.row(org,actor,rid)
            return bool(r and r['owner']==owner and r['held'] and r['state'] in ('pending','running'))
    def finish(self,org,actor,rid,owner,state,response=None):
        if state not in ('succeeded','failed','cancelled','uncertain'):raise ValueError('Invalid terminal state')
        with self.transaction() as now:
            r=self.row(org,actor,rid)
            if not r or r['owner']!=owner:raise Denied()
            # A late response cannot promote an expired/cancelled execution.
            if r['state'] not in ('pending','running'):
                if r['state']=='cancelled' and r['held']:
                    self.db.execute('UPDATE runs SET held=0,updated=? WHERE org=? AND actor=? AND id=?',(now,org,actor,rid))
                return r['state']
            if state=='succeeded' and not r['dispatched']:raise Denied()
            self.db.execute('UPDATE runs SET state=?,held=0,charged=dispatched,updated=? WHERE org=? AND actor=? AND id=?',(state,now,org,actor,rid))
            if response is not None:
                if state!='succeeded':raise Denied()
                blob=self.history.seal(org,actor,rid,response)
                self.db.execute('INSERT INTO responses(org,actor,id,payload,created) VALUES(?,?,?,?,?)',(org,actor,rid,blob,now))
            self.event(r,state,now)
            return state
    def cancel(self,org,actor,rid):
        with self.transaction() as now:
            r=self.row(org,actor,rid)
            if not r:
                day=datetime.fromtimestamp(now,timezone.utc).date().isoformat()
                self.db.execute('INSERT INTO runs VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)',(org,actor,rid,None,'','cancelled',day,0,0,0,now,now,now))
                self.event(self.row(org,actor,rid),'cancelled',now)
            elif r['state'] in ('pending','running'):
                self.db.execute("UPDATE runs SET state='cancelled',charged=dispatched,held=dispatched,updated=? WHERE org=? AND actor=? AND id=?",(now,org,actor,rid))
                self.event(r,'cancelled',now)
        return {'cancelled':True}
    def status(self,org,actor,rid=None):
        with self.transaction() as now:
            day=datetime.fromtimestamp(now,timezone.utc).date().isoformat()
            used=self.db.execute('SELECT coalesce(sum(charged),0) FROM runs WHERE org=? AND day=?',(org,day)).fetchone()[0]
            rows=([self.row(org,actor,rid)] if rid else self.db.execute('SELECT * FROM runs WHERE org=? AND actor=? ORDER BY created DESC LIMIT 10',(org,actor)).fetchall())
            return {'dailyLimit':self.daily,'reservedOrDispatched':used,'remaining':max(0,self.daily-used),'period':day,'timezone':'UTC',
                    'usage':None,'cost':None,'scope':'local-instance','runs':[{'request_id':r['id'],'state':r['state'],'dispatched':bool(r['dispatched']),'created':r['created'],'updated':r['updated'],'usage':None,'cost':None} for r in rows if r]}

"""Encrypted, actor-scoped assistant history. No browser-supplied response writes."""
import json
import os
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from .durable_sessions import private_file
from uniion.core.contracts import Denied

class History:
    def __init__(self,ledger):
        self.ledger=ledger
        if ledger.path==':memory:':key=os.urandom(32)
        else:
            path=Path(ledger.path).with_suffix('.history.key')
            # Never silently replace a lost key when stored ciphertext exists.
            if not path.exists() and ledger.db.execute('SELECT count(*) FROM responses').fetchone()[0]:raise RuntimeError('History key missing')
            key=private_file(path,os.urandom(32)).read_bytes()
        self.cipher=AESGCM(key)
    def aad(self,org,actor,rid):return json.dumps(['uniion-ai-history-v1',org,actor,rid],separators=(',',':')).encode()
    def seal(self,org,actor,rid,response):
        nonce=os.urandom(12)
        return nonce+self.cipher.encrypt(nonce,json.dumps(response,ensure_ascii=False).encode(),self.aad(org,actor,rid))
    def decode(self,row):
        blob=row['payload'];response=json.loads(self.cipher.decrypt(blob[:12],blob[12:],self.aad(row['org'],row['actor'],row['id'])))
        return {'id':row['id'],'version':row['version'],'remembered':bool(row['remembered']),'archived':bool(row['archived']),'created':row['created'],'response':response}
    def rows(self,org,actor):
        with self.ledger.transaction():
            return self.ledger.db.execute('SELECT * FROM responses WHERE org=? AND actor=? AND archived=0 ORDER BY created DESC LIMIT 50',(org,actor)).fetchall()
    def remembered_rows(self,org,actor):
        with self.ledger.transaction():
            return self.ledger.db.execute('SELECT * FROM responses WHERE org=? AND actor=? AND archived=0 AND remembered=1 ORDER BY created DESC',(org,actor)).fetchall()
    def read(self,org,actor,rid):
        with self.ledger.transaction():
            row=self.ledger.db.execute('SELECT * FROM responses WHERE org=? AND actor=? AND id=? AND archived=0',(org,actor,rid)).fetchone()
            if not row:raise Denied()
            return self.decode(row)
    def preference(self,org,actor):
        with self.ledger.transaction():
            row=self.ledger.db.execute('SELECT * FROM memory_preferences WHERE org=? AND actor=?',(org,actor)).fetchone()
            return {'enabled':bool(row['enabled']),'version':row['version']} if row else {'enabled':False,'version':0}
    def configure(self,org,actor,enabled,version):
        if type(enabled)!=bool or type(version)!=int or version<0:raise Denied()
        with self.ledger.transaction() as now:
            row=self.ledger.db.execute('SELECT * FROM memory_preferences WHERE org=? AND actor=?',(org,actor)).fetchone()
            if (row['version'] if row else 0)!=version:raise Denied('ai_version_conflict')
            self.ledger.db.execute('INSERT INTO memory_preferences VALUES(?,?,?,?) ON CONFLICT(org,actor) DO UPDATE SET enabled=excluded.enabled,version=excluded.version',(org,actor,int(enabled),version+1))
            self.ledger.event({'org':org,'actor':actor,'id':'memory'},'memory_enabled' if enabled else 'memory_disabled',now)
        return {'enabled':enabled,'version':version+1}
    def change(self,org,actor,rid,version,action,enabled=None):
        if type(version)!=int or version<1 or action not in ('remember','archive') or (action=='remember' and type(enabled)!=bool):raise Denied()
        with self.ledger.transaction() as now:
            row=self.ledger.db.execute('SELECT * FROM responses WHERE org=? AND actor=? AND id=? AND archived=0',(org,actor,rid)).fetchone()
            if not row or row['version']!=version:raise Denied('ai_version_conflict')
            if action=='remember':
                count=self.ledger.db.execute('SELECT count(*) FROM responses WHERE org=? AND actor=? AND archived=0 AND remembered=1',(org,actor)).fetchone()[0]
                if enabled and not row['remembered'] and count>=8:raise Denied('ai_memory_limit')
                self.ledger.db.execute('UPDATE responses SET remembered=?,version=version+1 WHERE org=? AND actor=? AND id=?',(int(enabled),org,actor,rid))
            else:self.ledger.db.execute('UPDATE responses SET archived=1,remembered=0,version=version+1 WHERE org=? AND actor=? AND id=?',(org,actor,rid))
            self.ledger.event(row,'history_archived' if action=='archive' else 'memory_remembered' if enabled else 'memory_unlinked',now)
        return {'updated':True,'version':version+1}
    def signature(self,org,actor):
        # One transaction for opt-in and all remembered versions, not a truncated listing.
        with self.ledger.transaction():
            p=self.ledger.db.execute('SELECT enabled,version FROM memory_preferences WHERE org=? AND actor=?',(org,actor)).fetchone()
            pref=tuple(p) if p else (0,0)
            rows=self.ledger.db.execute('SELECT id,version FROM responses WHERE org=? AND actor=? AND archived=0 AND remembered=1 ORDER BY id',(org,actor)).fetchall() if pref[0] else []
            return pref,[tuple(r) for r in rows]
    def draft(self,org,actor,rid,version,action,text=None):
        if type(version)!=int or version<1 or action not in ('edit','review'):raise Denied()
        if action=='edit' and (not isinstance(text,str) or not 1<=len(text.strip())<=6000 or any(ord(c)<32 and c not in '\n\t\r' for c in text)):raise Denied()
        with self.ledger.transaction() as now:
            row=self.ledger.db.execute('SELECT * FROM responses WHERE org=? AND actor=? AND id=? AND archived=0',(org,actor,rid)).fetchone()
            if not row or row['version']!=version:raise Denied('ai_version_conflict')
            response=self.decode(row)['response']
            if response.get('mode')!='business-draft':raise Denied()
            if action=='edit':
                edits=response.get('edits',[])
                if len(edits)>=20:raise Denied('ai_revision_limit')
                response['edits']=edits+[{'text':response['text'],'version':version,'at':now}]
                response['text']=text.strip();response['reviewed']=False
            else:response['reviewed']=True
            self.ledger.db.execute('UPDATE responses SET payload=?,version=version+1 WHERE org=? AND actor=? AND id=?',(self.seal(org,actor,rid,response),org,actor,rid))
            self.ledger.event(row,'draft_'+action,now)
        return {'updated':True,'version':version+1}

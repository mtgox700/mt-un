#!/usr/bin/env python3
"""Prototype local : fichiers statiques + passerelle ChatGPT via Codex app-server."""
import json, os, pathlib, queue, secrets, shutil, subprocess, threading, time
from exports import export_file
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
ROOT = pathlib.Path(__file__).resolve().parent
PUBLIC = ROOT / 'public'
PORT = int(os.environ.get('UNIION_PORT', '5050'))
ORIGIN = 'http://127.0.0.1:%d' % PORT
TOKEN = secrets.token_urlsafe(32)
LOCK = threading.BoundedSemaphore(2)
CODEX = shutil.which('codex')


def complete(body):
    proc = subprocess.Popen([CODEX, 'app-server', '--stdio', '-c', 'mcp_servers={}', '-c', 'web_search="disabled"', '-c', 'features.apps=false', '-c', 'features.shell_tool=false', '-c', 'features.browser_use=false', '-c', 'features.computer_use=false', '-c', 'features.multi_agent=false'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, cwd=str(ROOT))
    messages = queue.Queue()
    def reader():
        for line in proc.stdout:
            try: messages.put(json.loads(line))
            except ValueError: pass
        messages.put({'fatal': 'Connexion Codex interrompue'})
    threading.Thread(target=reader, daemon=True).start()
    deadline = time.monotonic() + 180
    def send(method, params, ident=None):
        msg = {'method': method, 'params': params}
        if ident is not None: msg['id'] = ident
        proc.stdin.write(json.dumps(msg) + '\n'); proc.stdin.flush()
    def receive():
        msg = messages.get(timeout=max(.1, deadline-time.monotonic()))
        if 'fatal' in msg: raise RuntimeError(msg['fatal'])
        if 'method' in msg and 'id' in msg:
            proc.stdin.write(json.dumps({'id':msg['id'],'error':{'code':-32601,'message':'Outils et approbations indisponibles dans ce prototype'}})+'\n'); proc.stdin.flush()
        return msg
    def rpc(ident, method, params):
        send(method, params, ident)
        while True:
            msg = receive()
            if msg.get('id') == ident:
                if 'error' in msg: raise RuntimeError(msg['error'].get('message','Erreur Codex'))
                return msg.get('result', {})
    try:
        rpc(1, 'initialize', {'clientInfo': {'name':'uniion_local','version':'0.1.0'}})
        send('initialized', {})
        account = rpc(2, 'account/read', {})
        if (account.get('account') or {}).get('type') != 'chatgpt':
            raise RuntimeError('Connectez Codex à ChatGPT avec codex login, puis réessayez.')
        thread = rpc(3, 'thread/start', {'ephemeral':True, 'cwd':str(ROOT), 'sandbox':'read-only', 'approvalPolicy':'never', 'baseInstructions':'Tu es le moteur textuel du prototype uniion. Réponds uniquement à la demande, sans outils, sans accès aux fichiers et sans action externe. Respecte le format demandé. Ne prétends pas avoir vérifié une source en ligne.', 'developerInstructions':body['system'], 'config':{'web_search':'disabled','features.shell_tool':False,'features.apps':False,'features.multi_agent':False}})
        rpc(4, 'turn/start', {'threadId':thread['thread']['id'], 'input':[{'type':'text','text':body['user']} ], 'effort':body.get('effort','medium')})
        output = []
        while True:
            msg = receive()
            if msg.get('method') == 'item/completed':
                item = msg.get('params',{}).get('item',{})
                if item.get('type') == 'agentMessage': output.append(item.get('text',''))
            if msg.get('method') == 'turn/completed':
                turn = msg.get('params',{}).get('turn',{})
                if turn.get('status') != 'completed': raise RuntimeError((turn.get('error') or {}).get('message','Réponse IA interrompue'))
                if not output: raise RuntimeError('Réponse IA vide')
                return '\n'.join(output)
    finally:
        proc.terminate()
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: proc.kill(); proc.wait()

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs): super().__init__(*args, directory=str(PUBLIC), **kwargs)
    def log_message(self, fmt, *args): pass
    def json(self, status, data):
        raw = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status); self.send_header('Content-Type','application/json; charset=utf-8'); self.send_header('Cache-Control','no-store'); self.send_header('Content-Length',str(len(raw))); self.end_headers(); self.wfile.write(raw)
    def allowed_host(self): return self.headers.get('Host') == '127.0.0.1:%d' % PORT
    def do_GET(self):
        if not self.allowed_host(): return self.json(403, {'error':'Hôte refusé'})
        if self.path == '/':
            self.send_response(302); self.send_header('Location','/uniion%20App%20v3.dc.html'); self.end_headers(); return
        if self.path == '/local-bridge.js':
            raw = ("""window.uniionLocal = {
              complete: async function(system,user,max,effort) {
                const r = await fetch('/api/complete',{method:'POST',headers:{'Content-Type':'application/json','X-Uniion-Token':%s},body:JSON.stringify({system,user,max,effort})});
                const d=await r.json(); if(!r.ok) throw new Error(d.error || 'Erreur IA locale'); return d.text;
              },
              download: async function(data) {
                const r = await fetch('/api/export',{method:'POST',headers:{'Content-Type':'application/json','X-Uniion-Token':%s},body:JSON.stringify(data)});
                if(!r.ok) { const d=await r.json(); throw new Error(d.error || 'Export impossible'); }
                const blob=await r.blob(), url=URL.createObjectURL(blob), a=document.createElement('a');
                a.href=url; a.download=data.filename || 'export'; document.body.appendChild(a); a.click(); a.remove(); setTimeout(()=>URL.revokeObjectURL(url),60000);
              }
            };""" % (json.dumps(TOKEN),json.dumps(TOKEN))).encode()
            self.send_response(200); self.send_header('Content-Type','text/javascript'); self.send_header('Cache-Control','no-store'); self.end_headers(); self.wfile.write(raw); return
        if self.path == '/api/status': return self.json(200, {'bridge':'codex-chatgpt','local':True})
        return super().do_GET()
    def do_POST(self):
        if not self.allowed_host() or self.headers.get('Origin') != ORIGIN or self.headers.get('X-Uniion-Token') != TOKEN: return self.json(403,{'error':'Origine refusée'})
        if self.path not in ('/api/complete','/api/export'): return self.json(404,{'error':'Route inconnue'})
        try:
            length = int(self.headers.get('Content-Length','0'))
            if not 0 < length <= 200000: return self.json(413,{'error':'Requête trop volumineuse'})
            data = json.loads(self.rfile.read(length))
            if not isinstance(data,dict): return self.json(400,{'error':'Objet JSON attendu'})
            if self.path == '/api/export':
                raw, mime = export_file(data)
                self.send_response(200); self.send_header('Content-Type',mime); self.send_header('Cache-Control','no-store'); self.send_header('Content-Length',str(len(raw))); self.end_headers(); self.wfile.write(raw); return
            if data.get('effort','medium') not in ('low','medium','high'): return self.json(400,{'error':'Effort invalide'})
            if not all(isinstance(data.get(k),str) and len(data[k]) <= 100000 for k in ('system','user')): return self.json(400,{'error':'Requête invalide'})
        except (ValueError, TypeError): return self.json(400,{'error':'JSON invalide'})
        if not LOCK.acquire(timeout=180): return self.json(503,{'error':'File IA occupée depuis 180 secondes. Réessayez.'})
        try: self.json(200,{'text':complete(data)})
        except queue.Empty: self.json(504,{'error':'Délai IA dépassé (180 secondes).'})
        except Exception as exc: self.json(502,{'error':str(exc)[:500]})
        finally: LOCK.release()

if __name__ == '__main__':
    if not CODEX: raise SystemExit('Codex CLI introuvable : installer Codex et se connecter à ChatGPT.')
    print('Prototype uniion : '+ORIGIN, flush=True)
    ThreadingHTTPServer(('127.0.0.1',PORT), Handler).serve_forever()

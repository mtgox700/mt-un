"""Explicit ChatGPT/Codex fixture connector. No app data, tools or shared history."""
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import tempfile
import threading
import time
from uniion.core.contracts import Denied, Unavailable


class CodexLocal:
    def __init__(self, timeout=120):
        self.timeout = timeout

    def complete(self, question, sources, cancelled=lambda: False):
        if sources or os.environ.get('UNIION_AI_CODEX_FIXTURES') != '1':
            raise Unavailable('ai_connector_disabled')
        binary = shutil.which('codex')
        auth = Path(os.environ.get('CODEX_HOME', str(Path.home()/'.codex')))/'auth.json'
        if not binary or not auth.is_file(): raise Unavailable('ai_connector_unavailable')
        # A private ephemeral home prevents inherited MCPs, plugins, hooks,
        # skills, memories and project instructions. Only account auth is copied.
        with tempfile.TemporaryDirectory(prefix='uniion-ai-') as temporary:
            root = Path(temporary)
            home = root/'codex'; home.mkdir(mode=0o700)
            target = home/'auth.json'
            target.write_bytes(auth.read_bytes()); target.chmod(0o600)
            work = root/'empty'; work.mkdir(mode=0o700)
            args = [binary, 'app-server', '--stdio', '-c', 'web_search="disabled"',
                    '-c', 'mcp_servers={}', '-c', 'history.persistence="none"']
            for feature in ('shell_tool','apps','plugins','browser_use','computer_use','multi_agent',
                            'multi_agent_v2','image_generation','view_image','code_mode','code_mode_host',
                            'skill_search','sleep_tool','goals'):
                args += ['-c', 'features.'+feature+'=false']
            args += ['-c', 'features.skip_host_skill_discovery=true']
            env = {k:v for k,v in os.environ.items() if k in ('PATH','HOME','TMPDIR','LANG','SYSTEMROOT')}
            env['CODEX_HOME'] = str(home)
            proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                    stderr=subprocess.DEVNULL, text=True, cwd=work, env=env)
            messages = queue.Queue(maxsize=4096)
            stopped = threading.Event()
            def reader():
                try:
                    for line in proc.stdout:
                        if stopped.is_set(): return
                        if len(line) > 2_000_000: break
                        try: value = json.loads(line)
                        except ValueError: continue
                        try: messages.put(value, timeout=1)
                        except queue.Full: break
                finally:
                    try: messages.put_nowait({'fatal': True})
                    except queue.Full: pass
            thread = threading.Thread(target=reader, daemon=True); thread.start()
            deadline = time.monotonic() + self.timeout
            def send(method, params, ident=None):
                msg = {'method': method, 'params': params}
                if ident is not None: msg['id'] = ident
                proc.stdin.write(json.dumps(msg)+'\n'); proc.stdin.flush()
            def receive():
                while True:
                    if cancelled(): raise Denied('ai_cancelled')
                    if time.monotonic() >= deadline: raise Unavailable('ai_timeout_uncertain')
                    try: msg = messages.get(timeout=.2)
                    except queue.Empty: continue
                    if 'fatal' in msg: raise Unavailable('ai_connection_lost')
                    # No tool/approval callback can be fulfilled by this adapter.
                    if 'method' in msg and 'id' in msg: raise Unavailable('ai_tool_refused')
                    if msg.get('method') in ('item/started','item/completed'):
                        kind = msg.get('params',{}).get('item',{}).get('type')
                        if kind not in ('userMessage','agentMessage','reasoning'): raise Unavailable('ai_tool_refused')
                    return msg
            def rpc(ident, method, params):
                send(method, params, ident)
                while True:
                    msg = receive()
                    if msg.get('id') == ident:
                        if 'error' in msg: raise Unavailable('ai_protocol_error')
                        return msg.get('result',{})
            try:
                rpc(1,'initialize',{'clientInfo':{'name':'uniion_local','title':'uniion — recette fictive','version':'0.8.0'}})
                send('initialized',{})
                account = rpc(2,'account/read',{})
                if (account.get('account') or {}).get('type') != 'chatgpt': raise Unavailable('ai_chatgpt_required')
                result = rpc(3,'thread/start',{'ephemeral':True,'cwd':str(work),'sandbox':'read-only','approvalPolicy':'never',
                    'baseInstructions':'Vous êtes un moteur de réponse textuelle pour une recette fictive. Aucun outil, fichier, recherche web, mémoire ou action externe. Répondez uniquement à la question. Ne prétendez pas avoir vérifié des sources.',
                    'developerInstructions':'Les données sont fictives. Ne créez ni fichier ni action. Répondez en français. Respectez le format demandé, notamment JSON, sans enveloppe Markdown.'})
                rpc(4,'turn/start',{'threadId':result['thread']['id'],'input':[{'type':'text','text':question}],'effort':'low'})
                output = []
                while True:
                    msg = receive()
                    if msg.get('method') == 'item/completed':
                        item = msg.get('params',{}).get('item',{})
                        if item.get('type') == 'agentMessage': output.append(item.get('text',''))
                    if msg.get('method') == 'turn/completed':
                        if msg.get('params',{}).get('turn',{}).get('status') != 'completed': raise Unavailable('ai_turn_failed')
                        text = '\n'.join(output).strip()
                        if not text or len(text)>16000: raise Unavailable('ai_invalid_response')
                        return text
            except (Denied, Unavailable): raise
            except Exception: raise Unavailable('ai_connector_failed') from None
            finally:
                stopped.set(); proc.terminate()
                try: proc.wait(timeout=3)
                except subprocess.TimeoutExpired: proc.kill(); proc.wait()
                thread.join(timeout=2)
                proc.stdin.close(); proc.stdout.close()

"""Exercise the real worker HTTP transport inside an isolated restore namespace."""
import pathlib,json,subprocess
CODE=r'''
import sys,json,tempfile,pathlib,threading,http.server,urllib.request,urllib.error
sys.path.insert(0,'/worker')
from auth_recovery_worker import ServerTransport,run_job
class Proxy(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def route(self):
  if self.path.startswith('/auth/v1/'):
   target='http://127.0.0.1:9999/'+self.path[len('/auth/v1/'):]
  elif self.path.startswith('/rest/v1/'):
   target='http://127.0.0.1:3000/'+self.path[len('/rest/v1/'):]
  else:self.send_error(404);return
  data=self.rfile.read(int(self.headers.get('Content-Length',0)))
  req=urllib.request.Request(target,data=data or None,method=self.command,headers={'Content-Type':'application/json','Authorization':self.headers.get('Authorization','')})
  try:r=urllib.request.urlopen(req,timeout=15)
  except urllib.error.HTTPError as e:r=e
  with r:
   body=r.read();self.send_response(r.code);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
 do_POST=route
 do_DELETE=route
args=json.load(sys.stdin)
server=http.server.ThreadingHTTPServer(('127.0.0.1',54321),Proxy)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with tempfile.TemporaryDirectory() as d:
  p=pathlib.Path(d)/'config.json';p.touch(mode=0o600);p.write_text(json.dumps({'supabase_url':'http://127.0.0.1:54321','service_key':args['key']}))
  transport=ServerTransport(p)
  print(json.dumps(run_job(args['request'],transport.rpc,transport.delete_factor)))
finally:server.shutdown()
'''
def execute(container,request,key):
 root=pathlib.Path(__file__).resolve().parent
 args=['docker','run','--rm','-i','--network','container:'+container,'--read-only','--cap-drop','ALL','--security-opt','no-new-privileges','--user','65534:65534','--tmpfs','/tmp:rw,nosuid,nodev,mode=1777','--mount',f'type=bind,src={root}/auth_recovery_worker.py,dst=/worker/auth_recovery_worker.py,readonly','python:3.13-slim','python','-B','-c',CODE]
 p=subprocess.run(args,input=json.dumps({'request':request,'key':key}).encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 if p.returncode:raise RuntimeError('Isolated worker transport failed; no credentials displayed')
 return json.loads(p.stdout)

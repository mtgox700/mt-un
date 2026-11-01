"""Ephemeral local UI recipe: real fictive Auth/MFA, no production entry point."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'tests/s09_audio_integration.py').read_text().split("check('invalid_container_refused'")[0].replace('preuves/S09-A2-audio','preuves/S09-B/ui')
__file__=str(root/'tests/s09_audio_integration.py')
exec(compile(source,__file__,'exec'))
sql(f"""insert into public.uniion_module_access select '{org}',m,true,true,'included',now()+interval '1 day' from unnest(array['agenda','dossiers'])m;
insert into public.uniion_permissions select '{org}','{a['id']}',m,'read' from unnest(array['agenda','dossiers'])m;
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) select '{org}',m,'paid',now()-interval '1 day',now()+interval '1 day','RECETTE-S09-B' from unnest(array['agenda','dossiers'])m;""")
(root/'preuves/S09-B/ui-fictif.wav').write_bytes(raw)
from wsgiref.simple_server import make_server,WSGIRequestHandler
import uniion.http_sessions as http
import os
port=int(os.environ.get('S09_RECIPE_PORT','5069'));http.PORT=str(port);http.ORIGIN='http://127.0.0.1:'+str(port)
# Explicit isolated port for this recipe only; normal application policy unchanged.
app.sessions.clock=time.time
used=False
class Quiet(WSGIRequestHandler):
 def log_message(self,*a):pass
def wrapper(e,start):
 global used
 if e.get('PATH_INFO')=='/recipe' and not used and e.get('HTTP_HOST')=='127.0.0.1:'+str(port):
  used=True;start('302 Found',[('Location','/s02?organization='+org+'&screen=reunions'),('Set-Cookie',x.cookie+'; Path=/; HttpOnly; SameSite=Strict'),('Cache-Control','no-store')]);return [b'']
 if os.environ.get('S09_SYNTHETIC_MIC')=='1' and e.get('PATH_INFO')=='/s02':
  response=[];body=b''.join(app(e,lambda status,headers:response.append((status,headers))))
  injection=b'''<script>navigator.mediaDevices.getUserMedia=async()=>{const c=new AudioContext();await c.resume();const o=c.createOscillator(),g=c.createGain(),d=c.createMediaStreamDestination();g.gain.value=0.01;o.frequency.value=440;o.connect(g);g.connect(d);o.start();d.stream.getTracks().forEach(t=>{const stop=t.stop.bind(t);t.stop=()=>{stop();o.stop();c.close()}});return d.stream;};</script>'''
  body=body.replace(b'<script src="/host/demo.js">',injection+b'<script src="/host/demo.js">');status,headers=response[0];headers=[(k,v) for k,v in headers if k.lower()!='content-length'];headers.append(('Content-Length',str(len(body))));start(status,headers);return [body]
 return app(e,start)
with make_server('127.0.0.1',port,wrapper,handler_class=Quiet) as server:
 print('Recette fictive prête : http://127.0.0.1:'+str(port)+'/recipe',flush=True);server.serve_forever()

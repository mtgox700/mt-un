"""Ephemeral local UI recipe: real fictive Auth/MFA, no production entry point."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'tests/s09_audio_integration.py').read_text().split("check('invalid_container_refused'")[0].replace('preuves/S09-A2-audio','preuves/S09-D/ui')
__file__=str(root/'tests/s09_audio_integration.py')
exec(compile(source,__file__,'exec'))
sql(f"""insert into public.uniion_module_access select '{org}',m,true,true,'included',now()+interval '1 day' from unnest(array['agenda','dossiers'])m;
insert into public.uniion_permissions select '{org}','{a['id']}',m,'read' from unnest(array['agenda','dossiers'])m;
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference) select '{org}',m,'paid',now()-interval '1 day',now()+interval '1 day','RECETTE-S09-D' from unnest(array['agenda','dossiers'])m;""")
# Synthetic speech is uploaded through the real audio command before UI actions.
with wave.open(str(root/'preuves/S09-D/parole-fictive.wav')) as r:
 buf=io.BytesIO()
 with wave.open(buf,'wb') as w:w.setparams(r.getparams());w.writeframes(r.readframes(r.getnframes()))
raw=buf.getvalue();payload.update(content=base64.b64encode(raw).decode(),filename='parole-fictive.wav')
st,result,_=upload();check('ui_speech_uploaded',st==200)
aid=result['id']
check('ui_marker',call(x,'audio_markers_save',{'id':rid,'audio':aid,'version':0,'markers':[{'id':str(uuid.uuid4()),'timeMs':1000,'kind':'decision','note':'Dossier vendredi — formulation à relire.'}]})[0]==200)
check('ui_transcription_start',business(x,'transcription_start',{'id':rid,'audio':aid})[0]==200)
import sys
sys.path.insert(0,str(root/'operations'))
from transcription_worker import process_one
account=json.loads((root/'.local-auth/transcription-worker.json').read_text())
check('ui_real_transcription',process_one(api,api.login(account['email'],account['password'])['access_token']))
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','rights',false),('{org}','{a['id']}','content_review',false),('{org}','{a['id']}','content_publish',false),('{org}','{b['id']}','content_review',false),('{org}','{b['id']}','content_publish',false)")
check('ui_reviewer_audio',call(x,'audio_grant',{'id':rid,'user':b['id'],'version':0,'read':True,'write':False,'download':False})[0]==200)
(root/'preuves/S09-D/ui-recipe.json').write_text(json.dumps({'organization':org,'meeting':rid,'recipient':a['email']}))
from wsgiref.simple_server import make_server,WSGIRequestHandler
import uniion.http_sessions as http
import os
port=int(os.environ.get('S09_RECIPE_PORT','5072'));http.PORT=str(port);http.ORIGIN='http://127.0.0.1:'+str(port)
# Explicit isolated port for this recipe only; normal application policy unchanged.
app.sessions.clock=time.time
# Discard only synthetic-clock bootstrap quota timestamps in this isolated recipe instance.
app.sessions.attempts.clear()
used=set()
class Quiet(WSGIRequestHandler):
 def log_message(self,*a):pass
def wrapper(e,start):
 global used
 if e.get('PATH_INFO') in ('/recipe','/recipe-reviewer','/recipe-author') and e.get('PATH_INFO') not in used and e.get('HTTP_HOST')=='127.0.0.1:'+str(port):
  route=e['PATH_INFO'];used.add(route);client=y if route=='/recipe-reviewer' else x
  start('302 Found',[('Location','/s02?organization='+org+'&screen=reunions'),('Set-Cookie',client.cookie+'; Path=/; HttpOnly; SameSite=Strict'),('Cache-Control','no-store')]);return [b'']
 if os.environ.get('S09_SYNTHETIC_MIC')=='1' and e.get('PATH_INFO')=='/s02':
  response=[];body=b''.join(app(e,lambda status,headers:response.append((status,headers))))
  injection=b'''<script>navigator.mediaDevices.getUserMedia=async()=>{const c=new AudioContext();await c.resume();const o=c.createOscillator(),g=c.createGain(),d=c.createMediaStreamDestination();g.gain.value=0.01;o.frequency.value=440;o.connect(g);g.connect(d);o.start();d.stream.getTracks().forEach(t=>{const stop=t.stop.bind(t);t.stop=()=>{stop();o.stop();c.close()}});return d.stream;};</script>'''
  body=body.replace(b'<script src="/host/demo.js">',injection+b'<script src="/host/demo.js">');status,headers=response[0];headers=[(k,v) for k,v in headers if k.lower()!='content-length'];headers.append(('Content-Length',str(len(body))));start(status,headers);return [body]
 return app(e,start)
with make_server('127.0.0.1',port,wrapper,handler_class=Quiet) as server:
 print('Recette fictive prête : http://127.0.0.1:'+str(port)+'/recipe',flush=True);server.serve_forever()

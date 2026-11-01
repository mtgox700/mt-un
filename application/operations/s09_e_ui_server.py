"""Ephemeral UI for the already executed fictive retention fixture, no mutations."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
__file__=str(root/'tests/s09_consent_integration.py')
source=(root/'tests/s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:")
exec(compile(source,__file__,'exec'))
f=json.loads((root/'.local-auth/s08-fixture.json').read_text());fixture=json.loads((root/'preuves/S09-E/restore-fixture.json').read_text());org=fixture['organization']
x=Client();check('login',x.login(f['author'])[0]==200);check('mfa',verify(x,f['authorFactor'],f['authorSecret'])[0][0]==200)
from wsgiref.simple_server import make_server,WSGIRequestHandler
import uniion.http_sessions as http
http.PORT='5073';http.ORIGIN='http://127.0.0.1:5073';app.sessions.clock=time.time;app.sessions.attempts.clear();used=False
class Quiet(WSGIRequestHandler):
 def log_message(self,*a):pass
def wrapper(e,start):
 global used
 if not used and e.get('PATH_INFO')=='/recipe' and e.get('HTTP_HOST')=='127.0.0.1:5073':
  used=True;start('302 Found',[('Location','/s02?organization='+org+'&screen=reunions'),('Set-Cookie',x.cookie+'; Path=/; HttpOnly; SameSite=Strict'),('Cache-Control','no-store')]);return [b'']
 return app(e,start)
with make_server('127.0.0.1',5073,wrapper,handler_class=Quiet) as server:
 print('Recette fictive E : http://127.0.0.1:5073/recipe',flush=True);server.serve_forever()

"""Local-only modular demo host. No API, secrets or access to S01 sessions."""
from pathlib import Path
import json,re,os
from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from urllib.parse import urlsplit,unquote
PORT=int(os.environ.get('UNIION_FRONTEND_PORT','5063'))
ROOT=Path(__file__).resolve().parents[1]/'frontend'
def assemble_reference():
 manifest=json.loads((ROOT/'manifest.json').read_text());html=(ROOT/'host/shell.html').read_text()
 for module in manifest['modules']:
  path=(ROOT/module['view']).resolve()
  if ROOT.resolve() not in path.parents:raise ValueError('Invalid view')
  html=html.replace('<!--MODULE:'+module['id']+'-->',path.read_text())
 logic=(ROOT/manifest['logic']).read_text()
 # Initial route is fixture-only, never an authorization for real data.
 logic=logic.replace('const self = this;',"const initial = new URLSearchParams(location.search).get('screen'); if (['accueil','dossiers','dossier','contacts'].includes(initial)) this.setState({authed:true,route:initial}); const self = this;",1)
 return html.replace('<!--LOGIC-->',logic).encode()
def assemble():
 return (ROOT/('dist/index-before-state.html' if os.environ.get('UNIION_NATIVE')=='before-state' else 'dist/index-native.html' if os.environ.get('UNIION_NATIVE')=='1' else 'dist/index.html')).read_bytes()
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  if self.headers.get('Host')!='127.0.0.1:'+str(PORT):self.send_error(403);return
  path=unquote(urlsplit(self.path).path)
  if path=='/':raw=assemble();mime='text/html; charset=utf-8'
  else:
   file=(ROOT/path.lstrip('/')).resolve()
   if ROOT.resolve() not in file.parents or not file.is_file() or file.suffix not in ('.js','.css','.png','.json'):self.send_error(404);return
   raw=file.read_bytes();mime={'.js':'text/javascript','.css':'text/css','.png':'image/png','.json':'application/json'}[file.suffix]
  self.send_response(200);self.send_header('Content-Type',mime);self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
if __name__=='__main__':ThreadingHTTPServer(('127.0.0.1',PORT),Handler).serve_forever()

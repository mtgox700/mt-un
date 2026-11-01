import os,sys
from pathlib import Path
os.environ['UNIION_PORT']='5054'
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'reference-prototype/2026-10-23-v1/application'))
import server
PAGE='''<!doctype html><html lang="fr"><meta charset="utf-8"><title>Banc de recette responsive</title><style>body{margin:0;background:#ddd;font:14px system-ui}nav{padding:8px;position:sticky;top:0;background:white;z-index:2}button{margin-right:8px}iframe{display:block;border:0;background:white;margin:8px}</style><nav aria-label="Dimensions de recette"><button onclick="size(1280,900)">Bureau 1280</button><button onclick="size(390,844)">Mobile 390</button><button onclick="size(768,1024)">Tablette 768</button><button onclick="size(1024,768)">Tablette paysage 1024</button><span id="dimensions">390 × 844</span></nav><iframe id="prototype" title="Prototype inchangé" width="390" height="844" src="/uniion%20App%20v3.dc.html"></iframe><script>function size(w,h){const f=document.getElementById('prototype');f.width=w;f.height=h;document.getElementById('dimensions').textContent=w+' × '+h}</script></html>'''.encode()
class Handler(server.Handler):
 def do_GET(self):
  if self.path=='/recette-responsive':
   if not self.allowed_host():return self.json(403,{'error':'Hôte refusé'})
   self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.send_header('Content-Length',str(len(PAGE)));self.end_headers();self.wfile.write(PAGE)
  else:super().do_GET()
print('Recette isolée http://127.0.0.1:5054/recette-responsive',flush=True)
server.ThreadingHTTPServer(('127.0.0.1',5054),Handler).serve_forever()

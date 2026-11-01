"""Explicit same-origin entry for the S02 invitation adapter; no API proxy."""
from pathlib import Path
import json,re
from urllib.parse import parse_qs
ROOT=Path(__file__).resolve().parents[1]/'frontend'
FONT_ROOT=Path(__file__).resolve().parent/'assets/fonts/studio'
ASSETS={'/extensions/uniion-studio.js':'text/javascript','/uniion-logo.png':'image/png','/rights/shared-content.js':'text/javascript','/rights/rights.js':'text/javascript','/rights/partage.css':'text/css','/rights/uniion-logo.png':'image/png','/dist/application-native.js':'text/javascript','/generated/pseudo.css':'text/css','/runtime/local-files.js':'text/javascript','/host/demo.js':'text/javascript'}
ASSETS.update({'/fonts/studio/'+p.name:('text/css' if p.suffix=='.css' else 'font/ttf') for p in FONT_ROOT.iterdir() if p.suffix in ('.css','.ttf')})
def serve(e,start):
 path=e.get('PATH_INFO','')
 if path not in ('/s02','/s02/rights') and path not in ASSETS:return None
 from uniion.http_sessions import PORT
 if e.get('HTTP_HOST')!='127.0.0.1:'+PORT or e.get('REQUEST_METHOD')!='GET':
  start('403 Forbidden',[('Content-Type','text/plain')]);return [b'Forbidden']
 if path in ('/s02','/s02/rights'):
  org=parse_qs(e.get('QUERY_STRING','')).get('organization',[''])[0]
  if not re.fullmatch('[0-9a-fA-F-]{36}',org):
   start('400 Bad Request',[('Content-Type','text/plain')]);return [b'Organization required']
  # Org selects a target, never confers authorization. Every POST is checked by S01/RLS.
  raw=(ROOT/('rights/index.html' if path=='/s02/rights' else 'dist/index-native.html')).read_text()
  bridge='<script>window.uniionS01=Object.freeze({fetch:window.fetch.bind(window),organizationId:'+json.dumps(org)+'});</script>'
  raw=raw.replace('<script src="/host/demo.js">',bridge+'<script src="/host/demo.js">').encode();mime='text/html; charset=utf-8'
 else:
  raw=((FONT_ROOT/path.rsplit('/',1)[1]) if path.startswith('/fonts/studio/') else (ROOT/path.lstrip('/'))).read_bytes();mime=ASSETS[path]
 start('200 OK',[('Content-Type',mime),('Content-Length',str(len(raw))),('Cache-Control','no-store'),('X-Content-Type-Options','nosniff'),('Referrer-Policy','no-referrer'),('X-Frame-Options','DENY')]);return [raw]

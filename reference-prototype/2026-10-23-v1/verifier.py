#!/usr/bin/env python3
"""Verify reference contents. Does not change files or invoke network/AI."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parent
manifest=json.loads((root/'manifest.json').read_text())
errors=[]
for item in manifest['files']:
 p=root/item['path']
 if not p.is_file():errors.append('MANQUANT '+item['path']);continue
 if hashlib.sha256(p.read_bytes()).hexdigest()!=item['sha256']:errors.append('MODIFIÉ '+item['path'])
if errors:
 print('\n'.join(errors));sys.exit(1)
print('OK : '+str(len(manifest['files']))+' fichiers conformes à la référence '+manifest['version'])

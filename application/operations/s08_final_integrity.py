"""Check protected references and historical proof without rewriting either."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1];proof=root/'preuves/S08-F-final';result={}
for name,base in [('integrite',root.parent),('preuves',root)]:
 before=json.loads((proof/(name+'-avant.json')).read_text())
 changed=[p for p,h in before.items() if not (base/p).is_file() or hashlib.sha256((base/p).read_bytes()).hexdigest()!=h]
 result[name]={'count':len(before),'changed':changed,'passed':not changed}
secrets=set()
def collect(v,k=''):
 if isinstance(v,dict):
  for key,value in v.items():collect(value,key)
 elif isinstance(v,list):
  for value in v:collect(value,k)
 elif isinstance(v,str) and len(v)>=12 and any(t in k.lower() for t in ('password','secret','token','key')):secrets.add(v)
for p in (root/'.local-auth').glob('*s08*.json'):
 collect(json.loads(p.read_text()))
files=[p for p in proof.rglob('*') if p.suffix in ('.json','.log','.md')]
bad=[str(p.relative_to(root)) for p in files if any(s in p.read_text() for s in secrets) or re.search(r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}',p.read_text())]
result['secret_scan']={'files':len(files),'flagged_paths':bad,'passed':not bad,'scope':'S08 fixture secrets and JWT patterns, not exhaustive'}
(proof/'integrite-apres.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,ensure_ascii=False));assert all(v['passed'] for v in result.values())

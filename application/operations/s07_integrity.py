"""Verify references, historical evidence and absence of known local secrets."""
from pathlib import Path
import json,hashlib,re
root=Path(__file__).resolve().parents[1];proof=root/'preuves/S07-F'
results={}
for name,base in [('integrite',root.parent),('preuves',root)]:
 before=json.loads((proof/(name+'-avant.json')).read_text());bad=[p for p,h in before.items() if not (base/p).is_file() or hashlib.sha256((base/p).read_bytes()).hexdigest()!=h]
 results[name]={'checked':len(before),'changed':bad,'passed':not bad}
secrets=set()
def collect(value,key=''):
 if isinstance(value,dict):
  for k,v in value.items():collect(v,k)
 elif isinstance(value,list):
  for v in value:collect(v,key)
 elif isinstance(value,str) and len(value)>=12 and any(s in key.lower() for s in ('password','secret','token','key')):secrets.add(value)
for p in (root/'.local-auth').rglob('*.json'):
 try:collect(json.loads(p.read_text()))
 except (ValueError,UnicodeError):pass
bad=[];count=0
paths=list(proof.rglob('*'))+list((root/'operations').glob('s07*.py'))+[root/'tests/s07_f_regressions.py',root/'tests/s07_f_suite.py',root/'tests/s07_volume_edges.py']
for p in paths:
 if p.is_file() and p.suffix in ('.json','.log','.md','.py','.txt','.html'):
  text=p.read_text();count+=1
  if any(secret in text for secret in secrets) or re.search(r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}',text):bad.append(str(p.relative_to(root)))
results['secrets']={'files':count,'known_values_checked':len(secrets),'flagged_paths':bad,'passed':not bad,'scope':'Known local fixture secrets and JWT pattern; not a proof of absence of every possible secret.'}
(proof/'integrite-apres.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,ensure_ascii=False));assert all(v['passed'] for v in results.values())

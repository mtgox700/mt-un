"""Consolidated source/evidence handoff, excluding all private runtime stores."""
from pathlib import Path
import hashlib,json,re,zipfile
root=Path(__file__).resolve().parents[1]
allowed={'.py','.js','.mjs','.jsfrag','.json','.html','.css','.md','.txt','.toml','.sql','.sh','.yml','.yaml','.svg','.png','.woff','.woff2','.ttf','.log','.lock'}
excluded={'node_modules','__pycache__','.git','.venv','venv'}
files=[root/'README.md',root/'pyproject.toml',root/'planification/S08-demarrage/PLAN.md',root/'planification/S08-recette/LIRE-EN-PREMIER.md']
for name in ('uniion','frontend','supabase','tests','operations','docs','scripts','ci','generated'):
 for p in (root/name).rglob('*'):
  rel=p.relative_to(root)
  if p.is_file() and not p.is_symlink() and p.suffix in allowed and not any(x in excluded or x.startswith('.') for x in rel.parts): files.append(p)
for folder in (root/'preuves').glob('S08*'):
 files += [p for p in folder.rglob('*') if p.is_file() and p.suffix in {'.md','.html','.json','.log','.png','.txt'} and not any(x.startswith('.') for x in p.relative_to(root).parts)]
files=sorted(set(files));manifest={};known=set()
def collect(v,k=''):
 if isinstance(v,dict):
  for key,value in v.items():collect(value,key)
 elif isinstance(v,list):
  for value in v:collect(value,k)
 elif isinstance(v,str) and len(v)>=12 and any(t in k.lower() for t in ('password','secret','token','key')):known.add(v)
for p in (root/'.local-auth').rglob('*.json'):collect(json.loads(p.read_text()))
for p in files:
 data=p.read_bytes()
 if p.suffix not in {'.png','.woff','.woff2','.ttf'}:
  content=data.decode('utf-8',errors='replace')
  assert not any(s in content for s in known),f'Known credential in {p.relative_to(root)}'
  assert not re.search(r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}',content),f'JWT in {p.relative_to(root)}'
 manifest[str(p.relative_to(root))]=hashlib.sha256(data).hexdigest()
target=root/'planification/UNIION-S08-CLOTURE-LOCALE.zip'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,'application/'+str(p.relative_to(root)))
 z.writestr('LIRE-EN-PREMIER.txt','S08 — consolidation locale fictive. Lire application/preuves/S08-F-final/CLOTURE.md et RESERVES.md. Sources, migrations et preuves ; dépendances/services à préparer séparément. Aucun secret, compte, base ou sauvegarde inclus. Acceptation produit distincte ; décisions de production reportées à S16 avant tout usage réel.\n')
 z.writestr('manifest.json',json.dumps({'date':'2026-10-31','files':manifest},ensure_ascii=False,indent=2))
with zipfile.ZipFile(target) as z:
 assert z.testzip() is None
 assert all(hashlib.sha256(z.read('application/'+n)).hexdigest()==h for n,h in manifest.items())
receipt={'archive':target.name,'files':len(files)+2,'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'verified':True,'secret_scan':'Known local fixture credentials and JWT patterns; not exhaustive','private_stores_included':False}
target.with_suffix('.manifest.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt))

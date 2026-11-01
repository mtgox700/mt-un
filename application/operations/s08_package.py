"""Documentation/recipe handoff only. Explicit allowlist, no private stores."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
files=[root/'planification/S08-recette/LIRE-EN-PREMIER.md',root/'planification/S08-demarrage/PLAN.md']
files += [root/f'preuves/S08-{lot}/BILAN.md' for lot in 'ABCDE']
files += [p for p in (root/'preuves/S08-F').rglob('*') if p.is_file() and p.suffix in ('.md','.json','.log','.png')]
files += [root/'operations'/n for n in ('s08_replay.py','s08_fresh.py','s08_restore.py','s08_proof_scope.py','s08_f_integrity.py','s08_package.py')]
files += [root/'frontend/modules/ai/assistant.js',root/'frontend/state/assistant-server.test.mjs']
files=sorted(set(files))
manifest={}
for p in files:
 assert p.is_file() and not p.is_symlink() and p.resolve().is_relative_to(root)
 name=str(p.relative_to(root));assert not any(x.startswith('.local') or x=='sources' for x in p.parts)
 manifest[name]=hashlib.sha256(p.read_bytes()).hexdigest()
target=root/'planification/UNIION-S08-RECETTE.zip'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,'S08-recette/'+str(p.relative_to(root)))
 z.writestr('S08-recette/manifest.json',json.dumps({'date':'2026-10-31','scope':'Recette fictive uniquement — S08 métier non clôturé','files':manifest},ensure_ascii=False,indent=2))
with zipfile.ZipFile(target) as z:
 assert z.testzip() is None
 assert all(hashlib.sha256(z.read('S08-recette/'+name)).hexdigest()==sha for name,sha in manifest.items())
receipt={'archive':target.name,'files':len(files)+1,'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'verified':True,'private_stores_included':False}
target.with_suffix('.manifest.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt))

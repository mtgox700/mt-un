"""Evidence handoff supplement; no databases, identities, keys or private stores."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
proof=root/'preuves/S08-E-complet'
files=[root/'README.md',root/'planification/S08-demarrage/PLAN.md']
files += [p for p in proof.rglob('*') if p.is_file() and p.suffix in ('.md','.json','.log','.png')]
files += list((root/'operations').glob('s08_e_complet_*.py'))
files += list((root/'supabase/migrations').glob('2026103101[456]*.sql'))
files += list((root/'tests').glob('s08_native_*.py'))
files += list((root/'frontend/modules/business').glob('*.js'))
files += [root/'frontend/modules/ai'/n for n in ('actions.js','assistant.js','specialists.js')]
files += list((root/'uniion/adapters').glob('ai_*.py'))
files += [root/'uniion/adapters/business_records.py',root/'uniion/ai_http.py',root/'uniion/core/ai_action_catalog.json']
files=sorted(set(files));manifest={}
for p in files:
 assert p.is_file() and not p.is_symlink() and p.resolve().is_relative_to(root)
 assert not any(x.startswith('.local') or x=='sources' for x in p.parts)
 manifest[str(p.relative_to(root))]=hashlib.sha256(p.read_bytes()).hexdigest()
target=root/'planification/UNIION-S08-E-COMPLET-RECETTE.zip'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,'S08-E-complet/'+str(p.relative_to(root)))
 z.writestr('S08-E-complet/LIRE-EN-PREMIER.txt','Complément de preuves et sources sélectionnées du lot E. Le workspace application reste la livraison complète ; cette archive ne constitue pas une installation autonome. Voir preuves/S08-E-complet/BILAN.md. Recette locale fictive uniquement. Aucun secret ni base inclus. S08 et la production restent ouverts.\n')
 z.writestr('S08-E-complet/manifest.json',json.dumps({'date':'2026-10-31','scope':'Lot E local fictif ; complément de recette, pas déploiement','files':manifest},ensure_ascii=False,indent=2))
with zipfile.ZipFile(target) as z:
 assert z.testzip() is None
 assert all(hashlib.sha256(z.read('S08-E-complet/'+n)).hexdigest()==h for n,h in manifest.items())
receipt={'archive':target.name,'files':len(files)+2,'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'verified':True,'private_stores_included':False}
target.with_suffix('.manifest.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt))

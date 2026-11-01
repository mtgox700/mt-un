"""Static module boundaries; trusted packaged modules only, no arbitrary extensions."""
import ast,pathlib,hashlib,json
ROOT=pathlib.Path(__file__).resolve().parents[1]
def check():
 errors=[]
 for p in (ROOT/'uniion').rglob('*.py'):
  rel=p.relative_to(ROOT);tree=ast.parse(p.read_text())
  if 'modules' not in rel.parts and 'core' not in rel.parts:continue
  for node in ast.walk(tree):
   imports=[]
   if isinstance(node,ast.Import):imports=[a.name for a in node.names]
   if isinstance(node,ast.ImportFrom):imports=[node.module or '']
   for name in imports:
    if 'adapters' in name or name in ('urllib','requests','httpx','psycopg','supabase') or name.startswith(('urllib.','http.')):errors.append(str(rel)+': accès infrastructure interdit')
    if 'core' in rel.parts and name.startswith('uniion.modules'):errors.append(str(rel)+': noyau dépendant du métier')
    if 'modules' in rel.parts and name.startswith('uniion.modules.') and not name.startswith('uniion.modules.'+rel.parts[2]+'.'):errors.append(str(rel)+': import direct entre modules')
 manifest=json.loads((ROOT/'supabase/baseline/manifest.json').read_text())
 for name,digest in manifest['files'].items():
  if hashlib.sha256((ROOT/'supabase/baseline'/name).read_bytes()).hexdigest()!=digest:errors.append(name+': baseline modifiée')
 if errors:raise SystemExit('\n'.join(errors))
 print('Frontières des modules et 14 migrations de référence : OK')
if __name__=='__main__':check()

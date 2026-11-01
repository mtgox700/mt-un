"""One-way extraction. Reads reference, writes only application/frontend."""
from pathlib import Path
import re,json,hashlib,shutil
root=Path(__file__).resolve().parents[2];dest=root/'application/frontend';ref=root/'prototype-local/public/uniion App v3.dc.html';text=ref.read_text()
style=re.search(r'<style>([\s\S]*?)</style>',text).group(1);(dest/'theme/reference.css').write_text(style)
text=text.replace('<style>'+style+'</style>','<link rel="stylesheet" href="/theme/reference.css">',1)
logic=re.search(r'(<script type="text/x-dc"[^>]*>)([\s\S]*?)(</script>)',text)
(dest/'runtime/reference-logic.js').write_text(logic.group(2));text=text[:logic.start(2)]+'<!--LOGIC-->'+text[logic.end(2):]
modules=[]
for key,condition in [('home','isAccueil'),('cases','isDossiers'),('case-detail','isDossier'),('contacts','isContacts')]:
 match=re.search(r'<sc-if value="{{ '+condition+r' }}"[^>]*>',text);assert match
 depth=1;end=None
 for token in re.finditer(r'</?sc-if\b[^>]*>',text[match.end():]):
  depth+= -1 if token.group().startswith('</') else 1
  if depth==0:end=match.end()+token.end();break
 assert end
 fragment=text[match.start():end];(dest/f'modules/{key}.html').write_text(fragment)
 text=text[:match.start()]+'<!--MODULE:'+key+'-->'+text[end:]
 modules.append({'id':key,'view':f'modules/{key}.html','condition':condition,'sha256':hashlib.sha256(fragment.encode()).hexdigest()})
text=re.sub(r'<script src="\./local-bridge.js"></script>','<script src="/host/demo.js"></script>',text)
text=text.replace('./support.js','/runtime/support.js').replace('./local-files.js','/runtime/local-files.js')
(dest/'host/shell.html').write_text(text)
for name in ['support.js','local-files.js']:shutil.copyfile(ref.parent/name,dest/'runtime'/name)
shutil.copytree(ref.parent/'extensions',dest/'extensions',dirs_exist_ok=True);shutil.copyfile(ref.parent/'uniion-logo.png',dest/'uniion-logo.png')
(dest/'manifest.json').write_text(json.dumps({'version':1,'mode':'isolated-demo','reference':str(ref.relative_to(root)),'reference_sha256':hashlib.sha256(ref.read_bytes()).hexdigest(),'modules':modules,'remaining_views':'legacy shell','logic':'runtime/reference-logic.js'},indent=2))
print('4 vues et thème extraits ; référence non modifiée.')

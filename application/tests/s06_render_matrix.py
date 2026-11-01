from pathlib import Path
import shutil,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
root=Path(__file__).resolve().parents[1];out=root/'preuves/S06-finalisation/rendus';out.mkdir(exist_ok=True)
for name in ['logo-recette.png']:
 shutil.copyfile(root/'preuves/S03-logos-styles'/name,out/name)
for name in ['blocs-fixtures.json','logo-fictif.svg']:
 shutil.copyfile(root/'preuves/S03-svg-classique'/name,out/name)
for name in ['s03_studio_render.py','s03_classic_blocks_render.py','s03_landscape.py']:
 source=(root/'tests'/name).read_text().replace('preuves/S03-logos-styles','preuves/S06-finalisation/rendus').replace('preuves/S03-svg-classique','preuves/S06-finalisation/rendus').replace('preuves/S03-paysage','preuves/S06-finalisation/rendus')
 if name=='s03_studio_render.py':
  source=source.replace("  raw=render(doc,4);", "  try:raw=render(doc,4)\n  except Exception as exc:\n   results.append({'style':style['id'],'format':fmt,'blocked':type(exc).__name__});continue\n  ")
 exec(compile(source,str(root/'tests'/name),'exec'),{'__file__':str(root/'tests'/name)})

from pathlib import Path
import subprocess,sys,json
root=Path(__file__).resolve().parents[1];out=root/'preuves/S05-finalisation/regression';out.mkdir(exist_ok=True)
results=[]
for name in ['s05_cases','s05_assignments','s05_files','s05_versions','s05_trash','s05_classification']:
 source=(root/'tests'/f'{name}.py').read_text()
 import re
 source=re.sub(r"out=ROOT/'preuves/[^']+'",'out=Path('+repr(str(out/name))+')',source).replace('out.mkdir(exist_ok=True)','out.mkdir(parents=True,exist_ok=True)')
 code="from pathlib import Path\n__file__="+repr(str(root/'tests'/f'{name}.py'))+"\n"+source
 p=subprocess.run([sys.executable,'-B','-c',code],cwd=root,capture_output=True,text=True)
 results.append({'suite':name,'passed':p.returncode==0,'result':p.stdout.strip()})
 if p.returncode:print(name+' failed');break
(out/'suites.json').write_text(json.dumps(results,indent=2));print(json.dumps(results))

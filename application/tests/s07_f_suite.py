"""Serial Auth acceptance avoids competing MFA challenges on shared fictive actors."""
from pathlib import Path
import subprocess,sys,json,time
root=Path(__file__).resolve().parents[1];out=root/'preuves/S07-F';results=[]
for name in ['s07_messaging','s07_discovery','s07_members','s07_files','s07_live','s07_live_edges','s07_access_edges','s07_b_edges','s07_file_edges','s07_discovery_edges','s07_volume_edges']:
 start=time.monotonic()
 with (out/(name+'-final139.log')).open('w') as log:r=subprocess.run([sys.executable,'-B',str(root/'tests/s07_f_regressions.py'),name,'--final'],stdout=log,stderr=subprocess.STDOUT)
 results.append({'suite':name,'exit':r.returncode,'seconds':round(time.monotonic()-start,2)})
 (out/'regressions-final139.json').write_text(json.dumps(results,indent=2));print(json.dumps(results[-1]),flush=True)
 if r.returncode:raise SystemExit(r.returncode)

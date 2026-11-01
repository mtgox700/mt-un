"""Local fictional S02 acceptance suite. No resets, deletion, or production target."""
import json,subprocess,sys,time,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'preuves/S02-recette-globale';out.mkdir(exist_ok=True)
names=['s02_identity_views','s02_identity_edits','s02_members_management','s02_fine_permissions','s02_organizations_shares','s02_shared_files','s02_shared_pdf','s02_collections','s02_collection_creation','s02_journal','s02_support_tickets','s02_support_access','s02_support_requests','s02_support_files','s02_support_registry','s02_paid_modules','s02_partners']
results=[]
for name in names:
 start=time.monotonic()
 try:
  p=subprocess.run([sys.executable,'-B','tests/'+name+'.py'],cwd=ROOT,capture_output=True,text=True,timeout=150)
  record={'suite':name,'exit':p.returncode,'seconds':round(time.monotonic()-start,2)}
  for line in p.stdout.splitlines():
   try:
    d=json.loads(line)
    if isinstance(d,dict) and 'passed' in d:record.update({k:d[k] for k in ('passed','count') if k in d})
   except ValueError:pass
  if p.returncode:
   labels=re.findall(r'AssertionError: ([A-Za-z0-9_ -]+)',p.stderr);record['failure']=labels[-1] if labels else 'Suite en échec : diagnostic local nécessaire'
 except subprocess.TimeoutExpired:record={'suite':name,'exit':-1,'failure':'Délai dépassé'}
 results.append(record);(out/'integration.json').write_text(json.dumps(results,indent=2));print(json.dumps(record),flush=True)

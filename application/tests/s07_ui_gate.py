"""Toggle only the newly created, fictional S07 organization's module for UI refusal."""
import json,sys,subprocess,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1]
org=str(uuid.UUID(json.loads((root/'.local-auth/s07-fixture.json').read_text())['organization']))
if sys.argv[1] not in ('on','off'):raise SystemExit('on/off')
enabled='true' if sys.argv[1]=='on' else 'false'
q=f"update public.uniion_module_access set enabled={enabled} where organization_id='{org}' and module='messagerie' and exists(select 1 from public.uniion_organizations where id='{org}' and name='S07 — échanges fictifs')"
p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
if p.returncode:raise RuntimeError('Fixture toggle failed')
print('Module fictif S07 : '+sys.argv[1])

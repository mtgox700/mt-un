"""Run earlier acceptance against D without changing historical proofs or fixtures."""
from pathlib import Path
import sys
name=sys.argv[1]
if name not in ('s07_messaging','s07_members','s07_files'):raise SystemExit('unknown suite')
source=Path(__file__).with_name(name+'.py').read_text()
for old,new in [('preuves/S07-A','preuves/S07-D/regression-A'),('preuves/S07-B','preuves/S07-D/regression-B'),('preuves/S07-C','preuves/S07-D/regression-C')]:source=source.replace(old,new)
# The C test fixture image lives in the output folder it creates; B reads the original A actors.
if name=='s07_messaging':source=source.replace('.local-auth/s07-fixture.json','.local-auth/s07-d-regression-a.json')
source=source.replace('.local-auth/s07-b-fixture.json','.local-auth/s07-d-regression-b.json').replace('.local-auth/s07-c-fixture.json','.local-auth/s07-d-regression-c.json')
exec(compile(source,str(Path(__file__).with_name(name+'.py')),'exec'))

"""Run earlier acceptance against E without changing historical proofs or fixtures."""
from pathlib import Path
import sys
name=sys.argv[1]
if name not in ('s07_messaging','s07_members','s07_files','s07_discovery'):raise SystemExit('unknown suite')
source=Path(__file__).with_name(name+'.py').read_text()
for old,new in [('preuves/S07-A','preuves/S07-E/regression-A'),('preuves/S07-B','preuves/S07-E/regression-B'),('preuves/S07-C','preuves/S07-E/regression-C')]:source=source.replace(old,new)
source=source.replace('preuves/S07-D','preuves/S07-E/regression-D').replace('.local-auth/s07-d-fixture.json','.local-auth/s07-e-regression-d.json')
# The C test fixture image lives in the output folder it creates; B reads the original A actors.
if name=='s07_messaging':source=source.replace('.local-auth/s07-fixture.json','.local-auth/s07-e-regression-a.json')
source=source.replace('.local-auth/s07-b-fixture.json','.local-auth/s07-e-regression-b.json').replace('.local-auth/s07-c-fixture.json','.local-auth/s07-e-regression-c.json')
if name=='s07_discovery':
 source=source.replace('preuves/S07-E/regression-C/piece-recette.png','preuves/S07-C/piece-recette.png')
 source=source.replace("out=ROOT/'preuves/S07-E/regression-C'","out=ROOT/'preuves/S07-C'")
exec(compile(source,str(Path(__file__).with_name(name+'.py')),'exec'))

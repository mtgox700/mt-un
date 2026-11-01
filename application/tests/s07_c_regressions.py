"""Prior acceptance reruns, preserving their historical proofs and UI fixtures."""
from pathlib import Path
import sys
name=sys.argv[1]
if name not in ('s07_messaging','s07_members','s05_files','s05_classification'):raise SystemExit('unknown suite')
source=Path(__file__).with_name(name+'.py').read_text()
for old,new in [('preuves/S07-A','preuves/S07-C/regression-A'),('preuves/S07-B','preuves/S07-C/regression-B'),('preuves/S05-coffre','preuves/S07-C/regression-coffre'),('preuves/S05-classement','preuves/S07-C/regression-classement')]:source=source.replace(old,new)
if name=='s07_messaging':source=source.replace('.local-auth/s07-fixture.json','.local-auth/s07-c-regression-a.json')
source=source.replace('.local-auth/s07-b-fixture.json','.local-auth/s07-c-regression-b.json').replace('.local-auth/s05-coffre.json','.local-auth/s07-c-regression-coffre.json').replace('.local-auth/s05-classement.json','.local-auth/s07-c-regression-classement.json')
exec(compile(source,str(Path(__file__).with_name(name+'.py')),'exec'))

"""Run A acceptance against B migrations without replacing A's proofs/UI fixture."""
from pathlib import Path
source=Path(__file__).with_name('s07_messaging.py').read_text()
source=source.replace("out=ROOT/'preuves/S07-A'","out=ROOT/'preuves/S07-B/regression-A'").replace(".local-auth/s07-fixture.json",".local-auth/s07-a-regression-fixture.json")
exec(compile(source,__file__,'exec'))

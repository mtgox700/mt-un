from pathlib import Path
p=Path(__file__).with_name('s06_lifecycle.py')
source=p.read_text().replace("preuves/S06-finalisation","preuves/S06-pages-complementaires").replace(".local-auth/s06-lifecycle.json",".local-auth/s06-continuation-access.json")
exec(compile(source,str(p),'exec'))

from pathlib import Path
p=Path(__file__).with_name('s06_continuations.py')
source=p.read_text().replace('preuves/S06-pages-complementaires','preuves/S06-cloture-finale')
exec(compile(source,str(p),'exec'))

assert len(results)==36 and all(x.get('passed') for x in results),results

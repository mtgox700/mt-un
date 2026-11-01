"""Run original acceptance suites with strictly isolated evidence and fixtures."""
from pathlib import Path
import sys,runpy
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'operations'))
from s07_proof_scope import install
name=sys.argv[1]
if not name.startswith('s07_') or not (Path(__file__).parent/(name+'.py')).is_file():raise SystemExit('Unknown suite')
install(('regressions-final139' if '--final' in sys.argv else 'regressions')+'/'+name)
runpy.run_path(str(Path(__file__).with_name(name+'.py')),run_name='__main__')

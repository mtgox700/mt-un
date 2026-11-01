"""Re-run existing acceptance without touching historical evidence or fixtures."""
import sys,runpy
from s08_proof_scope import install,ROOT
name=sys.argv[1]
allowed={'s08_policy_edges','s08_runs_integration','s08_assistant_integration','s08_actions_integration'}
if name not in allowed:raise ValueError('Unknown suite')
install(name)
sys.argv=[str(ROOT/'tests'/ (name+'.py'))]+sys.argv[2:]
runpy.run_path(sys.argv[0],run_name='__main__')

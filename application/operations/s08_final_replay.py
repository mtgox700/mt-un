"""Sequential current-code acceptance on fictional fixtures, historical evidence protected."""
import sys,runpy
from s08_final_scope import install,ROOT
install('transverse')
for name in ['s08_policy_edges','s08_context_integration','s08_runs_integration','s08_assistant_integration','s08_actions_integration','s08_native_integration','s08_native_followup']:
 print('SUITE '+name,flush=True)
 sys.argv=[str(ROOT/'tests'/(name+'.py'))]
 runpy.run_path(sys.argv[0],run_name='__main__')

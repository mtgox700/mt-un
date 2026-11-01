"""Secret-free quality gate, usable on the host and in an isolated Linux container."""
import pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[1]
for args in ([sys.executable,'-B','-m','unittest','discover','-s','tests','-p','test_*.py','-v'],[sys.executable,'-B','scripts/check_boundaries.py']):
    result=subprocess.run(args,cwd=root)
    if result.returncode:raise SystemExit(result.returncode)
print('Quality gate passed; no shared-stack credentials used.')

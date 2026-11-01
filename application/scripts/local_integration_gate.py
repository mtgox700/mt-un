"""Local quality pipeline. Fresh database only; does not use the shared stack."""
import pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[1]
for command in ([sys.executable,'-B','scripts/linux_quality.py'],[sys.executable,'-B','operations/ephemeral_ci.py']):
 result=subprocess.run(command,cwd=root)
 if result.returncode:raise SystemExit(result.returncode)
print('Local integration gate passed. Test containers stopped; volumes retained, no purge.')

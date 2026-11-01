"""Run local Linux quality tests with only code mounts, no network or secrets."""
import pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
args=['docker','run','--rm','--network','none','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges','--user','65534:65534','--tmpfs','/tmp:rw,nosuid,nodev,mode=1777']
for name in ('uniion','tests','scripts','operations','supabase'):
    # Operations contains code/templates only; private .local-* siblings are never mounted.
    args+=['--mount',f'type=bind,src={root/name},dst=/app/{name},readonly']
raise SystemExit(subprocess.run(args+['uniion-quality:local']).returncode)

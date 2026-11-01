"""Reset ONLY the dedicated fictional MFA fixture before a fresh enrollment test.
Never imported by application code. No credential, business data or factor deletion.
"""
import pathlib,json,uuid,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
def prepare():
 a=json.loads((ROOT/'.local-auth/sessions-fixtures.json').read_text())[0]
 uid=str(uuid.UUID(a['id']));email=a['email']
 if not email.endswith('@uniion-local.example'):raise RuntimeError('Fictional fixture required')
 # Refuse to reduce the requirement while an existing verified factor is present.
 q="DO $$ BEGIN IF EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id='"+uid+"' AND status='verified') THEN RAISE EXCEPTION 'Active fixture factor'; END IF; UPDATE uniion_private.mfa_requirements SET required=false WHERE user_id='"+uid+"'; END $$;"
 p=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True)
 if p.returncode:raise RuntimeError('Fixture preparation refused')

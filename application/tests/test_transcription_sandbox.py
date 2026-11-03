import json,os,pathlib,shutil,subprocess,sys,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'operations'))
import transcription_worker as tw
class EngineCommandTests(unittest.TestCase):
    def test_refused_without_sandbox_configuration(self):
        # R30 : plus d'exécution implicite du décodeur sur l'hôte.
        with self.assertRaises(ValueError):tw.engine_command(environ={})
    def test_host_mode_requires_explicit_opt_in(self):
        cmd=tw.engine_command(environ={'UNIION_TRANSCRIPTION_SANDBOX':'host'})
        self.assertTrue(cmd[0].endswith('.venv-transcription/bin/python'))
    def test_container_is_isolated(self):
        cmd=tw.engine_command(environ={'UNIION_TRANSCRIPTION_IMAGE':'sha256:abc','UNIION_TRANSCRIPTION_MODEL_DIR':'/srv/modeles','UNIION_DOCKER':'docker'})
        joined=' '.join(cmd)
        for flag in ('--network none','--read-only','--user 65532:65532','--cap-drop ALL','no-new-privileges','--memory 2g','--pids-limit 64'):
            self.assertIn(flag,joined)
        self.assertIn('/srv/modeles:/models:ro',cmd);self.assertIn('sha256:abc',cmd)
@unittest.skipUnless(shutil.which('docker') and subprocess.run(['docker','info'],capture_output=True).returncode==0,'Docker indisponible')
class SandboxSmokeTest(unittest.TestCase):
    def test_probe_has_no_network_no_write_and_no_root(self):
        probe=pathlib.Path(tempfile.mkdtemp())/'probe.py'
        probe.write_text("""import json,os,socket,sys
data=sys.stdin.buffer.read()
def net():
    try:socket.create_connection(('1.1.1.1',53),2);return True
    except OSError:return False
def write(p):
    try:open(p,'w').write('x');return True
    except OSError:return False
print(json.dumps({'bytes':len(data),'net':net(),'app':write('/app/x'),'tmp':write('/tmp/x'),'uid':os.getuid(),'models':os.environ.get('UNIION_TRANSCRIPTION_MODEL_DIR')}))
""")
        probe.chmod(0o644);probe.parent.chmod(0o755)
        cmd=tw.engine_command(script=probe,environ={'UNIION_TRANSCRIPTION_IMAGE':'python:3.12-alpine','UNIION_TRANSCRIPTION_MODEL_DIR':str(probe.parent),'UNIION_DOCKER':'docker'})
        run=tw.bounded_process(cmd,b'RIFF-fictif',timeout=120,max_output=10000)
        self.assertEqual(run.returncode,0,run.stdout)
        result=json.loads(run.stdout)
        self.assertEqual(result,{'bytes':11,'net':False,'app':False,'tmp':True,'uid':65532,'models':'/models'})

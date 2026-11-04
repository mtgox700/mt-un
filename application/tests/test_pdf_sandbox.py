import pathlib,shutil,subprocess,tempfile,unittest
from uniion.adapters import studio_pdf
class ChromeCommandTests(unittest.TestCase):
    def test_host_mode_unchanged_without_image(self):
        cmd=studio_pdf.chrome_command(pathlib.Path('/tmp/x'),environ={})
        self.assertEqual(cmd[0],studio_pdf.CHROME);self.assertIn('--host-resolver-rules=MAP * ~NOTFOUND',cmd)
    def test_container_is_isolated(self):
        cmd=studio_pdf.chrome_command(pathlib.Path('/tmp/x'),environ={'UNIION_PDF_IMAGE':'sha256:abc','UNIION_DOCKER':'docker'})
        joined=' '.join(cmd)
        for flag in ('--network none','--read-only','--cap-drop ALL','no-new-privileges','--memory 768m','--pids-limit 128','/tmp/x:/work'):self.assertIn(flag,joined)
        self.assertIn('file:///work/document.html',cmd)
def image_available():
    return shutil.which('docker') and subprocess.run(['docker','image','inspect','zenika/alpine-chrome:124'],capture_output=True).returncode==0
@unittest.skipUnless(image_available(),'Image Chromium de test absente')
class ChromeSandboxSmokeTest(unittest.TestCase):
    def test_pdf_rendered_without_network(self):
        # R47 : Chrome isolé imprime le PDF ; une ressource réseau du document n'est pas chargée.
        d=pathlib.Path(tempfile.mkdtemp())
        (d/'document.html').write_text('<!doctype html><meta charset="utf-8"><p>Ordre du jour fictif</p><img src="https://example.org/pixel.png">')
        run=subprocess.run(studio_pdf.chrome_command(d,environ={'UNIION_PDF_IMAGE':'zenika/alpine-chrome:124','UNIION_DOCKER':'docker'}),capture_output=True,timeout=120)
        self.assertEqual(run.returncode,0,run.stderr[-500:]);pdf=(d/'document.pdf').read_bytes()
        self.assertTrue(pdf.startswith(b'%PDF'));shutil.rmtree(d)

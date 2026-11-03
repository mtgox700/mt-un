import json,os,pathlib,tempfile,unittest
from unittest import mock
from uniion.service_credentials import load,CredentialsUnavailable
class ServiceCredentialsTests(unittest.TestCase):
    def setUp(self):
        self.dir=pathlib.Path(tempfile.mkdtemp());self.file=self.dir/'scanner.json'
        self.file.write_text(json.dumps({'email':'scanner@example.invalid','password':'fichier'}));self.file.chmod(0o600)
    def tearDown(self):
        for p in self.dir.iterdir():p.unlink()
        self.dir.rmdir()
    def test_environment_wins(self):
        with mock.patch.dict(os.environ,{'UNIION_SCANNER_EMAIL':'env@example.invalid','UNIION_SCANNER_PASSWORD':'env'},clear=False):
            self.assertEqual(load('UNIION_SCANNER',self.file),{'email':'env@example.invalid','password':'env'})
    def test_secret_file_variable(self):
        with mock.patch.dict(os.environ,{'UNIION_SCANNER_FILE':str(self.file)},clear=False):
            self.assertEqual(load('UNIION_SCANNER',self.dir/'absent.json')['password'],'fichier')
    def test_default_private_file(self):
        self.assertEqual(load('UNIION_SCANNER',self.file)['email'],'scanner@example.invalid')
    def test_readable_by_others_is_refused(self):
        # R3 : un fichier de secret lisible par le groupe ou les autres est refusé.
        for mode in (0o640,0o604,0o644):
            self.file.chmod(mode)
            with self.assertRaises(CredentialsUnavailable):load('UNIION_SCANNER',self.file)
    def test_symlink_and_incomplete_are_refused(self):
        link=self.dir/'lien.json';link.symlink_to(self.file)
        with self.assertRaises(CredentialsUnavailable):load('UNIION_SCANNER',link)
        with mock.patch.dict(os.environ,{'UNIION_SCANNER_EMAIL':'seul@example.invalid'},clear=False):
            with self.assertRaises(CredentialsUnavailable):load('UNIION_SCANNER',self.file)
    def test_missing_file_is_refused(self):
        with self.assertRaises(CredentialsUnavailable):load('UNIION_SCANNER',self.dir/'absent.json')

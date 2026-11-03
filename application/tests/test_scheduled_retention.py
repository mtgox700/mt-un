import datetime,json,pathlib,shutil,sys,tempfile,time,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'operations'))
import scheduled_backups as sb
def stamp(days_ago):return (datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=days_ago)).strftime('%Y%m%dT%H%M%SZ')
class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.base=pathlib.Path(tempfile.mkdtemp(prefix='.local-test-retention-',dir=ROOT))
        self.c={'state_dir':str(self.base/'state'),'backup_dir':str(self.base/'backups'),'key_dir':str(self.base/'keys'),'automatic_deletion':False,
                'interval_seconds':2700,'retry_seconds':300,'max_age_seconds':3600,'watchdog_seconds':720,'timeout_seconds':600,'minimum_free_bytes':0,'desktop_notifications':False,'retention_days':30}
        self.config=self.base/'config.json';self.config.write_text(json.dumps(self.c))
        self.old,self.recent,self.last=stamp(45),stamp(3),stamp(60)
        for s in (self.old,self.recent,self.last):
            (self.base/'backups'/s).mkdir(parents=True);(self.base/'backups'/s/'database.aesgcm').write_bytes(b'x')
            (self.base/'keys').mkdir(exist_ok=True);(self.base/'keys'/(s+'.key')).write_bytes(b'k'*32)
        import hashlib
        data=self.base/'backups'/self.last/'database.aesgcm';key=self.base/'keys'/(self.last+'.key')
        verified={'backup':self.last,'snapshot_at':time.time(),'key_path':str(key),'key_sha256':hashlib.sha256(key.read_bytes()).hexdigest(),'ciphertext_sha256':{str(data):hashlib.sha256(data.read_bytes()).hexdigest()}}
        (self.base/'state').mkdir();(self.base/'state'/'state.json').write_text(json.dumps({'last_verified':verified,'last_tick':time.time()}))
    def tearDown(self):shutil.rmtree(self.base)
    def test_monitor_reports_expired_backups_without_deleting(self):
        status=sb.monitor(str(self.config))
        self.assertIn('retention_due',status['issues']);self.assertEqual(status['expired_backups'],[self.old])
        self.assertFalse(status['automatic_deletion']);self.assertTrue((self.base/'backups'/self.old).exists())
    def test_shred_requires_explicit_approval(self):
        self.assertEqual(sb.shred(str(self.config),self.old)['status'],'approval_required')
        self.assertTrue((self.base/'keys'/(self.old+'.key')).exists())
    def test_shred_destroys_key_then_data(self):
        self.assertEqual(sb.shred(str(self.config),self.old,approve=True)['status'],'shredded')
        self.assertFalse((self.base/'keys'/(self.old+'.key')).exists());self.assertFalse((self.base/'backups'/self.old).exists())
        self.assertNotIn('retention_due',sb.monitor(str(self.config))['issues'])
    def test_shred_refuses_recent_last_verified_and_invalid(self):
        for s in (self.recent,self.last,'../etc','20260101T000000Z'):
            with self.assertRaises(ValueError):sb.shred(str(self.config),s,approve=True)
        self.assertTrue((self.base/'backups'/self.last).exists())
    def test_automatic_deletion_still_forbidden(self):
        self.config.write_text(json.dumps({**self.c,'automatic_deletion':True}))
        with self.assertRaises(ValueError):sb.monitor(str(self.config))

import base64,hashlib,unittest
from unittest.mock import patch,Mock
from uniion.adapters import convocation_archive as archive,agenda
from uniion.adapters.supabase_transport import SupabaseUnavailable

class ArchiveTests(unittest.TestCase):
 def test_corrupted_storage_is_never_returned(self):
  with patch.object(archive.antivirus,'worker_token',return_value='worker'),patch.object(archive.attachments,'storage',return_value=b'wrong'):
   with self.assertRaises(SupabaseUnavailable):archive.read(Mock(),{'path':'private','size':5,'sha256':hashlib.sha256(b'right').hexdigest()})
 def test_failed_storage_never_finalizes(self):
  api=Mock();items=[{'Content':base64.b64encode(b'valid').decode(),'ContentType':mime} for mime in ('application/pdf','text/calendar')]
  with patch.object(archive.antivirus,'worker_token',return_value='worker'),patch.object(archive.antivirus,'scan',return_value=('clean','','')),patch.object(archive.attachments,'storage',side_effect=SupabaseUnavailable):
   with self.assertRaises(SupabaseUnavailable):archive.persist(api,'org','convocation',items)
  self.assertEqual([c.args[2]['p_action'] for c in api.request.call_args_list],['reserve'])
 def test_archiving_failure_sends_no_mail(self):
  api=Mock();api.request.side_effect=[{'document':{},'version':1,'event':{}},{'deliveries':[{'user':'recipient','email':'fiction@example.invalid'}],'replayed':False}]
  data={'organization_id':'00000000-0000-0000-0000-000000000001','event_id':'00000000-0000-0000-0000-000000000002','action':'prepare','payload':{'attachment_version':1,'id':'00000000-0000-0000-0000-000000000003'}}
  with patch('uniion.adapters.agenda_pdf.render',return_value=b'%PDF'),patch.object(agenda,'calendar',return_value='ICS'),patch.object(archive.antivirus,'scan',return_value=('clean','','')),patch.object(archive,'persist',side_effect=SupabaseUnavailable),patch('urllib.request.build_opener') as mail:
   with self.assertRaises(SupabaseUnavailable):agenda.workflow(api,'user',data,send=True)
   mail.assert_not_called()

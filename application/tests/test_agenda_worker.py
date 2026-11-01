import unittest
from unittest.mock import patch
from operations import agenda_reminders as w
class WorkerTests(unittest.TestCase):
 def test_revocation_before_delivery(self):
  with patch.object(w,'sql',side_effect=['{"id":"00000000-0000-4000-8000-000000000001","email":"x@example.invalid"}','f','']),patch.object(w,'deliver') as send:
   self.assertEqual(w.run(),{'sent':0,'uncertain':0});send.assert_not_called()
 def test_ambiguous_failure_is_retained(self):
  with patch.object(w,'sql',side_effect=['{"id":"00000000-0000-4000-8000-000000000001","email":"x@example.invalid"}','t','','']) as sql,patch.object(w,'deliver',side_effect=OSError()):
   self.assertEqual(w.run(),{'sent':0,'uncertain':1});self.assertIn('false',sql.call_args_list[2].args[0])

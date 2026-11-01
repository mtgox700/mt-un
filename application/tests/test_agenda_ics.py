import unittest
from uniion.adapters.agenda import calendar
class CalendarTests(unittest.TestCase):
 def event(self,**extra):return dict(id='00000000-0000-4000-8000-000000000001',version=3,date='2026-10-27',start='09:00',end='10:00',title='Réunion',lieu='Salle',notes='',**extra)
 def test_winter_utc(self):
  text=calendar(self.event());self.assertIn('DTSTART:20261027T080000Z',text);self.assertIn('SEQUENCE:3',text)
 def test_summer_utc(self):
  e=self.event();e['date']='2026-07-01';self.assertIn('DTSTART:20260701T070000Z',calendar(e))
 def test_injection_and_utf8_folding(self):
  e=self.event();e['title']='é'*100+'\r\nBEGIN:VEVENT';text=calendar(e);self.assertEqual(text.count('\r\nBEGIN:VEVENT\r\n'),1);self.assertTrue(all(len(line.encode())<=75 for line in text.split('\r\n')));self.assertIn('\\nBEGIN:VEVENT',text.replace('\r\n ',''))

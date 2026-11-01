import base64
import io
import struct
import unittest
import wave
from unittest.mock import patch
from uuid import uuid4
from uniion.adapters.meeting_audio import validate_audio, dispatch
from uniion.core.contracts import Denied

class AudioValidationTests(unittest.TestCase):
    def setUp(self):
        out=io.BytesIO()
        with wave.open(out,'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(16000);w.writeframes(b'\0\0'*80)
        self.raw=out.getvalue()
    def payload(self,raw=None,**kw):
        return {'filename':'fictif.wav','content':base64.b64encode(self.raw if raw is None else raw).decode(),**kw}
    def test_valid_pcm(self):
        self.assertEqual(validate_audio(self.payload())[1],self.raw)
    def test_rejects_truncation_trailing_bytes_and_fake_size(self):
        for raw in (self.raw[:-1],self.raw+b'x',b'RIFF'+b'\0'*40,self.raw[:40]+struct.pack('<I',100000)+self.raw[44:]):
            with self.subTest(length=len(raw)),self.assertRaises(Denied):validate_audio(self.payload(raw))
    def test_rejects_unsafe_names_and_nonbase64(self):
        for changes in ({'filename':'../x.wav'},{'filename':'x.mp3'},{'filename':'x\n.wav'},{'content':'%%%'}):
            with self.subTest(changes=changes),self.assertRaises(Denied):validate_audio(self.payload(**changes))
    def test_rejects_unsupported_codec_and_inconsistent_frame_layout(self):
        for offset,value in ((20,3),(22,9),(32,5),(34,12)):
            raw=bytearray(self.raw);struct.pack_into('<H',raw,offset,value)
            with self.subTest(offset=offset),self.assertRaises(Denied):validate_audio(self.payload(bytes(raw)))
    def test_rejects_embedded_metadata(self):
        raw=self.raw+b'LIST'+struct.pack('<I',4)+b'test'
        raw=raw[:4]+struct.pack('<I',len(raw)-8)+raw[8:]
        with self.assertRaises(Denied):validate_audio(self.payload(raw))
    def test_denied_before_content_processing(self):
        class API:
            def request(self,*a,**kw):raise Denied()
        with patch('uniion.adapters.meeting_audio.validate_audio') as validate,self.assertRaises(Denied):
            dispatch(API(),'token',str(uuid4()),'audio_upload',{'id':str(uuid4()),'request_id':str(uuid4()),'consentVersion':1,**self.payload()})
        validate.assert_not_called()
    def test_injected_fields_and_unknown_action(self):
        for action,payload in [('audio_delete',{'id':str(uuid4())}),('audio_list',{'id':str(uuid4()),'actor':'bad'})]:
            with self.assertRaises(Denied):dispatch(None,'token',str(uuid4()),action,payload)

class AudioDurationTests(unittest.TestCase):
    def test_duration_uses_frames_rate_and_channels(self):
        from uniion.adapters.meeting_audio import duration_ms
        for channels,rate,width in ((1,8000,1),(2,48000,3),(1,16000,2)):
            out=io.BytesIO()
            with wave.open(out,'wb') as w:
                w.setnchannels(channels);w.setsampwidth(width);w.setframerate(rate)
                w.writeframes(b'\0'*(rate//10*channels*width))
            raw=out.getvalue()
            validate_audio({'filename':'test.wav','content':base64.b64encode(raw).decode()})
            with self.subTest(channels=channels,rate=rate,width=width):self.assertEqual(duration_ms(raw),100)

    def test_fractional_millisecond_floored(self):
        from uniion.adapters.meeting_audio import duration_ms
        out=io.BytesIO()
        with wave.open(out,'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(16000);w.writeframes(b'\0\0'*17)
        self.assertEqual(duration_ms(out.getvalue()),1)

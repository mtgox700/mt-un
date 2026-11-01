"""Offline CPU transcription of one validated PCM source, stdin -> JSON stdout."""
import os
os.environ.update(HF_HUB_OFFLINE='1', TRANSFORMERS_OFFLINE='1', HF_HUB_DISABLE_TELEMETRY='1')
import hashlib, io, json, pathlib, sys, wave
ROOT=pathlib.Path(__file__).resolve().parents[1]
def transcribe(raw):
 from faster_whisper import WhisperModel
 manifest=json.loads((ROOT/'.local-transcription/model-manifest.json').read_text())
 model=ROOT/'.local-transcription/model'
 for name,digest in manifest['files'].items():
  if pathlib.Path(name).name!=name or hashlib.sha256((model/name).read_bytes()).hexdigest()!=digest:
   raise ValueError('Model integrity failure')
 with wave.open(io.BytesIO(raw),'rb') as audio:
  duration=audio.getnframes()*1000//audio.getframerate()
 engine=WhisperModel(str(model),local_files_only=True,device='cpu',compute_type='int8',cpu_threads=2,num_workers=1)
 segments,info=engine.transcribe(io.BytesIO(raw),language='fr',beam_size=5,vad_filter=True,condition_on_previous_text=False)
 result=[]
 for s in segments:
  start=max(0,min(duration,int(s.start*1000)));end=max(start,min(duration,int(s.end*1000)))
  if s.text.strip() and end>start:result.append({'startMs':start,'endMs':end,'text':s.text.strip()})
 return {'engine':'faster-whisper/1.2.1','model':manifest['revision'],'segments':result}
if __name__=='__main__':
 raw=sys.stdin.buffer.read(5242881)
 if not 44<=len(raw)<=5242880:raise ValueError('Audio limit')
 print(json.dumps(transcribe(raw),ensure_ascii=False))

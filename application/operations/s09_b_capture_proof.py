"""Read back only the explicitly identified fictive UI capture; never logs credentials."""
import sys,json,subprocess,io,wave,struct,math,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root))
from uniion.adapters.supabase_transport import SupabaseAccess
from uniion.adapters import antivirus,attachments
org='f4ec1ef5-9155-4f30-a16e-57afe5342eb5'
# Recipe-specific recording id is selected from the first segment, not from arbitrary organizations.
q=f"select coalesce(json_agg(t),'[]') from (select a.path,a.sha256,a.duration_ms,q.position,q.offset_ms from uniion_private.meeting_audio a join uniion_private.meeting_audio_sequences q on q.audio_id=a.id where a.organization_id='{org}' and q.recording_id=(select q2.recording_id from uniion_private.meeting_audio_sequences q2 join uniion_private.meeting_audio a2 on a2.id=q2.audio_id where a2.organization_id='{org}' order by a2.created_at limit 1) order by q.position) t"
r=subprocess.run(['/Users/mt/.docker/bin/docker','exec','-i','supabase_db_unii','psql','-At','-U','postgres','-v','ON_ERROR_STOP=1'],input=q.encode(),capture_output=True,check=True)
rows=json.loads(r.stdout);api=SupabaseAccess('http://127.0.0.1:54321','',local=True);token=antivirus.worker_token(api);proof=[]
for row in rows:
 raw=attachments.storage(api,token,row['path']);assert hashlib.sha256(raw).hexdigest()==row['sha256']
 with wave.open(io.BytesIO(raw),'rb') as w:
  rate=w.getframerate();frames=w.getnframes();samples=list(struct.unpack('<'+'h'*frames,w.readframes(frames)))
 rms=math.sqrt(sum(x*x for x in samples)/len(samples))/32768
 crossings=sum(a<=0<b for a,b in zip(samples,samples[1:]));frequency=crossings/(frames/rate)
 assert .005<rms<.009 and 435<frequency<445
 proof.append({'position':row['position'],'offsetMs':row['offset_ms'],'durationMs':row['duration_ms'],'sampleRate':rate,'frames':frames,'rms':rms,'frequencyHz':frequency,'sha256Matches':True})
assert len(proof)==2
(root/'preuves/S09-B-final/capture-server.json').write_text(json.dumps({'fictiveSignalHz':440,'segments':proof,'passed':True},indent=2));print(json.dumps({'passed':True,'segments':len(proof)}))

"""Local-only durable transcription worker; dedicated identity, renewable leases."""
import argparse,hashlib,json,pathlib,sys,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from uniion.adapters.supabase_transport import SupabaseAccess
from uniion.adapters.attachments import storage
from uniion.adapters.antivirus import bounded_process

SANDBOX_FLAGS=['--rm','-i','--network','none','--read-only','--user','65532:65532','--cap-drop','ALL',
 '--security-opt','no-new-privileges','--memory','2g','--memory-swap','2g','--cpus','2','--pids-limit','64',
 '--tmpfs','/tmp:rw,noexec,nosuid,size=64m,uid=65532,gid=65532']

def engine_command(script=None,environ=None):
 """Command that transcribes one PCM source read on stdin (R30).

 Default: an isolated container (no network, read-only, unprivileged, bounded),
 image named by UNIION_TRANSCRIPTION_IMAGE, model mounted read-only.
 Running the decoder directly on the host requires UNIION_TRANSCRIPTION_SANDBOX=host.
 """
 import os,uuid
 environ=os.environ if environ is None else environ
 script=pathlib.Path(script or ROOT/'operations/transcribe_local.py')
 if environ.get('UNIION_TRANSCRIPTION_SANDBOX')=='host':
  return [str(ROOT/'.venv-transcription/bin/python'),str(script)]
 image=environ.get('UNIION_TRANSCRIPTION_IMAGE')
 if not image:raise ValueError('Transcription sandbox not configured')
 from uniion.adapters.antivirus import DOCKER
 models=pathlib.Path(environ.get('UNIION_TRANSCRIPTION_MODEL_DIR',str(ROOT/'.local-transcription')))
 return [environ.get('UNIION_DOCKER',DOCKER),'run','--name','uniion-transcribe-'+uuid.uuid4().hex,*SANDBOX_FLAGS,
  '-e','UNIION_TRANSCRIPTION_MODEL_DIR=/models','-e','HF_HUB_OFFLINE=1',
  '-v',str(models)+':/models:ro','-v',str(script)+':/app/transcribe.py:ro',image,'python','/app/transcribe.py']

def process_one(api,token):
 def rpc(action,**kw):return api.request('/rest/v1/rpc/uniion_transcription_worker',token,{'p_action':action,**kw})
 claim=rpc('claim')
 if not claim:return False
 args={'p_job':claim['id'],'p_lease':claim['lease']}
 try:
  part=rpc('next',**args)
  while not part.get('done'):
   raw=storage(api,token,part['path'])
   if len(raw)!=part['size'] or hashlib.sha256(raw).hexdigest()!=part['sha256']:raise ValueError('Source integrity')
   run=bounded_process(engine_command(),raw,timeout=240,max_output=200000)
   if run.returncode:raise ValueError('Local engine unavailable')
   result=json.loads(run.stdout)
   part=rpc('finish',**args,p_audio=part['audio'],p_result=result)
  return True
 except Exception:
  try:rpc('error',**args)
  except Exception:pass # Cancellation/revocation wins over a late worker response.
  return False

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--once',action='store_true');args=parser.parse_args()
 from uniion.service_credentials import load
 config=load('UNIION_TRANSCRIPTION',ROOT/'.local-auth/transcription-worker.json')
 api=SupabaseAccess('http://127.0.0.1:54321','',local=True)
 while True:
  try:
   session=api.login(config['email'],config['password'])
   try:process_one(api,session['access_token'])
   finally:api.logout(session['access_token'])
  except Exception:print('Local transcription worker unavailable',file=sys.stderr)
  if args.once:break
  time.sleep(3)
if __name__=='__main__':main()

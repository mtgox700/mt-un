"""Local-only durable transcription worker; dedicated identity, renewable leases."""
import argparse,hashlib,json,pathlib,sys,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from uniion.adapters.supabase_transport import SupabaseAccess
from uniion.adapters.attachments import storage
from uniion.adapters.antivirus import bounded_process

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
   run=bounded_process([str(ROOT/'.venv-transcription/bin/python'),str(ROOT/'operations/transcribe_local.py')],raw,timeout=240,max_output=200000)
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
 config=json.loads((ROOT/'.local-auth/transcription-worker.json').read_text())
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

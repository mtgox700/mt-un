"""Independent local watchdog: sanitized health only, no Auth/keys/business data."""
import pathlib,json,time,os,fcntl,argparse,subprocess
from session_health import monitor,DEFAULT
ROOT=pathlib.Path(__file__).resolve().parents[1]
STATE=ROOT/'.local-session-watchdog'
def write(path,data):
 temp=path.with_name(path.name+'.pending');fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
 with os.fdopen(fd,'w') as stream:json.dump(data,stream);stream.flush();os.fsync(stream.fileno())
 os.replace(temp,path)
def desktop(kind):
 message='Le contrôle local des sessions demande une intervention. Consulter le bilan opérationnel.' if kind=='alert' else 'Le contrôle local des sessions fonctionne de nouveau.'
 code='on run argv\ndisplay notification (item 1 of argv) with title "UNIION · Sessions"\nend run'
 try:return subprocess.run(['/usr/bin/osascript','-e',code,message],capture_output=True,timeout=8).returncode==0
 except (OSError,subprocess.TimeoutExpired):return False
def tick(health=DEFAULT,state_dir=STATE,notify=desktop,now=None):
 now=time.time() if now is None else now;state_dir=pathlib.Path(state_dir)
 state_dir.mkdir(parents=True,exist_ok=True,mode=0o700);state_dir.chmod(0o700)
 fd=os.open(state_dir/'runner.lock',os.O_RDWR|os.O_CREAT,0o600)
 with os.fdopen(fd,'a') as lock:
  try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  except BlockingIOError:return {'status':'already_running'}
  result=monitor(health,now)
  # Short-lived queued work is observable, but only persistent delays notify.
  issues=sorted(x for x in result['issues'] if x!='revocations_pending')
  path=state_dir/'state.json'
  try:old=json.loads(path.read_text())
  except FileNotFoundError:old={'issues':[],'sequence':0}
  changed=issues!=old['issues'];sequence=old['sequence'];event=None
  if changed:
   sequence+=1;kind='alert' if issues else 'recovery'
   accepted=notify(kind) if notify else None
   event={'id':sequence,'at':now,'kind':kind,'issues':issues,'notification_request_accepted':accepted}
   fd=os.open(state_dir/'events.jsonl',os.O_APPEND|os.O_CREAT|os.O_WRONLY,0o600)
   with os.fdopen(fd,'a') as stream:stream.write(json.dumps(event)+'\n');stream.flush();os.fsync(stream.fileno())
  write(path,{'issues':issues,'sequence':sequence,'checked_at':now,'health':result,'last_event':event or old.get('last_event')})
  return {'status':'alert' if issues else 'ok','issues':issues,'changed':changed,'sequence':sequence,'checked_at':now}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--health',default=str(DEFAULT));p.add_argument('--state-dir',default=str(STATE));p.add_argument('--no-notifications',action='store_true');args=p.parse_args()
 try:print(json.dumps(tick(args.health,args.state_dir,notify=None if args.no_notifications else desktop)))
 except Exception:
  print(json.dumps({'status':'watchdog_error','issues':['watchdog_unavailable']}));raise SystemExit(1)

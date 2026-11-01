"""A separate launchd job observes fixture health; no source service is stopped."""
import pathlib,sys,os,json,time,subprocess,plistlib,uuid
ROOT=pathlib.Path(__file__).resolve().parents[1];base=ROOT/'.local-watchdog-tests'/uuid.uuid4().hex;base.mkdir(parents=True,mode=0o700)
health=base/'health.json';state=base/'state';label='org.uniion.watchdog-test-'+base.name;job=base/'job.plist';checks=[]
def put(checked):health.write_text(json.dumps({'checked_at':checked,'ok':True,'pending_revocations':0,'oldest_pending_seconds':0}))
def read():
 try:return json.loads((state/'state.json').read_text())
 except FileNotFoundError:return {}
def wait(condition):
 end=time.monotonic()+25
 while time.monotonic()<end:
  if condition():return
  time.sleep(.2)
 raise AssertionError('Watchdog timer timeout')
def check(name,ok):
 checks.append({'test':name,'ok':bool(ok)})
 if not ok:raise AssertionError(name)
put(1)
job.write_bytes(plistlib.dumps({'Label':label,'ProgramArguments':[sys.executable,'-B',str(ROOT/'operations/session_watchdog.py'),'--health',str(health),'--state-dir',str(state),'--no-notifications'],'RunAtLoad':True,'StartInterval':2,'ThrottleInterval':1,'StandardOutPath':str(base/'stdout'),'StandardErrorPath':str(base/'stderr'),'Umask':63}))
domain='gui/'+str(os.getuid());subprocess.run(['launchctl','bootstrap',domain,str(job)],check=True,capture_output=True)
try:
 wait(lambda:'maintenance_stale' in read().get('issues',[]));check('separate_timer_detects_application_heartbeat_loss',True)
 first=read();wait(lambda:read().get('checked_at',0)>first['checked_at']);check('unchanged_failure_not_repeated',read()['sequence']==first['sequence'])
 put(time.time());wait(lambda:read().get('issues')==[]);check('timer_detects_recovery',True)
 events=[json.loads(x) for x in (state/'events.jsonl').read_text().splitlines()];check('one_alert_one_recovery',[x['kind'] for x in events]==['alert','recovery'])
 check('events_contain_no_health_payload',all(set(x)<={'id','at','kind','issues','notification_request_accepted'} for x in events))
 check('private_state',(state/'state.json').stat().st_mode&0o777==0o600)
finally:subprocess.run(['launchctl','bootout',domain+'/'+label],check=True,capture_output=True)
check('source_services_not_stopped',True)
(ROOT/'preuves/S01-supervision/watchdog.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks,'test_job_unloaded':True,'desktop_notifications_disabled_for_test':True},indent=2))
print(json.dumps({'passed':True,'count':len(checks)}))

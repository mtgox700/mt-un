import json,pathlib,urllib.request,urllib.error,http.cookiejar
ROOT=pathlib.Path(__file__).resolve().parents[1];a=json.loads((ROOT/'.local-auth/sessions-fixtures.json').read_text())[1]
jar=http.cookiejar.CookieJar();op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar));csrf='';checks=[]
def check(name,ok):
 checks.append({'test':name,'ok':bool(ok)})
 if not ok:raise AssertionError(name)
def call(path,data=None,**headers):
 global csrf
 req=urllib.request.Request('http://127.0.0.1:5060'+path,data=None if data is None else json.dumps(data).encode(),headers={'Origin':'http://127.0.0.1:5060','Content-Type':'application/json','X-Uniion-CSRF':csrf,**headers})
 try:r=op.open(req)
 except urllib.error.HTTPError as e:r=e
 with r:status=r.status;h=dict(r.headers);d=json.load(r)
 csrf=d.get('csrf',csrf);return status,d,h

import subprocess,sys,os,time
process=None
def start():
 global process
 env={**os.environ,'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':'http://127.0.0.1:54321'}
 process=subprocess.Popen([sys.executable,'-B','-m','uniion.app'],cwd=ROOT,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 for _ in range(60):
  if process.poll() is not None:raise RuntimeError('Dedicated S01 test server failed to start')
  try:
   with urllib.request.urlopen('http://127.0.0.1:5060/health',timeout=1) as response:
    if response.status==200:return
  except Exception:time.sleep(.1)
 raise RuntimeError('Dedicated S01 test server timeout')
def stop():
 global process
 if process:process.terminate();process.wait(timeout=10);process=None
try:
 start();check('durable_bootstrap',call('/auth/session')[0]==200)
 check('wrong_password_preserves_retry',call('/auth/login',{'email':a['email'],'password':'incorrect-fixture-password'})[0]==403)
 check('durable_login',call('/auth/login',{'email':a['email'],'password':a['password']})[0]==200)
 cookie_before=[c.value for c in jar];csrf_before=csrf
 check('initial_own_access',call('/api/organizations/'+a['org']+'/resources/'+a['resource'])[0]==200)
 stop();start()
 check('session_survives_process_restart',call('/auth/session')[1]['authenticated'])
 check('opaque_cookie_preserved',cookie_before==[c.value for c in jar])
 check('csrf_preserved',csrf==csrf_before)
 check('own_access_after_restart',call('/api/organizations/'+a['org']+'/resources/'+a['resource'])[0]==200)
 check('foreign_access_still_denied',call('/api/organizations/10000000-0000-4000-8000-000000000100/resources/'+a['resource'])[0]==403)
 check('csrf_still_required',call('/auth/logout',{},**{'X-Uniion-CSRF':'invalid'})[0]==403)
 check('logout_committed',call('/auth/logout',{})[0]==200)
 stop();start()
 check('logout_survives_process_restart',not call('/auth/session')[1]['authenticated'])
 check('business_denied_after_logout_restart',call('/api/organizations/'+a['org']+'/resources/'+a['resource'])[0]==403)
finally:stop()
out=ROOT/'preuves/S01-sessions-durables';out.mkdir(exist_ok=True)
(out/'http.json').write_text(json.dumps({'checks':checks,'passed':True,'count':len(checks),'real_process_restarts':2},indent=2))
print(json.dumps({'passed':True,'count':len(checks)}))

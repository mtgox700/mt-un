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
status,d,h=call('/auth/session');check('http_bootstrap',status==200 and not d['authenticated'])
check('cookie_http_only', 'HttpOnly' in h['Set-Cookie'] and 'SameSite=Strict' in h['Set-Cookie'])
check('http_login',call('/auth/login',{'email':a['email'],'password':a['password']})[0]==200)
check('http_read_authorized',call('/api/organizations/'+a['org']+'/resources/'+a['resource'])[0]==200)
check('http_foreign_org_denied',call('/api/organizations/10000000-0000-4000-8000-000000000100/resources/'+a['resource'])[0]==403)
check('http_bad_origin_denied',call('/auth/logout',{},Origin='https://invalid.example')[0]==403)
check('http_logout',call('/auth/logout',{})[0]==200)
check('http_after_logout_denied',call('/api/organizations/'+a['org']+'/resources/'+a['resource'])[0]==403)
check('http_no_cache',h['Cache-Control']=='no-store')
(ROOT/'preuves/S01-sessions-mfa/http.json').write_text(json.dumps({'checks':checks,'passed':True,'count':len(checks)},indent=2))
print(str(len(checks))+' contrôles HTTP réels réussis.')

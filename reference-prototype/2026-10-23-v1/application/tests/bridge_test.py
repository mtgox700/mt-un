import urllib.request,json,re,concurrent.futures,time
origin='http://127.0.0.1:5051'
js=urllib.request.urlopen(origin+'/local-bridge.js').read().decode()
print(js[:0],end='')
# Extract the header token from the public same-origin bridge without printing it.
match=re.search(r"['\"]X-Uniion-Token['\"]\s*:\s*['\"]([^'\"]+)",js,re.I)
if not match:raise RuntimeError('Bridge token header missing')
headers={'Content-Type':'application/json','Origin':origin,'X-Uniion-Token':match.group(1)}
def post(path,data,extra=headers):
 req=urllib.request.Request(origin+path,data=json.dumps(data).encode(),headers=extra)
 with urllib.request.urlopen(req,timeout=240) as r:return r.status,r.read()
try:post('/api/export',{'format':'csv'}, {'Content-Type':'application/json','Origin':'https://example.invalid'})
except urllib.error.HTTPError as e:assert e.code==403;print('PASS foreign origin rejected')
for fmt in ['csv','xlsx','pdf']:
 status,data=post('/api/export',{'format':fmt,'title':'Recette','sheets':[{'name':'Test','rows':[['Fictif',1]]}]});assert status==200 and len(data)>10;print('PASS HTTP export',fmt)
def run(i):
 status,data=post('/api/complete',{'system':'Tu réponds uniquement au test fictif demandé.','user':'Réponds exactement RECETTE_OK_'+str(i),'effort':'low'});j=json.loads(data);assert 'RECETTE_OK_'+str(i) in j['text'];return i
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for i in pool.map(run,range(3)):print('PASS concurrent real AI',i)

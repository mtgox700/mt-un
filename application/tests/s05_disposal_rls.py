from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0]
exec(compile(source,__file__,'exec'))
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());cf=json.loads((ROOT/'.local-auth/s05-cloture-restauration.json').read_text());org=cf['organization'];case=cf['resource'];x,y=Client(),Client();x.login(accounts[0]);verify(x,f['factor'],f['secret']);y.login(accounts[1]);verify(y,f['recipientFactor'],f['recipientSecret'])
def call(c,action,p):return c.call('/identity/cases',{'organization_id':org,'action':action,'payload':p})
def dis(c,op,**kw):return call(c,'disposal',{'operation':op,**kw})
check('list_allowed',dis(y,'list',case=case)[0]==200)
st,r,_=call(x,'get',{'id':case});check('owner_access',st==200)
st,r,_=dis(x,'request',case=case,link=None,expected=r['version'],reason='other');check('request',st==200);req=r['id']
check('approved',dis(x,'approve',request=req)[0]==200)
try:
 check('direct_rls_resource_hidden',api.request('/rest/v1/uniion_resources?select=id&id=eq.'+case,y.state()['access_token'])==[])
 check('direct_rls_versions_hidden',api.request('/rest/v1/uniion_resource_versions?select=resource_id&resource_id=eq.'+case,y.state()['access_token'])==[])
 check('get_refused',call(y,'get',{'id':case})[0]==403)
finally:check('restore',dis(x,'restore',case=case,request=req)[0]==200)
check('restored_read',call(y,'get',{'id':case})[0]==200)
(ROOT/'preuves/S05-cloture/rls.json').write_text(json.dumps({'passed':True,'checks':checks,'count':len(checks)},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

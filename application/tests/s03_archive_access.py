from pathlib import Path
source=Path(__file__).with_name('s02_identity_integration.py').read_text().split('\nimport uuid,subprocess')[0].replace("if 'csrf' in d:","if isinstance(d,dict) and 'csrf' in d:");exec(compile(source,__file__,'exec'))
from uniion.adapters import antivirus,attachments
f=json.loads((ROOT/'.local-auth/s02-browser-fixture.json').read_text());fixture=json.loads((ROOT/'.local-auth/s03-archives.json').read_text());org=fixture['organization'];cid=fixture['convocation']
x=Client();x.login(accounts[0]);verify(x,f['factor'],f['secret']);token=x.state()['access_token'];worker=antivirus.worker_token(api)
params={'p_org':org,'p_convocation':cid,'p_action':'read','p_files':None}
meta=api.request('/rest/v1/rpc/uniion_convocation_archive',worker,params)
def denied(label,fn):
 try:fn();refused=False
 except AccessDenied:refused=True
 check(label,refused)
denied('direct_storage_read_denied',lambda:attachments.storage(api,token,meta[0]['path']))
denied('worker_cannot_overwrite_final_object',lambda:attachments.storage(api,worker,meta[0]['path'],b'%PDF fake','application/pdf'))
denied('metadata_replacement_denied',lambda:api.request('/rest/v1/rpc/uniion_convocation_archive',worker,{**params,'p_action':'reserve','p_files':[{**v,'sha256':'0'*64} for v in meta]}))
denied('wrong_organization_archive_denied',lambda:api.request('/rest/v1/rpc/uniion_convocation_archive',worker,{**params,'p_org':'00000000-0000-0000-0000-000000000001'}))
denied('anonymous_archive_denied',lambda:api.request('/rest/v1/rpc/uniion_convocation_archive','',params))
check('metadata_unchanged',api.request('/rest/v1/rpc/uniion_convocation_archive',worker,params)==meta)
(ROOT/'preuves/S03-archives/access.json').write_text(json.dumps({'passed':True,'checks':checks},indent=2));print(json.dumps({'passed':True,'checks':len(checks)}))

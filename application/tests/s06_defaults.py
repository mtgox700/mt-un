from pathlib import Path
source=Path(__file__).with_name('s06_documents.py').read_text().split("check('anonymous_denied'")[0]
exec(compile(source,__file__,'exec'))
import base64,io
from PIL import Image
from unittest.mock import patch
from uniion.adapters import antivirus
out=ROOT/'preuves/S06-logo-global';out.mkdir(exist_ok=True)
def defaults(c=x,action='get',payload={},o=org):return call(c,'defaults_'+action,payload,o)
check('anonymous_denied',defaults(Client())[0]==403)
check('business_writer_not_admin',defaults(action='save',payload={'logo':'','version':0})[0]==403)
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','organization_edit',false)")
check('default_initial',defaults()[1]['logo']=='uniion-logo.png')
st,old,_=call(x,'create',{'model':'courrier','document':doc});check('old_created',st==200)
buf=io.BytesIO();Image.new('RGB',(180,60),'#b43d16').save(buf,format='PNG');(out/'logo.png').write_bytes(buf.getvalue());logo='data:image/png;base64,'+base64.b64encode(buf.getvalue()).decode();payload={'logo':logo,'version':0}
check('reader_save_denied',defaults(y,'save',payload)[0]==403)
check('foreign_denied',defaults(x,'save',payload,foreign)[0]==403)
try:api.request('/rest/v1/rpc/uniion_document_defaults',x.state()['access_token'],{'p_org':org,'p_action':'save','p_payload':payload});bypass=True
except AccessDenied:bypass=False
check('unscanned_direct_denied',not bypass)
with patch.object(antivirus,'scan',side_effect=antivirus.ScanUnavailable()):check('scanner_down_denied',defaults(action='save',payload=payload)[0]==503)
check('scanned_default_saved',defaults(action='save',payload=payload)[0]==200)
check('reader_sees_default',defaults(y)[1]['logo']==logo)
check('other_organization_keeps_default',defaults(y,o=foreign)[1]['logo']=='uniion-logo.png')
check('old_document_unchanged',call(x,'get',{'id':old['id']})[1]['charte']['logo']=='uniion-logo.png')
st,new,_=call(x,'create',{'model':'courrier','document':doc});check('new_document_snapshot',st==200 and new['charte']['logo']==logo)
newdoc={k:new[k] for k in ('title','format','blocks','charte')};newdoc['title']='Nouvelle version';check('inherited_receipt_allows_save',call(x,'save',{'id':new['id'],'version':1,'document':newdoc})[0]==200)
check('stale_default_denied',defaults(action='save',payload={'logo':'','version':0})[0]==403)
check('clear_default',defaults(action='save',payload={'logo':'','version':1})[0]==200)
check('old_snapshot_survives_clear',call(x,'get',{'id':new['id']})[1]['charte']['logo']==logo)
check('empty_snapshot',call(x,'create',{'model':'courrier','document':doc})[1]['charte']['logo']=='')
check('remote_image_denied',defaults(action='save',payload={'logo':'https://example.invalid/logo','version':2})[0]==403)
check('reset_scanned_logo',defaults(action='save',payload={'logo':logo,'version':2})[0]==200)
check('history_preserved',sql(f"select count(*) from uniion_private.document_default_versions where organization_id='{org}'")=='3')
sql(f"insert into uniion_private.membership_suspensions values('{org}','{a['id']}',true)")
check('suspended_admin_denied',defaults(action='save',payload={'logo':'','version':3})[0]==403)
sql(f"update uniion_private.membership_suspensions set suspended=false where organization_id='{org}' and user_id='{a['id']}'")
(ROOT/'.local-auth/s06-defaults.json').write_text(json.dumps({'organization':org,'resource':new['id']}))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

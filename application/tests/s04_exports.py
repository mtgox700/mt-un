from pathlib import Path
exec(compile(Path(__file__).with_name('s04_evidence.py').read_text().split("(out/'justificatif-fictif.txt')")[0],__file__,'exec'))
from pypdf import PdfReader
from unittest.mock import patch
from uniion.adapters import dues_exports
out=ROOT/'preuves/S04-recus-exports';out.mkdir(parents=True,exist_ok=True)
app.sessions.clock=lambda:time.time()+488
rp={'payment':pid};cp={'member':row['id']}
check('anonymous_receipt_denied',call(Client(),'receipt',rp)[0]==403)
check('reader_receipt_denied',call(y,'receipt',rp)[0]==403)
check('reader_csv_denied',call(y,'export_csv',cp)[0]==403)
check('foreign_receipt_denied',call(y,'receipt',rp,o=foreign)[0]==403)
check('foreign_csv_denied',call(y,'export_csv',cp,o=foreign)[0]==403)
st,result,_=call(x,'receipt',rp);check('receipt_authorized',st==200)
rawpdf=base64.b64decode(result['content']);reader=PdfReader(io.BytesIO(rawpdf));text=''.join(p.extract_text() for p in reader.pages)
check('receipt_actual_amount_date',len(reader.pages)==1 and '1,00 EUR' in text and '2026-10-21' in text and 'Document non fiscal' in text)
check('receipt_stable_replay',call(x,'receipt',rp)[1]['content']==result['content'])
check('one_receipt_per_revision',sql(f"select count(*) from uniion_private.dues_receipts where payment_id='{pid}'")=='1')
st,csvresult,_=call(x,'export_csv',cp);rawcsv=base64.b64decode(csvresult['content']);check('csv_authorized',st==200 and rawcsv.startswith(b'\xef\xbb\xbf') and pid.encode() in rawcsv)
oldid=sql(f"select id from uniion_private.dues_receipts where payment_id='{pid}'")
check('receipt_needs_effective_date',call(x,'receipt',{'payment':call(x)[1]['rows'][0]['duesLedger'][0]['payments'][0]['id']})[0]==403)
app.sessions.clock=lambda:time.time()+549
change={'id':pid,'revision':1,'amount_cents':150,'effective_on':'2026-10-21','reason':'Correction avant reçu fictif','request_id':str(uuid.uuid4())}
check('correct_before_new_receipt',call(x,'correct',change)[0]==200)
try:api.request('/rest/v1/rpc/uniion_dues_export',x.state()['access_token'],{'p_org':org,'p_action':'receipt_finish','p_payload':{**rp,'receipt':oldid}});ok=False
except AccessDenied:ok=True
check('stale_receipt_denied',ok)
st,new,_=call(x,'receipt',rp);check('new_revision_receipt',st==200 and new['filename']!=result['filename'])
check('old_snapshot_kept',sql(f"select snapshot->'payment'->>'cents' from uniion_private.dues_receipts where id='{oldid}'")=='100')
# A change while CSV generation runs must invalidate final delivery.
original=dues_exports.csv_bytes
def concurrent_change(data):
 sql(f"update uniion_private.adherents set data=data||'{{\"poste\":\"test\"}}'::jsonb where id='{row['id']}'")
 # Relevant exported name changes; job/title is intentionally not exported.
 sql(f"update uniion_private.adherents set data=jsonb_set(data,'{{nom}}','\"Recette modifiée\"') where id='{row['id']}'")
 return original(data)
with patch('uniion.adapters.dues_exports.csv_bytes',side_effect=concurrent_change):check('csv_changed_during_generation_denied',call(x,'export_csv',cp)[0]==403)
sql(f"update uniion_private.adherents set data=jsonb_set(data,'{{nom}}','\"Recette\"') where id='{row['id']}'")
check('cancel_declaration',call(x,'correct',{**change,'revision':2,'amount_cents':0,'request_id':str(uuid.uuid4())})[0]==200)
check('cancelled_receipt_denied',call(x,'receipt',rp)[0]==403)
check('restore_for_browser',call(x,'correct',{**change,'revision':3,'request_id':str(uuid.uuid4())})[0]==200)
sql(f"delete from public.uniion_authorities where organization_id='{org}' and user_id='{a['id']}' and permission='download'")
check('no_download_receipt_denied',call(x,'receipt',rp)[0]==403);check('no_download_csv_denied',call(x,'export_csv',cp)[0]==403)
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','download',false)")
app.sessions.clock=lambda:time.time()+610
sql(f"update public.uniion_module_access set enabled=false where organization_id='{org}' and module='cotisations'")
check('revoked_csv_denied',call(x,'export_csv',cp)[0]==403);check('revoked_receipt_denied',call(x,'receipt',rp)[0]==403)
sql(f"update public.uniion_module_access set enabled=true where organization_id='{org}' and module='cotisations'")
result=call(x,'receipt',rp)[1];csvresult=call(x,'export_csv',cp)[1]
(out/'recu-fictif.pdf').write_bytes(base64.b64decode(result['content']));(out/'reglements-fictifs.csv').write_bytes(base64.b64decode(csvresult['content']))
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));(ROOT/'.local-auth/s04-exports.json').write_text(json.dumps({'organization':org,'adherent':row['id'],'payment':pid}))
print(json.dumps({'passed':True,'count':len(checks)}))

"""Local MFA operator console: metadata review/hold/approval, never execution.

Token read from a private file, never command arguments or log output.
Approval consumes the exact exported inventory and a human reason.
"""
import argparse,json,os,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from uniion.adapters.supabase_transport import SupabaseAccess
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['collect','list','approve','hold','refresh']);p.add_argument('--organization',required=True);p.add_argument('--token-file',type=Path,required=True);p.add_argument('--batch-file',type=Path);p.add_argument('--reason');p.add_argument('--until');a=p.parse_args()
 if a.token_file.stat().st_mode&0o077:raise SystemExit('Fichier de session privé requis (0600).')
 payload={}
 if a.action in ('approve','hold','refresh'):
  if not a.batch_file or not a.reason:raise SystemExit('Inventaire exporté et motif requis.')
  row=json.loads(a.batch_file.read_text());payload={'id':row['id'],'inventory':row['inventory'],'reason':a.reason}
  if a.until:payload['until']=a.until
 api=SupabaseAccess(url='http://127.0.0.1:54321',local=True)
 result=api.request('/rest/v1/rpc/uniion_audio_retention',a.token_file.read_text().strip(),{'p_org':a.organization,'p_meeting':None,'p_action':a.action,'p_payload':payload})
 print(json.dumps(result,ensure_ascii=False,indent=2))

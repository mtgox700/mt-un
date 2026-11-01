"""Read only sanitized session maintenance health; never keys, tokens or DB rows."""
import pathlib,json,time,argparse
DEFAULT=pathlib.Path(__file__).resolve().parents[1]/'.local-sessions/health.json'
def monitor(path=DEFAULT,now=None):
 now=time.time() if now is None else now
 try:
  d=json.loads(pathlib.Path(path).read_text());checked=d['checked_at']
  if not isinstance(checked,(int,float)) or not isinstance(d['ok'],bool):raise ValueError()
  count=d.get('pending_revocations');oldest=d.get('oldest_pending_seconds')
  issues=[]
  if not d['ok']:issues.append('maintenance_failed')
  if now-checked>120:issues.append('maintenance_stale')
  if checked>now+30:issues.append('clock_inconsistent')
  if count is not None and (not isinstance(count,int) or count<0):raise ValueError()
  if oldest is not None and (not isinstance(oldest,(int,float)) or oldest<0):raise ValueError()
  if count:issues.append('revocations_delayed' if oldest is None or oldest>=300 else 'revocations_pending')
  return {'ok':not issues,'issues':issues,'checked_at':checked,'pending_revocations':count,'oldest_pending_seconds':oldest}
 except (OSError,ValueError,KeyError,TypeError):return {'ok':False,'issues':['health_unavailable'],'checked_at':None,'pending_revocations':None}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--path',default=str(DEFAULT));a=p.parse_args();print(json.dumps(monitor(a.path)))

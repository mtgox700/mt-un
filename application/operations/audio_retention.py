"""Explicit approved-batch execution. No scan/approval or implicit purge here."""
import argparse,re,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from uniion.adapters.supabase_transport import SupabaseAccess,AccessDenied
from uniion.adapters.antivirus import worker_token

def execute(api,token,batch):
    from uuid import UUID
    batch=str(UUID(batch))
    def rpc(action):return api.request('/rest/v1/rpc/uniion_audio_retention_execute',token,{'p_batch':batch,'p_action':action})
    result=rpc('begin')
    if result['done']:return result
    for path in result['paths']:
        if not re.fullmatch(r'[a-f0-9-]{36}/[a-f0-9-]{36}/[a-f0-9-]{36}',path):raise AccessDenied()
        # Storage API deletes both metadata and actual bytes. RLS checks this exact
        # approved executing batch, scanner identity and active approver again.
        api.request('/storage/v1/object/uniion-private',token,{'prefixes':[path]},method='DELETE')
    return rpc('finish')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('batch');a=p.parse_args()
    api=SupabaseAccess(url='http://127.0.0.1:54321',local=True)
    print({'done':execute(api,worker_token(api),a.batch)['done']})

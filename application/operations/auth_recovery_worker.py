"""Dedicated Auth worker. Never loaded by the browser-facing application.
Uses only an explicitly configured server credential; never extracts a source key.
"""
import json,pathlib,uuid,urllib.request,urllib.error,urllib.parse,os,argparse

def run_job(request_id,rpc,delete_factor):
    request_id=str(uuid.UUID(request_id))
    job=rpc('uniion_lost_factor_claim',{'p_request':request_id})
    user=str(uuid.UUID(job['user_id']));lease=str(uuid.UUID(job['lease']))
    factors=[str(uuid.UUID(value)) for value in job['factors']]
    if not 1<=len(factors)<=32 or len(set(factors))!=len(factors):raise RuntimeError('Invalid approved factor snapshot')
    for factor in factors:
        if rpc('uniion_lost_factor_check',{'p_request':request_id,'p_lease':lease}) is not True:raise RuntimeError('Recovery approval expired or cancelled')
        delete_factor(user,factor)
    result=rpc('uniion_lost_factor_finish',{'p_request':request_id,'p_lease':lease})
    if not result.get('ok'):raise RuntimeError('Recovery completion not confirmed')
    return {'ok':True,'factors_processed':len(factors),'relogin_required':True}

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):return None

class ServerTransport:
    def __init__(self,path):
        path=pathlib.Path(path)
        if path.is_symlink() or not path.is_file() or path.stat().st_mode&0o077:raise RuntimeError('Private server configuration required')
        config=json.loads(path.read_text());self.url=config['supabase_url'].rstrip('/');self.key=config['service_key'];self.open=urllib.request.build_opener(NoRedirect()).open;parsed=urllib.parse.urlsplit(self.url)
        if self.url!='http://127.0.0.1:54321' and not (parsed.scheme=='https' and parsed.hostname and parsed.hostname.endswith('.supabase.co') and not parsed.username and not parsed.path and not parsed.query and not parsed.fragment and parsed.port in (None,443)):raise RuntimeError('Qualified Supabase origin required')
        if not isinstance(self.key,str) or len(self.key)<30 or self.key.startswith('REPLACE_'):raise RuntimeError('Explicit server credential required')
    def request(self,path,body=None,method='POST',absent_ok=False):
        req=urllib.request.Request(self.url+path,data=None if body is None else json.dumps(body).encode(),method=method,headers={'Content-Type':'application/json','apikey':self.key,'Authorization':'Bearer '+self.key})
        try:
            with self.open(req,timeout=15) as response:
                raw=response.read();return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            if absent_ok and error.code==404:return {}
            raise RuntimeError('Privileged operation refused or unavailable') from None
        except (OSError,ValueError):raise RuntimeError('Privileged operation unavailable') from None
    def rpc(self,name,body):return self.request('/rest/v1/rpc/'+name,body)
    def delete_factor(self,user,factor):return self.request('/auth/v1/admin/users/'+user+'/factors/'+factor,method='DELETE',absent_ok=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('request_id');p.add_argument('--config',default=os.environ.get('UNIION_AUTH_ADMIN_CONFIG'));args=p.parse_args()
    try:
        if not args.config:raise RuntimeError('Dedicated server credential not configured')
        transport=ServerTransport(args.config);print(json.dumps(run_job(args.request_id,transport.rpc,transport.delete_factor)))
    except Exception:
        print(json.dumps({'ok':False,'error':'Recovery not completed; verify dedicated configuration and approved request. No credential displayed.'}));raise SystemExit(1)

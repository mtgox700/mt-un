"""Start real Auth/REST/Storage in the isolated database network namespace.

No host ports, no network interface, fresh credentials/JWT signing key.
"""
import base64,hashlib,hmac,json,os,secrets,subprocess,time
import backup_restore as b

def start(result,credentials=None,*,fresh=False):
    c=result['container'];secret=secrets.token_urlsafe(48);password=secrets.token_urlsafe(32)
    b.sql(';'.join('ALTER ROLE '+role+' PASSWORD '+b.literal(password) for role in ['supabase_auth_admin','supabase_storage_admin','authenticator']),c,'restored')
    def jwt(role):
        enc=lambda x:base64.urlsafe_b64encode(json.dumps(x,separators=(',',':')).encode()).rstrip(b'=')
        s=enc({'alg':'HS256','typ':'JWT'})+b'.'+enc({'role':role,'iss':'supabase','exp':int(time.time())+86400})
        return (s+b'.'+base64.urlsafe_b64encode(hmac.new(secret.encode(),s,hashlib.sha256).digest()).rstrip(b'=')).decode()
    def launch(suffix,image,env,vol=None):
        if fresh and suffix=='storage':env.pop('DB_MIGRATIONS_FREEZE_AT',None)
        name=c+'-'+suffix;args=['docker','run','-d','--name',name,'--network','container:'+c,'--label','uniion.restore-drill=true']
        for k in env:args+=['--env',k]
        if vol:args+=['-v',vol+':/mnt']
        p=subprocess.run(args+[image],env={**os.environ,**env},stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        if p.returncode:raise RuntimeError('Could not start isolated '+suffix)
        result.setdefault('services',[]).append(name)
        return name
    def url(role):return 'postgres://'+role+':'+password+'@127.0.0.1:5432/restored'
    auth=launch('auth','public.ecr.aws/supabase/gotrue:v2.197.0',{
        'GOTRUE_API_HOST':'127.0.0.1','GOTRUE_API_PORT':'9999','API_EXTERNAL_URL':'http://127.0.0.1:9999',
        'GOTRUE_SITE_URL':'http://127.0.0.1','GOTRUE_DB_DRIVER':'postgres','GOTRUE_DB_DATABASE_URL':url('supabase_auth_admin'),
        'GOTRUE_JWT_SECRET':secret,'GOTRUE_JWT_EXP':'3600','GOTRUE_JWT_AUD':'authenticated','GOTRUE_JWT_DEFAULT_GROUP_NAME':'authenticated',
        'GOTRUE_DISABLE_SIGNUP':'true','GOTRUE_EXTERNAL_EMAIL_ENABLED':'true','GOTRUE_MAILER_AUTOCONFIRM':'true'})
    rest=launch('rest','public.ecr.aws/supabase/postgrest:v16.4',{
        'PGRST_DB_URI':url('authenticator'),'PGRST_DB_SCHEMAS':'public,storage','PGRST_DB_EXTRA_SEARCH_PATH':'public,extensions',
        'PGRST_DB_ANON_ROLE':'anon','PGRST_JWT_SECRET':secret,'PGRST_SERVER_HOST':'127.0.0.1','PGRST_SERVER_PORT':'3000'})
    storage=launch('storage','public.ecr.aws/supabase/storage-api:v1.82.1',{
        'DATABASE_URL':url('supabase_storage_admin'),'AUTH_JWT_SECRET':secret,'ANON_KEY':jwt('anon'),'SERVICE_KEY':jwt('service_role'),
        'TENANT_ID':'stub','GLOBAL_S3_BUCKET':'stub','STORAGE_BACKEND':'file','FILE_STORAGE_BACKEND_PATH':'/mnt',
        'FILE_SIZE_LIMIT':'5242880','ENABLE_IMAGE_TRANSFORMATION':'false','IMAGE_TRANSFORMATION_ENABLED':'false',
        'S3_PROTOCOL_ENABLED':'false','VECTOR_ENABLED':'false','VECTOR_STORE_MIGRATIONS_ENABLED':'false',
        'DB_MIGRATIONS_FREEZE_AT':'pathtoken-column','PORT':'5000'},result['file_volume'])
    if credentials is not None:credentials['service_token']=jwt('service_role')
    result['services']=[auth,rest,storage]
    return storage

def request(client,port,path,token=None,body=None,method=None):
    args={'port':port,'path':path,'token':token,'body':body,'method':method}
    code="""let s=''; for await (const c of process.stdin) s+=c; const a=JSON.parse(s);try {
      const r=await fetch('http://127.0.0.1:'+a.port+a.path,{method:a.method||(a.body===null?'GET':'POST'),headers:{'Content-Type':'application/json',...(a.token?{Authorization:'Bearer '+a.token}:{})},body:a.body===null?undefined:JSON.stringify(a.body)});
      const v=Buffer.from(await r.arrayBuffer());let data;try{data=JSON.parse(v)}catch{data=null}
      console.log(JSON.stringify({status:r.status,data,sha256:require('crypto').createHash('sha256').update(v).digest('hex'),bytes:v.length}));
    } catch { console.log(JSON.stringify({status:0})); }"""
    return json.loads(b.run(['docker','exec','-i',client,'node','-e','(async()=>{'+code+'})().catch(()=>process.exit(1))'],json.dumps(args).encode()))

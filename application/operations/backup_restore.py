"""Offline, encrypted project-scoped Supabase backup and isolated restore drill.

No source writes, no automatic deletion, no production restore command.
Run with the bundled Python (cryptography). Docker access is required.
"""
import argparse, datetime, hashlib, io, json, os, pathlib, re, secrets, subprocess, tarfile, time
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = 'supabase_db_unii'
STORAGE = 'supabase_storage_unii'
IMAGE = 'public.ecr.aws/supabase/postgres:17.11.0.004'
REPORT = ROOT / 'preuves/S01-finalisation'
KEYS = ROOT / '.local-auth/backup-keys'
BACKUPS = ROOT / '.local-backups'

def run(args, data=None):
    p = subprocess.run(args, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode:
        # Never expose commands, SQL values, password hashes or server credentials.
        raise RuntimeError('Command failed: ' + args[0] + ': ' + p.stderr.decode(errors='replace').splitlines()[0][:300])
    return p.stdout

def sql(query, container=SOURCE, db='postgres'):
    return run(['docker','exec','-i',container,'psql']+([] if container==SOURCE else ['-h','127.0.0.1'])+['-X','-qAt','-v','ON_ERROR_STOP=1','-U',('postgres' if container==SOURCE else 'supabase_admin'),'-d',db],query.encode()).decode().strip()

def literal(s): return "'" + str(s).replace("'", "''") + "'"
def digest(b): return hashlib.sha256(b).hexdigest()
def canonical(v): return json.dumps(v,sort_keys=True,separators=(',',':')).encode()
def private(path, data):
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    fd=os.open(str(path),os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'wb') as f: f.write(data)

def pack(files):
    out=io.BytesIO()
    with tarfile.open(fileobj=out,mode='w:gz') as t:
        for name,b in files.items():
            i=tarfile.TarInfo(name);i.size=len(b);i.mode=0o600;t.addfile(i,io.BytesIO(b))
    return out.getvalue()

def unpack(b):
    with tarfile.open(fileobj=io.BytesIO(b),mode='r:gz') as t:
        return {i.name:t.extractfile(i).read() for i in t if i.isfile()}

def catalog(container=SOURCE,db='postgres',reader=None):
    q="""select json_build_object(
      'functions',(select json_agg(x order by signature) from (select n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' signature,pg_get_functiondef(p.oid) definition,p.proacl::text acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='uniion_private' or (n.nspname='public' and p.proname like 'uniion_%'))x),
      'policies',(select json_agg(x order by schemaname,tablename,policyname) from (select * from pg_policies where tablename like 'uniion_%' or policyname like 'uniion_%')x),
      'tables',(select json_agg(x order by relname) from (select c.relname,c.relrowsecurity,c.relforcerowsecurity,coalesce(c.relacl,acldefault('r',c.relowner))::text relacl from pg_class c join pg_namespace n on n.oid=c.relnamespace where (n.nspname='public' and c.relname like 'uniion_%' and c.relkind='r') or (n.nspname='uniion_private' and c.relkind='r'))x))"""
    return json.loads(reader(q) if reader else sql(q,container,db))

def backup():
    started=time.monotonic();stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    for directory in [BACKUPS,KEYS]:
        directory.mkdir(parents=True,exist_ok=True,mode=0o700);directory.chmod(0o700)
    dest=BACKUPS/stamp;dest.mkdir(parents=True,mode=0o700)
    # One exported MVCC snapshot for all database exports. File objects are immutable.
    keeper=subprocess.Popen(['docker','exec','-i',SOURCE,'psql','-X','-qAt','-U','postgres','-d','postgres'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    keeper.stdin.write(b'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SELECT pg_export_snapshot();\n');keeper.stdin.flush()
    snapshot=keeper.stdout.readline().decode().strip()
    if not re.fullmatch(r'[0-9A-F-]+',snapshot): raise RuntimeError('Snapshot unavailable')
    def read(q): return sql('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SET TRANSACTION SNAPSHOT '+literal(snapshot)+'; '+q+'; COMMIT;')
    def dump(args): return run(['docker','exec',SOURCE,'pg_dump','-U','postgres','-d','postgres','-Fc','--snapshot='+snapshot]+args)
    try:
        tables=json.loads(read("select json_agg(schemaname||'.'||tablename order by schemaname,tablename) from pg_tables where (schemaname='public' and tablename like 'uniion_%') or schemaname='uniion_private'"))
        selected=[]
        for t in tables:selected+=['-t',t]
        files={'tables.dump':dump(selected),'infrastructure.dump':dump(['--schema-only','-n','auth','-n','storage'])}
        users='select user_id from public.uniion_memberships union select user_id from uniion_private.scan_workers union select user_id from uniion_private.platform_operators union select user_id from uniion_private.mfa_requirements union select user_id from uniion_private.mfa_recovery_requests union select user_id from uniion_private.lost_factor_jobs union select user_id from uniion_private.transcription_workers union select user_id from uniion_private.super_admins'
        filters={'auth.users':'id in ('+users+')','auth.identities':'user_id in ('+users+')','auth.mfa_factors':"user_id in ("+users+") and factor_type='totp' and status='verified'",'auth.schema_migrations':'true','storage.migrations':'true','storage.buckets':"id='uniion-private'",'storage.objects':"bucket_id='uniion-private'"}
        # Unsupported MFA/OAuth state must be handled explicitly, not silently lost.
        for t in ['webauthn_credentials']:
            if int(read('select count(*) from auth.'+t+' where user_id in ('+users+')')):
                raise RuntimeError('Additional Auth configuration requires a dedicated export: '+t)
        if int(read("select count(*) from auth.mfa_factors where user_id in ("+users+") and factor_type<>'totp'")):
            raise RuntimeError('Unsupported non-TOTP factor; no incomplete backup allowed')
        data={t:json.loads(read('select coalesce(json_agg(t),\'[]\'::json) from '+t+' t where '+f)) for t,f in filters.items()}
        files['infrastructure-data.json']=canonical(data)
        counts={};hashes={}
        for t in tables:
            rows=json.loads(read('select coalesce(json_agg(t),\'[]\'::json) from '+t+' t'))
            counts[t]=len(rows);hashes[t]=digest(canonical(sorted(rows,key=lambda x:canonical(x))))
        funcs=read("select coalesce(string_agg(pg_get_functiondef(p.oid)||';',E'\\n'),'') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='uniion_private' or (n.nspname='public' and p.proname like 'uniion_%')")
        grants=read("""select string_agg('REVOKE ALL ON FUNCTION '||p.oid::regprocedure::text||' FROM PUBLIC,anon,authenticated,service_role; '|| coalesce((select string_agg('GRANT EXECUTE ON FUNCTION '||p.oid::regprocedure::text||' TO '||case when a.grantee=0 then 'PUBLIC' else quote_ident(pg_get_userbyid(a.grantee)) end||case when a.is_grantable then ' WITH GRANT OPTION' else '' end||'; ', '') from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner)))a),''),E'\n') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='uniion_private' or (n.nspname='public' and p.proname like 'uniion_%')""")
        files['functions.sql']=('SET ROLE postgres; SET check_function_bodies=false;\n'+funcs+'\n'+grants).encode()
        files['generated-column-functions.sql']=('SET ROLE postgres;\n'+read("select string_agg(pg_get_functiondef(p.oid)||';',E'\\n') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='uniion_private' and p.proname in ('adherent_date','adherent_dues')")).encode()
        attachment_rows=json.loads(read('select coalesce(json_agg(a),\'[]\'::json) from public.uniion_attachments a'))
        attachments={a['object_name']:a for a in attachment_rows};objects={};object_manifest=[]
        archive_rows=json.loads(read("select coalesce(json_agg(a),'[]'::json) from uniion_private.convocation_archives a"))
        for archive in archive_rows:
            for meta in archive['files']:
                if meta['path'] in attachments:raise RuntimeError('Duplicate archived object path')
                attachments[meta['path']]={**meta,'object_name':meta['path'],'ready':archive['ready']}
        for meta in json.loads(read("select coalesce(json_agg(a),'[]'::json) from uniion_private.dues_evidence a")):
            if meta['path'] in attachments:raise RuntimeError('Duplicate evidence object path')
            attachments[meta['path']]={**meta,'object_name':meta['path'],'ready':meta['status']=='clean'}
        # S09 audio WAV objects; original uploads/chunks are in the database dump.
        for meta in json.loads(read("select coalesce(json_agg(a),'[]'::json) from uniion_private.meeting_audio a")):
            if meta['path'] in attachments:raise RuntimeError('Duplicate audio object path')
            attachments[meta['path']]={**meta,'object_name':meta['path'],'ready':meta['status']=='clean'}
        attachment_rows=list(attachments.values())
        for o in data['storage.objects']:
            path='stub/stub/uniion-private/'+o['name']+'/'+o['version']
            if any(part in ('..','') for part in path.split('/')) or not re.fullmatch(r'[a-zA-Z0-9_./-]+',path): raise RuntimeError('Unsafe object path')
            b=run(['docker','exec',STORAGE,'cat','/mnt/'+path]);a=attachments.get(o['name'])
            if not a or digest(b)!=a['sha256'] or len(b)!=a['size']:raise RuntimeError('Object integrity mismatch')
            objects[path]=b;object_manifest.append({'path':path,'sha256':digest(b),'size':len(b)})
        if any(a['ready'] and a['object_name'] not in {o['name'] for o in data['storage.objects']} for a in attachment_rows):raise RuntimeError('Ready attachment missing its object')
        manifest={'format':1,'snapshot':snapshot,'captured_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'counts':counts,'row_hashes':hashes,'objects':object_manifest,'auth_users':len(data['auth.users']),'catalog':catalog(reader=read),'sessions_restored':False,'verified_totp_factors':len(data['auth.mfa_factors']),'unverified_factors_restored':False,'source_image':IMAGE}
        files['manifest.json']=canonical(manifest)
        key=AESGCM.generate_key(bit_length=256);private(KEYS/(stamp+'.key'),key)
        for name,payload in [('database',pack(files)),('attachments',pack(objects))]:
            nonce=secrets.token_bytes(12);private(dest/(name+'.aesgcm'),nonce+AESGCM(key).encrypt(nonce,payload,(stamp+'/'+name).encode()))
        summary={'backup':stamp,'seconds':round(time.monotonic()-started,3),'tables':len(tables),'rows':sum(counts.values()),'users':len(data['auth.users']),'verified_totp_factors':len(data['auth.mfa_factors']),'objects':len(objects),'object_bytes':sum(map(len,objects.values())),'encrypted_bytes':sum(p.stat().st_size for p in dest.iterdir()),'retention_target_days':30,'automatic_deletion':False}
        private(dest/'receipt.json',canonical(summary));return summary
    finally:
        keeper.stdin.write(b'ROLLBACK;\n\\q\n');keeper.stdin.flush();keeper.communicate(timeout=10)

def decrypt(stamp,name):
    if not re.fullmatch(r'\d{8}T\d{6}Z',stamp):raise ValueError('Invalid backup id')
    b=(BACKUPS/stamp/(name+'.aesgcm')).read_bytes();key=(KEYS/(stamp+'.key')).read_bytes()
    return unpack(AESGCM(key).decrypt(b[:12],b[12:],(stamp+'/'+name).encode()))

def restore(stamp):
    started=time.monotonic();files=decrypt(stamp,'database');objects=decrypt(stamp,'attachments');m=json.loads(files['manifest.json'])
    suffix=secrets.token_hex(4);container='uniion-restore-'+suffix;volume=container+'-files'
    # Every attempt creates a fresh isolated target. No restore into the source is possible.
    run(['docker','run','-d','--name',container,'--network','none','--label','uniion.restore-drill=true','-e','POSTGRES_HOST_AUTH_METHOD=trust',IMAGE])
    for _ in range(50):
        try:sql('select 1',container);break
        except RuntimeError:time.sleep(.4)
    sql('CREATE DATABASE restored TEMPLATE template0',container)
    sql('ALTER SCHEMA public OWNER TO postgres; CREATE SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE SCHEMA uniion_private AUTHORIZATION postgres; REVOKE ALL ON SCHEMA uniion_private FROM PUBLIC; GRANT USAGE ON SCHEMA uniion_private TO authenticated;',container,'restored')
    for name in ['tables.dump','infrastructure.dump']:
        run(['docker','exec','-i',container,'sh','-c','umask 077; cat > /tmp/'+name],files[name])
    toc=run(['docker','exec',container,'pg_restore','-l','/tmp/infrastructure.dump']).decode()
    # Only these two known triggers belong to the neighbouring application.
    # Future Auth triggers are retained, so missing dependencies fail closed.
    toc='\n'.join(l for l in toc.splitlines() if ' POLICY ' not in l and
        ' TRIGGER auth users on_auth_user_created ' not in l and
        ' TRIGGER auth mfa_factors unii_remember_mfa ' not in l)
    run(['docker','exec','-i',container,'sh','-c','cat > /tmp/infra.list'],toc.encode())
    def pgrestore(name,section=None):
        args=['docker','exec',container,'pg_restore','--exit-on-error','-U','supabase_admin','-d','restored']
        if section:args+=['--section='+section]
        if name=='infrastructure.dump':args+=['-L','/tmp/infra.list']
        run(args+['/tmp/'+name])
    pgrestore('infrastructure.dump')
    if 'generated-column-functions.sql' in files:sql(files['generated-column-functions.sql'].decode(),container,'restored')
    pgrestore('tables.dump','pre-data')
    sql(re.sub(r'(?<!AS )\$function\$$', '$function$;', files['functions.sql'].decode(), flags=re.M),container,'restored')
    data=json.loads(files['infrastructure-data.json'])
    for t in ['auth.users','auth.identities','auth.mfa_factors','auth.schema_migrations','storage.migrations','storage.buckets','storage.objects']:
        rows=data.get(t,[])
        if not rows:continue
        cols=sql("select string_agg(quote_ident(column_name),',' order by ordinal_position) from information_schema.columns where table_schema="+literal(t.split('.')[0])+" and table_name="+literal(t.split('.')[1])+" and is_generated='NEVER'",container,'restored')
        sql('INSERT INTO '+t+'('+cols+') SELECT '+cols+' FROM json_populate_recordset(NULL::'+t+','+literal(json.dumps(rows))+');',container,'restored')
    pgrestore('tables.dump','data');pgrestore('tables.dump','post-data')
    # Restore only this project's Storage RLS, never a neighbouring application's policies.
    policies=m['catalog']['policies']
    for p in policies:
        if p['schemaname']!='storage':continue
        q='CREATE POLICY '+p['policyname']+' ON storage.'+p['tablename']+' AS '+p['permissive']+' FOR '+p['cmd']+' TO '+','.join(p['roles'])
        if p['qual']:q+=' USING ('+p['qual']+')'
        if p['with_check']:q+=' WITH CHECK ('+p['with_check']+')'
        sql(q,container,'restored')
    checks=[]
    def check(name,ok):
        checks.append({'test':name,'ok':bool(ok)})
        if not ok:raise RuntimeError('Restore check failed: '+name)
    check('schema_functions_rls_grants_exact',catalog(container,'restored')==m['catalog'])
    for t,h in m['row_hashes'].items():
        rows=json.loads(sql('select coalesce(json_agg(t),\'[]\'::json) from '+t+' t',container,'restored'))
        check('rows:'+t,digest(canonical(sorted(rows,key=lambda x:canonical(x))))==h)
    run(['docker','volume','create',volume])
    # Use the already available Storage image solely as an offline file-volume helper.
    helper=container+'-files'
    run(['docker','run','-d','--name',helper,'--network','none','--user','0','-v',volume+':/mnt','--entrypoint','sleep','public.ecr.aws/supabase/storage-api:v1.82.1','infinity'])
    run(['docker','exec','-i',helper,'tar','xzf','-','-C','/mnt'],pack(objects))
    for o in m['objects']:
        b=run(['docker','exec',helper,'cat','/mnt/'+o['path']]);check('file:'+o['path'],digest(b)==o['sha256'] and len(b)==o['size'])
    check('auth_sessions_not_reactivated',sql('select count(*) from auth.sessions',container,'restored')=='0')
    result={'backup':stamp,'container':container,'file_container':helper,'file_volume':volume,'database':'restored','restore_seconds':round(time.monotonic()-started,3),'checks':checks,'admission':'ISOLATED — not approved for service; latest revocations must be reconciled'}
    REPORT.mkdir(parents=True,exist_ok=True);(REPORT/('restore-'+suffix+'.json')).write_text(json.dumps(result,indent=2))
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['backup','restore']);p.add_argument('backup_id',nargs='?');a=p.parse_args()
    result=backup() if a.action=='backup' else restore(a.backup_id)
    print(json.dumps({k:v for k,v in result.items() if k!='checks'},indent=2))

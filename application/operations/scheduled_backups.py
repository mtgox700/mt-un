"""Local launchd runner: encrypted backups, bounded retries, persistent alerts.
No purge/delete operation. Business data and the application UI are untouched.
"""
import argparse,datetime,fcntl,hashlib,json,os,pathlib,signal,subprocess,sys,time,uuid

ROOT=pathlib.Path(__file__).resolve().parents[1]
DEFAULT=ROOT/'operations/backup-schedule.json'
MESSAGES={
 'backup_failed':'La sauvegarde locale a échoué. Vérifier Docker et Supabase local.',
 'timeout':'La sauvegarde locale a dépassé le délai autorisé.',
 'overdue':'Aucune sauvegarde vérifiée depuis plus d’une heure.',
 'low_space':'Espace disque insuffisant pour une nouvelle sauvegarde. Aucune purge effectuée.',
 'integrity':'La dernière sauvegarde vérifiée est absente ou a été modifiée.',
 'interrupted':'La sauvegarde précédente a été interrompue.',
 'recovered':'La sauvegarde locale fonctionne de nouveau.',
 'scheduler_stale':'Le planificateur local ne donne plus de signe de vie.'}

def load_config(path):
    c=json.loads(pathlib.Path(path).read_text())
    for key in ['state_dir','backup_dir','key_dir']:
        p=pathlib.Path(c[key]).resolve()
        if ROOT not in p.parents or not p.name:raise ValueError('Private project directory required')
    if c.get('automatic_deletion') is not False:raise ValueError('Automatic deletion forbidden')
    if c['interval_seconds']<1 or c['timeout_seconds']<1:raise ValueError('Invalid interval')
    return c

def write(path,data):
    path=pathlib.Path(path);path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    tmp=path.with_name(path.name+'.pending-'+uuid.uuid4().hex)
    fd=os.open(str(tmp),os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:json.dump(data,f,indent=2);f.flush();os.fsync(f.fileno())
    os.replace(str(tmp),str(path))

def read(path,default):
    try:return json.loads(pathlib.Path(path).read_text())
    except FileNotFoundError:return default

def event(c,state,kind,code,now):
    directory=pathlib.Path(c['state_dir']);number=state.get('sequence',0)+1;state['sequence']=number
    e={'id':number,'at':now,'kind':kind,'code':code,'message':MESSAGES.get(code,code),'test':c.get('test',False),'last_backup':state.get('last_verified',{}).get('backup')}
    fd=os.open(str(directory/'events.jsonl'),os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600)
    with os.fdopen(fd,'a') as f:f.write(json.dumps(e)+'\n');f.flush();os.fsync(f.fileno())
    # Fixed generic text only: no resource name, credentials, payload or exception.
    if c.get('desktop_notifications') and kind in ('alert','recovery'):
        title=('RECETTE — ' if c.get('test') else '')+'UNIION · Sauvegardes'
        script='on run argv\ndisplay notification (item 1 of argv) with title (item 2 of argv)\nend run'
        try:
            p=subprocess.run(['/usr/bin/osascript','-e',script,e['message'],title],capture_output=True,timeout=8)
            e['desktop_request_accepted']=p.returncode==0
        except (OSError,subprocess.TimeoutExpired):e['desktop_request_accepted']=False
        write(directory/'last-notification.json',e)
    return e

def alert(c,s,code,now):
    active=s.setdefault('active_alerts',{})
    if code not in active:
        active[code]={'since':now};event(c,s,'alert',code,now)

def clear(c,s,codes,now):
    removed=[k for k in codes if s.setdefault('active_alerts',{}).pop(k,None) is not None]
    if removed:event(c,s,'recovery','recovered',now)

def verify_last(s):
    v=s.get('last_verified')
    if not v:return True
    try:
        return all(hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()==h for p,h in v['ciphertext_sha256'].items()) and hashlib.sha256(pathlib.Path(v['key_path']).read_bytes()).hexdigest()==v['key_sha256']
    except OSError:return False

def worker(c):
    import backup_restore as b,security_cut
    b.BACKUPS=pathlib.Path(c['backup_dir']);b.KEYS=pathlib.Path(c['key_dir'])
    if c.get('docker_host'):os.environ['DOCKER_HOST']=c['docker_host'];os.environ.pop('DOCKER_CONTEXT',None)
    result=b.backup();stamp=result['backup'];security_cut.capture(stamp)
    db=b.decrypt(stamp,'database');objects=b.decrypt(stamp,'attachments');manifest=json.loads(db['manifest.json'])
    assert {'tables.dump','infrastructure.dump','infrastructure-data.json','functions.sql','manifest.json'}<=set(db)
    assert set(objects)=={o['path'] for o in manifest['objects']}
    for o in manifest['objects']:
        assert b.digest(objects[o['path']])==o['sha256'] and len(objects[o['path']])==o['size']
    receipt={'backup':stamp,'snapshot_at':datetime.datetime.strptime(stamp,'%Y%m%dT%H%M%SZ').replace(tzinfo=datetime.timezone.utc).timestamp(),
       'completed_at':time.time(),'objects':len(objects),'key_path':str(b.KEYS/(stamp+'.key')),'key_sha256':b.digest((b.KEYS/(stamp+'.key')).read_bytes()),
       'ciphertext_sha256':{str(p):b.digest(p.read_bytes()) for p in (b.BACKUPS/stamp).glob('*.aesgcm')}}
    b.private(b.BACKUPS/stamp/'verified.json',b.canonical(receipt))
    return receipt

def tick(config,force=False):
    c=load_config(config);directory=pathlib.Path(c['state_dir']);directory.mkdir(parents=True,exist_ok=True,mode=0o700);directory.chmod(0o700)
    fd=os.open(str(directory/'runner.lock'),os.O_CREAT|os.O_RDWR,0o600)
    with os.fdopen(fd,'a') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return {'status':'already_running'}
        path=directory/'state.json';s=read(path,{'sequence':0,'active_alerts':{}});now=time.time();s['last_tick']=now
        if s.get('running_since'):alert(c,s,'interrupted',now);s.pop('running_since',None)
        last=s.get('last_verified',{}).get('snapshot_at',0)
        if (last and now-last>c['max_age_seconds']) or (not last and s.get('last_attempt')):alert(c,s,'overdue',now)
        if not verify_last(s):alert(c,s,'integrity',now)
        due=force or not last or now-last>=c['interval_seconds'] or bool(s['active_alerts'])
        if (not force and now-s.get('last_attempt',0)<c['retry_seconds']) or not due:
            write(path,s);return {'status':'waiting','active_alerts':list(s['active_alerts'])}
        import shutil
        if shutil.disk_usage(ROOT).free<c['minimum_free_bytes']:
            alert(c,s,'low_space',now);write(path,s);return {'status':'low_space'}
        s['last_attempt']=now;s['running_since']=now;write(path,s)
        # Keep the flock alive in the worker too if the supervising process dies.
        p=subprocess.Popen([sys.executable,'-B',str(pathlib.Path(__file__).resolve()),'worker','--config',str(pathlib.Path(config).resolve())],stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True,pass_fds=(lock.fileno(),))
        code='backup_failed'
        try:
            output,_=p.communicate(timeout=c['timeout_seconds'])
            result=json.loads(output) if p.returncode==0 else None
        except subprocess.TimeoutExpired:
            os.killpg(p.pid,signal.SIGTERM)
            try:p.communicate(timeout=3)
            except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.communicate()
            result=None;code='timeout'
        except (ValueError,OSError):result=None
        now=time.time();s.pop('running_since',None);s['last_finished']=now
        if result:
            s['last_verified']=result;s['consecutive_failures']=0
            clear(c,s,list(s['active_alerts']),now)
            event(c,s,'success','backup_verified',now)
        else:
            s['consecutive_failures']=s.get('consecutive_failures',0)+1;alert(c,s,code,now)
        write(path,s)
        return {'status':'ok' if result else 'failed','backup':result['backup'] if result else None,'active_alerts':list(s['active_alerts'])}

def monitor(config,ack=False):
    c=load_config(config);directory=pathlib.Path(c['state_dir']);s=read(directory/'state.json',{});now=time.time()
    issues=sorted(s.get('active_alerts',{}))
    if now-s.get('last_tick',0)>c['watchdog_seconds']:issues.append('scheduler_stale')
    if now-s.get('last_verified',{}).get('snapshot_at',0)>c['max_age_seconds'] and 'overdue' not in issues:issues.append('overdue')
    if not verify_last(s) and 'integrity' not in issues:issues.append('integrity')
    cursor=read(directory/'monitor-cursor.json',{'sequence':0,'issues':[]})
    try:events=[json.loads(l) for l in (directory/'events.jsonl').read_text().splitlines()]
    except FileNotFoundError:events=[]
    new=[e for e in events if e['id']>cursor['sequence'] and e['kind'] in ('alert','recovery')]
    status={'issues':sorted(set(issues)),'events':new,'changed':bool(new) or sorted(set(issues))!=cursor['issues'],
      'last_backup':s.get('last_verified',{}).get('backup'),'last_tick':s.get('last_tick'),'automatic_deletion':False}
    if ack:write(directory/'monitor-cursor.json',{'sequence':s.get('sequence',0),'issues':status['issues']})
    return status

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['tick','worker','monitor']);p.add_argument('--config',default=str(DEFAULT));p.add_argument('--ack',action='store_true');p.add_argument('--force',action='store_true');a=p.parse_args()
    try:
        if a.action=='worker':result=worker(load_config(a.config))
        elif a.action=='tick':result=tick(a.config,force=a.force)
        else:result=monitor(a.config,a.ack)
        print(json.dumps(result))
    except Exception:
        # Never leak Docker/SQL errors or secrets into scheduler logs.
        print(json.dumps({'status':'runner_error','action':a.action}));sys.exit(1)

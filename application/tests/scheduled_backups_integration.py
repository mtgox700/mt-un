"""Real launchd timer, fictional local backup data, isolated scheduler state.
No source service is stopped, no original or backup is deleted.
"""
import datetime,fcntl,json,os,pathlib,plistlib,subprocess,sys,time
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'operations'))
import scheduled_backups as s

def main():
    stamp=datetime.datetime.now().strftime('%Y%m%dT%H%M%S');base=ROOT/'.local-backup-scheduler-tests'/stamp;base.mkdir(parents=True,mode=0o700)
    config=base/'config.json';c=s.load_config(s.DEFAULT);c.update({'test':True,'desktop_notifications':False,'interval_seconds':10,'retry_seconds':1,'timeout_seconds':60,'minimum_free_bytes':1,'state_dir':str(base/'state'),'backup_dir':str(base/'backups'),'key_dir':str(base/'keys'),'docker_host':'unix:///private/tmp/uniion-nonexistent-recipe.sock'})
    s.write(config,c);state=base/'state/state.json';label='org.uniion.backups-test-'+stamp.lower();job=base/'job.plist';checks=[]
    def check(n,ok):
        checks.append({'test':n,'ok':bool(ok)})
        if not ok:raise AssertionError(n)
    def wait(test,seconds=45):
        start=time.monotonic()
        while time.monotonic()-start<seconds:
            if test():return
            time.sleep(.3)
        raise AssertionError('Timed out waiting for scheduled event')
    def events():
        try:return [json.loads(l) for l in (base/'state/events.jsonl').read_text().splitlines()]
        except FileNotFoundError:return []
    plist={'Label':label,'ProgramArguments':[sys.executable,'-B',str(ROOT/'operations/scheduled_backups.py'),'tick','--config',str(config)],'RunAtLoad':True,'StartInterval':5,'ThrottleInterval':1,'EnvironmentVariables':{'PATH':'/Users/mt/.docker/bin:/usr/bin:/bin'},'StandardOutPath':str(base/'out.log'),'StandardErrorPath':str(base/'err.log'),'Umask':63}
    job.write_bytes(plistlib.dumps(plist));subprocess.run(['/bin/launchctl','bootstrap','gui/501',str(job)],check=True)
    try:
        wait(lambda:s.read(state,{}).get('consecutive_failures',0)>=2)
        check('automatic_failed_backups_detected',True)
        check('failure_notification_deduplicated',sum(e['code']=='backup_failed' for e in events())==1)
        check('persistent_alert_available',s.monitor(config)['changed'] and 'backup_failed' in s.monitor(config)['issues'])
        notification=s.read(base/'state/last-notification.json',{})
        s.monitor(config,ack=True);check('unchanged_monitor_stays_quiet',not s.monitor(config)['changed'])
        c.pop('docker_host');s.write(config,c)
        wait(lambda:sum(e['kind']=='success' for e in events())>=2,60)
        check('two_timer_triggered_real_backups',True)
        latest=s.read(state,{})
        check('recovery_clears_incident',not latest['active_alerts'])
        check('recovery_notification_recorded',any(e['kind']=='recovery' for e in events()))
        check('archives_and_key_integrity',s.verify_last(latest))
        check('each_success_verified',len(list((base/'backups').glob('*/verified.json')))==2)
    finally:
        subprocess.run(['/bin/launchctl','bootout','gui/501/'+label],check=True)
    # Guards use only this isolated fixture after its timer has been unloaded.
    c['desktop_notifications']=False;s.write(config,c)
    with open(base/'state/runner.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        check('concurrent_runner_refused',s.tick(config)['status']=='already_running')
    latest=s.read(state,{});saved=json.loads(json.dumps(latest))
    latest['last_tick']=time.time()-2000;latest['last_verified']['snapshot_at']=time.time()-7200;s.write(state,latest)
    check('stopped_scheduler_detected','scheduler_stale' in s.monitor(config)['issues'])
    check('hourly_age_breach_detected','overdue' in s.monitor(config)['issues'])
    latest['last_verified']['key_sha256']='0'*64;s.write(state,latest)
    check('key_integrity_change_detected','integrity' in s.monitor(config)['issues'])
    s.write(state,saved);latest=s.read(state,{});first=next(iter(latest['last_verified']['ciphertext_sha256']));latest['last_verified']['ciphertext_sha256'][first]='0'*64;s.write(state,latest)
    check('archive_integrity_change_detected','integrity' in s.monitor(config)['issues'])
    before={str(p):p.stat().st_size for p in (base/'backups').rglob('*') if p.is_file()}
    s.write(state,{**saved,'last_attempt':0,'running_since':time.time()-100});c['minimum_free_bytes']=10**30;s.write(config,c)
    check('low_disk_space_blocks_without_purge',s.tick(config)['status']=='low_space')
    check('interrupted_previous_run_detected','interrupted' in s.read(state,{})['active_alerts'])
    check('backups_unchanged_after_space_failure',before=={str(p):p.stat().st_size for p in (base/'backups').rglob('*') if p.is_file()})
    c['minimum_free_bytes']=1;c['timeout_seconds']=1;s.write(config,c)
    temp=s.read(state,{});temp['last_attempt']=0;s.write(state,temp)
    check('hung_worker_bounded',s.tick(config)['status']=='failed' and 'timeout' in s.read(state,{})['active_alerts'])
    check('no_backup_file_removed',all(pathlib.Path(p).exists() for p in before))
    check('private_state_permissions',(state.stat().st_mode&0o777)==0o600)
    result={'passed':True,'checks':checks,'fixture':str(base),'timer_unloaded':True,'backups_deleted':0,'notification_limit':'Persistent alerts tested; desktop notifications disabled for isolated failure test'}
    report=ROOT/'preuves/S01-identite';report.mkdir(exist_ok=True);s.write(report/'scheduler.json',result)
    print(json.dumps({'passed':True,'checks':len(checks),'fixture':str(base)}))
if __name__=='__main__':main()

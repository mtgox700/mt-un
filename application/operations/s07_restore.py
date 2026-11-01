"""Fresh encrypted snapshot and offline isolated restore, including S07."""
import backup_restore as b,json,sys
b.REPORT=b.ROOT/'preuves/S07-F'/('restore-final140' if '--final' in sys.argv else '.');b.REPORT.mkdir(exist_ok=True)
r=b.backup();restored=b.restore(r['backup'])
(b.REPORT/'backup.json').write_text(json.dumps(r,indent=2))
print(json.dumps({'backup':r['backup'],'checks':len(restored['checks']),'container':restored['container']}))

import backup_restore as b,json
from pathlib import Path
b.REPORT=b.ROOT/'preuves/S05-finalisation'
r=b.backup(); restored=b.restore(r['backup']); print(json.dumps({'backup':r['backup'],'checks':len(restored['checks']),'container':restored['container']}))

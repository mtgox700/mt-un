import backup_restore as b,json
b.REPORT=b.ROOT/'preuves/S06-finalisation'
r=b.backup();restored=b.restore(r['backup']);print(json.dumps({'backup':r['backup'],'checks':len(restored['checks']),'container':restored['container']}))

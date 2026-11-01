"""Replay A1/A2/markers into NEW final proof directories, never historical outputs."""
from pathlib import Path
import subprocess,sys,json
root=Path(__file__).resolve().parents[1]
proof=root/'preuves/S09-A-final'
results=[]
for filename,old,new in [('s09_consent_integration.py','preuves/S09-A-consentement','preuves/S09-A-final/a1'),('s09_audio_integration.py','preuves/S09-A2-audio','preuves/S09-A-final/a2'),('s09_markers_integration.py',None,None)]:
    script=root/'tests'/filename
    source=script.read_text()
    if old:source=source.replace(old,new)
    folder=proof/({'s09_consent_integration.py':'a1','s09_audio_integration.py':'a2','s09_markers_integration.py':'markers'}[filename])
    folder.mkdir(parents=True,exist_ok=True)
    command='__file__='+repr(str(script))+'\n'+source
    result=subprocess.run([sys.executable,'-B','-c',command],cwd=root,capture_output=True,text=True)
    (folder/'run.log').write_text(result.stdout+result.stderr)
    if result.returncode:raise SystemExit(filename+' failed; see its new local proof log')
    report=json.loads((folder/'integration.json').read_text());results.append({'suite':filename,'count':report['count'],'passed':report['passed']})
    print(filename,report['count'],'OK',flush=True)
(proof/'acceptance.json').write_text(json.dumps({'passed':True,'suites':results,'count':sum(x['count'] for x in results)},indent=2))

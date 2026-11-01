"""Real local audio marker revisions; all data fictive, historical proofs untouched."""
from pathlib import Path
source=Path(__file__).with_name('s09_audio_integration.py').read_text().split("check('listen_exact_bytes'")[0].replace('preuves/S09-A2-audio','preuves/S09-A-final/markers')
exec(compile(source,__file__,'exec'))
def get(c=None):return business(c or x,'audio_markers_get',{'id':rid,'audio':aid})
def save(items,version=0,c=None,**kw):return business(c or x,'audio_markers_save',{'id':rid,'audio':aid,'version':version,'markers':items,**kw})
m={'id':str(uuid.uuid4()),'timeMs':50,'kind':'decision','note':'Décision entièrement fictive'}
check('duration_verified_100ms',get()[1]['durationMs']==100)
check('initial_empty',get()[1]['version']==0 and get()[1]['markers']==[])
check('manager_without_audio_denied',get(y)[0]==403)
check('first_revision_saved',save([m])[1]['version']==1)
check('separate_read_same_marker',get()[1]['markers']==[m])
check('stale_version_denied',save([m])[0]==403)
for label,markers in [('past_end',[{**m,'timeMs':101}]),('negative',[{**m,'timeMs':-1}]),('fraction',[{**m,'timeMs':0.5}]),('bool_time',[{**m,'timeMs':True}]),('extra',[{**m,'actor':a['id']}]),('missing',[{'id':m['id']}]),('duplicate',[m,m]),('kind',[{**m,'kind':'execute'}]),('note_limit',[{**m,'note':'x'*1001}]),('null_note',[{**m,'note':None}]),('count',[m]*101)]:
 check(label+'_refused',save(markers,version=1)[0]==403)
check('bad_version_refused',save([m],version=True)[0]==403)
check('extra_parent_refused',save([m],version=1,actor=a['id'])[0]==403)
check('invalid_writes_leave_version',get()[1]['version']==1)
end={**m,'timeMs':100,'note':'Dernier repère fictif'}
check('valid_update',save([end],version=1)[1]['version']==2)
check('clear_new_revision',save([],version=2)[1]['version']==3)
check('previous_versions_retained',sql(f"select count(*) from uniion_private.meeting_audio_markers where audio_id='{aid}'")=='3')
check('markers_do_not_change_consent',read()[1]['current'] is True)
check('private_marker_table',sql("select not has_table_privilege('authenticated','uniion_private.meeting_audio_markers','select')")=='t')
try:
 api.request('/rest/v1/rpc/uniion_meeting_audio_duration',x.state()['access_token'],{'p_id':aid,'p_sha':hashlib.sha256(raw).hexdigest(),'p_duration_ms':999});denied=False
except AccessDenied:denied=True
check('forged_duration_denied',denied)
check('cross_org_marker_refused',business(x,'audio_markers_get',{'id':rid,'audio':aid},foreign)[0]==403)
st,other,_=business(x,'create',{'data':{'title':'Autre réunion fictive'}});check('other_meeting_created',st==200)
check('cross_meeting_refused',business(x,'audio_markers_get',{'id':other['id'],'audio':aid})[0]==403)
check('readonly_audio_grant',grant(a['id'],version=1,write=False)[0]==200)
check('readonly_marker_get',get()[0]==200)
check('readonly_marker_save_denied',save([m],version=3)[0]==403)
check('write_grant_restored',grant(a['id'],version=2)[0]==200)
check('source_note_saved',save([m],version=3)[0]==200)
app=create_app(Config.load({'UNIION_ENV':'development-local','UNIION_SUPABASE_URL':api.url}),api)
x=Client();check('restart_login',x.login(a)[0]==200);check('restart_mfa',verify(x,f['authorFactor'],f['authorSecret'])[0][0]==200)
check('restart_marker_persistence',get()[1]['markers']==[m] and get()[1]['version']==4)
# Two concurrent requests with the same expected version: exactly one may commit.
from concurrent.futures import ThreadPoolExecutor
token=x.state()['access_token']
def concurrent_save(note):
 try:
  api.request('/rest/v1/rpc/uniion_meeting_audio_markers',token,{'p_org':org,'p_meeting':rid,'p_action':'save','p_payload':{'audio':aid,'version':4,'markers':[{**m,'note':note}]}})
  return True
 except AccessDenied:return False
with ThreadPoolExecutor(max_workers=2) as pool:outcomes=list(pool.map(concurrent_save,['Note fictive A','Note fictive B']))
check('concurrent_single_winner',sum(outcomes)==1)
check('concurrent_version_not_overwritten',get()[1]['version']==5)
check('withdrawal_saved',write(x,version=1,accepted=False)[0]==200)
check('withdrawal_denies_marker_read',get()[0]==403)
check('withdrawal_denies_marker_write',save([m],version=5)[0]==403)
check('no_content_in_marker_audit',sql(f"select bool_and(not(details ? 'markers') and not(details ? 'note')) from public.uniion_security_events where organization_id='{org}' and event like 'meeting.audio.markers.%'")=='t')
(out/'integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))

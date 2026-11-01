"""D: real transcription -> source-restricted PV -> reviewed published copy."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
(root/'preuves/S09-D').mkdir(exist_ok=True)
shutil.copyfile(root/'preuves/S09-C/parole-fictive.wav',root/'preuves/S09-D/parole-fictive.wav')
source=Path(__file__).with_name('s09_transcription_integration.py').read_text().split('# New two-part recording')[0].replace('preuves/S09-C','preuves/S09-D')
exec(compile(source,__file__,'exec'))
marker={'id':str(uuid.uuid4()),'timeMs':1000,'kind':'decision','note':'Point fictif : dossier vendredi, formulation à vérifier.'}
check('marker_saved',call(x,'audio_markers_save',{'id':rid,'audio':aid,'version':0,'markers':[marker]})[0]==200)
def pv(action,c=x):return business(c,'pv_'+action,{'id':rid,'audio':aid})
check('pv_absent',pv('status')[1]['absent'])
st,d,_=pv('prepare');check('pv_prepared',st==200);pid=d['id']
check('separate_resource',pid!=rid and d['meetingPV'])
check('transcript_and_marker', 'vendredi' in d['transcript'] and marker['note'] in d['minutes'])
check('readable_times_and_empty_agenda','00:00:00.000' in d['minutes'] and 'Ordre du jour non renseigné.' in d['minutes'] and 'Décision' in d['minutes'])
check('idempotent_pv',pv('prepare')[1]['id']==pid)
check('consent_not_invalidated',read()[1]['current'])
check('source_version_unchanged',sql(f"select version from public.uniion_resources where id='{rid}'")=='1')
check('snapshot_marker_version',sql(f"select source_snapshot->0->>'markerVersion' from uniion_private.meeting_minutes where resource_id='{pid}'")=='1')
def get(c=x):return business(c,'get',{'id':pid})
check('reviewer_without_audio_cannot_read',get(y)[0]==403)
check('inventory_requires_publish',business(y,'pv_publications',{'id':rid})[0]==403)
# Grants are explicit in this isolated fictive organization, never real tenants.
sql(f"insert into public.uniion_authorities values('{org}','{a['id']}','rights',false),('{org}','{a['id']}','content_review',false),('{org}','{a['id']}','content_publish',false),('{org}','{b['id']}','content_review',false),('{org}','{b['id']}','content_publish',false)")
check('reviewer_audio_granted',call(x,'audio_grant',{'id':rid,'user':b['id'],'version':0,'read':True,'write':False,'download':False})[0]==200)
check('reviewer_reads_all_sources',get(y)[0]==200)
from uniion.adapters.ai_context_service import ContextService
ctx=ContextService(lambda path,body:api.request(path,x.state()['access_token'],body))
source=ctx.load(org,[{'kind':'reunions','id':pid}])[0]
check('s08_context_has_transcript_and_markers',any('vendredi' in p['text'] for p in source['passages'] if p['location']=='transcript') and any(marker['note'] in p['text'] for p in source['passages'] if p['location']=='markers'))
check('authorized_direct_resource',len(api.request('/rest/v1/uniion_resources?select=id&id=eq.'+pid,x.state()['access_token']))==1)
fields=('title','type','date','ordre','markers','transcript','minutes','participants')
data={k:d[k] for k in fields if k in d}
check('source_snapshot_edit_refused',business(x,'save',{'id':pid,'version':1,'data':{**data,'transcript':'source falsifiée'}})[0]==403)
text='Procès-verbal fictif relu : préparer le dossier vendredi. La date du prochain rendez-vous reste à confirmer.'
st,d2,_=business(x,'save',{'id':pid,'version':1,'data':{**data,'minutes':text}});check('correction_version',st==200 and d2['version']==2)
check('stale_edit_refused',business(x,'save',{'id':pid,'version':1,'data':{**data,'minutes':'ancienne saisie'}})[0]==403)
def pub(action,c=x,version=2,**kw):return business(c,'publication_'+action,{'id':pid,'version':version,**kw})
check('self_review_denied',pub('review',recipients=[a['email']])[0]==403)
check('unreviewed_publish_denied',pub('publish')[0]==403)
check('other_org_denied',business(x,'get',{'id':pid},foreign)[0]==403)
check('second_actor_review',pub('review',y,recipients=[a['email']])[0]==200)
check('publish_version',pub('publish')[0]==200)
check('publish_idempotent',pub('publish')[0]==200)
feed=business(x,'publication_feed',{})[1]['rows'];check('published_text_only',len(feed)==1 and set(feed[0]['body'])=={'title','minutes'} and feed[0]['body']['minutes']==text)
check('no_download',feed[0]['download'] is False)
check('nonrecipient_no_feed',business(y,'publication_feed',{})[1]['rows']==[])
st,d3,_=business(x,'save',{'id':pid,'version':2,'data':{**data,'minutes':text+' Correction complémentaire.'}});check('edit_new_version',st==200 and d3['version']==3 and d3['status']=='Brouillon')
check('new_version_needs_review',pub('publish',version=3)[0]==403)
check('old_publication_unchanged',business(x,'publication_feed',{})[1]['rows'][0]['body']['minutes']==text)
long_text='Texte fictif relu. '*6000
st,longrow,_=business(x,'save',{'id':pid,'version':3,'data':{**data,'minutes':long_text}})
check('long_correction_not_truncated',st==200 and longrow['minutes']==long_text and get()[1]['minutes']==long_text)
check('revoke_author_audio',grant(a['id'],version=1,read=False,write=False)[0]==200)
check('ordinary_derivative_hidden',get()[0]==403)
check('s08_context_denied_after_revoke',refused(lambda:ctx.load(org,[{'kind':'reunions','id':pid}])))
check('direct_resource_hidden',api.request('/rest/v1/uniion_resources?select=id&id=eq.'+pid,x.state()['access_token'])==[])
check('direct_versions_hidden',api.request('/rest/v1/uniion_resource_versions?select=version&resource_id=eq.'+pid,x.state()['access_token'])==[])
feed=business(x,'publication_feed',{})[1]['rows'];check('approved_copy_independent',feed[0]['body']['minutes']==text and feed[0]['source'] is None)
check('approved_copy_no_audio',listen()[0]==403)
check('consent_withdrawn',write(version=1,accepted=False)[0]==200)
check('reviewer_draft_hidden_after_withdrawal',get(y)[0]==403)
check('approved_copy_survives_withdrawal',len(business(x,'publication_feed',{})[1]['rows'])==1)
inventory=business(y,'pv_publications',{'id':rid})[1]['rows'];check('inventory_after_withdrawal',inventory==[{'id':pid,'version':2}])
check('reviewer_revokes_old_version_after_withdrawal',pub('revoke',y)[0]==200)
check('revoked_copy_hidden',business(x,'publication_feed',{})[1]['rows']==[])
check('private_provenance',sql("select not has_table_privilege('authenticated','uniion_private.meeting_minutes','select')")=='t')
# Separate current recording snapshot: adding a segment must not reuse an older single-part PV.
# Restore explicit test rights and create a new consent/audio generation.
check('restore_test_audio_grant',grant(a['id'],version=2)[0]==200)
check('new_consent',write(version=2,accepted=True)[0]==200)
recording=str(uuid.uuid4());newpayload={**payload,'request_id':recording,'consentVersion':3}
st,r,_=upload(c=x,p=newpayload);check('new_audio',st==200);aid=r['id']
check('new_sequence_first',call(x,'audio_sequence',{'id':rid,'audio':aid,'recording':recording,'position':0})[0]==200)
check('new_transcription_first',tx('start')[0]==200 and process_one(api,wt))
first_pv=pv('prepare')[1];check('first_snapshot_ready',first_pv.get('meetingPV') is True)
st,r,_=upload(c=x,p={**newpayload,'request_id':str(uuid.uuid4())});check('new_sequence_audio_second',st==200);second=r['id']
check('new_sequence_second',call(x,'audio_sequence',{'id':rid,'audio':second,'recording':recording,'position':1})[0]==200)
check('new_set_no_stale_pv',pv('status')[1].get('absent') is True)
check('new_transcription_set',tx('start')[1]['total']==2 and process_one(api,wt))
second_pv=pv('prepare')[1];check('new_set_distinct_pv',second_pv['id']!=first_pv['id'])
check('all_parts_in_pv',second_pv['transcript'].count('vendredi')==2)
check('all_sources_snapshotted',sql(f"select jsonb_array_length(source_snapshot) from uniion_private.meeting_minutes where resource_id='{second_pv['id']}'")=='2')
(out/'minutes-integration.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2))
(out/'pv-redige.json').write_text(json.dumps({'title':d['title'],'version':2,'minutes':text},ensure_ascii=False,indent=2))
print({'passed':True,'count':len(checks)})

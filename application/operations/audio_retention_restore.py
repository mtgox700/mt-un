"""Reconcile a stale isolated restore with a fresh restrictive journal.

Never targets the working database. The original encrypted backup is retained.
No admission to production: offline devices and independent backup retention
remain explicitly recorded. Export while the source is quiescent for real use.
"""
import json,re
import backup_restore as b
import revocation_journal
TABLES=('audio_retention_batches','audio_retention_items','audio_tombstones','meeting_consents','meeting_audio_grants','business_publications')
def journal():
    # One SQL statement / MVCC snapshot for the complete restriction journal.
    pieces=[]
    for table in TABLES:
        fields='t.*' if table!='business_publications' else 'id,revoked_at'
        pieces.append(b.literal(table)+",(select coalesce(jsonb_agg(t),'[]') from (select "+fields+' from uniion_private.'+table+' t)t)')
    for table in ('uniion_memberships','uniion_resource_grants','uniion_permissions','uniion_authorities','uniion_module_access'):
        pieces.append(b.literal(table)+",(select coalesce(jsonb_agg(t),'[]') from public."+table+' t)')
    # Access controls (R36): suspensions, privileged roles, workers, trusted factors, shares.
    pieces += revocation_journal.journal_pieces()
    return json.loads(b.sql('select jsonb_build_object('+','.join(pieces)+')'))

def reconcile(result,data):
    c=result['container'];db=result['database'];helper=result['file_container']
    if not re.fullmatch(r'uniion-restore-[a-f0-9]{8}',c) or db!='restored' or helper!=c+'-files':raise ValueError('Isolated target required')
    if b.run(['docker','inspect','-f','{{.HostConfig.NetworkMode}}',c]).decode().strip()!='none':raise ValueError('Offline target required')
    def sql(q):return b.sql(q,c,db)
    # Import only metadata into temporary tables; never restore business text from journal.
    q=['begin']
    for table in TABLES:
        if table=='business_publications':
            q.append('create temporary table j_business_publications(id uuid,revoked_at timestamptz)')
        else:q.append('create temporary table j_'+table+' (like uniion_private.'+table+')')
        q.append('insert into j_'+table+' select * from jsonb_populate_recordset(null::j_'+table+','+b.literal(json.dumps(data[table]))+'::jsonb)')
    q += ["insert into uniion_private.audio_retention_batches select j.* from j_audio_retention_batches j where exists(select 1 from public.uniion_resources r where r.id=j.meeting_id) on conflict(id) do update set state=excluded.state,approved_by=excluded.approved_by,approved_at=excluded.approved_at,finished_at=excluded.finished_at,inventory=excluded.inventory",
          "insert into uniion_private.audio_retention_items select j.* from j_audio_retention_items j where exists(select 1 from uniion_private.meeting_audio a where a.id=j.audio_id) on conflict(audio_id) do nothing",
          "insert into uniion_private.audio_tombstones select j.* from j_audio_tombstones j where exists(select 1 from uniion_private.meeting_audio a where a.id=j.audio_id) on conflict(audio_id) do nothing",
          "update uniion_private.meeting_audio set status='blocked' where id in(select audio_id from uniion_private.audio_tombstones)",
          "update uniion_private.meeting_audio_originals set status='blocked' where audio_id in(select audio_id from uniion_private.audio_tombstones)",
          "delete from uniion_private.meeting_audio_chunks where audio_id in(select audio_id from uniion_private.audio_tombstones)",
          "delete from uniion_private.meeting_audio_original_parts where audio_id in(select audio_id from uniion_private.audio_tombstones)",
          "update uniion_private.transcription_jobs j set state='cancelled',lease=null,worker=null,error='audio_deleted' where state<>'done' and exists(select 1 from uniion_private.audio_tombstones t where t.audio_id=any(j.source_ids))",
          # A newer consent never legitimizes old restored bytes.
          "update uniion_private.meeting_consents c set accepted=false where not exists(select 1 from j_meeting_consents j where j.organization_id=c.organization_id and j.meeting_id=c.meeting_id and j.version=c.version and j.accepted)",
          "update uniion_private.meeting_audio_grants g set can_read=false,can_write=false,can_download=false where not exists(select 1 from j_meeting_audio_grants j where j.organization_id=g.organization_id and j.meeting_id=g.meeting_id and j.user_id=g.user_id and j.can_read and (not g.can_write or j.can_write) and (not g.can_download or j.can_download))",
          "update uniion_private.business_publications p set revoked_at=coalesce(p.revoked_at,now()) where not exists(select 1 from j_business_publications j where j.id=p.id and j.revoked_at is null)"]
    # Do not reintroduce removed memberships or grants from the stale backup.
    for table,keys in [('uniion_memberships',['organization_id','user_id']),('uniion_resource_grants',['organization_id','resource_id','user_id']),('uniion_permissions',['organization_id','user_id','module','action']),('uniion_authorities',['organization_id','user_id','authority']),('uniion_module_access',['organization_id','module'])]:
        # Exact-row intersection is deliberately conservative: changed rights must
        # be reissued, not silently widened during restoration.
        rows=data[table]
        q.append('delete from public.'+table+' t where not exists(select 1 from jsonb_array_elements('+b.literal(json.dumps(rows))+"::jsonb) j where j=to_jsonb(t))")
    q += revocation_journal.statements(data)
    q.append('commit');sql(';\n'.join(q)+';')
    objects=json.loads(sql("select coalesce(json_agg(o),'[]') from storage.objects o where bucket_id='uniion-private' and name in(select a.path from uniion_private.meeting_audio a join uniion_private.audio_tombstones t on t.audio_id=a.id)"))
    for o in objects:
        path='stub/stub/uniion-private/'+o['name']+'/'+o['version']
        if not re.fullmatch(r'[a-zA-Z0-9_./-]+',path) or any(x in ('..','') for x in path.split('/')):raise ValueError('Unsafe path')
        # Explicit replay of an already approved, identified deletion, isolated volume only.
        b.run(['docker','exec',helper,'rm','-f','--','/mnt/'+path])
    sql("begin; set local storage.allow_delete_query='true'; delete from storage.objects where bucket_id='uniion-private' and name in(select a.path from uniion_private.meeting_audio a join uniion_private.audio_tombstones t on t.audio_id=a.id); commit")
    result['reconciliation']={'applied':True,'deleted_restored_objects':len(objects),'journal_sha256':b.digest(b.canonical(data)),'offline_devices':'unconfirmed','production_admission':False}
    return result['reconciliation']

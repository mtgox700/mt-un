"""Encrypted, recent security checkpoint and conservative reconciliation.

This local checkpoint is not yet an independent off-site revocation journal.
Changed grants are closed, never expanded. No business data is deleted.
"""
import datetime,json,secrets
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import backup_restore as b

SPECS={
 'uniion_organizations':(['id'],'active=false'),
 'uniion_memberships':(['organization_id','user_id'],'revoked_at=now()'),
 'uniion_module_access':(['organization_id','module'],'authorized=false,enabled=false'),
 'uniion_resource_grants':(['organization_id','resource_id','user_id'],'revoked_at=now()'),
 'uniion_shares':(['id'],'revoked_at=coalesce(revoked_at,now())'),
 'uniion_directory_grants':(['organization_id','target_id','grantee','listed_user'],'revoked_at=coalesce(revoked_at,now())')}

def capture(backup_id):
    tables=list(SPECS)+['uniion_permissions','uniion_authorities','uniion_partners']
    # One database statement = one consistent snapshot of all security controls.
    pairs=[]
    for t in tables:pairs += [b.literal(t),"(select coalesce(json_agg(x),'[]'::json) from public."+t+' x)']
    for name,q in {
      'resources':'select id,organization_id,external_share_allowed from public.uniion_resources',
      'attachments':'select id,ready,scan_status,scan_generation,sha256 from public.uniion_attachments',
      'workers':'select user_id from uniion_private.scan_workers',
      'mfa':"select id,user_id,secret,status,factor_type from auth.mfa_factors where user_id in (select user_id from public.uniion_memberships union select user_id from uniion_private.scan_workers union select user_id from uniion_private.platform_operators union select user_id from uniion_private.mfa_requirements union select user_id from uniion_private.mfa_recovery_requests union select user_id from uniion_private.lost_factor_jobs)",
      'mfa_requirements':'select user_id,required from uniion_private.mfa_requirements',
      'platform_operators':'select user_id,active from uniion_private.platform_operators',
      'trusted_mfa':'select factor_id,user_id,authorized_at,valid_until from uniion_private.trusted_mfa_factors',
      'users':"select id,email,encrypted_password,banned_until,deleted_at from auth.users where id in (select user_id from public.uniion_memberships union select user_id from uniion_private.scan_workers union select user_id from uniion_private.platform_operators union select user_id from uniion_private.mfa_requirements union select user_id from uniion_private.mfa_recovery_requests union select user_id from uniion_private.lost_factor_jobs)"
    }.items():pairs += [b.literal(name),"(select coalesce(json_agg(x),'[]'::json) from ("+q+') x)']
    state=json.loads(b.sql('select json_build_object('+','.join(pairs)+')'))
    state['at']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    nonce=secrets.token_bytes(12);key=(b.KEYS/(backup_id+'.key')).read_bytes()
    b.private(b.BACKUPS/backup_id/'security-cut.aesgcm',nonce+AESGCM(key).encrypt(nonce,b.canonical(state),(backup_id+'/security-cut').encode()))
    return state['at']

def reconcile(result,max_age_seconds=600):
    # Refuse missing, stale or tampered checkpoint, and refuse any non-drill target.
    c=result['container'];info=json.loads(b.run(['docker','inspect',c]))[0]
    if not info['Config'].get('Labels',{}).get('uniion.restore-drill')=='true' or info['HostConfig']['NetworkMode']!='none':raise RuntimeError('Isolated restoration target required')
    stamp=result['backup'];raw=(b.BACKUPS/stamp/'security-cut.aesgcm').read_bytes();key=(b.KEYS/(stamp+'.key')).read_bytes()
    state=json.loads(AESGCM(key).decrypt(raw[:12],raw[12:],(stamp+'/security-cut').encode()))
    age=(datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(state['at'])).total_seconds()
    if not 0<=age<=max_age_seconds:raise RuntimeError('Security checkpoint is stale: restoration must remain closed')
    def rows(q):return json.loads(b.sql("select coalesce(json_agg(x),'[]'::json) from ("+q+')x',c,'restored'))
    def where(row,keys):return ' AND '.join(k+'='+b.literal(row[k]) for k in keys)
    def key(row,keys):return tuple(row[k] for k in keys)
    changes=[]
    for t,(keys,update) in SPECS.items():
        current={key(r,keys):r for r in state[t]}
        for r in rows('select * from public.'+t):
            if current.get(key(r,keys))!=r:changes.append('UPDATE public.'+t+' SET '+update+' WHERE '+where(r,keys))
    # Removed or changed business permissions/authorities close that membership.
    for t,keys in [('uniion_permissions',['organization_id','user_id','module','permission']),('uniion_authorities',['organization_id','user_id','permission'])]:
        current={key(r,keys):r for r in state[t]}
        for r in rows('select * from public.'+t):
            if current.get(key(r,keys))!=r:changes.append('UPDATE public.uniion_memberships SET revoked_at=now() WHERE '+where(r,['organization_id','user_id']))
    current={key(r,['source_id','target_id']) for r in state['uniion_partners']}
    for r in rows('select * from public.uniion_partners'):
        if key(r,['source_id','target_id']) not in current:changes.append('UPDATE public.uniion_shares SET revoked_at=coalesce(revoked_at,now()) WHERE '+where(r,['source_id','target_id']))
    current={r['id']:r for r in state['resources']}
    for r in rows('select id,organization_id,external_share_allowed from public.uniion_resources'):
        if current.get(r['id'])!=r:
            changes += ['UPDATE public.uniion_resources SET external_share_allowed=false WHERE id='+b.literal(r['id']),
                        'UPDATE public.uniion_resource_grants SET revoked_at=now() WHERE resource_id='+b.literal(r['id'])]
    current={r['id']:r for r in state['attachments']}
    for r in rows('select id,ready,scan_status,scan_generation,sha256 from public.uniion_attachments'):
        if current.get(r['id'])!=r:changes.append("UPDATE public.uniion_attachments SET ready=false,scan_status='error',scan_reason='Revalidation requise après restauration' WHERE id="+b.literal(r['id']))
    current={r['id']:r for r in state['users']}
    for r in rows('select id,email,encrypted_password,banned_until,deleted_at from auth.users'):
        if current.get(r['id'])!=r:
            changes += ["UPDATE auth.users SET banned_until='9999-12-31' WHERE id="+b.literal(r['id']),
                        'UPDATE public.uniion_memberships SET revoked_at=now() WHERE user_id='+b.literal(r['id'])]
    if sorted(state['workers'],key=str)!=sorted(rows('select user_id from uniion_private.scan_workers'),key=str):
        raise RuntimeError('Scanner identities changed: explicit reconciliation required; stay isolated')
    # Do not resurrect an authenticator removed/replaced after the snapshot.
    current={r['id']:r for r in state['mfa']}
    for r in rows('select id,user_id,secret,status,factor_type from auth.mfa_factors'):
        if current.get(r['id'])!=r:
            changes.append("UPDATE auth.users SET banned_until='9999-12-31' WHERE id="+b.literal(r['user_id']))
    current_operators={r['user_id']:r for r in state['platform_operators']}
    for r in rows('select user_id,active from uniion_private.platform_operators'):
        if current_operators.get(r['user_id'])!=r:
            changes.append('UPDATE uniion_private.platform_operators SET active=false WHERE user_id='+b.literal(r['user_id']))
    current_trust={r['factor_id']:r for r in state['trusted_mfa']}
    for r in rows('select factor_id,user_id,authorized_at,valid_until from uniion_private.trusted_mfa_factors'):
        if current_trust.get(r['factor_id'])!=r:
            changes.append("UPDATE auth.users SET banned_until='9999-12-31' WHERE id="+b.literal(r['user_id']))
    old_required={r['user_id']:r['required'] for r in rows('select user_id,required from uniion_private.mfa_requirements')}
    for r in state['mfa_requirements']:
        if r['required'] and not old_required.get(r['user_id']):
            changes.append('INSERT INTO uniion_private.mfa_requirements VALUES('+b.literal(r['user_id'])+',true) ON CONFLICT(user_id) DO UPDATE SET required=true')
    # Close every drill-issued session before possible admission; never replay one.
    b.sql('BEGIN;'+ ';'.join(changes+["UPDATE auth.sessions SET not_after=now()", "UPDATE uniion_private.invitations SET revoked_at=coalesce(revoked_at,now()) WHERE accepted_at IS NULL", "UPDATE uniion_private.mfa_recovery_requests SET expires_at=now() WHERE approved_at IS NULL", "UPDATE uniion_private.lost_factor_jobs SET state='cancelled' WHERE state<>'enrolled'"] )+';COMMIT;',c,'restored')
    return {'checkpoint_at':state['at'],'age_seconds':round(age,3),'restrictive_updates':len(changes),'mode':'deny changes; never grant new access','production_admission':False}

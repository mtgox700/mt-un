"""Access controls replayed from a fresh journal onto an isolated restore (R36).

Restrictive only: a row the journal no longer shows as granted is closed in the
restore; nothing absent from the restore is granted from the journal, except
suspensions and MFA requirements, which only remove access.
Standard library only, so the schema CI can test it on a migrated database.
"""
import json

# Journal queries, read in the same snapshot as the audio retention journal.
QUERIES={
 'membership_suspensions':'select organization_id,user_id,suspended from uniion_private.membership_suspensions',
 'super_admins':'select user_id,active from uniion_private.super_admins',
 'platform_operators':'select user_id,active from uniion_private.platform_operators',
 'trusted_mfa_factors':'select factor_id,user_id,valid_until from uniion_private.trusted_mfa_factors',
 'mfa_requirements':'select user_id,required from uniion_private.mfa_requirements',
 'scan_workers':'select user_id from uniion_private.scan_workers',
 'transcription_workers':'select user_id from uniion_private.transcription_workers',
 'uniion_shares':'select id,revoked_at,expires_at from public.uniion_shares'}

def literal(value):return "'"+str(value).replace("'","''")+"'"

def journal_pieces():
    """jsonb_build_object arguments for the journal query."""
    pieces=[]
    for name,query in QUERIES.items():
        pieces.append(literal(name)+",(select coalesce(jsonb_agg(t),'[]') from ("+query+')t)')
    return pieces

def statements(data):
    """SQL applied inside the reconciliation transaction of the restored database."""
    def rows(name,columns):
        return 'jsonb_to_recordset('+literal(json.dumps(data[name]))+'::jsonb) j('+columns+')'
    return [
     # Suspensions and MFA requirements recorded since the backup are applied.
     'update uniion_private.membership_suspensions s set suspended=true from '+rows('membership_suspensions','organization_id uuid,user_id uuid,suspended boolean')+' where j.suspended and s.organization_id=j.organization_id and s.user_id=j.user_id',
     'insert into uniion_private.membership_suspensions(organization_id,user_id,suspended) select j.organization_id,j.user_id,true from '+rows('membership_suspensions','organization_id uuid,user_id uuid,suspended boolean')+' where j.suspended and not exists(select 1 from uniion_private.membership_suspensions s where s.organization_id=j.organization_id and s.user_id=j.user_id)',
     'update uniion_private.mfa_requirements m set required=true from '+rows('mfa_requirements','user_id uuid,required boolean')+' where j.required and m.user_id=j.user_id',
     'insert into uniion_private.mfa_requirements(user_id,required) select j.user_id,true from '+rows('mfa_requirements','user_id uuid,required boolean')+' where j.required and not exists(select 1 from uniion_private.mfa_requirements m where m.user_id=j.user_id)',
     # Privileged roles: active only if still active in the journal.
     'update uniion_private.super_admins a set active=false where a.active and not exists(select 1 from '+rows('super_admins','user_id uuid,active boolean')+' where j.user_id=a.user_id and j.active)',
     'update uniion_private.platform_operators a set active=false where a.active and not exists(select 1 from '+rows('platform_operators','user_id uuid,active boolean')+' where j.user_id=a.user_id and j.active)',
     # Technical identities and trusted factors: kept only if identical in the journal.
     'delete from uniion_private.scan_workers w where not exists(select 1 from '+rows('scan_workers','user_id uuid')+' where j.user_id=w.user_id)',
     'delete from uniion_private.transcription_workers w where not exists(select 1 from '+rows('transcription_workers','user_id uuid')+' where j.user_id=w.user_id)',
     'delete from uniion_private.trusted_mfa_factors t where not exists(select 1 from '+rows('trusted_mfa_factors','factor_id uuid,user_id uuid,valid_until timestamptz')+' where j.factor_id=t.factor_id and j.user_id=t.user_id and j.valid_until is not distinct from t.valid_until)',
     # Shares: open only if still open in the journal, with the same or an earlier expiry.
     'update public.uniion_shares s set revoked_at=coalesce(s.revoked_at,now()) where s.revoked_at is null and not exists(select 1 from '+rows('uniion_shares','id uuid,revoked_at timestamptz,expires_at timestamptz')+' where j.id=s.id and j.revoked_at is null)',
     'update public.uniion_shares s set expires_at=least(s.expires_at,j.expires_at) from '+rows('uniion_shares','id uuid,revoked_at timestamptz,expires_at timestamptz')+' where j.id=s.id and j.expires_at<s.expires_at']

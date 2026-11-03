"""Rejoue le journal de révocations (operations/revocation_journal.py) sur la base migrée (R36).
Usage : python check_restore_journal.py <conteneur postgres> (migrations déjà appliquées)."""
import json,pathlib,subprocess,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[2]/'operations'))
import revocation_journal as rj
C=sys.argv[1]
def psql(sql):
    r=subprocess.run(['docker','exec','-i',C,'psql','-q','-X','-At','-U','postgres','-v','ON_ERROR_STOP=1'],input=sql,capture_output=True,text=True)
    if r.returncode:raise SystemExit('Échec SQL : '+r.stderr[:600])
    return r.stdout.strip()
U={k:f'00000000-0000-4000-8000-0000000000{k}' for k in ('01','02','03','04','05','06')}
O='10000000-0000-4000-8000-000000000001';O2='10000000-0000-4000-8000-000000000002'
F={k:f'20000000-0000-4000-8000-0000000000{k}' for k in ('01','02','03')}
S={k:f'30000000-0000-4000-8000-0000000000{k}' for k in ('01','02','03','04')}
# État restauré = sauvegarde ancienne (contraintes et triggers désactivés pour poser les fixtures).
psql(f"""begin;set local session_replication_role=replica;
insert into auth.users(id,email) select v::uuid,v||'@example.invalid' from unnest(array{list(U.values())}) v;
insert into public.uniion_organizations(id,name) values('{O}','Org fictive'),('{O2}','Org cible');
insert into uniion_private.membership_suspensions values('{O}','{U['01']}',false);
insert into uniion_private.super_admins values('{U['03']}',true),('{U['04']}',true);
insert into uniion_private.platform_operators values('{U['03']}',true);
insert into uniion_private.scan_workers values('{U['04']}'),('{U['05']}');
insert into uniion_private.transcription_workers values('{U['05']}');
insert into uniion_private.trusted_mfa_factors(factor_id,user_id,valid_until) values('{F['01']}','{U['01']}','2027-01-01'),('{F['02']}','{U['02']}',null),('{F['03']}','{U['03']}','2027-06-01');
insert into uniion_private.mfa_requirements values('{U['01']}',false);
insert into public.uniion_shares(id,source_id,target_id,creator,allowed,expires_at) select v::uuid,'{O}','{O2}','{U['01']}',array['{U['02']}']::uuid[],'2027-12-31' from unnest(array{list(S.values())}) v;
commit;""")
# Journal récent : ce que la source montre au moment de la restauration.
data={
 'membership_suspensions':[{'organization_id':O,'user_id':U['01'],'suspended':True}],
 'super_admins':[{'user_id':U['04'],'active':True}],
 'platform_operators':[{'user_id':U['03'],'active':False}],
 'trusted_mfa_factors':[{'factor_id':F['01'],'user_id':U['01'],'valid_until':'2027-01-01T00:00:00+00:00'},{'factor_id':F['03'],'user_id':U['03'],'valid_until':'2026-12-01T00:00:00+00:00'}],
 'mfa_requirements':[{'user_id':U['01'],'required':True},{'user_id':U['06'],'required':True}],
 'scan_workers':[{'user_id':U['04']}],'transcription_workers':[],
 'uniion_shares':[{'id':S['01'],'revoked_at':'2026-11-01T00:00:00+00:00','expires_at':'2027-12-31T00:00:00+00:00'},{'id':S['02'],'revoked_at':None,'expires_at':'2027-01-31T00:00:00+00:00'},{'id':S['04'],'revoked_at':None,'expires_at':'2027-12-31T00:00:00+00:00'}]}
psql('begin;'+';\n'.join(rj.statements(data))+';commit;')
psql('begin;'+';\n'.join(rj.statements(data))+';commit;') # rejeu idempotent
checks={
 'suspension appliquée':f"select suspended from uniion_private.membership_suspensions where user_id='{U['01']}'",
 'super-admin retiré inactif':f"select not active from uniion_private.super_admins where user_id='{U['03']}'",
 'super-admin conservé':f"select active from uniion_private.super_admins where user_id='{U['04']}'",
 'opérateur désactivé':f"select not active from uniion_private.platform_operators where user_id='{U['03']}'",
 'scanner retiré':f"select count(*)=1 from uniion_private.scan_workers",
 'worker de transcription retiré':"select count(*)=0 from uniion_private.transcription_workers",
 'facteurs de confiance non identiques retirés':f"select array_agg(factor_id::text)=array['{F['01']}'] from uniion_private.trusted_mfa_factors",
 'MFA exigée':"select count(*)=2 and bool_and(required) from uniion_private.mfa_requirements",
 'partage révoqué depuis':f"select revoked_at is not null from public.uniion_shares where id='{S['01']}'",
 'échéance de partage raccourcie':f"select expires_at='2027-01-31' from public.uniion_shares where id='{S['02']}'",
 'partage absent du journal révoqué':f"select revoked_at is not null from public.uniion_shares where id='{S['03']}'",
 'partage inchangé conservé':f"select revoked_at is null and expires_at='2027-12-31' from public.uniion_shares where id='{S['04']}'"}
failed=[name for name,q in checks.items() if psql(q)!='t']
for name in checks:print(('ÉCHEC ' if name in failed else 'ok    ')+name)
sys.exit(1 if failed else 0)

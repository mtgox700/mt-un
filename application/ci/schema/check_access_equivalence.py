"""R18 : la réécriture plpgsql des fonctions d'accès (migration 0184) doit rendre exactement les
mêmes décisions que les définitions SQL précédentes. Base vierge, migrations jusqu'à la version
précédente, jeu de cas varié, matrice des décisions avant et après, comparaison.
Usage : python check_access_equivalence.py <migration de réécriture>"""
import json,pathlib,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent;SUPA=HERE.parents[1]/'supabase';TARGET=sys.argv[1] if len(sys.argv)>1 else '202611030184_access_plpgsql.sql'
C='uniion-access-equivalence'
def sh(*a,**k):return subprocess.run(list(a),capture_output=True,text=True,**k)
def psql(sql):
    r=sh('docker','exec','-i',C,'psql','-q','-X','-At','-U','postgres','-v','ON_ERROR_STOP=1',input=sql)
    if r.returncode:raise SystemExit('Échec SQL : '+r.stderr[:500])
    return r.stdout.strip()
sh('docker','rm','-f',C);sh('docker','run','-d','--name',C,'-e','POSTGRES_PASSWORD=ci','postgres:17-alpine')
try:
    for _ in range(60):
        if sh('docker','exec',C,'pg_isready','-U','postgres').returncode==0:break
        time.sleep(1)
    time.sleep(2);psql((HERE/'supabase_stubs.sql').read_text())
    files=sorted((SUPA/'baseline').glob('*.sql'))+sorted((SUPA/'migrations').glob('*.sql'))
    names=[f.name for f in files];cut=names.index(TARGET)
    for f in files[:cut]:psql(f.read_text())
    O='10000000-0000-4000-8000-0000000000aa';O2='10000000-0000-4000-8000-0000000000bb'
    users={n:f'00000000-0000-4000-8000-0000000000{i:02d}' for i,n in enumerate(['normal','suspendu','sans_droit','expire','revoque','historique','ecriture','mfa_non_valide','mfa_exigee','non_membre'],1)}
    sessions={n:u.replace('00000000-','50000000-') for n,u in users.items()}
    R={n:f'20000000-0000-4000-8000-0000000000{i:02d}' for i,n in enumerate(['doc','doc_ancien','dossier_elimine','derive_ia','agenda_sans_module','doc_autre_org','doc_non_commercial'],1)}
    fixture=["begin","set local session_replication_role=replica",
     f"insert into public.uniion_organizations(id,name) values('{O}','Org'),('{O2}','Org 2')"]
    fixture+=[f"insert into auth.users(id,email) values('{u}','{n}@example.invalid')" for n,u in users.items()]
    fixture+=[f"insert into auth.sessions(id,user_id,aal) values('{sessions[n]}','{u}','aal1')" for n,u in users.items()]
    fixture+=[f"insert into public.uniion_memberships(organization_id,user_id,joined_at) values('{O}','{u}',now()-interval '10 days')" for n,u in users.items() if n!='non_membre']
    fixture+=[f"update public.uniion_memberships set joined_at=now()-interval '1 day' where user_id='{users['historique']}'",
     f"insert into uniion_private.membership_suspensions values('{O}','{users['suspendu']}',true)",
     f"insert into auth.mfa_factors(id,user_id,status,factor_type) values(gen_random_uuid(),'{users['mfa_non_valide']}','verified','totp')",
     f"insert into uniion_private.mfa_requirements values('{users['mfa_exigee']}',true)"]
    for m in ('documents','dossiers'):
        fixture+=[f"insert into public.uniion_module_access values('{O}','{m}',true,true,'included','2099-01-01')",
                  f"insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference,reason) values('{O}','{m}','paid',now()-interval '30 days','2099-01-01','FICTIF','Recette')"]
    fixture+=[f"insert into public.uniion_module_access values('{O}','reporting',true,true,'included','2099-01-01')",
              f"insert into uniion_private.module_catalog(id,name,available) values('reporting','Reporting',true) on conflict(id) do update set available=true"]
    for n,u in users.items():
        if n=='sans_droit':continue
        for m in ('documents','dossiers','agenda','reporting'):
            fixture.append(f"insert into public.uniion_permissions values('{O}','{u}','{m}','read')")
            if n=='ecriture':fixture.append(f"insert into public.uniion_permissions values('{O}','{u}','{m}','write')")
    mods={'doc':'documents','doc_ancien':'documents','dossier_elimine':'dossiers','derive_ia':'dossiers','agenda_sans_module':'agenda','doc_autre_org':'documents','doc_non_commercial':'reporting'}
    for n,rid in R.items():
        org=O2 if n=='doc_autre_org' else O
        created="now()-interval '5 days'" if n=='doc_ancien' else 'now()'
        fixture.append(f"insert into public.uniion_resources(id,organization_id,module,title,created_at) values('{rid}','{org}','{mods[n]}','{n}',{created})")
        for un,u in users.items():
            valid="now()-interval '1 day'" if un=='expire' else "'2099-01-01'"
            revoked='now()' if un=='revoque' else 'null'
            fixture.append(f"insert into public.uniion_resource_grants values('{org}','{rid}','{u}',{str(un=='ecriture').lower()},false,{valid},{revoked})")
    fixture+=[f"insert into uniion_private.case_disposals(organization_id,resource_id,version,reason,state,requester) values('{O}','{R['dossier_elimine']}',1,'obsolete','approved','{users['normal']}')",
              f"insert into uniion_private.ai_case_derivatives values('{O}',gen_random_uuid(),'{users['normal']}','{R['derive_ia']}','[]')","commit"]
    psql(';\n'.join(fixture)+';')
    def matrix():
        result={}
        for n,u in users.items():
            claims=json.dumps({'sub':u,'session_id':sessions[n],'aal':'aal1','role':'authenticated'})
            rows=psql(f"select set_config('request.jwt.claims','{claims}',false);"
              +"select json_build_object('session',uniion_private.session_allowed(),'member',uniion_private.member('"+O+"'),'member2',uniion_private.member('"+O2+"'),"
              +"'access',(select json_object_agg(r.title||':'||w,uniion_private.resource_access(r.organization_id,r.id,w)) from public.uniion_resources r cross join (values(false),(true)) v(w)),"
              +"'commercial',(select json_object_agg(m,uniion_private.commercial_allowed('"+O+"',m)) from unnest(array['documents','dossiers','agenda','reporting']) m))").splitlines()[-1]
            rls=psql(f"select set_config('request.jwt.claims','{claims}',false);set role authenticated;select count(*) from public.uniion_resources;reset role").splitlines()[-1]
            result[n]={**json.loads(rows),'rls_rows':int(rls)}
        return result
    before=matrix();psql((SUPA/'migrations'/TARGET).read_text());after=matrix()
    granted=sum(v for row in before.values() for v in row['access'].values())
    diff=[n for n in users if before[n]!=after[n]]
    print(f'{len(users)} utilisateurs × {len(R)} ressources × lecture/écriture : {granted} accès accordés avant, décisions {"identiques" if not diff else "DIFFÉRENTES"}')
    for n,row in before.items():print('  ',n,'rls',row['rls_rows'],'membre',row['member'],sorted(k for k,v in row['access'].items() if v))
    for n in diff:print('  écart',n,json.dumps(before[n],sort_keys=True),'->',json.dumps(after[n],sort_keys=True))
    if granted==0 or not any(r['rls_rows'] for r in before.values()):raise SystemExit('Jeu de cas inopérant : aucun accès accordé')
    sys.exit(1 if diff else 0)
finally:sh('docker','rm','-f',C)

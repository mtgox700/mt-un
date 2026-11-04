"""R19 : la sélection des candidats de la recherche (migration 0187) doit rendre exactement les
mêmes résultats. Base vierge, migrations jusqu'à la version précédente, jeu search_fixture.sql,
recherches avant et après, comparaison. Usage : python check_search_equivalence.py"""
import json,pathlib,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent;SUPA=HERE.parents[1]/'supabase';TARGET='202611040187_message_search_candidates.sql';C='uniion-search-equivalence'
def sh(*a,**k):return subprocess.run(list(a),capture_output=True,text=True,**k)
def psql(sql):
    r=sh('docker','exec','-i',C,'psql','-q','-X','-At','-U','postgres','-v','ON_ERROR_STOP=1',input=sql)
    if r.returncode:raise SystemExit('Échec SQL : '+r.stderr[:500])
    return r.stdout.strip()
CLAIMS=json.dumps({'sub':'60000000-0000-4000-8000-000000000001','session_id':'61000000-0000-4000-8000-000000000001','aal':'aal2','role':'authenticated'})
QUERIES=[{'query':q} for q in ('budget','bureau','caché','secret','transfert','négociation','introuvable')]+[{'query':'budget','before':'ffffffff-ffff-4fff-bfff-ffffffffffff'}]
def search():
    out=[]
    for p in QUERIES:
        row=psql(f"select set_config('request.jwt.claims','{CLAIMS}',false);select public.uniion_messaging('62000000-0000-4000-8000-000000000001','search','{json.dumps(p,ensure_ascii=False)}')").splitlines()[-1]
        out.append(json.loads(row))
    return out
sh('docker','rm','-f',C);sh('docker','run','-d','--name',C,'-e','POSTGRES_PASSWORD=ci','postgres:17-alpine')
try:
    for _ in range(60):
        if sh('docker','exec',C,'pg_isready','-U','postgres').returncode==0:break
        time.sleep(1)
    time.sleep(2);psql((HERE/'supabase_stubs.sql').read_text())
    files=sorted((SUPA/'baseline').glob('*.sql'))+sorted((SUPA/'migrations').glob('*.sql'))
    cut=[f.name for f in files].index(TARGET)
    for f in files[:cut]:psql(f.read_text())
    psql((HERE/'search_fixture.sql').read_text())
    before=search();psql((SUPA/'migrations'/TARGET).read_text());after=search()
    found=sum(len(r['rows']) for r in before)
    same=before==after
    print(f"{len(QUERIES)} recherches, {found} résultats avant : {'identiques' if same else 'DIFFÉRENTS'}")
    if not found:raise SystemExit('Jeu de cas inopérant : aucun résultat')
    if not same:
        for p,b,a in zip(QUERIES,before,after):
            if b!=a:print('  écart',p,len(b['rows']),'->',len(a['rows']))
    sys.exit(0 if same else 1)
finally:sh('docker','rm','-f',C)

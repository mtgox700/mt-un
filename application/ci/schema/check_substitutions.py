"""Rejoue les migrations sur un Postgres vierge et vérifie que chaque replace() des migrations
par substitution de texte trouve bien son fragment dans la définition existante (constat R52).
Usage : python check_substitutions.py <conteneur postgres>  (stubs déjà appliqués)"""
import pathlib,re,subprocess,sys
C=sys.argv[1];ROOT=pathlib.Path(__file__).resolve().parents[2]/'supabase'
def psql(sql=None,file=None):
    r=subprocess.run(['docker','exec','-i',C,'psql','-q','-X','-At','-U','postgres','-v','ON_ERROR_STOP=1']+(['-c',sql] if sql else []),input=file,capture_output=True,text=True)
    if r.returncode:raise SystemExit('Échec : '+(r.stderr or '')[:400])
    return r.stdout
def defs():
    # Définitions de fonctions et de contraintes : certaines migrations réécrivent aussi des CHECK.
    return psql("select string_agg(pg_get_functiondef(p.oid),E'\\n\\x1e\\n') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','uniion_private') and p.prokind='f'")+psql("select string_agg(pg_get_constraintdef(c.oid),E'\\n') from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname in ('public','uniion_private')")
LIT=re.compile(r"""(?:E'((?:[^'\\]|''|\\.)*)'|'((?:[^']|'')*)'|\$(\w*)\$(.*?)\$\3\$)""",re.S)
def first_literal(s):
    m=LIT.match(s.lstrip())
    if not m:return None
    if m.group(1) is not None:return m.group(1).replace("''","'").encode().decode('unicode_escape')
    if m.group(2) is not None:return m.group(2).replace("''","'")
    return m.group(4)
missing=0;checked=0
for f in sorted((ROOT/'baseline').glob('*.sql'))+sorted((ROOT/'migrations').glob('*.sql')):
    text=f.read_text()
    if 'pg_get_functiondef' in text:
        before=defs()
        for m in re.finditer(r"\breplace\(\s*\w+\s*,",text):
            lit=first_literal(text[m.end():])
            if lit is None:continue
            checked+=1
            if lit not in before:
                missing+=1;print(f'INTROUVABLE {f.name} : {lit[:90]!r}')
    psql(file=text)
print(f'{checked} remplacements vérifiés, {missing} sans fragment trouvé avant migration')
sys.exit(1 if missing else 0)

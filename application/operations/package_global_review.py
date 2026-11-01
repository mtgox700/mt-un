"""Read-only global review snapshot; never includes private runtime stores."""
from pathlib import Path
import hashlib,json,re,zipfile
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'application/planification/review-globale-2026-11-01'
OUT.mkdir(exist_ok=True)
excluded_names={'node_modules','__pycache__','.git','.build-tools','.DS_Store','venv','.venv','dist','coverage','.pytest_cache'}
allowed_hidden={'.github','.gitignore','.env.example','.gitkeep','.gitattributes','.dockerignore'}
known=set()
def collect(v,key=''):
 if isinstance(v,dict):
  for k,x in v.items():collect(x,k)
 elif isinstance(v,list):
  for x in v:collect(x,key)
 elif isinstance(v,str) and len(v)>=12 and any(w in key.lower() for w in ('password','secret','token','private_key','apikey','api_key')):known.add(v)
# Read known secrets only in memory, never print/store them in the package.
for p in ROOT.rglob('*.json'):
 if any(x.startswith('.local-') for x in p.parts):
  try:collect(json.loads(p.read_text()))
  except (ValueError,UnicodeError,OSError):pass
files=[];omitted=[]
for p in sorted(ROOT.rglob('*')):
 if not p.is_file():continue
 rel=p.relative_to(ROOT);reason=None
 if OUT in p.parents:continue
 if p.is_symlink():reason='lien symbolique'
 elif any(x in excluded_names or (x.startswith('.') and x not in allowed_hidden) for x in rel.parts):reason='dépendance, cache ou état privé'
 elif p.suffix.lower() in {'.zip','.tar','.gz','.7z','.aesgcm','.enc','.key','.pem','.p12','.sqlite','.sqlite3','.db','.pyc','.dump'}:reason='archive imbriquée, base, clé ou binaire privé'
 if reason:
  omitted.append({'path':str(rel),'reason':reason});continue
 data=p.read_bytes()
 content=data.decode('utf-8',errors='replace')
 if any(s in content for s in known) or re.search(r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}',content) or re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',content):
  omitted.append({'path':str(rel),'reason':'détection de secret : fichier exclu sans afficher sa valeur'});continue
 files.append((p,rel,data))
guide='''# uniion — package global pour revue de code

Snapshot du 1er novembre 2026, préparé pour lecture et revue, sans reprise des développements ni déploiement.

## Point de départ

L’application courante se trouve dans `application/`. État transmis : S09 A à E réalisés en local fictif ; lot F et qualification de production S16 ouverts. Lire d’abord :

- `application/preuves/S09-E/BILAN.md` et `RESTE-A-FAIRE.md` ;
- `application/planification/S09-demarrage/HANDOVER-S09.md` ;
- `application/docs/S09-CONSERVATION-RESTAURATION.md` ;
- les décisions validées de `planification/S00/`.

Les anciens bilans et prototypes sont historiques. Ils ne remplacent pas le code actuel ni ses limites documentées. Les fichiers `sources/` sont des références synchronisées en lecture seule.

## Périmètre

Sources Python et frontend, migrations SQL, tests, opérations, CI, configuration exemple, documentation, planification, décisions, références visuelles et preuves disponibles. Les chemins relatifs du projet sont préservés. Les sources originales incluses ne sont pas modifiées.

`MANIFEST.json` donne taille et SHA-256 de chaque fichier inclus. `EXCLUSIONS.json` identifie les fichiers omis : secrets, états privés, environnements virtuels, dépendances, caches, Git et archives antérieures imbriquées. Les captures et fichiers fictifs de preuve restent inclus. Les dépendances se reconstruisent depuis les déclarations du projet ; les bases et services ne sont pas embarqués.

## Axes de revue prioritaires

1. Authentification/MFA, séparation des rôles, cloisonnement organisationnel, RLS et accès directs aux RPC/Storage.
2. Droits distincts audio, consentement/version, traitements durables, concurrence et révocation pendant les jobs.
3. Provenance des PV, restrictions cumulatives, relecture par second acteur et indépendance des copies diffusées.
4. Conservation : inventaire figé, approbation sans lecture métier, reprise d’effacement, tombstones et anti-réinjection.
5. Sauvegarde/restauration : journal récent, réapplication des restrictions, erreurs partielles et absence d’admission implicite.
6. Coffre local : données partiellement synchronisées, nettoyage confirmé, expiration, multi-onglets et changements d’identité.
7. Architecture modulaire, gestion des erreurs, tests manquants et limites de la qualification matérielle.

## Vérifications non destructives

Avec Python 3.11+ et un Node compatible avec les dépendances du dépôt :

```sh
cd application
python3 -B -m unittest discover -s tests -p 'test_*.py'
python3 -B scripts/check_boundaries.py
node --test frontend/state/*.test.mjs frontend/host/*.test.mjs
cd frontend
node build.mjs
```

Installer les dépendances déclarées au préalable. Certains tests peuvent exiger des outils locaux documentés. Les recettes `*_integration.py` et scripts `operations/` ne doivent pas être exécutés aveuglément : certains créent des comptes, modifient des droits, exécutent des suppressions approuvées ou restaurent des données fictives. Lire leur portée et préparer un environnement isolé ; les comptes, clés, modèles de transcription et services locaux ne sont pas fournis.

## Format attendu du retour

Pour chaque constat : priorité, fichier et ligne, scénario reproductible, impact, preuve et correction proposée. Distinguer bug confirmé, risque à tester et amélioration facultative. Ne pas déduire une garantie de production des résultats locaux historiques.

## Confidentialité et limites

Aucune publication ni transmission externe effectuée. Contrôle des secrets connus localement, des JWT et clés privées ; ce contrôle n’est pas une garantie exhaustive. Consulter les exclusions avant diffusion. Ce package de revue n’est pas une sauvegarde exploitable ni un installateur autonome.
'''
manifest={'date':'2026-11-01','purpose':'revue de code globale','files':{str(rel):{'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()} for _,rel,data in files}}
extras={'LIRE-EN-PREMIER.md':guide.encode(),'MANIFEST.json':json.dumps(manifest,ensure_ascii=False,indent=2).encode(),'EXCLUSIONS.json':json.dumps(omitted,ensure_ascii=False,indent=2).encode()}
target=OUT/'UNIION-PROJET-GLOBAL-REVIEW-2026-11-01.zip'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for _,rel,data in files:z.writestr('projet/'+str(rel),data)
 for name,data in extras.items():z.writestr(name,data)
with zipfile.ZipFile(target) as z:
 assert z.testzip() is None
 assert len(z.namelist())==len(files)+len(extras)
 for _,rel,data in files:assert hashlib.sha256(z.read('projet/'+str(rel))).digest()==hashlib.sha256(data).digest()
for name,data in extras.items():(OUT/name).write_bytes(data)
receipt={'archive':target.name,'files':len(files),'entries':len(files)+len(extras),'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'verified':True,'excluded_files':len(omitted),'secret_detected_files':[x['path'] for x in omitted if x['reason'].startswith('détection')],'private_runtime_included':False}
(OUT/'VERIFICATION.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(receipt,ensure_ascii=False))

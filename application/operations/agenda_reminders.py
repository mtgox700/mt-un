"""Local-only scheduler. No credentials extracted; generic mail to Mailpit only.
Ambiguous delivery stays uncertain/sending for operator reconciliation, never blind retry.
"""
import json,subprocess,urllib.request,uuid
class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,req,fp,code,msg,headers,newurl):return None
DOCKER='/Users/mt/.docker/bin/docker'
def sql(query):
 p=subprocess.run([DOCKER,'exec','-i','supabase_db_unii','psql','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=query.encode(),capture_output=True,timeout=20)
 if p.returncode:raise RuntimeError('Local reminder database unavailable')
 return p.stdout.decode().strip()
def deliver(job):
 payload={'From':{'Email':'agenda@uniion-local.example','Name':'uniion — Agenda local'},'To':[{'Email':job['email']}],'Subject':'Rappel Agenda uniion — recette locale','Text':'Une échéance de votre agenda approche. Connectez-vous à uniion pour consulter les événements actuellement autorisés. Aucun contenu métier n’est inclus dans ce courriel.','Headers':{'Message-ID':'<'+job['id']+'@agenda.uniion.local>'}}
 req=urllib.request.Request('http://127.0.0.1:54324/api/v1/send',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'},method='POST')
 with urllib.request.build_opener(NoRedirect()).open(req,timeout=8) as res:
  if res.status!=200:raise RuntimeError('Capture mailbox unavailable')
  res.read()
def run():
 sent=uncertain=0
 for _ in range(100):
  raw=sql('select uniion_private.agenda_claim();');job=json.loads(raw) if raw else None
  if not job:break
  if job.get('skipped'):continue
  ident=str(uuid.UUID(job['id']));ok=False
  if sql("select uniion_private.agenda_preflight('"+ident+"');")!='t':continue
  try:deliver(job);ok=True;sent+=1
  except Exception:uncertain+=1
  sql("select uniion_private.agenda_finish('"+ident+"',"+('true' if ok else 'false')+");")
 return {'sent':sent,'uncertain':uncertain}
if __name__=='__main__':
 try:print(json.dumps(run()))
 except Exception:print(json.dumps({'error':'Local reminder processing failed; inspect queue status.'}));raise SystemExit(1)
